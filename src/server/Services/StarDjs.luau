--!strict
-- Star DJ guest sets (GDD: star DJs). The location's booking board (a feature item) gets a
-- "Book a DJ" prompt for its owner, which opens the board on their client (UI/DjBoard). Booking
-- costs cash; the DJ plays a guest set at the plot's decks: the plot's income times their
-- multiplier (like a boost, never on top of one), a bigger crowd, and the star catches every drop,
-- so everyone sees the payoff. The owner can't use the decks meanwhile. Afterwards the DJ rests
-- before they can be booked again (the rest is saved). The set is mirrored on the plot as
-- "StarDj" and "StarDjEndsAt" for the clients: the DJ's figure, the HUD and the decks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Booking = require(ReplicatedStorage.Shared.Economy.Booking)
local Crates = require(ReplicatedStorage.Shared.Economy.Crates)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Music = require(script.Parent.Music)
local PlayerState = require(script.Parent.PlayerState)
local Progression = require(script.Parent.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(script.Parent.Shop)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)

local StarDjs = {}

-- Fires (state, djId) when the owner books a star DJ.
StarDjs.booked = Signal.new()

local CHECK_EVERY = 0.1
local BOOK_LOCK = 1 -- seconds between two booking requests from one player

local caughtUpTo: { [Player]: number } = {} -- per owner, the server time up to which the star caught drops
local lastRequest: { [Player]: number } = {}

-- The biggest part of the location's booking board, once it's bought.
local function boardPart(state: PlayerState.State): BasePart?
	local items: { Types.Item } = Items[state.locationId] or {}
	local folder = state.plot:FindFirstChild("Items")
	for _, item in items do
		if item.feature ~= "booking" or not state.bought[item.id] or not folder then
			continue
		end
		local model = folder:FindFirstChild(item.id)
		local parts: { Instance } = if model then model:GetDescendants() else {}
		local biggest: BasePart? = nil
		for _, part in parts do
			if part:IsA("BasePart") and (not biggest or part.Size.Magnitude > biggest.Size.Magnitude) then
				biggest = part
			end
		end
		return biggest
	end
	return nil
end

local function attachPrompt(state: PlayerState.State)
	local part = boardPart(state)
	if not part or part:FindFirstChild("BookPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BookPrompt"
	prompt.ActionText = "Book a DJ"
	prompt.ObjectText = "Booking board"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerUserId", state.player.UserId) -- clients hide it from everyone else
	prompt.Triggered:Connect(function(player)
		if player == state.player then
			Remotes.event("OpenBoard"):FireClient(player)
		end
	end)
	prompt.Parent = part
end

local function publish(state: PlayerState.State)
	local set = state.starDj
	state.plot:SetAttribute("StarDj", if set then set.djId else nil)
	state.plot:SetAttribute("StarDjEndsAt", if set then set.endsAt else nil)
end

-- Ends the owner's guest set; `quiet` skips telling them (they're moving on).
function StarDjs.endSet(state: PlayerState.State, quiet: boolean)
	local set = state.starDj
	if not set then
		return
	end
	state.starDj = nil
	caughtUpTo[state.player] = nil
	publish(state)
	PlayerState.updateIncome(state)
	if not quiet then
		Remotes.event("DjNotice"):FireClient(state.player, "ended", set.djId)
	end
end

local function book(player: Player, djId: unknown)
	local clock = os.clock()
	if typeof(djId) ~= "string" or clock - (lastRequest[player] or 0) < BOOK_LOCK then
		return
	end
	lastRequest[player] = clock
	local state = PlayerState.get(player)
	local dj = Booking.find(djId)
	if not state or not dj then
		return
	end
	local refusal = Booking.refusal(dj, {
		locationId = state.locationId,
		hasBoard = PlayerState.hasFeature(state, "booking"),
		owned = Crates.isOwned(dj, state.ownedDjs),
		cash = state.cash,
		playing = state.starDj ~= nil,
		restUntil = state.djRestUntil[dj.id],
		now = os.time(),
	})
	if refusal then
		Remotes.event("DjNotice"):FireClient(player, "refused", dj.id, refusal)
		return
	end

	PlayerState.setCash(state, state.cash - dj.price)
	local now = workspace:GetServerTimeNow()
	state.starDj = { djId = dj.id, multiplier = dj.multiplier, endsAt = now + Balance.StarDjs.setSeconds }
	state.djRestUntil[dj.id] = os.time() + Balance.StarDjs.setSeconds + Balance.StarDjs.restSeconds
	caughtUpTo[player] = now
	publish(state)
	PlayerState.updateIncome(state)
	PlayerState.mirror(state)
	Remotes.event("DjNotice"):FireClient(player, "started", dj.id)
	StarDjs.booked:fire(state, dj.id)
end

-- During a set the star catches every drop of the plot's mix; at its end the set is over.
local function play(state: PlayerState.State, now: number, hit: RemoteEvent)
	local set = state.starDj
	if not set then
		return
	end
	local since = caughtUpTo[state.player] or now
	for _, drop in Music.drops(state.plot) do
		if drop.time > since and drop.time <= now then
			hit:FireAllClients(state.plot, "perfect")
		end
	end
	caughtUpTo[state.player] = now
	if now >= set.endsAt then
		StarDjs.endSet(state, false)
	end
end

-- Runs once a player has a plot: a booking board they already own gets its prompt.
function StarDjs.begin(state: PlayerState.State)
	attachPrompt(state)
end

function StarDjs.start()
	Remotes.event("BookDj").OnServerEvent:Connect(book)
	Shop.bought:connect(function(state: PlayerState.State)
		attachPrompt(state)
	end)
	Progression.leaving:connect(function(state: PlayerState.State)
		StarDjs.endSet(state, true)
	end)

	local hit = Remotes.event("DropHit")
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < CHECK_EVERY then
			return
		end
		elapsed = 0
		local now = workspace:GetServerTimeNow()
		for _, state in PlayerState.all() do
			play(state, now, hit)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		caughtUpTo[player] = nil
		lastRequest[player] = nil
	end)
end

return StarDjs
