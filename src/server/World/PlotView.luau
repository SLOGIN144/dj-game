--!strict
-- Everything visible on one plot: the spawn, the owner sign, the register, the location's room,
-- the bought items and the button pads. Only the server changes these; they replicate to everyone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Blockouts = require(ReplicatedStorage.Shared.Config.Blockouts)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local PartFactory = require(script.Parent.PartFactory)
local PlotLayout = require(ReplicatedStorage.Shared.Config.PlotLayout)
local Types = require(ReplicatedStorage.Shared.Types)

local PlotView = {}

export type Pad = { item: Types.Item, effect: Types.ItemEffect }

local PAD_COLOUR = Color3.fromRGB(70, 255, 140)
local REGISTER_TEXT = Color3.fromRGB(120, 255, 160)
local REGISTER_FULL = Color3.fromRGB(255, 170, 60)
local POP_IN = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function origin(plot: Model): CFrame
	return plot:GetPivot()
end

local function child(plot: Model, name: string): Instance
	return plot:FindFirstChild(name) :: Instance
end

local function label(name: string, parent: Instance, position: UDim2, size: UDim2, colour: Color3): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Position = position
	text.Size = size
	text.TextColor3 = colour
	text.TextScaled = true
	text.TextStrokeTransparency = 0.4
	text.Font = Enum.Font.BuilderSansExtraBold
	text.Parent = parent
	return text
end

local function billboard(parent: BasePart, size: Vector2, height: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(size.X, size.Y) -- scale on a BillboardGui is in studs
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	gui.Parent = parent
	return gui
end

function PlotView.setup(plot: Model)
	local root = origin(plot)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 0.4, 6)
	spawn.CFrame = root * CFrame.new(PlotLayout.spawn + Vector3.new(0, 0.2, 0))
	spawn.Color = Color3.fromRGB(150, 90, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.4
	spawn.Parent = plot

	local sign = Instance.new("Part")
	sign.Name = "Sign"
	sign.Anchored = true
	sign.Size = Vector3.new(16, 4, 0.5)
	sign.CFrame = root * CFrame.new(PlotLayout.sign)
	sign.Color = Color3.fromRGB(20, 20, 28)
	sign.Parent = plot
	local signGui = Instance.new("SurfaceGui")
	signGui.Name = "SignGui"
	signGui.Face = Enum.NormalId.Front
	signGui.LightInfluence = 0
	signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	signGui.PixelsPerStud = 40
	signGui.Parent = sign
	label("Owner", signGui, UDim2.fromScale(0.05, 0.1), UDim2.fromScale(0.9, 0.8), Color3.fromRGB(150, 90, 255))
	for _, x in { -7, 7 } do
		local post = Instance.new("Part")
		post.Name = "SignPost"
		post.Anchored = true
		post.Size = Vector3.new(0.5, PlotLayout.sign.Y - 2, 0.5)
		post.CFrame = root * CFrame.new(PlotLayout.sign.X + x, (PlotLayout.sign.Y - 2) / 2, PlotLayout.sign.Z)
		post.Color = Color3.fromRGB(40, 40, 48)
		post.Parent = plot
	end

	local register = Instance.new("Part")
	register.Name = "Register"
	register.Anchored = true
	register.Size = Vector3.new(3, 3, 2)
	register.CFrame = root * CFrame.new(PlotLayout.register + Vector3.new(0, 1.5, 0))
	register.Color = Color3.fromRGB(30, 34, 40)
	register.Parent = plot
	local registerGui = billboard(register, Vector2.new(6, 2.4), 3.2)
	registerGui.Name = "AmountGui"
	label("Amount", registerGui, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.65), REGISTER_TEXT).Text = "$0"
	local hint =
		label("Hint", registerGui, UDim2.fromScale(0, 0.65), UDim2.fromScale(1, 0.35), Color3.new(0.86, 0.86, 0.9))
	hint.Text = "Touch to collect"

	for _, name in { "Shell", "Items", "Pads" } do
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = plot
	end
	PlotView.setOwner(plot, nil)
