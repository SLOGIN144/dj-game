--!strict
-- The delivery truck (docs/superpowers/specs/2026-11-05-truck-delivery-design.md): a blockout that
-- drives down the street from its far end, stops at the kerb in front of a plot, waits while its
-- boxes come off, and drives away and fades. The whole street sees it. An imported model can
-- replace the blockout later (ServerStorage › Art › street › street_truck, front towards -Z,
-- pivot on the ground at its centre).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Art = require(script.Parent.Art)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Builder = require(script.Parent.Builder)

local Truck = {}

local LANE = 10.5 -- studs from the road's centre line to the truck's middle: the lane by the kerb
local GROUND = 0.2 -- the road's top, in world space
local LEAVE_DISTANCE = 60 -- studs the truck drives on after unloading before it's gone
local FADE_SECONDS = 1
local TAILGATE = 7.6 -- studs behind the truck's middle, where the boxes come off
local FACE = CFrame.Angles(0, -math.pi / 2, 0) -- the front (local -Z) points along +X

local WHITE = Color3.fromRGB(236, 236, 242)
local DARK = Color3.fromRGB(30, 30, 38)
local ACCENT = Color3.fromRGB(150, 90, 255)

local function blockout(): Model
	local model = Instance.new("Model")
	model.Name = "DeliveryTruck"
	local at = CFrame.identity
	local cargo = Builder.part("Cargo", Vector3.new(6.4, 6.4, 9.6), at * CFrame.new(0, 4.2, 2.6), WHITE, model)
	Builder.part("Cab", Vector3.new(6.4, 4.4, 4.2), at * CFrame.new(0, 3.2, -4.3), WHITE, model)
	Builder.part("Chassis", Vector3.new(6, 0.8, 14), at * CFrame.new(0, 1.3, 0.4), DARK, model)
	Builder.part(
		"Windscreen",
		Vector3.new(5.4, 1.8, 0.1),
		at * CFrame.new(0, 4.0, -6.42),
		Color3.fromRGB(110, 170, 230),
		model,
		{ material = Enum.Material.Glass, transparency = 0.3 }
	)
	Builder.neon("Stripe", Vector3.new(6.5, 0.5, 9.7), at * CFrame.new(0, 2.7, 2.6), ACCENT, model)
	for _, side in { -1, 1 } do
		Builder.neon(
			"Headlight",
			Vector3.new(0.8, 0.6, 0.1),
			at * CFrame.new(side * 2.2, 2.2, -6.42),
			Color3.fromRGB(255, 240, 200),
			model
		)
		Builder.neon(
			"Taillight",
			Vector3.new(0.8, 0.6, 0.1),
			at * CFrame.new(side * 2.4, 2.2, 7.42),
			Color3.fromRGB(255, 60, 60),
			model
		)
		for _, z in { -4.2, 5.4 } do
			Builder.part(
				"Wheel",
				Vector3.new(0.9, 2.2, 2.2),
				at * CFrame.new(side * 3.2, 1.1, z),
				DARK,
				model,
				{ shape = Enum.PartType.Cylinder }
			)
		end
		-- "DELIVERY" along both sides of the cargo box
		local gui = Instance.new("SurfaceGui")
		gui.Face = if side == 1 then Enum.NormalId.Right else Enum.NormalId.Left
		gui.LightInfluence = 0.3
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 0.5)
		text.Position = UDim2.fromScale(0, 0.18)
		text.BackgroundTransparency = 1
		text.Text = "DELIVERY"
		text.TextScaled = true
		text.TextColor3 = DARK
		text.Font = Enum.Font.BuilderSansExtraBold
		text.Parent = gui
		gui.Parent = cargo
	end
	model.PrimaryPart = cargo
	model.WorldPivot = at
	return model
end

-- A truck: the imported model if there is one, else the blockout, standing at the origin.
local function build(): Model
	local art = Art.find("street", "street_truck")
	if art then
		return Art.place(art, CFrame.identity, workspace)
	end
	return blockout()
end

-- Drives `model` along the road from `fromX` to `toX` at about `speed`, easing in or out. Returns
-- false if the delivery was cancelled on the way.
local function drive(
	model: Model,
	fromX: number,
	toX: number,
	z: number,
	speed: number,
	ease: "in" | "out",
	cancelled: () -> boolean
): boolean
	local duration = math.max(0.1, math.abs(toX - fromX) / speed * 1.4) -- easing makes the middle faster
	local began = os.clock()
	while true do
		if cancelled() then
			return false
		end
		local alpha = math.min(1, (os.clock() - began) / duration)
		local eased = if ease == "out" then 1 - (1 - alpha) ^ 2 else alpha ^ 2
		model:PivotTo(CFrame.new(fromX + (toX - fromX) * eased, GROUND, z) * FACE)
		if alpha >= 1 then
			return true
		end
		RunService.Heartbeat:Wait()
	end
end

local function fadeOut(model: Model)
	local began = os.clock()
	while model.Parent do
		local alpha = math.min(1, (os.clock() - began) / FADE_SECONDS)
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				local base = part:GetAttribute("BaseTransparency")
				if typeof(base) ~= "number" then
					base = part.Transparency
					part:SetAttribute("BaseTransparency", base)
				end
				part.Transparency = (base :: number) + (1 - (base :: number)) * alpha
			end
		end
		if alpha >= 1 then
			return
		end
		RunService.Heartbeat:Wait()
	end
end

-- Sends a truck to the kerb in front of `plot` so that it stops there `seconds` from now, calls
-- `onStopped` with the tailgate's CFrame, lets it wait, then drives it away. Yields until the truck
-- is gone. `cancelled` is asked all the time: once it says true the truck just disappears.
function Truck.run(plot: Model, seconds: number, onStopped: (tailgate: CFrame) -> (), cancelled: () -> boolean)
	local street = workspace:FindFirstChild("Street")
	local ground = if street then street:FindFirstChild("Ground") else nil
	local half = if ground and ground:IsA("BasePart") then ground.Size.X / 2 else 100
	local pivot = plot:GetPivot().Position
	local stopX = pivot.X
	local z = (if pivot.Z >= 0 then 1 else -1) * LANE
	local startX = -half - 12
	local speed = Balance.Delivery.truckSpeed
	-- The drive takes about distance/speed (a little longer, with the easing); it starts that long
	-- before the stop, and later still if the street is longer than the delivery time.
	local travel = math.abs(stopX - startX) / speed * 1.4
	if travel > seconds then
		speed = math.abs(stopX - startX) / seconds * 1.4
		travel = seconds
	end
	local waited = os.clock() + (seconds - travel)
	while os.clock() < waited do
		if cancelled() then
			return
		end
		task.wait(0.1)
	end

	local model = build()
	model.Parent = street or workspace
	local function gone(): boolean
		if cancelled() or not model.Parent then
			model:Destroy()
			return true
		end
		return false
	end
	model:PivotTo(CFrame.new(startX, GROUND, z) * FACE)
	if not drive(model, startX, stopX, z, speed, "out", gone) then
		return
	end
	onStopped(model:GetPivot() * CFrame.new(0, 3.2, TAILGATE))
	local leave = os.clock() + Balance.Delivery.unloadSeconds
	while os.clock() < leave do
		if gone() then
			return
		end
		task.wait(0.1)
	end
	if drive(model, stopX, stopX + LEAVE_DISTANCE, z, speed, "in", gone) then
		fadeOut(model)
	end
	model:Destroy()
end

return Truck
