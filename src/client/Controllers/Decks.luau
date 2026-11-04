--!strict
-- The owner's side of the decks (GDD: drop bonus). A "Play" ProximityPrompt on the plot's decks
-- item, made on this client so only the owner sees it, puts the player at the decks: the camera
-- moves to the decks shot and the main button appears. Space, a click or a tap on the button
-- presses; the press is judged by the heard audio (TimingJudge) and sent to the server, which
-- checks it and grants the boost. E (the prompt, now "Leave"), the Leave button or walking away
-- leaves. Away from the decks, drops still fire the lights but give no boost.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Blockouts = require(ReplicatedStorage.Shared.Config.Blockouts)
local Boost = require(ReplicatedStorage.Shared.Economy.Boost)
local Camera = require(script.Parent.Camera)
local DecksUI = require(script.Parent.Parent.UI.DecksUI)
local MixTimeline = require(ReplicatedStorage.Shared.Music.MixTimeline)
local OwnPlot = require(script.Parent.OwnPlot)
local PlotMixes = require(script.Parent.PlotMixes)
local PlotMusic = require(script.Parent.PlotMusic)
local PlotSpace = require(ReplicatedStorage.Shared.Util.PlotSpace)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TimingJudge = require(ReplicatedStorage.Shared.Music.TimingJudge)
local TrackInfo = require(ReplicatedStorage.Shared.Music.TrackInfo)
local Types = require(ReplicatedStorage.Shared.Types)

local Decks = {}

local ACTION = "DecksMain"
local PROMPT_DISTANCE = 9
local DROP_SHAKE = 0.35

local player = Players.LocalPlayer
local plot: Model? = nil
local prompt: ProximityPrompt? = nil
local playing = false
local pressed: { [string]: boolean } = {} -- drops already pressed for
local lastShaken = -math.huge -- the drop time the camera last shook for
local openTracks: () -> () = function() end

local function blockout(): Types.Blockout?
	local locationId = if plot then plot:GetAttribute("LocationId") else nil
	return if typeof(locationId) == "string" then Blockouts[locationId] else nil
end

local function rootPart(): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function press()
	if not playing or not plot then
		return
	end
	local entry = PlotMixes.get(plot)
	if not entry then
		return
	end
	local drop, offset = MixTimeline.nearestDrop(entry.drops, PlotMixes.now())
	if not drop or math.abs(offset) > Balance.Boost.pressWindow then
		return -- not near a drop: nothing happens, and no penalty
	end
	local key = Boost.dropKey(drop)
	if pressed[key] then
		return
	end
	pressed[key] = true
	-- Judge by what the player hears when their decks are playing this plot.
	local heard = if PlotMusic.listening() == plot then PlotMusic.heardOffset(drop.n, drop.beat) else nil
	local judged = heard or offset
	DecksUI.grade(TimingJudge.grade(judged))
	Remotes.event("DropPress"):FireServer(drop.time + judged)
end

local function onAction(_: string, state: Enum.UserInputState, _: InputObject): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		press()
	end
	return Enum.ContextActionResult.Sink -- Space doesn't jump at the decks
end

-- Space presses at the decks, so jumping is off there; sinking the key alone may not stop the
-- default controls.
local function setJumping(enabled: boolean)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, enabled)
	end
end

local function leave()
	if not playing then
		return
	end
	playing = false
	setJumping(true)
	ContextActionService:UnbindAction(ACTION)
	Camera.release()
	DecksUI.show(false)
	if prompt then
		prompt.ActionText = "Play"
	end
end

local function enter()
	local layout = blockout()
	local root = rootPart()
	local character = player.Character
	if playing or not plot or not layout or not root or not character then
		return
	end
	if plot:GetAttribute("StarDj") ~= nil then
		return -- a star DJ has the decks
	end
	local origin = PlotSpace.origin(plot)
	local stand = origin * layout.decks.stand
	local items = plot:FindFirstChild("Items")
	local booth = if items then items:FindFirstChild(layout.decks.itemId) else nil
	local facing = if booth and booth:IsA("Model")
		then booth:GetPivot().Position
		else origin * layout.decks.cameraLookAt
	character:PivotTo(CFrame.lookAt(stand + Vector3.new(0, 3, 0), Vector3.new(facing.X, stand.Y + 3, facing.Z)))

	Camera.focus(origin * CFrame.lookAt(layout.decks.camera, layout.decks.cameraLookAt))
	ContextActionService:BindActionAtPriority(
		ACTION,
		onAction,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonA
	)
	playing = true
	setJumping(false)
	if prompt then
		prompt.ActionText = "Leave"
	end
	DecksUI.show(true)
