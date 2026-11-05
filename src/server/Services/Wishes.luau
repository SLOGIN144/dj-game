--!strict
-- Guests with wishes (Config/Wishes). While the owner is in their club with a few friends around,
-- every minute or two one guest wishes for something: a drop caught, a new track, another item built
-- or the register emptied. The owner just does it within the time; the guest cheers and pays a tip. A
-- wish that lapses costs nothing. The wish is published on the plot for the clients, which draw the
-- bubble over that guest: "Wish" (the kind), "WishGuest" (which friend), "WishEndsAt" (server time)
-- and "WishCount" (how many were granted, so clients can cheer).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Blockouts = require(ReplicatedStorage.Shared.Config.Blockouts)
local Decks = require(script.Parent.Decks)
local Economy = require(script.Parent.Economy)
local PlayerState = require(script.Parent.PlayerState)
local PlotSpace = require(ReplicatedStorage.Shared.Util.PlotSpace)
local Progression = require(script.Parent.Progression)
local Shop = require(script.Parent.Shop)
local TrackShop = require(script.Parent.TrackShop)
local Tracks = require(ReplicatedStorage.Shared.Config.Tracks)
local Unlocks = require(ReplicatedStorage.Shared.Economy.Unlocks)
local Wishes = {}

local CHECK_EVERY = 1
local random = Random.new()

type Wish = { kind: string, endsAt: number }

type Entry = {
	onFloor: number, -- seconds the owner has spent in their club since the last wish
	nextAt: number, -- seconds in the club when the next wish comes up
	wish: Wish?,
	granted: number,
}

local entries: { [Player]: Entry } = {}

local function nextDelay(): number
	return random:NextNumber(Balance.Wishes.minSeconds, Balance.Wishes.maxSeconds)
end

local function inClub(state: PlayerState.State): boolean
	local character = state.player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return root ~= nil and root:IsA("BasePart") and PlotSpace.contains(state.plot, root.Position)
end

-- The wishes that make sense for the owner right now.
local function possible(state: PlayerState.State): { string }
	local kinds = {}
	local blockout = Blockouts[state.locationId]
	if blockout and state.bought[blockout.decks.itemId] then
		table.insert(kinds, "drop")
	end
	for _, track in Tracks do
		if not state.ownedTracks[track.id] then
			table.insert(kinds, "track")
			break
		end
	end
	if #Unlocks.visible(state.locationId, state.bought) > 0 then
		table.insert(kinds, "order")
	end
	if state.register >= math.max(1, state.income * Balance.Wishes.collectSeconds) then
		table.insert(kinds, "collect")
	end
	return kinds
end

local function publish(state: PlayerState.State, entry: Entry)
	local plot = state.plot
	local wish = entry.wish
	if wish then
		local guests = plot:GetAttribute("Guests")
		local count = if typeof(guests) == "number" then math.max(1, math.floor(guests)) else 1
		plot:SetAttribute("WishGuest", random:NextInteger(1, count))
		plot:SetAttribute("WishEndsAt", workspace:GetServerTimeNow() + (wish.endsAt - os.clock()))
		plot:SetAttribute("Wish", wish.kind)
	else
		plot:SetAttribute("Wish", nil)
		plot:SetAttribute("WishGuest", nil)
		plot:SetAttribute("WishEndsAt", nil)
	end
	plot:SetAttribute("WishCount", entry.granted)
end

local function begin(state: PlayerState.State, entry: Entry): boolean
	local kinds = possible(state)
	if #kinds == 0 then
		return false
	end
	entry.wish = { kind = kinds[random:NextInteger(1, #kinds)], endsAt = os.clock() + Balance.Wishes.waitSeconds }
	publish(state, entry)
	return true
end

-- Ends the owner's wish; `granted` pays the tip and tells the clients to cheer.
local function finish(state: PlayerState.State, entry: Entry, granted: boolean)
	entry.wish = nil
	entry.onFloor = 0
	entry.nextAt = nextDelay()
	if granted then
		entry.granted += 1
		Economy.reward(state, math.max(Balance.Wishes.minTip, math.floor(state.baseIncome * Balance.Wishes.tipSeconds)))
	end
	publish(state, entry)
end

-- What the owner just did, which grants a wish of that kind if one is up.
local function did(state: PlayerState.State, kind: string)
	local entry = entries[state.player]
	local wish = if entry then entry.wish else nil
	if entry and wish and wish.kind == kind then
		finish(state, entry, true)
	end
end

-- Starts counting towards the owner's first wish.
function Wishes.begin(state: PlayerState.State)
	entries[state.player] = { onFloor = 0, nextAt = nextDelay(), wish = nil, granted = 0 }
end

-- Makes the next wish come up at the next check (Studio testing, Services/DevTools).
function Wishes.soon(state: PlayerState.State)
	local entry = entries[state.player]
	if entry and not entry.wish then
		entry.onFloor = entry.nextAt
	end
end

-- Forgets a leaving owner's wish.
function Wishes.stop(state: PlayerState.State)
	entries[state.player] = nil
end

function Wishes.start()
	Decks.caught:connect(function(state: PlayerState.State)
		did(state, "drop")
	end)
	TrackShop.bought:connect(function(state: PlayerState.State)
		did(state, "track")
	end)
	Shop.bought:connect(function(state: PlayerState.State)
		did(state, "order")
	end)
	Economy.collected:connect(function(state: PlayerState.State)
		did(state, "collect")
	end)
	-- The old floor is sealed and the new one has its own friends: start afresh.
	Progression.leaving:connect(function(state: PlayerState.State)
		local entry = entries[state.player]
		if entry then
			entry.wish = nil
			entry.onFloor = 0
			entry.nextAt = nextDelay()
			publish(state, entry)
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < CHECK_EVERY then
			return
		end
		local step = elapsed
		elapsed = 0
		for player, entry in entries do
			local state = PlayerState.get(player)
			if not state then
				continue
			end
			local wish = entry.wish
			if wish then
				if os.clock() >= wish.endsAt then
					finish(state, entry, false)
				end
				continue
			end
			local guests = state.plot:GetAttribute("Guests")
			if not inClub(state) or typeof(guests) ~= "number" or guests < Balance.Wishes.minGuests then
				continue
			end
			entry.onFloor += step
			if entry.onFloor >= entry.nextAt then
				if not begin(state, entry) then
					entry.onFloor = 0
					entry.nextAt = nextDelay() -- nothing to wish for yet; try again later
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		entries[player] = nil
	end)
end

return Wishes
