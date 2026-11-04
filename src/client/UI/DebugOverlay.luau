--!strict
-- Dev-only overlay, toggled with F2 in Studio: the mix plan of the plot you hear, each deck's
-- drift from the plan, the phase error between the decks during a blend (the GDD wants under 1/16
-- beat), the next drop, income and FPS. While it's open, F3 gives cash, F4 finishes the location,
-- F6 starts an event and F7 rests every star DJ (the server only allows these in Studio).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MixTimeline = require(ReplicatedStorage.Shared.Music.MixTimeline)
local PlotMixes = require(script.Parent.Parent.Controllers.PlotMixes)
local PlotMusic = require(script.Parent.Parent.Controllers.PlotMusic)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TrackInfo = require(ReplicatedStorage.Shared.Music.TrackInfo)

local DebugOverlay = {}

local TOGGLE_KEY = Enum.KeyCode.F2
local REFRESH = 0.2
local CHEATS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.F3] = "cash",
	[Enum.KeyCode.F4] = "finish",
	[Enum.KeyCode.F6] = "event",
	[Enum.KeyCode.F7] = "rest",
}

local function phaseError(a: number, b: number): number
	local diff = (a - b) % 1
	return math.min(diff, 1 - diff)
end

local function describe(): string
	local lines = {}
	local plot = PlotMusic.listening()
	local entry = if plot then PlotMixes.get(plot) else nil
	if not plot or not entry then
		return "No mix in earshot"
	end
	local now = PlotMixes.now()
	table.insert(lines, string.format("Hearing %s", plot.Name))

	local layers, main = MixTimeline.at(entry.plan, PlotMixes.tracks, now)
	for _, segment in entry.plan do
		local track = PlotMixes.tracks[segment.trackId]
		if track then
			table.insert(
				lines,
				string.format(
					"#%d %-16s %-5s start %+7.1fs  drop %+7.1fs  end %+7.1fs  x%.4f",
					segment.n,
					segment.trackId,
					segment.mixIn,
					segment.startTime - now,
					MixTimeline.dropTime(segment, track) - now,
					MixTimeline.endTime(segment, track) - now,
					segment.speed
				)
			)
		end
	end
	if main then
		local section = TrackInfo.sectionAt(main.track, main.beat)
		table.insert(
			lines,
			string.format("Main #%d beat %.2f (%s), speed %.4f", main.segment.n, main.beat, section.kind, main.speed)
		)
	end
	for index, deck in PlotMusic.report() do
		table.insert(
			lines,
			string.format(
				"Deck %s: #%s %s ready=%s playing=%s drift %+.1f ms speed %.4f",
				if index == 1 then "A" else "B",
				tostring(deck.n),
				tostring(deck.trackId),
				tostring(deck.ready),
				tostring(deck.playing),
				deck.drift * 1000,
				deck.speed
			)
		)
	end
	if #layers == 2 then
		local a, b = PlotMusic.heardBeat(1), PlotMusic.heardBeat(2)
		if a and b then
			table.insert(lines, string.format("Blend phase error (heard): %.4f beat (limit 0.0625)", phaseError(a, b)))
		end
	end
	local drop = MixTimeline.nextDrop(entry.drops, now)
	if drop then
		table.insert(lines, string.format("Next drop in %.1f s", drop.time - now))
	end
	return table.concat(lines, "\n")
end

function DebugOverlay.start()
	if not RunService:IsStudio() then
		return
	end
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "DebugOverlay"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.Enabled = false

	local text = Instance.new("TextLabel")
	text.Name = "Info"
	text.AnchorPoint = Vector2.new(0, 1)
	text.Position = UDim2.new(0, 8, 1, -8)
	text.Size = UDim2.fromOffset(640, 260)
	text.BackgroundColor3 = Color3.new(0, 0, 0)
	text.BackgroundTransparency = 0.35
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.Font = Enum.Font.Code
	text.TextSize = 13
	text.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == TOGGLE_KEY then
			gui.Enabled = not gui.Enabled
		elseif gui.Enabled and CHEATS[input.KeyCode] then
			Remotes.event("DevCheat"):FireServer(CHEATS[input.KeyCode])
		end
	end)

	local frames, sinceFps, fps, sinceRefresh = 0, 0, 0, 0
	RunService.RenderStepped:Connect(function(dt)
		frames += 1
		sinceFps += dt
		if sinceFps >= 1 then
			fps, frames, sinceFps = frames / sinceFps, 0, 0
		end
		sinceRefresh += dt
		if not gui.Enabled or sinceRefresh < REFRESH then
			return
		end
		sinceRefresh = 0
		local income = player:GetAttribute("Income")
		text.Text = string.format(
			"%s\nIncome %s/s   FPS %.0f   [F3 cash  F4 finish  F6 event  F7 rest DJs]",
			describe(),
			tostring(if typeof(income) == "number" then math.floor(income * 100) / 100 else 0),
			fps
		)
	end)
end

return DebugOverlay
