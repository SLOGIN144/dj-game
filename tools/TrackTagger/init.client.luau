--!strict
-- Track Tagger: dev-only tool that measures a track's BPM and first downbeat, marks its sections
-- and cue point, and prints the finished entry for src/shared/Config/Tracks.luau.
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

local BeatMath = require(ReplicatedStorage.Shared.Util.BeatMath)
local TaggerState = require(script.TaggerState)
local TaggerUI = require(script.TaggerUI)
local TapTempo = require(script.TapTempo)
local TrackExport = require(script.TrackExport)
local TrackPlayer = require(script.TrackPlayer)
local Types = require(ReplicatedStorage.Shared.Types)

local LOAD_TIMEOUT = 15 -- seconds to wait for a track to load
local NUDGE = 0.005 -- seconds the downbeat moves per , or . press
local NUDGE_FINE = 0.001 -- the same with Shift held
local SEEK_WITHOUT_GRID = 2 -- seconds per arrow press before there is a beat grid
local BEST_TAP_COUNT = 32

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
local loading = false

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

-- Fills the title (and id) from the asset's Creator Store info, when Roblox has it. The uploader is
-- usually a distributor account rather than the artist, so it only goes into the artist hint.
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
	end
	local creator = info.Creator
	if type(creator) == "table" and type(creator.Name) == "string" then
		TaggerUI.setFieldHint(ui, "artist", string.format("artist (uploaded by %s)", creator.Name))
	end
end

local function loadTrack()
	if loading then
		return
	end
	local digits = string.match(ui.assetBox.Text, "%d+")
	local assetId = if digits then tonumber(digits) else nil
	if not assetId or assetId <= 0 then
		problem("Paste a track's asset ID (the number from its Creator Store page).")
		return
	end

	loading = true
	status(string.format("Loading %d...", assetId))
	local ok, reason = track:load(assetId, LOAD_TIMEOUT)
	loading = false
	if not ok then
		loadedAssetId = nil
		problem(string.format("Couldn't load %d: %s", assetId, reason or "unknown error"))
		return
	end

	loadedAssetId = assetId
	state = TaggerState.new()
	for _, name in { "id", "title", "artist" } do
		TaggerUI.setField(ui, name, "")
	end
	TaggerUI.setFieldHint(ui, "artist", "artist")
	TaggerUI.setExport(ui, "")
	task.spawn(prefillFromAssetInfo, assetId)
	redraw()
	status(
		string.format("Loaded (%s long). Press Space to play, then tap T on every beat.", formatTime(track:getLength()))
	)
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

local function export()
	local entry = TaggerState.toTrack(state, readMeta())
	if not entry then
		problem("Tap the BPM (T) and mark the first downbeat (D) before exporting.")
		return
	end
	local text = TrackExport.toLua(entry)
	TaggerUI.setExport(ui, text)
	print("[TrackTagger] Paste this into src/shared/Config/Tracks.luau:\n" .. text)

	local warnings = TrackExport.validate(entry)
	for _, message in warnings do
		warn("[TrackTagger] " .. message)
	end
	if #warnings == 0 then
		status("Exported. Copy it from the box below or the Output window.")
	else
		problem(string.format("Exported with %d warning(s): %s", #warnings, table.concat(warnings, "; ")))
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
	if not fit then
		status(string.format("Keep tapping... (%d of at least %d)", #state.taps, TapTempo.MIN_TAPS))
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
	if loading then
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
		status("Taps cleared. Tap T on every beat.")
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

	if fit then
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

	if state.firstBeat and beat then
		local bar, beatInBar = BeatMath.barAndBeat(beat)
		table.insert(lines, string.format("downbeat  %.3f s   now at bar %d, beat %d", state.firstBeat, bar, beatInBar))
		table.insert(lines, string.format("cue       beat %d (bar %d)", state.cuePoint, state.cuePoint // 4 + 1))
	else
		table.insert(lines, "downbeat  -   press D on a 1 after tapping")
	end

	local parts = {}
	for _, section in state.sections do
		table.insert(parts, string.format("%s %d", section.kind, section.startBeat))
	end
	table.insert(lines, "sections  " .. (if #parts > 0 then table.concat(parts, " · ") else "-   keys 1-5"))
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

ui.loadButton.Activated:Connect(loadTrack)
ui.assetBox.FocusLost:Connect(function(enterPressed: boolean)
	if enterPressed then
		loadTrack()
	end
end)

ui.overview.MouseButton1Down:Connect(function(x: number)
	if not loadedAssetId then
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

print("[TrackTagger] Ready. Paste a track's asset ID and press Load.")
