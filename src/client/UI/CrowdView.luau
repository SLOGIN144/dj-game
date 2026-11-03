--!strict
-- Placeholder "stage" for the prototype: a crowd of simple figures that bounce with the beat
-- (harder as energy rises, hands up at the top), venue-coloured light pulses, a big flash and
-- confetti for drops. The 3D venue and real crowd replace this in build step 5.

local TweenService = game:GetService("TweenService")

local CrowdView = {}
CrowdView.__index = CrowdView

local PEOPLE = 42
local ROWS = 3
local CONFETTI_COLOURS = {
	Color3.fromRGB(255, 90, 140),
	Color3.fromRGB(255, 210, 80),
	Color3.fromRGB(90, 200, 255),
	Color3.fromRGB(140, 255, 150),
	Color3.fromRGB(200, 120, 255),
}

type Person = { root: Frame, hands: Frame, phase: number, speed: number, baseY: number }

export type CrowdView = typeof(setmetatable(
	{} :: {
		_frame: Frame,
		_glow: Frame,
		_flash: Frame,
		_confetti: Frame,
		_people: { Person },
		_colour: Color3,
		_random: Random,
	},
	CrowdView
))

local function corner(parent: Instance, radius: UDim)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = radius
	uiCorner.Parent = parent
end

function CrowdView.new(parent: Instance, colour: Color3): CrowdView
	local frame = Instance.new("Frame")
	frame.Name = "Stage"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 0.65)
	frame.ClipsDescendants = true
	frame.Parent = parent

	-- A coloured glow behind the crowd that pulses with the beat.
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.BorderSizePixel = 0
	glow.BackgroundColor3 = colour
	glow.BackgroundTransparency = 0.85
	glow.AnchorPoint = Vector2.new(0.5, 1)
	glow.Position = UDim2.fromScale(0.5, 1.15)
	glow.Size = UDim2.fromScale(1.3, 0.9)
	corner(glow, UDim.new(0.5, 0))
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new(1, 0)
	fade.Parent = glow
	glow.Parent = frame

	local random = Random.new(7)
	local people: { Person } = {}
	for i = 1, PEOPLE do
		local row = (i - 1) % ROWS
		local scale = 0.75 + row * 0.18 -- front rows are bigger
		local person = Instance.new("Frame")
		person.BackgroundTransparency = 1
		person.AnchorPoint = Vector2.new(0.5, 1)
		person.Size = UDim2.fromOffset(34 * scale, 70 * scale)
		local baseY = 0.78 + row * 0.1
		person.Position = UDim2.fromScale(random:NextNumber(0.03, 0.97), baseY)
		person.ZIndex = 2 + row
		person.Parent = frame

		local shade = 0.06 + row * 0.04
		local body = Instance.new("Frame")
		body.BorderSizePixel = 0
		body.BackgroundColor3 = Color3.new(shade, shade, shade + 0.03)
		body.AnchorPoint = Vector2.new(0.5, 1)
		body.Position = UDim2.fromScale(0.5, 1)
		body.Size = UDim2.fromScale(1, 0.62)
		corner(body, UDim.new(0.35, 0))
		body.ZIndex = person.ZIndex
		body.Parent = person

		local head = Instance.new("Frame")
		head.BorderSizePixel = 0
		head.BackgroundColor3 = body.BackgroundColor3
		head.AnchorPoint = Vector2.new(0.5, 0)
		head.Size = UDim2.fromScale(0.62, 0.32)
		head.Position = UDim2.fromScale(0.5, 0.02)
		corner(head, UDim.new(0.5, 0))
		head.ZIndex = person.ZIndex
		head.Parent = person

		-- Two raised arms, shown when the energy is high.
		local hands = Instance.new("Frame")
		hands.BackgroundTransparency = 1
		hands.Size = UDim2.fromScale(1.4, 0.5)
		hands.AnchorPoint = Vector2.new(0.5, 1)
		hands.Position = UDim2.fromScale(0.5, 0.15)
		hands.Visible = false
		hands.Parent = person
		for side = -1, 1, 2 do
			local arm = Instance.new("Frame")
			arm.BorderSizePixel = 0
			arm.BackgroundColor3 = body.BackgroundColor3
			arm.AnchorPoint = Vector2.new(0.5, 1)
			arm.Size = UDim2.fromScale(0.14, 1)
			arm.Position = UDim2.fromScale(0.5 + side * 0.3, 1)
			arm.Rotation = side * 18
			corner(arm, UDim.new(0.5, 0))
			arm.ZIndex = person.ZIndex
			arm.Parent = hands
		end

		table.insert(people, {
			root = person,
			hands = hands,
			phase = random:NextNumber(0, 0.25),
			speed = random:NextNumber(0.9, 1.1),
			baseY = baseY,
		})
	end

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.BorderSizePixel = 0
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 20
	flash.Parent = parent

	local confetti = Instance.new("Frame")
	confetti.Name = "Confetti"
	confetti.BackgroundTransparency = 1
	confetti.Size = UDim2.fromScale(1, 1)
	confetti.ZIndex = 21
	confetti.Parent = parent

	return setmetatable({
		_frame = frame,
		_glow = glow,
		_flash = flash,
		_confetti = confetti,
		_people = people,
		_colour = colour,
		_random = random,
	}, CrowdView)
