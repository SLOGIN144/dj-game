--!strict
-- The button pads on each plot and buying from them. The server checks every purchase: only the
-- plot's owner, only a shown button, only with enough cash.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Income = require(ReplicatedStorage.Shared.Economy.Income)
local PlayerState = require(script.Parent.PlayerState)
local PlotLayout = require(ReplicatedStorage.Shared.Config.PlotLayout)
local PlotView = require(script.Parent.Parent.World.PlotView)
local Pricing = require(ReplicatedStorage.Shared.Economy.Pricing)
local Unlocks = require(ReplicatedStorage.Shared.Economy.Unlocks)

local Shop = {}

local BUY_LOCK = 0.3 -- seconds between two purchases by one player, so one step buys once
local STAND_RADIUS = PlotLayout.padSize / 2 + 1 -- a character this close to a pad's centre stands on it
local CHECK_EVERY = 0.1

local lastBuy: { [Player]: number } = {}
-- The pad (item id) that appeared under its owner's feet. It only works once they step off, so
-- buying one button never buys the next one by accident.
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
	local position = state.plot:GetPivot():PointToObjectSpace(part.Position)
	for index, slot in PlotLayout.buttonSlots do
		if Vector2.new(position.X - slot.X, position.Z - slot.Z).Magnitude <= STAND_RADIUS then
			return index
		end
	end
	return nil
end

-- Shows the next items of the owner's location as button pads.
function Shop.refresh(state: PlayerState.State)
	local effects = Pricing.effects(state.locationId)
	local pads: { PlotView.Pad } = {}
	for _, item in Unlocks.visible(state.locationId, state.bought) do
		table.insert(pads, { item = item, effect = effects[item.id] })
	end

	PlotView.setPads(state.plot, pads, function(itemId, hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if character and Players:GetPlayerFromCharacter(character) == state.player then
			Shop.buy(state, itemId)
		end
	end)

	local slot = standingSlot(state)
	blocked[state.player] = if slot and pads[slot] then pads[slot].item.id else nil
end

-- Buys an item for the player if they may and can afford it. Returns whether it was bought.
function Shop.buy(state: PlayerState.State, itemId: string): boolean
	local player = state.player
	local now = os.clock()
	if blocked[player] == itemId or now - (lastBuy[player] or 0) < BUY_LOCK then
		return false
	end
	if not Unlocks.canBuy(state.locationId, state.bought, itemId) then
		return false
	end
	local effect = Pricing.effects(state.locationId)[itemId]
	if state.cash < effect.cost then
		return false
	end

	lastBuy[player] = now
	PlayerState.setCash(state, state.cash - effect.cost)
	state.bought[itemId] = true
	PlotView.showItem(state.plot, state.locationId, itemId, true)
	PlayerState.setIncome(state, Income.perSecond(state.locationId, state.bought))
	Shop.refresh(state)

	if Unlocks.isComplete(state.locationId, state.bought) then
		-- Move on to the next location comes in build step 3.
		print(string.format("[Shop] %s finished %s", player.Name, state.locationId))
	end
	return true
end

-- Unblocks pads once their owner has stepped off them.
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
		lastBuy[player] = nil
		blocked[player] = nil
	end)
end

return Shop
