--!strict
-- The decks and the drop bonus on the server. The owner's client judges a press and sends when it
-- happened; the server checks it against the plot's own planned drops (Economy/Boost.judgePress):
-- only the plot's owner, standing at its decks, once per drop, with the grade worked out from the
-- press time. A Perfect or Good press starts a boost (it replaces a weaker one, never stacks), and
-- everyone sees the payoff through DropHit. Boosts are mirrored on the plot as "Boost" and
-- "BoostEndsAt" for the HUD, lights and guests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Blockouts = require(ReplicatedStorage.Shared.Config.Blockouts)
local Boost = require(ReplicatedStorage.Shared.Economy.Boost)
local Music = require(script.Parent.Music)
local PlayerState = require(script.Parent.PlayerState)
local PlotSpace = require(ReplicatedStorage.Shared.Util.PlotSpace)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local TimingJudge = require(ReplicatedStorage.Shared.Music.TimingJudge)

local Decks = {}

-- Fires (state, grade) when an owner catches a drop with a Perfect or Good press.
Decks.caught = Signal.new()

local PRESS_LOCK = 0.2 -- seconds between two presses a player can send
local EXPIRY_CHECK = 0.25

local lastPress: { [Player]: number } = {}
local usedDrops: { [Player]: { [string]: boolean } } = {}

-- Whether the owner stands at their plot's decks, and has bought them.
local function atDecks(state: PlayerState.State): boolean
	local blockout = Blockouts[state.locationId]
	if not blockout or not state.bought[blockout.decks.itemId] then
		return false
	end
	local character = state.player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return false
	end
	local stand = PlotSpace.origin(state.plot) * blockout.decks.stand
	local offset = root.Position - stand
	return Vector2.new(offset.X, offset.Z).Magnitude <= Balance.Boost.decksRange
end

local function publish(state: PlayerState.State)
	local boost = state.boost
	state.plot:SetAttribute("Boost", if boost then boost.multiplier else nil)
	state.plot:SetAttribute("BoostEndsAt", if boost then boost.endsAt else nil)
end

local function onPress(player: Player, pressTime: unknown, result: RemoteEvent, hit: RemoteEvent)
	if typeof(pressTime) ~= "number" or pressTime ~= pressTime then
		return
	end
	local state = PlayerState.get(player)
	if not state then
		return
	end
	local clock = os.clock()
	if clock - (lastPress[player] or 0) < PRESS_LOCK then
		return
	end
	lastPress[player] = clock
	if not atDecks(state) then
		return
	end

	local now = workspace:GetServerTimeNow()
	local used = usedDrops[player] or {}
	usedDrops[player] = used
	local grade: TimingJudge.Grade = Boost.judgePress(Music.drops(state.plot), pressTime, now, used)
	if grade ~= "miss" then
		state.boost = Boost.combine(state.boost, Boost.forGrade(grade, now), now)
		if grade == "perfect" then
			state.stats.perfectDrops += 1
		else
			state.stats.goodDrops += 1
		end
		publish(state)
		PlayerState.updateIncome(state)
		hit:FireAllClients(state.plot, grade)
		Decks.caught:fire(state, grade)
	end
	local boost = state.boost
	result:FireClient(player, grade, if boost then boost.multiplier else 1, if boost then boost.endsAt else 0)
end

function Decks.start()
	local press = Remotes.event("DropPress")
	local result = Remotes.event("DropResult")
	local hit = Remotes.event("DropHit")
	press.OnServerEvent:Connect(function(player, pressTime)
		onPress(player, pressTime, result, hit)
	end)

	-- Ends boosts when their time is up.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < EXPIRY_CHECK then
			return
		end
		elapsed = 0
		local now = workspace:GetServerTimeNow()
		for _, state in PlayerState.all() do
			local boost = state.boost
			if boost and boost.endsAt <= now then
				state.boost = nil
				publish(state)
				PlayerState.updateIncome(state)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastPress[player] = nil
		usedDrops[player] = nil
	end)
end

return Decks
