--!strict
-- What the owner can order next, and what happens when an ordered item is placed. The next few
-- items of the location are the "shelf" the phone lists (mirrored on the player as "Shelf");
-- Services/Delivery takes the cash when they order and calls `place` once the box is at its outline.
-- The server checks everything: only a shelf item can be placed, once. Once a location is finished,
-- the Move On pad stands on the floor (Services/Progression moves the plot on).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlayerState = require(script.Parent.PlayerState)
local PlotLayout = require(ReplicatedStorage.Shared.Config.PlotLayout)
local PlotSpace = require(ReplicatedStorage.Shared.Util.PlotSpace)
local PlotView = require(script.Parent.Parent.World.PlotView)
local Pricing = require(ReplicatedStorage.Shared.Economy.Pricing)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Unlocks = require(ReplicatedStorage.Shared.Economy.Unlocks)

local Shop = {}

-- Fires (state, itemId) after an item is built, (state) once the location's last item is built, and
-- (state) when the owner steps on the Move On pad.
Shop.bought = Signal.new()
Shop.completed = Signal.new()
Shop.moveOnPressed = Signal.new()

local MOVE_ON = "MoveOn" -- what `blocked` holds while the Move On pad is under its owner's feet

local STAND_RADIUS = PlotLayout.padSize / 2 + 1 -- a character this close to a pad's centre stands on it
local CHECK_EVERY = 0.1

-- Whether the Move On pad appeared under its owner's feet. It only works once they step off, so
-- finishing the location never moves them on by accident.
local blocked: { [Player]: string? } = {}

local function root(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

-- The plot slot the player stands on, if any.
local function standingSlot(state: PlayerState.State): number?
	local part = root(state.player)
	if not part then
		return nil
	end
	local position = PlotSpace.origin(state.plot):PointToObjectSpace(part.Position)
	for index, slot in PlotSpace.layout(state.locationId).buttonSlots do
		if Vector2.new(position.X - slot.X, position.Z - slot.Z).Magnitude <= STAND_RADIUS then
			return index
		end
	end
	return nil
end

local function isOwner(state: PlayerState.State, hit: BasePart): boolean
	local character = hit:FindFirstAncestorOfClass("Model")
	return character ~= nil and Players:GetPlayerFromCharacter(character) == state.player
end

-- Shows the Move On pad for a finished location with another one after it.
local function offerMoveOn(state: PlayerState.State): boolean
	local nextId = Unlocks.nextLocation(state.locationId)
	local location = PlotSpace.location(nextId)
	if not location or not Unlocks.isComplete(state.locationId, state.bought) then
		return false
	end
	PlotView.setMoveOn(state.plot, location.name, function(hit)
		if blocked[state.player] ~= MOVE_ON and isOwner(state, hit) then
			Shop.moveOnPressed:fire(state)
		end
	end)
	blocked[state.player] = if standingSlot(state) == PlotLayout.moveOnSlot then MOVE_ON else nil
	return true
end

-- Publishes the shelf (the next items to order, ids in a comma list on the player) and shows the
-- Move On pad once the location is finished.
function Shop.refresh(state: PlayerState.State)
	local ids = {}
	for _, item in Unlocks.visible(state.locationId, state.bought) do
		table.insert(ids, item.id)
	end
	state.player:SetAttribute("Shelf", table.concat(ids, ","))
	if offerMoveOn(state) then
		return
	end
	PlotView.clearPads(state.plot)
	blocked[state.player] = nil
end

-- Builds an item the owner ordered (its cash is already taken) if it's on the shelf and not built
-- yet. Returns whether it was built.
function Shop.place(state: PlayerState.State, itemId: string, animate: boolean?): boolean
	if state.bought[itemId] or not Unlocks.canBuy(state.locationId, state.bought, itemId) then
		return false
	end
	state.bought[itemId] = true
	PlotView.showItem(state.plot, state.locationId, itemId, animate ~= false)
	PlayerState.updateIncome(state)
	Shop.refresh(state)

	Shop.bought:fire(state, itemId)
	if Unlocks.isComplete(state.locationId, state.bought) then
		Shop.completed:fire(state)
	end
	return true
end

-- Buys and builds an item at once, with no phone, truck or boxes. The game itself never calls this:
-- it's for the Studio shortcuts and the simulation. Returns whether it worked.
function Shop.buy(state: PlayerState.State, itemId: string): boolean
	if state.bought[itemId] or not Unlocks.canBuy(state.locationId, state.bought, itemId) then
		return false
	end
	local cost = Pricing.effects(state.locationId)[itemId].cost
	if state.cash < cost then
		return false
	end
	PlayerState.setCash(state, state.cash - cost)
	return Shop.place(state, itemId, true)
end

-- Unblocks the Move On pad once its owner has stepped off it.
function Shop.start()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < CHECK_EVERY then
			return
		end
		elapsed = 0
		for player in blocked do
			local state = PlayerState.get(player)
			if not state or standingSlot(state) == nil then
				blocked[player] = nil
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		blocked[player] = nil
	end)
end

return Shop
