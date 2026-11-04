--!strict
-- The camera: the normal Roblox camera everywhere, except a fixed shot while playing the decks,
-- with a slow drift and a short shake on drops, and a short look at each new part of the club
-- when the player buys it standing still (GDD: Camera).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Camera = {}

local BIND_NAME = "DecksCamera"
local PEEK_NAME = "PeekCamera"
local SHAKE_SECONDS = 0.35
local PEEK_IN = 0.5 -- seconds turning to the new part
local PEEK_HOLD = 1 -- seconds looking at it
local PEEK_OUT = 0.5 -- seconds turning back
local PEEK_CLOSER = 0.2 -- how far the camera moves towards the part, as a share of the way
local STILL = 0.05 -- a MoveDirection below this counts as standing still

local shot: CFrame? = nil
local shakeAt = -math.huge
local shakeStrength = 0
local peeking = false

local function giveBack()
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		local character = Players.LocalPlayer.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

local function stopPeek()
	if peeking then
		peeking = false
		RunService:UnbindFromRenderStep(PEEK_NAME)
	end
end

local function smooth(alpha: number): number
	local t = math.clamp(alpha, 0, 1)
	return t * t * (3 - 2 * t)
end

local function render()
	local camera = workspace.CurrentCamera
	if not shot or not camera then
		return
	end
	local t = os.clock()
	local drift = CFrame.new(math.sin(t * 0.17) * 0.35, math.sin(t * 0.11) * 0.15, 0)
		* CFrame.Angles(math.sin(t * 0.23) * 0.012, math.sin(t * 0.19) * 0.02, 0)
	local age = t - shakeAt
	local shake = CFrame.identity
	if age < SHAKE_SECONDS then
		local amount = shakeStrength * (1 - age / SHAKE_SECONDS)
		shake = CFrame.Angles(
			math.noise(t * 25, 1) * 0.03 * amount,
			math.noise(t * 25, 2) * 0.03 * amount,
			math.noise(t * 25, 3) * 0.02 * amount
		)
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = (shot :: CFrame) * drift * shake
end

-- Holds the camera on `cframe` until `release`.
function Camera.focus(cframe: CFrame)
	stopPeek()
	if not shot then
		RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, render)
	end
	shot = cframe
end

function Camera.release()
	if not shot then
		return
	end
	shot = nil
	RunService:UnbindFromRenderStep(BIND_NAME)
	giveBack()
end

-- Turns the camera to look at `target` (a part of the club just bought) for a moment, then
-- back. Only when the player is standing still and not at the decks; moving cuts it short.
function Camera.peek(target: Vector3)
	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if shot or peeking or not camera or not humanoid or humanoid.MoveDirection.Magnitude > STILL then
		return
	end
	peeking = true
	local start = camera.CFrame
	local goal = CFrame.lookAt(start.Position:Lerp(target, PEEK_CLOSER), target)
	local began = os.clock()
	camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep(PEEK_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock() - began
		if humanoid.MoveDirection.Magnitude > STILL or t >= PEEK_IN + PEEK_HOLD + PEEK_OUT then
			stopPeek()
			giveBack()
			return
		end
		local amount = if t < PEEK_IN
			then smooth(t / PEEK_IN)
			elseif t < PEEK_IN + PEEK_HOLD then 1
			else 1 - smooth((t - PEEK_IN - PEEK_HOLD) / PEEK_OUT)
		camera.CFrame = start:Lerp(goal, amount)
	end)
end

-- A short shake, 0..1 (a drop is about 0.4, a Perfect press 1).
function Camera.shake(strength: number)
	if os.clock() - shakeAt < SHAKE_SECONDS and strength < shakeStrength then
		return
	end
	shakeAt = os.clock()
	shakeStrength = strength
end

return Camera
