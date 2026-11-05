--!strict
-- Shortcuts for testing in Studio only (the debug overlay's keys, UI/DebugOverlay): cash, finishing
-- the location, an event right now, rested star DJs. The server ignores them anywhere but Studio,
-- so they can't be used in a live game.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Delivery = require(script.Parent.Delivery)
local Economy = require(script.Parent.Economy)
local Events = require(script.Parent.Events)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local PlayerState = require(script.Parent.PlayerState)
local PlotView = require(script.Parent.Parent.World.PlotView)
local Pricing = require(ReplicatedStorage.Shared.Economy.Pricing)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(script.Parent.Shop)
local Types = require(ReplicatedStorage.Shared.Types)

local DevTools = {}

local CASH_MINUTES = 10 -- "cash" gives this many minutes of the location's full income

local function finish(state: PlayerState.State)
	Delivery.cancel(state) -- an order on its way would be built twice
	local items: { Types.Item } = Items[state.locationId] or {}
	for _, item in items do
		if not state.bought[item.id] then
			state.bought[item.id] = true
			PlotView.showItem(state.plot, state.locationId, item.id, false)
			Shop.bought:fire(state, item.id)
		end
	end
	PlayerState.updateIncome(state)
	Shop.refresh(state)
	Shop.completed:fire(state)
end

function DevTools.start()
	if not RunService:IsStudio() then
		return -- the remote doesn't even exist in a live game
	end
	Remotes.event("DevCheat").OnServerEvent:Connect(function(player, command: unknown)
		local state = PlayerState.get(player)
		if not state then
			return
		end
		if command == "cash" then
			Economy.reward(state, Pricing.endIncome(state.locationId) * CASH_MINUTES * 60)
		elseif command == "finish" then
			finish(state)
		elseif command == "event" then
			Events.soon(state)
		elseif command == "rest" then
			table.clear(state.djRestUntil)
			PlayerState.mirror(state)
		end
	end)
	print("[DevTools] Studio shortcuts on: open the overlay with F2, then F3 cash, F4 finish, F6 event, F7 rest DJs")
end

return DevTools