end

-- Bounce height (in fractions of the stage) for an energy level, in the GDD's crowd tiers.
local function bounceFor(energy: number): number
	if energy < 25 then
		return 0.002
	elseif energy < 50 then
		return 0.01
	elseif energy < 75 then
		return 0.025
	elseif energy < 90 then
		return 0.045
	end
	return 0.065
end

-- Call every frame with the playing track's beat position (nil when nothing plays).
function CrowdView.update(self: CrowdView, beat: number?, energy: number)
	local height = bounceFor(energy)
	local handsUp = energy >= 75
	for _, person in self._people do
		local lift = 0
		if beat then
			local cycle = (beat * person.speed + person.phase) % 1
			lift = math.abs(math.sin(cycle * math.pi)) * height
		end
		person.root.Position = UDim2.fromScale(person.root.Position.X.Scale, person.baseY - lift)
		person.hands.Visible = handsUp
	end
	local pulse = if beat then 1 - (beat % 1) else 0
	self._glow.BackgroundTransparency = 0.92 - (energy / 100) * 0.35 * (0.5 + 0.5 * pulse)
end

-- A white flash over everything, fading out. `strength` 0..1.
function CrowdView.flash(self: CrowdView, strength: number)
	self._flash.BackgroundTransparency = 1 - 0.75 * strength
	TweenService:Create(self._flash, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
end

-- Confetti falling over the screen. `amount` pieces.
function CrowdView.confetti(self: CrowdView, amount: number)
	for _ = 1, amount do
		local piece = Instance.new("Frame")
		piece.BorderSizePixel = 0
		piece.BackgroundColor3 = CONFETTI_COLOURS[self._random:NextInteger(1, #CONFETTI_COLOURS)]
		piece.Size = UDim2.fromOffset(self._random:NextInteger(6, 11), self._random:NextInteger(10, 18))
		piece.Position = UDim2.fromScale(self._random:NextNumber(0, 1), self._random:NextNumber(-0.25, -0.02))
		piece.Rotation = self._random:NextNumber(0, 360)
		piece.ZIndex = 21
		piece.Parent = self._confetti
		local duration = self._random:NextNumber(1.6, 2.8)
		local fall =
			TweenService:Create(piece, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromScale(piece.Position.X.Scale + self._random:NextNumber(-0.15, 0.15), 1.1),
				Rotation = piece.Rotation + self._random:NextNumber(-540, 540),
			})
		fall.Completed:Once(function()
			piece:Destroy()
		end)
		fall:Play()
	end
end

return CrowdView
