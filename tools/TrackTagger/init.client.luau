--!strict
-- Track Tagger: dev-only tool that works out a track's BPM, first downbeat, sections, cue point
-- and a starting energy rating from its audio, and prints the finished entry for
-- src/shared/Config/Tracks.luau. "Auto-tag picks" does this for every track in Picks.luau.
-- The keys are only for fixing a result by ear.
-- It lives in its own place (tagger.project.json), runs in Play mode and is never shipped.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

if not RunService:IsStudio() then
	return
end

local AutoTag = require(script.AutoTag)
local BeatMath = require(ReplicatedStorage.Shared.Util.BeatMath)
local Picks = require(script.Picks)
local TaggerState = require(script.TaggerState)
local TaggerUI = require(script.TaggerUI)
local TapTempo = require(script.TapTempo)
local TempoEstimate = require(script.TempoEstimate)
local TrackAnalysis = require(script.TrackAnalysis)
local TrackExport = require(script.TrackExport)
local TrackPlayer = require(script.TrackPlayer)
local Types = require(ReplicatedStorage.Shared.Types)

local LOAD_TIMEOUT = 15 -- seconds to wait for a track to load
local NUDGE = 0.005 -- seconds the downbeat moves per , or . press
local NUDGE_FINE = 0.001 -- the same with Shift held
local SEEK_WITHOUT_GRID = 2 -- seconds per arrow press before there is a beat grid
local BEST_TAP_COUNT = 32
local TAPS_BEFORE_CHECK = 8 -- taps needed before they are compared with the automatic tempo

local SECTION_KEYS: { [Enum.KeyCode]: Types.SectionKind } = {
	[Enum.KeyCode.One] = "intro",
	[Enum.KeyCode.Two] = "build",
	[Enum.KeyCode.Three] = "drop",
	[Enum.KeyCode.Four] = "breakdown",
	[Enum.KeyCode.Five] = "outro",
}

-- Hide chat, the backpack and the player list so the tagger has the whole screen.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
end)

local ui = TaggerUI.new(Players.LocalPlayer:WaitForChild("PlayerGui"))
local track = TrackPlayer.new(workspace)
local state = TaggerState.new()
local loadedAssetId: number? = nil
local busy = false -- loading or analysing; keys wait until it's done
local loadCount = 0 -- bumps on every load, so a running analysis of an older track stops
local analysis: TrackAnalysis.Result? = nil
local analysisProgress: number? = nil -- 0..1 while the track is being read

local function formatTime(seconds: number): string
	return string.format("%d:%05.2f", seconds // 60, seconds % 60)
end

local function status(text: string)
	TaggerUI.setStatus(ui, text, false)
end

local function problem(text: string)
	TaggerUI.setStatus(ui, text, true)
end

local function cueTime(): number?
	local fit, firstBeat = state.fit, state.firstBeat
	if not fit or not firstBeat then
		return nil
	end
	return BeatMath.beatToTime(state.cuePoint, fit.bpm, firstBeat)
end

-- Redraws everything on the overview bar except the playhead.
local function redraw()
	local length = track:getLength()
	local bpm = if state.fit then state.fit.bpm else nil
	TaggerUI.drawGrid(ui, length, bpm, TaggerState.gridOrigin(state))
	TaggerUI.drawSections(ui, length, state.sections, bpm, state.firstBeat)
	TaggerUI.drawMarkers(ui, length, state.firstBeat, cueTime())
end

local function findPick(assetId: number): Picks.Pick?
	for _, pick in Picks do
		if pick.assetId == assetId then
			return pick
		end
	end
	return nil
end

-- Fills title, id and genre from the asset's Creator Store name. The uploader is usually a
-- distributor account rather than the artist, so it only goes into the artist hint.
local function prefillFromAssetInfo(assetId: number)
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfoAsync(assetId, Enum.InfoType.Asset)
	end)
	if not ok or type(info) ~= "table" then
		return
	end
	if type(info.Name) == "string" and TaggerUI.getField(ui, "title") == "" then
		TaggerUI.setField(ui, "title", info.Name)
		TaggerUI.setField(ui, "id", TrackExport.makeId(info.Name))
		local isTechHouse = string.find(string.lower(info.Name), "tech house", 1, true) ~= nil
		TaggerUI.setField(ui, "genre", if isTechHouse then "tech house" else "house")
	end
	local creator = info.Creator
	if type(creator) == "table" and type(creator.Name) == "string" then
		TaggerUI.setFieldHint(ui, "artist", string.format("artist (uploaded by %s)", creator.Name))
	end
end

