--!strict
-- The goal tracker (GDD: HUD): the host's portrait and their goals, top left, with a tick for each
-- one done and a count for the ones that count up ("Catch 3 Perfect drops 1/3"). Finished goals
-- and counts come from the "GoalsDone" and "GoalProgress" Player attributes, owned tracks from
-- "OwnedTracks". Once all are done the tracker says so and fades away; moving on brings up the
-- next host's goals.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local GoalCheck = require(ReplicatedStorage.Shared.Economy.GoalCheck)
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

local function counts(): { [string]: number }
	local result = {}
	local text = player:GetAttribute("GoalProgress")
	if typeof(text) == "string" then
		for id, count in string.gmatch(text, "([^,=]+)=(%d+)") do
			result[id] = tonumber(count) or 0
		end
	end
	return result
end

local function tracksOwned(): number
	local count = 0
	local text = player:GetAttribute("OwnedTracks")
	if typeof(text) == "string" then
		for _ in string.gmatch(text, "[^,]+") do
			count += 1
		end
	end
	return count
end

local function fadeAway(panel: Frame)
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
		if panel.Parent then -- not rebuilt for the next location meanwhile
			panel.Visible = false
		end
	end)
end

-- Builds the tracker for a location's host. Returns its panel and how to refresh it.
local function build(gui: ScreenGui, locationId: string): (Frame?, () -> ())
	local host = GoalsConfig[locationId]
	if not host then
		return nil, function() end
	end

	local panel = Style.panel(gui, "Tracker", UDim2.fromOffset(280, 40 + ROW * #host.goals), UDim2.fromOffset(12, 64))
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
		local done, progress, owned = doneSet(), counts(), tracksOwned()
		local all = true
		for _, goal in host.goals do
			local row = rows[goal.id]
			if done[goal.id] then
				row.Text = "✓  " .. goal.text
				row.TextColor3 = Style.MUTED
			else
				all = false
				local needed = GoalCheck.needed(goal)
				local count = if needed > 1
					then string.format("  %d/%d", GoalCheck.count(goal, progress, owned), needed)
					else ""
				row.Text = string.format("○  %s%s  (%s)", goal.text, count, Format.money(goal.reward))
				row.TextColor3 = Style.TEXT
			end
		end
		header.Text = if all then "All done, nice!" else host.name .. "'s goals"
		if all and not faded then
			faded = true
			task.delay(FADE_AFTER, function()
				if panel.Parent then
					fadeAway(panel)
				end
			end)
		end
	end
	update()
	return panel, update
end

function GoalTracker.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Goals"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3
	gui.Parent = player:WaitForChild("PlayerGui")

	local plot = OwnPlot.wait()
	local panel: Frame? = nil
	local refresh: () -> () = function() end
	local function rebuild()
		if panel then
			panel:Destroy()
			panel = nil
		end
		local locationId = plot:GetAttribute("LocationId")
		if typeof(locationId) == "string" then
			panel, refresh = build(gui, locationId)
		end
	end
	plot:GetAttributeChangedSignal("LocationId"):Connect(rebuild)
	for _, attribute in { "GoalsDone", "GoalProgress", "OwnedTracks" } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			refresh()
		end)
	end
	Remotes.event("GoalDone").OnClientEvent:Connect(function()
		Sfx.play("goal")
	end)
	rebuild()
end

return GoalTracker
