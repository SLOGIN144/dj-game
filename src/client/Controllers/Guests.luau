--!strict
-- The friends on every plot, as many as the plot's "Guests" attribute (set by the server from
-- its income). They're simple figures built from parts on this client; R15 rigs with real dance
-- animations come later, once there are animation IDs. Each walks in from the location's
-- entrance, then dances on the plot's beat: knees bounce on every beat, a sway each bar, arms
-- that rise through the build and go up on the drop, and a jump on drops and Perfect presses.
-- Every client builds the same figures from the same seeds, so visitors see the same friends.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Blockouts = require(ReplicatedStorage.Shared.Config.Blockouts)
local PlotArea = require(ReplicatedStorage.Shared.Util.PlotArea)
local PlotMixes = require(script.Parent.PlotMixes)
local TrackInfo = require(ReplicatedStorage.Shared.Music.TrackInfo)
local Types = require(ReplicatedStorage.Shared.Types)

local Guests = {}

local VIEW_DISTANCE = 200 -- studs from the camera within which guests move
local WALK_SECONDS = 2.5
local JUMP_SECONDS = 0.45
local JUMP_HEIGHT = 1.1

local SHIRTS = {
	Color3.fromRGB(214, 84, 122),
	Color3.fromRGB(86, 150, 236),
	Color3.fromRGB(236, 186, 76),
	Color3.fromRGB(110, 200, 140),
	Color3.fromRGB(170, 110, 230),
	Color3.fromRGB(226, 226, 232),
}
local SKIN = {
	Color3.fromRGB(255, 220, 190),
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(196, 140, 104),
	Color3.fromRGB(140, 96, 70),
	Color3.fromRGB(96, 66, 50),
}
local PANTS = { Color3.fromRGB(40, 40, 56), Color3.fromRGB(58, 52, 80), Color3.fromRGB(30, 46, 70) }

type Guest = {
	model: Model,
	parts: { BasePart }, -- torso, head, left arm, right arm, left leg, right leg
	spot: Vector3, -- where it dances, in plot space
	arrivedAt: number, -- os.clock() it started walking in
	offset: number, -- its own beat offset, so the crowd isn't a drill team
	energy: number, -- its own dance size, ±10%
	style: number, -- 1 or 2: two slightly different arm moves
}

type PlotGuests = { guests: { Guest }, jumpAt: number }

local plots: { [Model]: PlotGuests } = {}
local folder: Folder

