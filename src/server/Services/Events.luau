--!strict
-- Club events (GDD: club life), one at a time, every 3-5 minutes the owner spends at their club.
-- Which ones can happen depends on the location (Config/Locations):
--   speaker: a speaker smokes and sparks, the music gets quieter (clients read the plot's
--     "SpeakerBlown") and income drops 25%, until the owner holds E on it for 2 seconds.
--   vip: a VIP waits at the entrance for a minute; greeting them (E) pays a big tip.
--   photographer: a photographer stands in front of the decks for 30 seconds; catching a drop
--     while they're there pays a bonus, with a camera flash.
-- Each has an on-screen marker; the owner's client shows a banner (EventNotice).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Blockouts = require(ReplicatedStorage.Shared.Config.Blockouts)
local Decks = require(script.Parent.Decks)
local Economy = require(script.Parent.Economy)
local Figures = require(script.Parent.Parent.World.Figures)
local PlayerState = require(script.Parent.PlayerState)
local PlotSpace = require(ReplicatedStorage.Shared.Util.PlotSpace)
local Progression = require(script.Parent.Progression)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)

local Events = {}

-- Fire (state, kind) when an event starts, (state, kind, tip) when the owner deals with it, and
-- (state, kind) when the chance passes (the VIP or the photographer left).
Events.started = Signal.new()
Events.fixed = Signal.new()
Events.missed = Signal.new()

local CHECK_EVERY = 1
local PHOTO_STEP = 6 -- studs in front of the DJ where the photographer stands
local random = Random.new()

type Active = {
	kind: Types.EventKind,
	props: { Instance }, -- the smoke, sparks, figure, prompt and marker
	endsAt: number?, -- os.clock() when a VIP or photographer leaves
	flash: BasePart?, -- the photographer's flash
}

type Entry = {
	onPlot: number, -- seconds the owner has spent at their club since the last event
	nextAt: number, -- seconds at the club when the next event happens
	active: Active?,
}

local entries: { [Player]: Entry } = {}

local function nextDelay(): number
	return random:NextNumber(Balance.Events.minSeconds, Balance.Events.maxSeconds)
end

local function tipFor(state: PlayerState.State, kind: Types.EventKind): number
	local seconds = Balance.Events[kind].tipSeconds
	return math.max(1, math.floor(state.baseIncome * seconds))
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
	for _, child in model:GetDescendants() do
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