end

function PlotView.setOwner(plot: Model, player: Player?)
	plot:SetAttribute("OwnerUserId", if player then player.UserId else nil)
	local owner = child(plot, "Sign"):FindFirstChild("Owner", true) :: TextLabel
	owner.Text = if player then player.DisplayName .. "'s Club" else "Free plot"
end

function PlotView.register(plot: Model): BasePart
	return child(plot, "Register") :: BasePart
end

function PlotView.spawn(plot: Model): SpawnLocation
	return child(plot, "Spawn") :: SpawnLocation
end

function PlotView.setShell(plot: Model, locationId: string)
	local shell = child(plot, "Shell")
	shell:ClearAllChildren()
	for _, spec in Blockouts[locationId].shell do
		PartFactory.build(spec, origin(plot), shell)
	end
end

-- Builds a bought item's parts. With `animate`, each part rises into place and fades in.
function PlotView.showItem(plot: Model, locationId: string, itemId: string, animate: boolean)
	local model = Instance.new("Model")
	model.Name = itemId
	model.Parent = child(plot, "Items")
	for _, spec in Blockouts[locationId].items[itemId] or {} do
		local part = PartFactory.build(spec, origin(plot), model)
		if animate then
			local target = part.CFrame
			local transparency = part.Transparency
			part.CFrame = target * CFrame.new(0, -1, 0)
			part.Transparency = 1
			TweenService:Create(part, POP_IN, { CFrame = target, Transparency = transparency }):Play()
		end
	end
end

-- Removes the room, the items and the pads, and empties the register label.
function PlotView.clear(plot: Model)
	for _, name in { "Shell", "Items", "Pads" } do
		child(plot, name):ClearAllChildren()
	end
	PlotView.setRegister(plot, 0, false)
end

-- Replaces the button pads with one per entry, in the layout's button slots.
function PlotView.setPads(plot: Model, pads: { Pad }, onTouched: (itemId: string, hit: BasePart) -> ())
	local folder = child(plot, "Pads")
	folder:ClearAllChildren()
	for index, entry in pads do
		local slot = PlotLayout.buttonSlots[index]
		if not slot then
			break
		end
		local pad = Instance.new("Part")
		pad.Name = "Pad_" .. entry.item.id
		pad.Anchored = true
		pad.CanCollide = false
		pad.Size = Vector3.new(5, 0.3, 5)
		pad.CFrame = origin(plot) * CFrame.new(slot + Vector3.new(0, 0.15, 0))
		pad.Color = PAD_COLOUR
		pad.Material = Enum.Material.Neon
		pad.Transparency = 0.2
		pad:SetAttribute("ItemId", entry.item.id)
		pad:SetAttribute("Price", entry.effect.cost)

		local price = if entry.effect.cost == 0 then "FREE" else Format.money(entry.effect.cost)
		local effect = if entry.item.kind == "gear"
			then string.format("x%.2f income", entry.effect.multiplier)
			else Format.rate(entry.effect.flat)
		local gui = billboard(pad, Vector2.new(8, 3.6), 3.4)
		gui.Name = "PadGui"
		label("ItemName", gui, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.4), Color3.new(1, 1, 1)).Text =
			entry.item.name
		label("Price", gui, UDim2.fromScale(0, 0.4), UDim2.fromScale(1, 0.33), PAD_COLOUR).Text = price
		label("Effect", gui, UDim2.fromScale(0, 0.73), UDim2.fromScale(1, 0.27), Color3.fromRGB(200, 200, 215)).Text =
			effect

		local itemId = entry.item.id
		pad.Touched:Connect(function(hit)
			onTouched(itemId, hit)
		end)
		pad.Parent = folder
	end
end

function PlotView.setRegister(plot: Model, amount: number, full: boolean)
	local amountLabel = PlotView.register(plot):FindFirstChild("Amount", true) :: TextLabel
	amountLabel.Text = Format.money(amount)
	amountLabel.TextColor3 = if full then REGISTER_FULL else REGISTER_TEXT
end

return PlotView