local function part(model: Model, name: string, size: Vector3, colour: Color3, shape: Enum.PartType?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = colour
	p.Shape = shape or Enum.PartType.Block
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = model
	return p
end

local function newGuest(plot: Model, index: number, spot: Vector3): Guest
	local plotIndex = plot:GetAttribute("PlotIndex")
	local random = Random.new((if typeof(plotIndex) == "number" then plotIndex else 0) * 97 + index)
	local shirt = SHIRTS[random:NextInteger(1, #SHIRTS)]
	local skin = SKIN[random:NextInteger(1, #SKIN)]
	local pants = PANTS[random:NextInteger(1, #PANTS)]

	local model = Instance.new("Model")
	model.Name = string.format("%s_Guest%d", plot.Name, index)
	local parts = {
		part(model, "Torso", Vector3.new(2, 2, 1), shirt),
		part(model, "Head", Vector3.new(1.25, 1.25, 1.25), skin, Enum.PartType.Ball),
		part(model, "LeftArm", Vector3.new(0.8, 1.8, 0.8), shirt),
		part(model, "RightArm", Vector3.new(0.8, 1.8, 0.8), shirt),
		part(model, "LeftLeg", Vector3.new(0.9, 2, 0.9), pants),
		part(model, "RightLeg", Vector3.new(0.9, 2, 0.9), pants),
	}
	model.Parent = folder
	return {
		model = model,
		parts = parts,
		spot = spot,
		arrivedAt = os.clock(),
		offset = random:NextNumber(-0.08, 0.08),
		energy = random:NextNumber(0.9, 1.1),
		style = random:NextInteger(1, 2),
	}
end

-- Adds or removes figures until the plot shows as many as its "Guests" attribute asks.
local function fit(plot: Model, entry: PlotGuests, blockout: Types.Blockout?)
	local wanted = plot:GetAttribute("Guests")
	local count = if typeof(wanted) == "number" and blockout then math.min(wanted, #blockout.guests.spots) else 0
	while #entry.guests > count do
		local guest = table.remove(entry.guests) :: Guest
		guest.model:Destroy()
	end
	if blockout then
		while #entry.guests < count do
			local index = #entry.guests + 1
			table.insert(entry.guests, newGuest(plot, index, blockout.guests.spots[index]))
		end
	end
end

-- Arm angle (radians, 0 = hanging, pi = straight up) and knee dip for the moment in the track.
local function pose(kind: Types.SectionKind, beat: number, through: number, style: number): (number, number)
	local phase = beat % 1
	local kick = (1 - phase) ^ 2
	local swing = math.sin(beat * math.pi)
	if kind == "drop" then
		return math.rad(160 + 14 * swing), 1
	elseif kind == "build" then
		return math.rad(40 + 70 * through + 18 * kick * style), 0.6 + 0.3 * through
	elseif kind == "breakdown" then
		return math.rad(95 + 25 * math.sin(beat * math.pi / 2)), 0.3
	end
	return math.rad(14 + 10 * swing), 0.5
end

local function animate(
	plot: Model,
	entry: PlotGuests,
	blockout: Types.Blockout,
	now: number,
	parts: { BasePart },
	frames: { CFrame }
)
	local origin = plot:GetPivot()
	local _, main = PlotMixes.at(plot, now)
	local mix = PlotMixes.get(plot)
	local boost = plot:GetAttribute("Boost")
	local bigger = if typeof(boost) == "number" and boost > 1 then 1.3 else 1

	-- A jump on a drop's first beat, and on a Perfect press.
	local jumpAge = os.clock() - entry.jumpAt
	if mix then
		for _, drop in mix.drops do
			local age = now - drop.time
			if age >= 0 and age < jumpAge then
				jumpAge = age
			end
		end
	end
	local jump = if jumpAge < JUMP_SECONDS then math.sin(jumpAge / JUMP_SECONDS * math.pi) * JUMP_HEIGHT else 0

	local lookAt = origin * blockout.guests.lookAt
	local entrance = origin * blockout.guests.entrance
	for _, guest in entry.guests do
		local spot = origin * guest.spot
		local walked = math.clamp((os.clock() - guest.arrivedAt) / WALK_SECONDS, 0, 1)
		local position = entrance:Lerp(spot, walked * walked * (3 - 2 * walked))
		local root: CFrame
		local legSwing, armAngle, dip, sway = 0, math.rad(10), 0, 0
		local bounce = 0
		local leftArm, rightArm
		if walked < 1 then
			-- Walking in, facing the way they go, arms swinging against the legs.
			root = CFrame.lookAt(position, Vector3.new(spot.X, position.Y, spot.Z))
			legSwing = math.sin(os.clock() * 9) * math.rad(28)
			leftArm, rightArm = armAngle - legSwing * 0.6, armAngle + legSwing * 0.6
		else
			root = CFrame.lookAt(position, Vector3.new(lookAt.X, position.Y, lookAt.Z))
			if main then
				local beat = main.beat + guest.offset
				local section = TrackInfo.sectionAt(main.track, beat)
				local index = table.find(main.track.sections, section) or 1
				local sectionEnd = TrackInfo.sectionEnd(main.track, index, section.startBeat + 64)
				local through =
					math.clamp((beat - section.startBeat) / math.max(1, sectionEnd - section.startBeat), 0, 1)
				local amount
				armAngle, amount = pose(section.kind, beat, through, guest.style)
				dip = (1 + math.cos(beat * 2 * math.pi)) / 2 * 0.3 * amount * guest.energy * bigger
				sway = math.sin(beat * math.pi / 2) * math.rad(10) * guest.energy * bigger
				bounce = jump
			else
				-- No music: just standing about.
				sway = math.sin(os.clock() * 0.8 + guest.offset * 40) * math.rad(4)
			end
			-- The two styles hold one arm a little higher than the other.
			local tilt = if guest.style == 1 then 0.12 else -0.12
			leftArm, rightArm = armAngle - tilt, armAngle + tilt
		end

		root *= CFrame.Angles(0, sway, 0)
		local upper = root * CFrame.new(0, bounce - dip, 0)
		local legs = root * CFrame.new(0, bounce, 0)
		frames[#frames + 1] = upper * CFrame.new(0, 3, 0)
		frames[#frames + 1] = upper * CFrame.new(0, 4.6, 0)
		frames[#frames + 1] = upper
			* CFrame.new(-1.4, 3.9, 0)
			* CFrame.Angles(leftArm, 0, -0.18)
			* CFrame.new(0, -0.9, 0)
		frames[#frames + 1] = upper
			* CFrame.new(1.4, 3.9, 0)
			* CFrame.Angles(rightArm, 0, 0.18)
			* CFrame.new(0, -0.9, 0)
		frames[#frames + 1] = legs * CFrame.new(-0.5, 2, 0) * CFrame.Angles(legSwing, 0, 0) * CFrame.new(0, -1, 0)
		frames[#frames + 1] = legs * CFrame.new(0.5, 2, 0) * CFrame.Angles(-legSwing, 0, 0) * CFrame.new(0, -1, 0)
		for _, p in guest.parts do
			parts[#parts + 1] = p
		end
	end
end

-- Every guest on a plot jumps, e.g. on a Perfect drop press.
function Guests.cheer(plot: Model)
	local entry = plots[plot]
	if entry then
		entry.jumpAt = os.clock()
	end
end

function Guests.start()
	folder = Instance.new("Folder")
	folder.Name = "LocalGuests"
	folder.Parent = workspace

	for _, plot in PlotMixes.plots() do
		plots[plot] = { guests = {}, jumpAt = -math.huge }
	end

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local now = PlotMixes.now()
		local eye = camera.CFrame.Position
		local parts: { BasePart } = {}
		local frames: { CFrame } = {}
		for plot, entry in plots do
			local locationId = plot:GetAttribute("LocationId")
			local blockout = if typeof(locationId) == "string" then Blockouts[locationId] else nil
			fit(plot, entry, blockout)
			if blockout and #entry.guests > 0 and PlotArea.distance(plot:GetPivot(), eye) <= VIEW_DISTANCE then
				animate(plot, entry, blockout, now, parts, frames)
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return Guests
