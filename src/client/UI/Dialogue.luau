--!strict
-- Lines from the location's host character (GDD: dialogue): a small panel with their portrait (a
-- coloured circle with their initial until there's art), name and one line. Lines queue up; each
-- stays a few seconds, or until tapped.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GoalsConfig = require(ReplicatedStorage.Shared.Config.Goals)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Style = require(script.Parent.Style)

local Dialogue = {}

local BASE_SECONDS = 3 -- every line stays at least this long
local PER_CHARACTER = 0.045 -- plus this much per character, so longer lines can be read
local SLIDE = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

type Line = { locationId: string, text: string }

local queue: { Line } = {}
local showing = false
local skip = false
local panel: Frame
local portrait: Frame
local initial: TextLabel
local nameLabel: TextLabel
local lineLabel: TextLabel

local SHOWN = UDim2.new(0.5, 0, 0, 150) -- under the HUD's money, boost and notice
local HIDDEN = UDim2.new(0.5, 0, 0, 120)

local function showNext()
	local line = table.remove(queue, 1)
	if not line then
		showing = false
		TweenService:Create(panel, SLIDE, { Position = HIDDEN, BackgroundTransparency = 1 }):Play()
		task.delay(SLIDE.Time, function()
			if not showing then
				panel.Visible = false
			end
		end)
		return
	end
	showing = true
	local host = GoalsConfig[line.locationId]
	portrait.BackgroundColor3 = if host then host.colour else Style.accent()
	initial.Text = if host then string.sub(host.name, 1, 1) else "?"
	nameLabel.Text = if host then string.format("%s  ·  %s", host.name, host.role) else ""
	lineLabel.Text = line.text
	panel.Visible = true
	panel.Position = HIDDEN
	panel.BackgroundTransparency = 1
	TweenService:Create(panel, SLIDE, { Position = SHOWN, BackgroundTransparency = Style.PANEL_TRANSPARENCY }):Play()

	skip = false
	local untilTime = os.clock() + BASE_SECONDS + #line.text * PER_CHARACTER
	task.spawn(function()
		while os.clock() < untilTime and not skip do
			task.wait(0.1)
		end
		showNext()
	end)
end

function Dialogue.say(locationId: string, text: string)
	table.insert(queue, { locationId = locationId, text = text })
	if not showing then
		showNext()
	end
end

function Dialogue.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Dialogue"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8

	panel = Style.panel(gui, "Panel", UDim2.new(0.9, 0, 0, 78), HIDDEN, Vector2.new(0.5, 0))
	panel.Visible = false
	Style.stroke(panel, Style.accent())
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(480, 78)
	limit.Parent = panel

	portrait = Instance.new("Frame")
	portrait.Name = "Portrait"
	portrait.Size = UDim2.fromOffset(54, 54)
	portrait.Position = UDim2.fromOffset(12, 12)
	portrait.BorderSizePixel = 0
	portrait.Parent = panel
	Style.corner(portrait, UDim.new(0.5, 0))
	initial = Style.label(portrait, "Initial", "", UDim2.fromScale(0.6, 0.6), UDim2.fromScale(0.2, 0.2), Style.PANEL)

	nameLabel = Style.label(panel, "Name", "", UDim2.new(1, -90, 0, 18), UDim2.fromOffset(78, 10), Style.GOLD)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	lineLabel =
		Style.label(panel, "Line", "", UDim2.new(1, -90, 0, 40), UDim2.fromOffset(78, 30), Style.TEXT, Style.BODY)
	lineLabel.TextXAlignment = Enum.TextXAlignment.Left
	lineLabel.TextWrapped = true

	-- Tapping the panel skips to the next line.
	local tap = Instance.new("TextButton")
	tap.Name = "Skip"
	tap.Size = UDim2.fromScale(1, 1)
	tap.BackgroundTransparency = 1
	tap.Text = ""
	tap.Parent = panel
	tap.Activated:Connect(function()
		skip = true
	end)

	Remotes.event("Say").OnClientEvent:Connect(function(locationId: unknown, text: unknown)
		if typeof(locationId) == "string" and typeof(text) == "string" then
			Dialogue.say(locationId, text)
		end
	end)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return Dialogue