local function marker(part: BasePart, text: string, colour: Color3, height: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "EventMarker"
	gui.Size = UDim2.fromOffset(if #text > 1 then 64 else 44, 44)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	local mark = Instance.new("TextLabel")
	mark.Size = UDim2.fromScale(1, 1)
	mark.BackgroundColor3 = colour
	mark.Text = text
	mark.TextScaled = true
	mark.TextColor3 = Color3.new(1, 1, 1)
	mark.Font = Enum.Font.BuilderSansExtraBold
	mark.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = mark
	gui.Parent = part
	return gui
end

local function ownerPrompt(state: PlayerState.State, part: BasePart, action: string, object: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EventPrompt"
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerUserId", state.player.UserId) -- clients hide it from everyone else
	prompt.Parent = part
	return prompt
end

local function clear(entry: Entry)
	local active = entry.active
	if active then
		for _, prop in active.props do
			prop:Destroy()
		end
	end
	entry.active = nil
	entry.onPlot = 0
	entry.nextAt = nextDelay()
end

-- Ends the owner's event: `success` pays its tip.
local function finish(state: PlayerState.State, entry: Entry, success: boolean)
	local active = entry.active
	if not active then
		return
	end
	local kind: Types.EventKind = active.kind
	clear(entry)
	if kind == "speaker" then
		state.speakerBlown = false
		state.plot:SetAttribute("SpeakerBlown", nil)
		PlayerState.updateIncome(state)
	end
	if success then
		local tip = tipFor(state, kind)
		Economy.reward(state, tip)
		state.stats.eventsDone += 1
		Remotes.event("EventNotice"):FireClient(state.player, kind, false, tip)
		Events.fixed:fire(state, kind, tip)
	else
		Remotes.event("EventNotice"):FireClient(state.player, kind, false, 0)
		Events.missed:fire(state, kind)
	end
end

local function blowSpeaker(state: PlayerState.State, entry: Entry): boolean
	local part = speakerPart(state)
	if not part then
		return false
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

	local prompt = ownerPrompt(state, part, "Fix", "Speaker")
	prompt.Name = "FixPrompt"
	prompt.HoldDuration = Balance.Events.speaker.holdSeconds
	prompt.Triggered:Connect(function(player)
		if player == state.player and entry.active and entry.active.kind == "speaker" then
			finish(state, entry, true)
		end
	end)

	local mark = marker(part, "!", Color3.fromRGB(255, 150, 40), part.Size.Y / 2 + 2.5)
	entry.active = { kind = "speaker", props = { smoke, sparks, prompt, mark } }
	return true
end

local function greetVip(state: PlayerState.State, entry: Entry): boolean
	local blockout = Blockouts[state.locationId]
	if not blockout then
		return false
	end
	local origin = PlotSpace.origin(state.plot)
	local door = origin * blockout.guests.entrance
	local inside = origin * blockout.guests.lookAt
	local at = CFrame.lookAt(door, Vector3.new(inside.X, door.Y, inside.Z))
	local figure = Figures.vip(at, state.plot)
	local torso = figure.PrimaryPart :: BasePart
	local prompt = ownerPrompt(state, torso, "Greet", "VIP guest")
	prompt.HoldDuration = 0.4
	prompt.Triggered:Connect(function(player)
		if player == state.player and entry.active and entry.active.kind == "vip" then
			finish(state, entry, true)
		end
	end)
	marker(torso, "VIP", Color3.fromRGB(230, 170, 40), 4)
	entry.active = { kind = "vip", props = { figure }, endsAt = os.clock() + Balance.Events.vip.waitSeconds }
	return true
end

local function photographer(state: PlayerState.State, entry: Entry): boolean
	local blockout = Blockouts[state.locationId]
	if not blockout or not state.bought[blockout.decks.itemId] or state.starDj then
		return false
	end
	local origin = PlotSpace.origin(state.plot)
	local stand = blockout.decks.stand
	local towards = blockout.decks.cameraLookAt - stand
	local flat = Vector3.new(towards.X, 0, towards.Z)
	if flat.Magnitude < 1e-3 then
		return false
	end
	local floor = if #blockout.guests.spots > 0 then blockout.guests.spots[1].Y else stand.Y
	local spot = stand + flat.Unit * PHOTO_STEP
	local feet = origin * Vector3.new(spot.X, floor, spot.Z)
	local dj = origin * stand
	local figure, flash = Figures.photographer(CFrame.lookAt(feet, Vector3.new(dj.X, feet.Y, dj.Z)), state.plot)
	marker(figure.PrimaryPart :: BasePart, "PHOTO", Color3.fromRGB(80, 160, 255), 4)
	entry.active = {
		kind = "photographer",
		props = { figure },
		endsAt = os.clock() + Balance.Events.photographer.waitSeconds,
		flash = flash,
	}
	return true
end

-- Starts one of the location's events that can happen right now.
local function begin(state: PlayerState.State, entry: Entry)
	local location = PlotSpace.location(state.locationId)
	if not location then
		return
	end
	local kinds = table.clone(location.events)
	while #kinds > 0 do
		local kind = table.remove(kinds, random:NextInteger(1, #kinds)) :: Types.EventKind
		local started = if kind == "speaker"
			then blowSpeaker(state, entry)
			elseif kind == "vip" then greetVip(state, entry)
			else photographer(state, entry)
		if started then
			Remotes.event("EventNotice")
				:FireClient(
					state.player,
					kind,
					true,
					0,
					if kind == "speaker" then 0 else Balance.Events[kind].waitSeconds
				)
			Events.started:fire(state, kind)
			return
		end
	end
end

-- A caught drop is the shot the photographer was waiting for.
local function onCaught(state: PlayerState.State)
	local entry = entries[state.player]
	local active = if entry then entry.active else nil
	if not entry or not active or active.kind ~= "photographer" then
		return
	end
	local flash = active.flash
	if flash then
		local light = Instance.new("PointLight")
		light.Range = 30
		light.Brightness = 8
		light.Color = Color3.new(1, 1, 1)
		light.Parent = flash
	end
	-- Hold the pose a moment so the flash shows, then pay and go.
	active.endsAt = nil
	task.delay(0.35, function()
		if entry.active == active then
			finish(state, entry, true)
		end
	end)
end

-- Starts counting towards the owner's first event.
function Events.begin(state: PlayerState.State)
	entries[state.player] = { onPlot = 0, nextAt = nextDelay() }
end

-- Makes the owner's next event happen at the next check (Studio testing, Services/DevTools).
function Events.soon(state: PlayerState.State)
	local entry = entries[state.player]
	if entry and not entry.active then
		entry.onPlot = entry.nextAt
	end
end

-- Forgets a leaving owner's event (their plot is cleared with everything on it).
function Events.stop(state: PlayerState.State)
	local entry = entries[state.player]
	if entry then
		clear(entry)
	end
	entries[state.player] = nil
	state.plot:SetAttribute("SpeakerBlown", nil)
end

-- Ends the owner's event without a tip (they're moving on) and starts counting afresh.
local function reset(state: PlayerState.State)
	local entry = entries[state.player]
	local active = if entry then entry.active else nil
	if not entry or not active then
		return
	end
	local kind: Types.EventKind = active.kind
	clear(entry)
	if kind == "speaker" then
		state.speakerBlown = false
		state.plot:SetAttribute("SpeakerBlown", nil)
	end
	Remotes.event("EventNotice"):FireClient(state.player, kind, false, 0)
end

function Events.start()
	Progression.leaving:connect(reset)
	Decks.caught:connect(onCaught)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < CHECK_EVERY then
			return
		end
		local step = elapsed
		elapsed = 0
		local clock = os.clock()
		for player, entry in entries do
			local state = PlayerState.get(player)
			if not state then
				continue
			end
			local active = entry.active
			if active then
				if active.endsAt and clock >= active.endsAt then
					finish(state, entry, false)
				end
				continue
			end
			if not onPlot(state) then
				continue
			end
			entry.onPlot += step
			if entry.onPlot >= entry.nextAt then
				begin(state, entry)
				if not entry.active then
					entry.onPlot = 0
					entry.nextAt = nextDelay() -- nothing could happen yet; try again later
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		entries[player] = nil
	end)
end

return Events