local function fillFields(assetId: number)
	for _, name in { "id", "title", "artist" } do
		TaggerUI.setField(ui, name, "")
	end
	TaggerUI.setFieldHint(ui, "artist", "artist")
	local pick = findPick(assetId)
	if pick then
		TaggerUI.setField(ui, "id", pick.id)
		TaggerUI.setField(ui, "title", pick.title)
		TaggerUI.setField(ui, "artist", pick.artist)
		TaggerUI.setField(ui, "genre", pick.genre)
	else
		task.spawn(prefillFromAssetInfo, assetId)
	end
end

local function sectionList(sections: { Types.Section }): string
	local parts = {}
	for _, section in sections do
		table.insert(parts, string.format("%s %d", section.kind, section.startBeat))
	end
	return table.concat(parts, " · ")
end

-- Loads a track and works everything out from its audio. Returns true when the analysis worked.
local function loadAndAnalyse(assetId: number): boolean
	busy = true
	loadCount += 1
	local thisLoad = loadCount
	analysis, analysisProgress = nil, nil
	status(string.format("Loading %d...", assetId))
	local loaded, reason = track:load(assetId, LOAD_TIMEOUT)
	if not loaded then
		busy, loadedAssetId = false, nil
		problem(string.format("Couldn't load %d: %s", assetId, reason or "unknown error"))
		return false
	end

	loadedAssetId = assetId
	state = TaggerState.new()
	fillFields(assetId)
	TaggerUI.setExport(ui, "")
	TaggerUI.drawWaveform(ui, {})
	redraw()

	analysisProgress = 0
	local result, failure = AutoTag.run(track, function(progress)
		analysisProgress = progress
		status(string.format("Reading the track to find its beat and sections... %d%%", math.round(progress * 100)))
	end, function()
		return loadCount ~= thisLoad
	end)
	if loadCount ~= thisLoad then
		return false -- a newer load took over
	end
	analysisProgress = nil
	busy = false

	if not result then
		problem(string.format("Couldn't work this track out (%s). Tap T on every beat and press D on a 1.", failure))
		return false
	end
	analysis = result
	TaggerState.applyAnalysis(state, result.grid.bpm, result.grid.firstBeat, result.sections, result.cuePoint)
	TaggerUI.setField(ui, "energy", tostring(result.energy))
	TaggerUI.drawWaveform(ui, result.waveform)
	redraw()
	status(
		string.format(
			"Done: %s BPM, %d sections. Press Space to listen (the light flashes white on every 1), then E to export.",
			result.grid.bpm,
			#result.sections
		)
	)
	return true
end

local function loadFromBox()
	if busy then
		return
	end
	local digits = string.match(ui.assetBox.Text, "%d+")
	local assetId = if digits then tonumber(digits) else nil
	if not assetId or assetId <= 0 then
		problem("Paste a track's asset ID (the number from its Creator Store page).")
		return
	end
	loadAndAnalyse(assetId)
end

local function seekTo(time: number)
	track:seek(time)
	TaggerState.endTapSession(state)
end

-- Jumps to the next bar line (Shift: beat) once there is a beat grid, or a few seconds before that.
local function seekBy(direction: number, fine: boolean)
	local position = track:getPosition()
	local target = TaggerState.jumpTarget(state, position, direction, fine)
	if not target then
		target = position + direction * (if fine then SEEK_WITHOUT_GRID / 4 else SEEK_WITHOUT_GRID)
	end
	seekTo(target)
end

-- Reads the text boxes. Numbers that don't parse become -1, so export flags them.
local function readMeta(): TaggerState.Meta
	local function number(name: string): number
		return tonumber(TaggerUI.getField(ui, name)) or -1
	end
	local title = TaggerUI.getField(ui, "title")
	local id = TaggerUI.getField(ui, "id")
	return {
		id = if id ~= "" then id else TrackExport.makeId(title),
		assetId = loadedAssetId or 0,
		title = title,
		artist = TaggerUI.getField(ui, "artist"),
		genre = TaggerUI.getField(ui, "genre"),
		energy = number("energy"),
		tier = number("tier"),
		price = number("price"),
	}
end

-- The entry for the loaded track, its warnings, and a one-line summary of how sure the analysis is.
local function buildEntry(): (Types.Track?, { string }, string)
	local entry = TaggerState.toTrack(state, readMeta())
	if not entry then
		return nil, {}, ""
	end
	local summary = string.format("%s: %s BPM, first beat %.3f s", entry.id, entry.bpm, entry.firstBeat)
	if analysis and state.fit and state.fit.tapCount == 0 then
		summary ..= string.format(
			", grid drift %d ms, beat fit %.2f, downbeat clarity %.2f, downbeat from %s",
			math.round(analysis.grid.driftMs),
			analysis.grid.beatConfidence,
			analysis.grid.downbeatConfidence,
			analysis.grid.downbeatMethod
		)
	end
	summary ..= ", sections " .. sectionList(entry.sections)
	return entry, TrackExport.validate(entry), summary
end