end

local function attachPrompt(model: Instance)
	local base = model:FindFirstChildWhichIsA("BasePart")
	while not base do
		model.ChildAdded:Wait()
		base = model:FindFirstChildWhichIsA("BasePart")
	end
	local newPrompt = Instance.new("ProximityPrompt")
	newPrompt.Name = "DecksPrompt"
	newPrompt.ActionText = if playing then "Leave" else "Play"
	newPrompt.ObjectText = "Decks"
	newPrompt.KeyboardKeyCode = Enum.KeyCode.E
	newPrompt.HoldDuration = 0
	newPrompt.MaxActivationDistance = PROMPT_DISTANCE
	newPrompt.RequiresLineOfSight = false
	newPrompt.Triggered:Connect(function()
		if playing then
			leave()
		else
			enter()
		end
	end)
	newPrompt.Parent = base
	prompt = newPrompt
end

-- The decks view every frame: the ring, the track, the drop shake, and leaving when walked away.
local function update()
	if not playing or not plot then
		return
	end
	local layout = blockout()
	local root = rootPart()
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not layout or not root or not humanoid or humanoid.Health <= 0 then
		leave()
		return
	end
	local stand = PlotSpace.origin(plot) * layout.decks.stand
	local offset = root.Position - stand
	if Vector2.new(offset.X, offset.Z).Magnitude > Balance.Boost.decksRange then
		leave()
		return
	end

	local now = PlotMixes.now()
	local entry = PlotMixes.get(plot)
	local _, main = PlotMixes.at(plot, now)
	if not entry or not main then
		DecksUI.update({ title = "Waiting for the music...", progress = 0, drops = {}, kick = 0 })
		return
	end
	local track = main.track
	local length = math.max(1, TrackInfo.safeEndBeat(track))
	local marks = {}
	for _, section in track.sections do
		if section.kind == "drop" then
			table.insert(marks, section.startBeat / length)
		end
	end

	local beatSeconds = 60 / (track.bpm * main.speed)
	local drop = MixTimeline.nextDrop(entry.drops, now - Balance.Timing.goodWindow)
	local beatsToDrop: number? = nil
	local secondsToDrop: number? = nil
	if drop then
		local seconds = drop.time - now
		secondsToDrop = seconds
		local beats = seconds / beatSeconds
		if beats <= Balance.Transition.countdownBeats then
			beatsToDrop = beats
		end
		if drop.time <= now and drop.time > lastShaken then
			lastShaken = drop.time
			Camera.shake(DROP_SHAKE)
		end
	end

	DecksUI.update({
		title = string.format("%s - %s", track.title, track.artist),
		progress = main.beat / length,
		drops = marks,
		beatsToDrop = beatsToDrop,
		secondsToDrop = secondsToDrop,
		kick = (1 - main.beat % 1) ^ 3,
	})
end

-- The track shop opens from the decks; UI/TrackShop sets this.
function Decks.setTracksHandler(handler: () -> ())
	openTracks = handler
end

function Decks.isPlaying(): boolean
	return playing
end

function Decks.start()
	DecksUI.build({
		press = press,
		leave = leave,
		tracks = function()
			openTracks()
		end,
	})

	Remotes.event("DropResult").OnClientEvent:Connect(function(grade: unknown, multiplier: unknown)
		if typeof(grade) == "string" and grade ~= "miss" and typeof(multiplier) == "number" then
			Camera.shake(if grade == "perfect" then 1 else 0.6)
		end
	end)

	player.CharacterRemoving:Connect(leave)
	RunService.RenderStepped:Connect(update)

	task.spawn(function()
		local own = OwnPlot.wait()
		while typeof(own:GetAttribute("LocationId")) ~= "string" do
			own:GetAttributeChangedSignal("LocationId"):Wait()
		end
		plot = own
		-- While a star DJ plays, the decks are theirs: the owner steps away and the prompt says so.
		own:GetAttributeChangedSignal("StarDj"):Connect(function()
			local starPlaying = own:GetAttribute("StarDj") ~= nil
			if starPlaying and playing then
				leave()
			end
			if prompt then
				prompt.ActionText = if starPlaying then "Star DJ playing" elseif playing then "Leave" else "Play"
				prompt.Enabled = not starPlaying
			end
		end)
		local items = own:WaitForChild("Items")
		local function check(child: Instance)
			local layout = blockout()
			if layout and child.Name == layout.decks.itemId then
				attachPrompt(child)
			end
		end
		items.ChildAdded:Connect(check)
		for _, child in items:GetChildren() do
			task.spawn(check, child)
		end
	end)
end

return Decks
