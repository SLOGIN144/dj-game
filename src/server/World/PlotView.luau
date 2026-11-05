--!strict
-- Everything visible on one plot: the spawn, the owner sign, the register, the location's room,
-- the bought items and the button pads. A location built in a venue (Ibiza) puts its room, pads,
-- register and spawn there instead (Shared/Util/PlotSpace), and the street plot keeps the last
-- club up as a showcase. Only the server changes these; they replicate to everyone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Art = require(script.Parent.Art)
local Blockouts = require(ReplicatedStorage.Shared.Config.Blockouts)
local Bounds = require(ReplicatedStorage.Shared.Util.Bounds)
local Builder = require(script.Parent.Builder)
local Building = require(script.Parent.Building)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local PartFactory = require(script.Parent.PartFactory)
local PlotLayout = require(ReplicatedStorage.Shared.Config.PlotLayout)
local PlotSpace = require(ReplicatedStorage.Shared.Util.PlotSpace)
local StreetProps = require(script.Parent.StreetProps)
local Types = require(ReplicatedStorage.Shared.Types)

local PlotView = {}

local MOVE_ON_COLOUR = Color3.fromRGB(255, 196, 60)
local REGISTER_TEXT = Color3.fromRGB(120, 255, 160)
local REGISTER_FULL = Color3.fromRGB(255, 170, 60)
local POP_IN = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- The street plot's own origin (the sign, the walkway, the building, the showcase).
local function origin(plot: Model): CFrame
	return plot:GetPivot()
end

local function plotIndex(plot: Model): number
	local index = plot:GetAttribute("PlotIndex")
	return if typeof(index) == "number" then index else 1
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
	spawn.CFrame = root * CFrame.new(PlotLayout.spawn + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, math.pi, 0)
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

	-- A path from the sidewalk to the room, under the spawn and the buttons.
	Builder.part(
		"Walkway",
		Vector3.new(12, 0.06, PlotLayout.size.Z / 2 - 6),
		root * CFrame.new(0, 0.03, -PlotLayout.size.Z / 4 - 3),
		Color3.fromRGB(86, 86, 100),
		plot,
		{ material = Enum.Material.Concrete }
	)

	local register = Instance.new("Part")
	register.Name = "Register"
	register.Anchored = true
	register.Size = Vector3.new(3, 3, 2)
	register.CFrame = root * CFrame.new(PlotLayout.register + Vector3.new(0, 1.5, 0))
	register.Color = Color3.fromRGB(30, 34, 40)
	register.Parent = plot
	-- Kiosk details (model sheet: plot_register): a glowing screen and a cash drawer.
	local kiosk = register.CFrame
	Builder.part(
		"Screen",
		Vector3.new(2.4, 1.2, 0.3),
		kiosk * CFrame.new(0, 2, -0.6),
		Color3.fromRGB(26, 29, 36),
		register
	)
	Builder.neon(
		"Display",
		Vector3.new(1.8, 0.6, 0.1),
		kiosk * CFrame.new(0, 2, -0.78),
		Color3.fromRGB(120, 255, 160),
		register
	)
	Builder.part(
		"Drawer",
		Vector3.new(2.4, 0.5, 0.2),
		kiosk * CFrame.new(0, -0.2, -1.05),
		Color3.fromRGB(58, 63, 74),
		register
	)
	local registerGui = billboard(register, Vector2.new(6, 2.4), 3.2)
	registerGui.Name = "AmountGui"
	label("Amount", registerGui, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.65), REGISTER_TEXT).Text = "$0"
	local hint =
		label("Hint", registerGui, UDim2.fromScale(0, 0.65), UDim2.fromScale(1, 0.35), Color3.new(0.86, 0.86, 0.9))
	hint.Text = "Touch to collect"

	for _, name in { "Shell", "Items", "Pads", "Showcase", "Boxes", "Outlines" } do
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = plot
	end
	PlotView.setOwner(plot, nil)
	PlotView.setBuilding(plot, "free")
end

-- A location's room into `folder` at `at`: its imported shell model, or its blockout.
local function buildRoom(folder: Instance, locationId: string, at: CFrame)
	PartFactory.clearTerrain(folder)
	folder:ClearAllChildren()
	local art = Art.find(locationId, "Shell")
	if art then
		Art.place(art, at, folder)
		return
	end
	for _, spec in Blockouts[locationId].shell do
		PartFactory.build(spec, at, folder)
	end
