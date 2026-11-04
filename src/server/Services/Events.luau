--!strict
-- Club events (GDD: club life), one at a time. The prototype has one: the blown speaker. Every
-- 3-5 minutes the owner spends on their plot (once they own the speaker), it blows: it smokes and
-- sparks, the music gets quieter (clients read the plot's "SpeakerBlown") and income drops 25%,
-- until the owner holds E on it for 2 seconds. Fixing it pays a small tip.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Blockouts = require(ReplicatedStorage.Shared.Config.Blockouts)
local Economy = require(script.Parent.Economy)
local PlayerState = require(script.Parent.PlayerState)
local PlotSpace = require(ReplicatedStorage.Shared.Util.PlotSpace)
local Progression = require(script.Parent.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local Events = {}

-- Fire (state, kind) when an event starts, and (state, kind, tip) when the owner deals with it.
Events.started = Signal.new()
Events.fixed = Signal.new()

local CHECK_EVERY = 1
local random = Random.new()

type Entry = {
	onPlot: number, -- seconds the owner has spent on their plot since the last event
	nextAt: number, -- seconds on the plot when the next event happens
	props: { Instance }?, -- the smoke, sparks, prompt and marker while the speaker is blown
}

local entries: { [Player]: Entry } = {}

local function nextDelay(): number
	return random:NextNumber(Balance.Events.minSeconds, Balance.Events.maxSeconds)
end

-- The speaker item's biggest part, which the smoke and the prompt go on.
local function speakerPart(state: PlayerState.State): BasePart?
	local blockout = Blockouts[state.locationId]
	local itemId = if blockout then blockout.speakerItem else nil
	if not itemId or not state.bought[itemId] then
		return nil
	end
	local items = state.plot:FindFirstChild("Items")
	local model = if items then items:FindFirstChild(itemId) else nil
	if not model then
		return nil
	end
	local biggest: BasePart? = nil
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and (not biggest or child.Size.Magnitude > biggest.Size.Magnitude) then
			biggest = child
		end
	end
	return biggest
end

local function onPlot(state: PlayerState.State): boolean
	local character = state.player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return root ~= nil and root:IsA("BasePart") and PlotSpace.contains(state.plot, root.Position)
end

local function fix(state: PlayerState.State, entry: Entry)
	local props = entry.props
	if not props then
		return
	end
	for _, prop in props do
		prop:Destroy()
	end
	entry.props = nil
	entry.onPlot = 0
	entry.nextAt = nextDelay()
	state.speakerBlown = false
	state.plot:SetAttribute("SpeakerBlown", nil)
	PlayerState.updateIncome(state)
	local tip = math.max(1, math.floor(state.baseIncome * Balance.Events.speaker.tipSeconds))
	Economy.reward(state, tip)
	state.stats.eventsDone += 1
	Remotes.event("EventNotice"):FireClient(state.player, "speaker", false, tip)
	Events.fixed:fire(state, "speaker", tip)
end

local function blow(state: PlayerState.State, entry: Entry)
	local part = speakerPart(state)
	if not part then
		return
	end
	state.speakerBlown = true
	state.plot:SetAttribute("SpeakerBlown", true)
	PlayerState.updateIncome(state)

	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(70, 70, 76)
	smoke.Opacity = 0.35
	smoke.RiseVelocity = 3
	smoke.Size = 2
	smoke.Parent = part

	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 170, 60))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.15)
	sparks.Rate = 6
	sparks.Lifetime = NumberRange.new(0.3, 0.6)
	sparks.Speed = NumberRange.new(4, 8)
	sparks.SpreadAngle = Vector2.new(40, 40)
	sparks.Acceleration = Vector3.new(0, -20, 0)
	sparks.Parent = part

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FixPrompt"
	prompt.ActionText = "Fix"
	prompt.ObjectText = "Speaker"
	prompt.HoldDuration = Balance.Events.speaker.holdSeconds
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerUserId", state.player.UserId) -- clients hide it from everyone else
	prompt.Triggered:Connect(function(player)
		if player == state.player then
			fix(state, entry)
		end
	end)
	prompt.Parent = part

	local marker = Instance.new("BillboardGui")
	marker.Name = "EventMarker"
	marker.Size = UDim2.fromOffset(44, 44)
	marker.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 2.5, 0)
	marker.AlwaysOnTop = true
	marker.LightInfluence = 0
	marker.MaxDistance = 120
	local mark = Instance.new("TextLabel")
	mark.Size = UDim2.fromScale(1, 1)
	mark.BackgroundColor3 = Color3.fromRGB(255, 150, 40)
	mark.Text = "!"
	mark.TextScaled = true
	mark.TextColor3 = Color3.new(1, 1, 1)
	mark.Font = Enum.Font.BuilderSansExtraBold
	mark.Parent = marker
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = mark
	marker.Parent = part

	local props: { Instance } = { smoke, sparks, prompt, marker }
	entry.props = props
	Remotes.event("EventNotice"):FireClient(state.player, "speaker", true, 0)
	Events.started:fire(state, "speaker")
end

-- Starts counting towards the owner's first event.
function Events.begin(state: PlayerState.State)
	entries[state.player] = { onPlot = 0, nextAt = nextDelay() }
end

-- Forgets a leaving owner's event (their plot's props are cleared with the plot).
function Events.stop(state: PlayerState.State)
	entries[state.player] = nil
	state.plot:SetAttribute("SpeakerBlown", nil)
end

-- Ends the owner's event without a tip (they're moving on) and starts counting afresh.
local function reset(state: PlayerState.State)
	local entry = entries[state.player]
	if not entry then
		return
	end
	local props: { Instance } = entry.props or {}
	for _, prop in props do
		prop:Destroy()
	end
	entry.props = nil
	entry.onPlot = 0
	entry.nextAt = nextDelay()
	if state.speakerBlown then
		state.speakerBlown = false
		state.plot:SetAttribute("SpeakerBlown", nil)
		Remotes.event("EventNotice"):FireClient(state.player, "speaker", false, 0)
	end
end

function Events.start()
	Progression.leaving:connect(reset)
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
			if not state or entry.props or not speakerPart(state) or not onPlot(state) then
				continue
			end
			entry.onPlot += step
			if entry.onPlot >= entry.nextAt then
				blow(state, entry)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		entries[player] = nil
	end)
end

return Events
