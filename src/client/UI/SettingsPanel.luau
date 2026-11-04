--!strict
-- The settings panel (GDD: settings: master volume, plus separate music and SFX sliders). A
-- small button at the top right opens it; the sliders change the volume at once
-- (Controllers/Volume), and the server saves them with the player's club.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Style = require(script.Parent.Style)
local Volume = require(script.Parent.Parent.Controllers.Volume)

local SettingsPanel = {}

local SLIDERS: { { key: string, label: string } } = {
	{ key = "master", label = "Master" },
	{ key = "music", label = "Music" },
	{ key = "sfx", label = "Sound effects" },
}

type Slider = { draw: (number) -> () }

local function slider(parent: Instance, key: string, text: string, y: number): Slider
	local name =
		Style.label(parent, key .. "Label", text, UDim2.new(0.36, -16, 0, 22), UDim2.fromOffset(16, y), Style.TEXT)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local value =
		Style.label(parent, key .. "Value", "", UDim2.fromOffset(48, 22), UDim2.new(1, -60, 0, y), Style.MUTED)

	local bar = Instance.new("Frame")
	bar.Name = key .. "Bar"
	bar.Size = UDim2.new(0.64, -84, 0, 10)
	bar.Position = UDim2.new(0.36, 0, 0, y + 6)
	bar.BackgroundColor3 = Color3.fromRGB(44, 44, 60)
	bar.BorderSizePixel = 0
	bar.Active = true
	bar.Parent = parent
	Style.corner(bar, UDim.new(0.5, 0))
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.Parent = bar
	Style.corner(fill, UDim.new(0.5, 0))
	Style.follow(fill, "BackgroundColor3")
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.fromOffset(20, 20)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.BackgroundColor3 = Style.TEXT
	knob.BorderSizePixel = 0
	knob.Parent = bar
	Style.corner(knob, UDim.new(0.5, 0))

	local function draw(level: number)
		fill.Size = UDim2.fromScale(level, 1)
		knob.Position = UDim2.fromScale(level, 0.5)
		value.Text = string.format("%d%%", math.round(level * 100))
	end

	local dragging = false
	local function setFrom(x: number)
		local level = math.clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1)
		local levels = Volume.get();
		(levels :: any)[key] = level
		Volume.set(levels)
		draw(level)
	end
	local function isPress(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end
	bar.InputBegan:Connect(function(input)
		if isPress(input) then
			dragging = true
			setFrom(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			setFrom(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if isPress(input) then
			dragging = false
		end
	end)
	return { draw = draw }
end

function SettingsPanel.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Settings"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12

	local open = Style.button(gui, "Open", "Settings", UDim2.fromOffset(104, 36), UDim2.new(1, -12, 0, 8))
	open.AnchorPoint = Vector2.new(1, 0)

	local panel = Style.panel(
		gui,
		"Panel",
		UDim2.fromOffset(360, 56 + 40 * #SLIDERS),
		UDim2.new(1, -12, 0, 52),
		Vector2.new(1, 0)
	)
	Style.follow(Style.stroke(panel, Style.accent()), "Color")
	panel.Visible = false
	Style.label(panel, "Title", "Settings", UDim2.new(1, -70, 0, 26), UDim2.fromOffset(16, 10)).TextXAlignment =
		Enum.TextXAlignment.Left
	local close = Style.button(panel, "Close", "X", UDim2.fromOffset(34, 34), UDim2.new(1, -44, 0, 8))

	local sliders: { [string]: Slider } = {}
	for index, entry in SLIDERS do
		sliders[entry.key] = slider(panel, entry.key, entry.label, 48 + (index - 1) * 40)
	end
	local function drawAll()
		local levels = Volume.get() :: any
		for key, entry in sliders do
			entry.draw(levels[key])
		end
	end

	open.Activated:Connect(function()
		panel.Visible = not panel.Visible
		drawAll()
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	Players.LocalPlayer:GetAttributeChangedSignal("Settings"):Connect(function()
		task.defer(drawAll)
	end)
	drawAll()
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return SettingsPanel