end

-- One item into `folder` at `at`: its imported model, or its blockout parts (rising into place
-- with `animate`). An item that replaces an earlier one takes its place in the folder.
local function buildItem(folder: Instance, locationId: string, item: Types.Item, at: CFrame, animate: boolean)
	if item.replaces then
		local replaced = folder:FindFirstChild(item.replaces)
		if replaced then
			replaced:Destroy()
		end
	end
	local specs: { Types.PartSpec } = Blockouts[locationId].items[item.id] or {}
	local art = Art.find(locationId, item.id)
	if art then
		local placed = Art.place(art, at * CFrame.new(Bounds.anchor(specs)), folder)
		placed.Name = item.id
		return
	end
	local model = Instance.new("Model")
	model.Name = item.id
	model.Parent = folder
	for _, spec in specs do
		local part = PartFactory.build(spec, at, model)
		if animate then
			local target = part.CFrame
			local transparency = part.Transparency
			part.CFrame = target * CFrame.new(0, -1, 0)
			part.Transparency = 1
			TweenService:Create(part, POP_IN, { CFrame = target, Transparency = transparency }):Play()
		end
	end
end

-- Puts the register and the spawn where the layout has them, relative to `at`.
local function placeFixtures(plot: Model, layout: PlotSpace.Layout, at: CFrame)
	PlotView.register(plot):PivotTo(at * CFrame.new(layout.register + Vector3.new(0, 1.5, 0)))
	-- Turned to face the room: characters spawn looking the way their spawn does.
	PlotView.spawn(plot).CFrame = at * CFrame.new(layout.spawn + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, math.pi, 0)
end

-- The jet at a venue that flies its owner back to the street (Services/Travel handles the prompt).
local function venueJet(plot: Model, layout: PlotSpace.Layout, at: CFrame, folder: Instance)
	local jetAt = layout.jet
	if not jetAt then
		return
	end
	local cframe = at * CFrame.new(jetAt)
	StreetProps.jet(cframe, folder)
	local door = Instance.new("Part")
	door.Name = "JetDoor"
	door.Anchored = true
	door.CanCollide = false
	door.Transparency = 1
	door.Size = Vector3.new(2, 2, 2)
	door.CFrame = cframe * CFrame.new(-11, 3, -6)
	door.Parent = folder
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TravelPrompt"
	prompt.ActionText = "Fly to the city"
	prompt.ObjectText = "Private jet"
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Travel", "street")
	prompt:SetAttribute("OwnerUserId", plot:GetAttribute("OwnerUserId")) -- clients hide it from everyone else
	prompt.Parent = door
end

