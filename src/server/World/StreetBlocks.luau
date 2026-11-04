--!strict
-- Filler buildings on the lots at both ends of the street, beyond the plots, so the street reads
-- as a lived-in city block (docs/concept/street.webp) rather than empty concrete: apartment blocks
-- with lit windows and neon edges, each with a shopfront on the ground floor. Decoration only;
-- the shop names are made up, no brands.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(script.Parent.Builder)
local Building = require(script.Parent.Building)
local Buildings = require(ReplicatedStorage.Shared.Config.Buildings)

local StreetBlocks = {}

local rgb = Color3.fromRGB
local WARM = rgb(255, 206, 140)

-- The shops, one per block, and their sign colours.
local SHOPS = {
	{ name = "VINYL", colour = rgb(255, 70, 200) },
	{ name = "NOODLES", colour = rgb(255, 170, 60) },
	{ name = "ARCADE", colour = rgb(60, 200, 255) },
	{ name = "LAUNDRY", colour = rgb(120, 255, 170) },
}

-- Where the blocks go: the lots between `plotsHalf` (the plots' half length along X) and the
-- street's end, behind the sidewalk.
export type Layout = {
	length: number, -- the street's ground along X
	plotsHalf: number,
	sidewalkEdge: number, -- |z| of the sidewalk's outer edge
}

local function shopfront(origin: CFrame, width: number, shop: { name: string, colour: Color3 }, parent: Instance)
	local window = Builder.part(
		"ShopWindow",
		Vector3.new(width - 6, 5, 0.3),
		origin * CFrame.new(0, 3, -0.2),
		WARM,
		parent,
		{ material = Enum.Material.Neon }
	)
	window.Transparency = 0.35
	Builder.part(
		"Awning",
		Vector3.new(width - 4, 0.4, 3),
		origin * CFrame.new(0, 6.2, -1.5) * CFrame.Angles(math.rad(-12), 0, 0),
		rgb(40, 38, 50),
		parent
	)
	local sign = Builder.part(
		"ShopSign",
		Vector3.new(math.min(width - 6, #shop.name * 2.4 + 4), 2.4, 0.4),
		origin * CFrame.new(0, 8, -0.4),
		rgb(16, 16, 24),
		parent
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Brightness = 3
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = shop.name
	text.TextScaled = true
	text.TextColor3 = shop.colour
	text.Font = Enum.Font.BuilderSansExtraBold
	text.Parent = gui
	gui.Parent = sign
	local glow = Instance.new("PointLight")
	glow.Color = shop.colour
	glow.Brightness = 1.2
	glow.Range = 16
	glow.Parent = sign
end

-- Builds a block on each side of the road at both ends of the street.
function StreetBlocks.build(parent: Instance, layout: Layout)
	local folder = Builder.folder("Blocks", parent)
	local free = layout.length / 2 - layout.plotsHalf - 10 -- room for a block on each end lot
	if free < 16 then
		return
	end
	local width = math.min(36, free)
	local index = 0
	for _, endSign in { -1, 1 } do
		for _, side in { 1, -1 } do
			index += 1
			local x = endSign * (layout.plotsHalf + 4 + width / 2)
			local facing = if side == 1 then CFrame.identity else CFrame.Angles(0, math.pi, 0)
			local origin = CFrame.new(x, 0, side * (layout.sidewalkEdge + 2)) * facing
			local stage: Buildings.Stage = {
				floors = 4 + (index % 3),
				floorHeight = 9,
				width = width,
				depth = 24,
				frontZ = 0,
				roomHeight = 8, -- the shopfront takes the ground floor
				colour = if index % 2 == 0 then rgb(96, 86, 104) else rgb(84, 80, 98),
				trim = rgb(62, 58, 72),
				neon = if index % 2 == 0 then SHOPS[index].colour else nil,
				litShare = 0.5,
			}
			local block = Builder.folder("Block" .. index, folder)
			Building.decor(origin, stage, index * 53, block)
			shopfront(origin, width, SHOPS[(index - 1) % #SHOPS + 1], block)
		end
	end
end

return StreetBlocks
