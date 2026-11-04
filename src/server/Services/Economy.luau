--!strict
-- Income piling up in every plot's register, and its owner collecting it by walking into it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlayerState = require(script.Parent.PlayerState)
local PlotView = require(script.Parent.Parent.World.PlotView)
local Register = require(ReplicatedStorage.Shared.Economy.Register)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local Economy = {}

-- Fires (state, amount) when an owner collects from their register.
Economy.collected = Signal.new()

local LABEL_EVERY = 0.25 -- seconds between register label updates
local COLLECT_LOCK = 0.5 -- seconds between two collects by one player

local lastCollect: { [Player]: number } = {}

local function showRegister(state: PlayerState.State)
	local full = state.income > 0 and state.register >= Register.capacity(state.income)
	PlotView.setRegister(state.plot, state.register, full)
end

local function collect(state: PlayerState.State, collected: RemoteEvent)
	local now = os.clock()
	if now - (lastCollect[state.player] or 0) < COLLECT_LOCK then
		return
	end
	local amount = math.floor(state.register)
	if amount <= 0 then
		return
	end
	lastCollect[state.player] = now
	state.register -= amount
	PlayerState.earn(state, amount)
	showRegister(state)
	collected:FireClient(state.player, amount)
	Economy.collected:fire(state, amount)
end

-- Gives the player cash outside the register (goal rewards, tips) and shows the "+$".
function Economy.reward(state: PlayerState.State, amount: number)
	local whole = math.floor(amount)
	if whole <= 0 then
		return
	end
	PlayerState.earn(state, whole)
	Remotes.event("Collected"):FireClient(state.player, whole)
end

-- Fills the registers and lets each plot's owner collect from theirs.
function Economy.start(plots: { Model })
	local collected = Remotes.event("Collected")

	for _, plot in plots do
		PlotView.register(plot).Touched:Connect(function(hit)
			local character = hit:FindFirstAncestorOfClass("Model")
			local player = if character then Players:GetPlayerFromCharacter(character) else nil
			local state = if player then PlayerState.get(player) else nil
			if state and state.plot == plot then
				collect(state, collected)
			end
		end)
	end

	local sinceLabel = 0
	RunService.Heartbeat:Connect(function(dt)
		sinceLabel += dt
		local updateLabels = sinceLabel >= LABEL_EVERY
		if updateLabels then
			sinceLabel = 0
		end
		for _, state in PlayerState.all() do
			state.stats.playSeconds += dt
			state.register = Register.fill(state.register, state.income, dt)
			if updateLabels then
				showRegister(state)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastCollect[player] = nil
	end)
end

return Economy