-- Sets the plot up for a location: the building on the street, the room (on the plot, or at the
-- plot's venue), the register and the spawn where the location has them, and while the room is
-- away at the venue, the last club left standing on the street. Items and pads start empty;
-- Plots and Shop add the bought items and the buttons.
function PlotView.setLocation(plot: Model, locationId: string)
	-- The origin first: clients read it when LocationId changes.
	local venue = PlotSpace.isVenue(locationId)
	plot:SetAttribute("SpaceOrigin", if venue then PlotSpace.venueOrigin(plotIndex(plot)) else nil)
	plot:SetAttribute("LocationId", locationId)
	PlotView.setBuilding(plot, locationId)
	child(plot, "Items"):ClearAllChildren()
	PlotView.clearDelivery(plot)
	child(plot, "Pads"):ClearAllChildren()

	local at = PlotSpace.origin(plot)
	local layout = PlotSpace.layout(locationId)
	local shell = child(plot, "Shell")
	buildRoom(shell, locationId, at)
	if venue then
		venueJet(plot, layout, at, shell)
	end

	local showcase = child(plot, "Showcase")
	showcase:ClearAllChildren()
	local shown = if venue then PlotSpace.showcaseFor(locationId) else nil
	if shown then
		local room = Instance.new("Folder")
		room.Name = "Room"
		room.Parent = showcase
		buildRoom(room, shown, origin(plot))
		local items: { Types.Item } = Items[shown] or {}
		for _, item in items do
			-- The register works where the owner is; a second one on the street would only confuse.
			if item.feature ~= "register" then
				buildItem(showcase, shown, item, origin(plot), false)
			end
		end
	end
	placeFixtures(plot, layout, at)
end

-- The building behind the room, for a location or "free" (Config/Buildings).
function PlotView.setBuilding(plot: Model, stageId: string)
	local index = plot:GetAttribute("PlotIndex")
	Building.show(plot, stageId, if typeof(index) == "number" then index * 31 else 1)
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

-- Builds a bought item at the plot's location. With `animate`, blockout parts rise into place
-- and fade in.
function PlotView.showItem(plot: Model, locationId: string, itemId: string, animate: boolean)
	local items: { Types.Item } = Items[locationId] or {}
	for _, item in items do
		if item.id == itemId then
			buildItem(child(plot, "Items"), locationId, item, PlotSpace.origin(plot), animate)
			return
		end
	end
end

-- Removes the room, the items, the pads and the showcase, the plot's state attributes, puts the
-- register and the spawn back on the street and empties the register label.
function PlotView.clear(plot: Model)
	for _, name in { "Shell", "Items", "Pads", "Showcase", "Boxes", "Outlines" } do
		PartFactory.clearTerrain(child(plot, name))
		child(plot, name):ClearAllChildren()
	end
	for _, attribute in { "LocationId", "SpaceOrigin", "Guests", "Boost", "BoostEndsAt", "SpeakerBlown", "StarDj" } do
		plot:SetAttribute(attribute, nil)
	end
	placeFixtures(plot, PlotSpace.layout(nil), origin(plot))
	PlotView.setRegister(plot, 0, false)
	PlotView.setBuilding(plot, "free")
end

-- A glowing pad with a floating label, at a button slot of the plot's location.
local function makePad(plot: Model, name: string, slot: Vector3, colour: Color3, size: number): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.Size = Vector3.new(size, 0.3, size)
	part.CFrame = PlotSpace.origin(plot) * CFrame.new(slot + Vector3.new(0, 0.15, 0))
	part.Color = colour
	part.Material = Enum.Material.Neon
	part.Transparency = 0.2
	return part
end

-- Takes the item buttons away: only the Move On pad ever stands on the floor now, the rest is ordered
-- on the phone (Services/Delivery).
function PlotView.clearPads(plot: Model)
	child(plot, "Pads"):ClearAllChildren()
end

local BOX_SIZE = Vector3.new(3.4, 2.6, 2.6)
local BOX_COLOUR = Color3.fromRGB(196, 150, 96)
local TAPE_COLOUR = Color3.fromRGB(150, 90, 255)
local OUTLINE_MIN = 0.6 -- the thinnest an outline is drawn, so flat things (a rug, posters) still show
local PROMPT_HEIGHT = 1.4 -- above the floor, where a place prompt hangs (it's reached from beneath a ceiling item)

-- The centre of a box lying on the pavement at slot `index` of an order, in world space.
function PlotView.boxSpot(plot: Model, index: number): CFrame
	local spots = PlotLayout.boxSpots
	local spot = spots[math.min(index, #spots)]
	return origin(plot) * CFrame.new(spot + Vector3.new(0, BOX_SIZE.Y / 2, 0))
end

-- A prompt only the plot's owner is meant to see; `kind` ("BoxItem" or "OutlineItem") says which
-- item it's for. Attributes are set before it's parented, so the clients' filter sees them at once.
local function ownerPrompt(
	plot: Model,
	parent: Instance,
	name: string,
	action: string,
	object: string,
	kind: string,
	itemId: string
): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = 0
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerUserId", plot:GetAttribute("OwnerUserId")) -- clients hide it from everyone else
	prompt:SetAttribute(kind, itemId)
	prompt.Parent = parent
	return prompt
end

-- A labelled box for `item` with the owner's "Pick up" prompt: at its pavement slot `index`, or
-- at `at` (the truck's tailgate) to be moved to the slot. Parented to the plot's Boxes folder.
function PlotView.addBox(plot: Model, item: Types.Item, index: number, at: CFrame?): Model
	local model = Instance.new("Model")
	model.Name = "Box_" .. item.id
	local start = at or PlotView.boxSpot(plot, index)
	local body = Builder.part("Body", BOX_SIZE, start, BOX_COLOUR, model, { material = Enum.Material.Cardboard })
	Builder.part(
		"Tape",
		Vector3.new(0.5, BOX_SIZE.Y + 0.1, BOX_SIZE.Z + 0.1),
		start,
		TAPE_COLOUR,
		model,
		{ material = Enum.Material.SmoothPlastic }
	)
	model.PrimaryPart = body
	local gui = billboard(body, Vector2.new(6, 1.4), 2.4)
	gui.Name = "BoxGui"
	label("ItemName", gui, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.new(1, 1, 1)).Text = item.name
	local prompt = ownerPrompt(plot, body, "PickUpPrompt", "Pick up", item.name, "BoxItem", item.id)
	prompt.MaxActivationDistance = 10
	model.Parent = child(plot, "Boxes")
	return model
end

-- The glowing outline where `item` goes in the owner's room, with its "Place" prompt. It's the box
-- of the item's parts, or the item's own `placements` entry.
function PlotView.addOutline(plot: Model, locationId: string, item: Types.Item): BasePart
	local blockout = Blockouts[locationId]
	local override = if blockout.placements then blockout.placements[item.id] else nil
	local bottom, size
	if override then
		bottom, size = override.at, override.size
	else
		local low, high = Bounds.ofSpecs(blockout.items[item.id] or {})
		size = high - low
		bottom = Vector3.new((low.X + high.X) / 2, low.Y, (low.Z + high.Z) / 2)
	end
	size = size:Max(Vector3.one * OUTLINE_MIN)
	local location = PlotSpace.location(locationId)
	local colour = if location then location.colour else Color3.fromRGB(150, 90, 255)

	local part = Instance.new("Part")
	part.Name = "Outline_" .. item.id
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = PlotSpace.origin(plot) * CFrame.new(bottom + Vector3.new(0, size.Y / 2, 0))
	part.Color = colour
	part.Material = Enum.Material.Neon
	part.Transparency = 0.7
	local frame = Instance.new("SelectionBox")
	frame.Adornee = part
	frame.Color3 = colour
	frame.LineThickness = 0.06
	frame.SurfaceColor3 = colour
	frame.SurfaceTransparency = 0.85
	frame.Parent = part
	local gui = billboard(part, Vector2.new(10, 2), size.Y / 2 + 2)
	gui.Name = "OutlineGui"
	label("ItemName", gui, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), colour).Text = "Place: " .. item.name

	-- The prompt hangs at floor height under the outline, so a ceiling or wall item is placed from below.
	local anchor = Instance.new("Attachment")
	anchor.Name = "PromptAnchor"
	anchor.Position = Vector3.new(0, 0.2 + PROMPT_HEIGHT - (bottom.Y + size.Y / 2), 0)
	anchor.Parent = part
	local prompt = ownerPrompt(plot, anchor, "PlacePrompt", "Place", item.name, "OutlineItem", item.id)
	prompt.MaxActivationDistance = 12
	part.Parent = child(plot, "Outlines")
	return part
end

-- Clears the boxes and outlines of a delivery (it's done, or cancelled).
function PlotView.clearDelivery(plot: Model)
	child(plot, "Boxes"):ClearAllChildren()
	child(plot, "Outlines"):ClearAllChildren()
end

-- Replaces the button pads with the Move On pad, once the location is finished: stepping on it
-- moves the plot on to `nextName`.
function PlotView.setMoveOn(plot: Model, nextName: string, onTouched: (hit: BasePart) -> ())
	local folder = child(plot, "Pads")
	folder:ClearAllChildren()
	local slots = PlotSpace.layout(PlotSpace.locationId(plot)).buttonSlots
	local slot = slots[PlotLayout.moveOnSlot] or slots[1]
	local part = makePad(plot, "Pad_MoveOn", slot, MOVE_ON_COLOUR, PlotLayout.padSize + 1)
	part:SetAttribute("MoveOn", nextName)
	local gui = billboard(part, Vector2.new(10, 3.6), 3.6)
	gui.Name = "PadGui"
	label("ItemName", gui, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.5), MOVE_ON_COLOUR).Text = "MOVE ON"
	label("Price", gui, UDim2.fromScale(0, 0.5), UDim2.fromScale(1, 0.5), Color3.new(1, 1, 1)).Text = "to " .. nextName
	part.Touched:Connect(onTouched)
	part.Parent = folder
end

function PlotView.setRegister(plot: Model, amount: number, full: boolean)
	local amountLabel = PlotView.register(plot):FindFirstChild("Amount", true) :: TextLabel
	amountLabel.Text = Format.money(amount)
	amountLabel.TextColor3 = if full then REGISTER_FULL else REGISTER_TEXT
end

return PlotView
