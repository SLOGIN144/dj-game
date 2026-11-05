--!strict
-- Opening DJ crates at the booking board (Config/Crates, Economy/Crates). The server takes the cash
-- (never Robux), rolls the DJ from those unlocked at the owner's location, and either adds them to the
-- DJs the owner has or, for a DJ they already have, pays back part of the price. The answer goes to
-- the owner as "CrateResult": (true, crateId, djId, refund) or (false, crateId, reason). Owned DJs
-- are mirrored as "OwnedDjs" and saved (schema version 3).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CrateRules = require(ReplicatedStorage.Shared.Economy.Crates)
local PlayerState = require(script.Parent.PlayerState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local Crates = {}

-- Fires (state, djId, isNew) after a crate is opened.
Crates.opened = Signal.new()

local OPEN_LOCK = 0.8 -- seconds between two openings by one player
local random = Random.new()
local lastOpen: { [Player]: number } = {}

local function open(player: Player, crateId: unknown, result: RemoteEvent)
	local clock = os.clock()
	if typeof(crateId) ~= "string" or clock - (lastOpen[player] or 0) < OPEN_LOCK then
		return
	end
	lastOpen[player] = clock
	local state = PlayerState.get(player)
	local crate = CrateRules.find(crateId)
	if not state or not crate then
		return
	end
	local function refuse(reason: string)
		result:FireClient(player, false, crate.id, reason)
	end
	if not PlayerState.hasFeature(state, "booking") then
		return refuse("noBoard")
	end
	local pool = CrateRules.pool(state.locationId)
	if not CrateRules.hasNew(pool, state.ownedDjs) then
		return refuse("complete")
	end
	local price = CrateRules.price(crate, state.locationId)
	if state.cash < price then
		return refuse("cash")
	end
	local dj = CrateRules.roll(crate, pool, function()
		return random:NextNumber()
	end)
	if not dj then
		return refuse("complete")
	end

	PlayerState.setCash(state, state.cash - price)
	local isNew = not CrateRules.isOwned(dj, state.ownedDjs)
	local refund = 0
	if isNew then
		state.ownedDjs[dj.id] = true
		PlayerState.mirror(state)
	else
		refund = CrateRules.duplicateRefund(price)
		PlayerState.setCash(state, state.cash + refund)
	end
	result:FireClient(player, true, crate.id, dj.id, refund)
	Crates.opened:fire(state, dj.id, isNew)
end

function Crates.start()
	local result = Remotes.event("CrateResult")
	Remotes.event("OpenCrate").OnServerEvent:Connect(function(player, crateId)
		open(player, crateId, result)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastOpen[player] = nil
	end)
end

return Crates
