--!strict
-- The goal tracker (GDD: HUD): the host's portrait and their goals with a tick for each one done,
-- top left. Finished goals come from the "GoalsDone" Player attribute; once all are done the
-- tracker says so and fades away.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local GoalsConfig = require(ReplicatedStorage.Shared.Config.Goals)
local OwnPlot = require(script.Parent.Parent.Controllers.OwnPlot)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(script.Parent.Parent.Controllers.Sfx)
local Style = require(script.Parent.Style)

local GoalTracker = {}

local ROW = 26
local FADE_AFTER = 8 -- seconds the "all done" tracker stays before fading

local player = Players.LocalPlayer

local function doneSet(): { [string]: boolean }
	local set = {}
	local text = player:GetAttribute("GoalsDone")
	if typeof(text) == "string" then
		for id in string.gmatch(text, "[^,]+") do
			set[id] = true
		end
	end
	return set
end

function GoalTracker.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Goals"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3
	gui.Parent = player:WaitForChild("PlayerGui")

	local plot = OwnPlot.wait()
	while typeof(plot:GetAttribute("LocationId")) ~= "string" do
		plot:GetAttributeChangedSignal("LocationId"):Wait()
	end
	local locationId = plot:GetAttribute("LocationId") :: string
	local host = GoalsConfig[locationId]
	if not host then
		return
	end

	local panel = Style.panel(gui, "Tracker", UDim2.fromOffset(260, 40 + ROW * #host.goals), UDim2.fromOffset(12, 64))
	Style.stroke(panel, host.colour)
	local portrait = Instance.new("Frame")
	portrait.Size = UDim2.fromOffset(26, 26)
	portrait.Position = UDim2.fromOffset(10, 8)
	portrait.BackgroundColor3 = host.colour
	portrait.BorderSizePixel = 0
	portrait.Parent = panel
	Style.corner(portrait, UDim.new(0.5, 0))
	Style.label(
		portrait,
		"Initial",
		string.sub(host.name, 1, 1),
		UDim2.fromScale(0.7, 0.7),
		UDim2.fromScale(0.15, 0.15),
		Style.PANEL
	)
	local header = Style.label(
		panel,
		"Header",
		host.name .. "'s goals",
		UDim2.new(1, -50, 0, 20),
		UDim2.fromOffset(44, 11),
		host.colour
	)
	header.TextXAlignment = Enum.TextXAlignment.Left

	local rows: { [string]: TextLabel } = {}
	for index, goal in host.goals do
		local row = Style.label(
			panel,
			goal.id,
			"",
			UDim2.new(1, -20, 0, ROW - 6),
			UDim2.fromOffset(12, 38 + (index - 1) * ROW),
			Style.TEXT,
			Style.BODY
		)
		row.TextXAlignment = Enum.TextXAlignment.Left
		rows[goal.id] = row
	end

	local faded = false
	local function update()
		local done = doneSet()
		local all = true
		for _, goal in host.goals do
			local row = rows[goal.id]
			if done[goal.id] then
				row.Text = "✓  " .. goal.text
				row.TextColor3 = Style.MUTED
			else
				all = false
				row.Text = string.format("○  %s  (%s)", goal.text, Format.money(goal.reward))
				row.TextColor3 = Style.TEXT
			end
		end
		header.Text = if all then "All done, nice!" else host.name .. "'s goals"
		if all and not faded then
			faded = true
			task.delay(FADE_AFTER, function()
				local fade = TweenInfo.new(1)
				TweenService:Create(panel, fade, { BackgroundTransparency = 1 }):Play()
				for _, descendant in panel:GetDescendants() do
					if descendant:IsA("TextLabel") then
						TweenService:Create(descendant, fade, { TextTransparency = 1 }):Play()
					elseif descendant:IsA("UIStroke") then
						TweenService:Create(descendant, fade, { Transparency = 1 }):Play()
					elseif descendant:IsA("Frame") then
						TweenService:Create(descendant, fade, { BackgroundTransparency = 1 }):Play()
					end
				end
				task.delay(1, function()
					panel.Visible = false
				end)
			end)
		end
	end
	player:GetAttributeChangedSignal("GoalsDone"):Connect(update)
	Remotes.event("GoalDone").OnClientEvent:Connect(function()
		Sfx.play("goal")
	end)
	update()
end

return GoalTracker