local function export()
	local entry, warnings, summary = buildEntry()
	if not entry then
		problem("No beat grid yet. Load a track, or tap T on every beat and press D on a 1.")
		return
	end
	local text = TrackExport.toLua(entry)
	TaggerUI.setExport(ui, text)
	print("[TrackTagger] " .. summary)
	print("[TrackTagger] Paste this into src/shared/Config/Tracks.luau:\n" .. text)
	for _, message in warnings do
		warn("[TrackTagger] " .. message)
	end
	if #warnings == 0 then
		status("Exported. Copy it from the box below or the Output window.")
	else
		problem(string.format("Exported with %d warning(s): %s", #warnings, table.concat(warnings, "; ")))
	end
end

-- Analyses every track in Picks.luau and prints all their entries at the end, ready to paste.
local function autoTagPicks()
	if busy then
		return
	end
	local entries, failed = {}, {}
	for i, pick in Picks do
		ui.assetBox.Text = tostring(pick.assetId)
		local ok = loadAndAnalyse(pick.assetId)
		local entry, warnings, summary = buildEntry()
		if ok and entry then
			print(string.format("[TrackTagger] %d/%d %s", i, #Picks, summary))
			for _, message in warnings do
				warn(string.format("[TrackTagger] %s: %s", pick.id, message))
			end
			table.insert(entries, TrackExport.toLua(entry))
		else
			table.insert(failed, pick.id)
			warn(string.format("[TrackTagger] %d/%d %s: analysis failed", i, #Picks, pick.id))
		end
	end
	local all = table.concat(entries, "\n")
	TaggerUI.setExport(ui, all)
	print(string.format("[TrackTagger] All picks (%d of %d), paste into Tracks.luau:\n%s", #entries, #Picks, all))
	if #failed == 0 then
		status(
			string.format("Auto-tagged all %d picks. The entries are in the box below and the Output window.", #entries)
		)
	else
		problem(string.format("Auto-tagged %d of %d picks; failed: %s", #entries, #Picks, table.concat(failed, ", ")))
	end
end

local function tap()
	if not track:isPlaying() then
		problem("Play the track first (Space), then tap T on every beat.")
		return
	end
	TaggerState.addTap(state, track:getPosition())
	redraw()
	local fit = state.fit
	-- After a few taps, compare with the automatic tempo to catch half- or double-time tapping.
	local hint = if fit
			and analysis
			and fit.tapCount >= TAPS_BEFORE_CHECK
		then TempoEstimate.checkTaps(fit.bpm, { bpm = analysis.grid.bpm, confidence = analysis.grid.beatConfidence })
		else nil
	if not fit or fit.tapCount == 0 then
		status(string.format("Keep tapping... (%d of at least %d)", #state.taps, TapTempo.MIN_TAPS))
	elseif hint then
		problem(hint)
	elseif fit.tapCount < BEST_TAP_COUNT then
		status(
			string.format("%s BPM so far. Keep tapping for accuracy (%d/%d).", fit.bpm, fit.tapCount, BEST_TAP_COUNT)
		)
	else
		status(string.format("%s BPM. Now press D exactly on a 1 (the first beat of a bar).", fit.bpm))
	end
end

local function markDownbeat()
	if not TaggerState.markDownbeat(state, track:getPosition()) then
		problem("Tap the BPM first (T on every beat), then press D on a 1.")
		return
	end
	redraw()
	status(
		string.format(
			"First downbeat at %.3f s. Check the light flashes white on each 1; use , and . if it's early or late.",
			state.firstBeat or 0
		)
	)
end

local function markSection(kind: Types.SectionKind)
	if not TaggerState.markSection(state, kind, track:getPosition()) then
		problem("Tap the BPM (T) and mark the first downbeat (D) before marking sections.")
		return
	end
	redraw()
	status(string.format("Marked %s. Sections snap to the nearest bar.", kind))
end

local function onKey(key: Enum.KeyCode)
	if busy then
		return
	end
	if not loadedAssetId then
		problem("Load a track first.")
		return
	end
	local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

	if key == Enum.KeyCode.Space then
		if track:isPlaying() then
			track:pause()
		else
			track:play()
		end
	elseif key == Enum.KeyCode.Left then
		seekBy(-1, shift)
	elseif key == Enum.KeyCode.Right then
		seekBy(1, shift)
	elseif key == Enum.KeyCode.Home then
		seekTo(state.firstBeat or 0) -- bar 1 once it's known, so arrow jumps stay on bar lines
	elseif key == Enum.KeyCode.T then
		tap()
	elseif key == Enum.KeyCode.R then
		TaggerState.resetTaps(state)
		redraw()
		status(if state.fit then "Taps cleared; back to the automatic tempo." else "Taps cleared. Tap T on every beat.")
	elseif key == Enum.KeyCode.B then
		TaggerState.toggleRounding(state)
		redraw()
		status(if state.roundBpm then "Whole-BPM rounding on." else "Whole-BPM rounding off (2 decimals).")
	elseif key == Enum.KeyCode.D then
		markDownbeat()
	elseif key == Enum.KeyCode.Comma or key == Enum.KeyCode.Period then
		local amount = if shift then NUDGE_FINE else NUDGE
		TaggerState.nudgeDownbeat(state, if key == Enum.KeyCode.Comma then -amount else amount)
		redraw()
	elseif SECTION_KEYS[key] then
		markSection(SECTION_KEYS[key])
	elseif key == Enum.KeyCode.Backspace then
		if TaggerState.removeSectionAt(state, track:getPosition()) then
			redraw()
			status("Section removed.")
		end
	elseif key == Enum.KeyCode.C then
		if TaggerState.setCue(state, track:getPosition()) then
			redraw()
			status(string.format("Cue point at beat %d.", state.cuePoint))
		else
			problem("Tap the BPM (T) and mark the first downbeat (D) before setting the cue point.")
		end
	elseif key == Enum.KeyCode.E then
		export()
	end
end

local function readoutText(position: number, length: number, beat: number?): string
	local fit = state.fit
	local lines = { string.format("time      %s / %s", formatTime(position), formatTime(length)) }

	if fit and fit.tapCount == 0 then
		table.insert(lines, string.format("bpm       %s   found automatically (tap T to override)", fit.bpm))
	elseif fit then
		table.insert(
			lines,
			string.format(
				"bpm       %s   measured %.2f from %d taps, worst tap %d ms, rounding %s",
				fit.bpm,
				fit.measuredBpm,
				fit.tapCount,
				math.round(fit.maxErrorMs),
				if state.roundBpm then "on" else "off"
			)
		)
	else
		table.insert(lines, string.format("bpm       -   tap T on every beat while it plays (%d taps)", #state.taps))
	end

	if analysisProgress then
		table.insert(lines, string.format("auto      reading the track... %d%%", math.round(analysisProgress * 100)))
	elseif analysis then
		table.insert(
			lines,
			string.format(
				"auto      grid drift %d ms, beat fit %.2f, downbeat clarity %.2f",
				math.round(analysis.grid.driftMs),
				analysis.grid.beatConfidence,
				analysis.grid.downbeatConfidence
			)
		)
	else
		table.insert(lines, "auto      -")
	end

	if state.firstBeat and beat then
		local bar, beatInBar = BeatMath.barAndBeat(beat)
		table.insert(lines, string.format("downbeat  %.3f s   now at bar %d, beat %d", state.firstBeat, bar, beatInBar))
		table.insert(lines, string.format("cue       beat %d (bar %d)", state.cuePoint, state.cuePoint // 4 + 1))
	else
		table.insert(lines, "downbeat  -")
	end

	local sections = sectionList(state.sections)
	table.insert(lines, "sections  " .. (if sections ~= "" then sections else "-"))
	return table.concat(lines, "\n")
end

local function update()
	if not loadedAssetId then
		return
	end
	local position, length = track:getPosition(), track:getLength()
	if length <= 0 then
		return
	end
	TaggerUI.setPlayhead(ui, position / length)

	local beat = TaggerState.beatAt(state, position)
	if beat then
		local flash = math.max(0, 1 - (beat - math.floor(beat)) * 4)
		if state.firstBeat then
			local bar, beatInBar = BeatMath.barAndBeat(beat)
			TaggerUI.setBeatLight(ui, flash, beatInBar == 1, string.format("%d.%d", bar, beatInBar))
		else
			TaggerUI.setBeatLight(ui, flash, false, "tap grid")
		end
	else
		TaggerUI.setBeatLight(ui, 0, false, "")
	end
	TaggerUI.setReadout(ui, readoutText(position, length, beat))
end

ui.loadButton.Activated:Connect(loadFromBox)
ui.autoButton.Activated:Connect(autoTagPicks)
ui.assetBox.FocusLost:Connect(function(enterPressed: boolean)
	if enterPressed then
		loadFromBox()
	end
end)

ui.overview.MouseButton1Down:Connect(function(x: number)
	if not loadedAssetId or busy then
		return
	end
	local fraction = (x - ui.overview.AbsolutePosition.X) / ui.overview.AbsoluteSize.X
	seekTo(fraction * track:getLength())
end)

-- Roblox's default controls may mark keys like Space as "processed" even with no character,
-- so only a focused text box blocks the tagger's keys.
UserInputService.InputBegan:Connect(function(input: InputObject)
	if input.UserInputType ~= Enum.UserInputType.Keyboard or UserInputService:GetFocusedTextBox() then
		return
	end
	onKey(input.KeyCode)
end)

RunService.RenderStepped:Connect(update)

print("[TrackTagger] Ready. Paste a track's asset ID and press Load, or press Auto-tag picks.")
