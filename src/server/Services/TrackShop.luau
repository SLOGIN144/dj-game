--!strict
-- The track shop at the decks: tracks for cash, never Robux, and no listening before buying (no
-- music library). Each bought track joins the plot's mix from the next transition (the Music
-- service reads the owned list) and adds Balance.Tracks.bonusPerTrack to its income for good.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerState = require(script.Parent.PlayerState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local TrackInfo = require(ReplicatedStorage.Shared.Music.TrackInfo)
local Tracks = require(ReplicatedStorage.Shared.Config.Tracks)

local TrackShop = {}

-- Fires (state, trackId) after a track is bought.
TrackShop.bought = Signal.new()

local TRACKS = TrackInfo.byId(Tracks)
local BUY_LOCK = 0.5 -- seconds between two purchases by one player

local lastBuy: { [Player]: number } = {}

-- How many tracks the player owns.
function TrackShop.owned(state: PlayerState.State): number
	local count = 0
	for _ in state.ownedTracks do
		count += 1
	end
	return count
end

local function buy(player: Player, trackId: unknown, result: RemoteEvent)
	if typeof(trackId) ~= "string" then
		return
	end
	local state = PlayerState.get(player)
	if not state then
		return
	end
	local clock = os.clock()
	if clock - (lastBuy[player] or 0) < BUY_LOCK then
		return
	end
	lastBuy[player] = clock

	local track = TRACKS[trackId]
	local reason: string? = nil
	if not track then
		reason = "unknown"
	elseif state.ownedTracks[trackId] then
		reason = "owned"
	elseif state.cash < track.price then
		reason = "cash"
	end
	if reason or not track then
		result:FireClient(player, trackId, false, reason)
		return
	end

	PlayerState.setCash(state, state.cash - track.price)
	state.ownedTracks[trackId] = true
	PlayerState.updateIncome(state)
	PlayerState.mirror(state)
	result:FireClient(player, trackId, true, nil)
	TrackShop.bought:fire(state, trackId)
end

function TrackShop.start()
	local request = Remotes.event("BuyTrack")
	local result = Remotes.event("TrackResult")
	request.OnServerEvent:Connect(function(player, trackId)
		buy(player, trackId, result)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastBuy[player] = nil
	end)
end

return TrackShop
