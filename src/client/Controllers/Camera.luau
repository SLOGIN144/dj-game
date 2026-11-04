--!strict
-- The camera: the normal Roblox camera everywhere, except a fixed shot while playing the decks,
-- with a slow drift and a short shake on drops (GDD: Camera).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Camera = {}

local BIND_NAME = "DecksCamera"
local SHAKE_SECONDS = 0.35

local shot: CFrame? = nil
local shakeAt = -math.huge
local shakeStrength = 0

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

-- A short shake, 0..1 (a drop is about 0.4, a Perfect press 1).
function Camera.shake(strength: number)
	if os.clock() - shakeAt < SHAKE_SECONDS and strength < shakeStrength then
		return
	end
	shakeAt = os.clock()
	shakeStrength = strength
end

return Camera
