--!strict
-- The UI look (GDD: dark, clean and rounded, with a neon accent from the location's colour, one
-- built-in sans font) and small builders every panel uses.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Locations = require(ReplicatedStorage.Shared.Config.Locations)

local Style = {}

Style.PANEL = Color3.fromRGB(16, 16, 24)
Style.PANEL_TRANSPARENCY = 0.12
Style.TEXT = Color3.fromRGB(255, 255, 255)
Style.MUTED = Color3.fromRGB(190, 190, 206)
Style.GOOD = Color3.fromRGB(120, 255, 160)
Style.WARN = Color3.fromRGB(255, 170, 60)
Style.BAD = Color3.fromRGB(255, 110, 120)
Style.GOLD = Color3.fromRGB(255, 214, 90)
Style.FONT = Enum.Font.BuilderSansExtraBold
Style.BODY = Enum.Font.BuilderSansMedium

-- The accent of the player's location (the dorm until Move on exists).
function Style.accent(): Color3
	return Locations[1].colour
end

function Style.corner(parent: GuiObject, radius: UDim?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or UDim.new(0, 14)
	corner.Parent = parent
end

function Style.stroke(parent: GuiObject, colour: Color3, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = colour
	stroke.Thickness = thickness or 2
	stroke.Transparency = 0.15
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function Style.panel(parent: Instance, name: string, size: UDim2, position: UDim2, anchor: Vector2?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = anchor or Vector2.zero
	frame.BackgroundColor3 = Style.PANEL
	frame.BackgroundTransparency = Style.PANEL_TRANSPARENCY
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Style.corner(frame)
	return frame
end

function Style.label(
	parent: Instance,
	name: string,
	text: string,
	size: UDim2,
	position: UDim2,
	colour: Color3?,
	font: Enum.Font?
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.TextColor3 = colour or Style.TEXT
	label.Font = font or Style.FONT
	label.TextScaled = true
	label.Parent = parent
	return label
end

function Style.button(parent: Instance, name: string, text: string, size: UDim2, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = Style.PANEL
	button.BackgroundTransparency = Style.PANEL_TRANSPARENCY
	button.TextColor3 = Style.TEXT
	button.Font = Style.FONT
	button.TextScaled = true
	button.AutoButtonColor = true
	button.BorderSizePixel = 0
	button.Parent = parent
	Style.corner(button)
	Style.stroke(button, Style.accent())
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = button
	return button
end

return Style
