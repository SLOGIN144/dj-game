--!strict
-- A bouncing arrow over the next thing to do on the player's own plot (GDD acceptance: a new
-- player knows what to do within 30 seconds). It follows the host's goals: the free first
-- button, the register to collect from, the button a goal asks for, the decks for a drop, the
-- booking board for a star DJ. Once a location is finished it points at Move On. Only the owner
-- sees it; it's a hint, the server decides everything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Blockouts = require(ReplicatedStorage.Shared.Config.Blockouts)
local GoalsConfig = require(ReplicatedStorage.Shared.Config.Goals)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local OwnPlot = require(script.Parent.Parent.Controllers.OwnPlot)
local PlotSpace = require(ReplicatedStorage.Shared.Util.PlotSpace)
local Style = require(script.Parent.Style)
local Types = require(ReplicatedStorage.Shared.Types)

local Guide = {}

local CHECK_EVERY = 0.5
local BOUNCE = 0.6 -- studs up and down
local NEAR = 7 -- studs: standing this close to the target hides the arrow

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

local function find(folder: Instance?, name: string): BasePart?
	local found = if folder then folder:FindFirstChild(name, true) else nil
	if found and found:IsA("BasePart") then
		return found
	elseif found then
		return found:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

-- The part a goal points at, if there's one to point at right now.
local function goalTarget(plot: Model, locationId: string, goal: Types.Goal): (BasePart?, string?)
	local items = plot:FindFirstChild("Items")
	local blockout = Blockouts[locationId]
	if goal.kind == "collect" then
		local register = find(plot, "Register")
		return register, "Collect"
	elseif goal.kind == "buy" and goal.target then
		-- The phone does the ordering; once the box is in hand the outline is the thing to find.
		return find(plot:FindFirstChild("Outlines"), "Outline_" .. goal.target), "Place here"
	elseif (goal.kind == "drop" or goal.kind == "perfect") and blockout then
		return find(items, blockout.decks.itemId), "Play"
	elseif goal.kind == "book" then
		local list: { Types.Item } = Items[locationId] or {}
		for _, item in list do
			if item.feature == "booking" then
				return find(items, item.id), "Book"
			end
		end
	end
	return nil, nil
end

-- What to point at: Move On, else the box to pick up or the outline to put it on, else the first
-- goal with a target. (Waiting for the truck, or choosing on the phone, has nothing in the world to
-- point at: the phone button pulses until the first order.)
local function target(plot: Model): (BasePart?, string?)
	local locationId = PlotSpace.locationId(plot)
	if not locationId then
		return nil, nil
	end
	local moveOn = find(plot:FindFirstChild("Pads"), "Pad_MoveOn")
	if moveOn then
		return moveOn, "Move on"
	end
	local order = player:GetAttribute("OrderState")
	if order == "ready" then
		return find(plot:FindFirstChild("Boxes"), "Body"), "Pick up"
	elseif order == "carrying" then
		local carrying = player:GetAttribute("Carrying")
		if typeof(carrying) == "string" then
			return find(plot:FindFirstChild("Outlines"), "Outline_" .. carrying), "Place here"
		end
	elseif order == "transit" then
		return nil, nil
	end
	local host = GoalsConfig[locationId]
	if not host then
		return nil, nil
	end
	local done = doneSet()
	for _, goal in host.goals do
		if not done[goal.id] then
			local part, text = goalTarget(plot, locationId, goal)
			if part then
				return part, text
			end
		end
	end
	return nil, nil
end

function Guide.start()
	local gui = Instance.new("BillboardGui")
	gui.Name = "Guide"
	gui.Size = UDim2.fromOffset(120, 64)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 140
	gui.Enabled = false
	local text = Style.label(gui, "Text", "", UDim2.new(1, 0, 0, 24), UDim2.fromOffset(0, 0), Style.GOLD)
	text.TextStrokeTransparency = 0.3
	local arrow = Style.label(gui, "Arrow", "▼", UDim2.new(1, 0, 0, 36), UDim2.fromOffset(0, 24), Style.GOLD)
	arrow.TextStrokeTransparency = 0.3
	gui.Parent = player:WaitForChild("PlayerGui")

	local plot = OwnPlot.wait()
	local current: BasePart? = nil
	local since = CHECK_EVERY
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since >= CHECK_EVERY then
			since = 0
			local part, label = target(plot)
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if
				part
				and root
				and root:IsA("BasePart")
				and (root.CFrame.Position - part.CFrame.Position).Magnitude < NEAR
			then
				part = nil -- they're there
			end
			current = part
			if part then
				gui.Adornee = part
			end
			gui.Enabled = part ~= nil
			text.Text = label or ""
		end
		if current and current.Parent then
			local height = current.Size.Y / 2 + 3.5
			gui.StudsOffset = Vector3.new(0, height + math.abs(math.sin(os.clock() * 3)) * BOUNCE, 0)
		end
	end)
end

return Guide
