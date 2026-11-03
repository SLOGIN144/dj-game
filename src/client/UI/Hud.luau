--!strict
-- The HUD: cash and income per second in a panel at the top, and a floating "+$" when the player
-- collects from their register. Values come from the server through Player attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Locations = require(ReplicatedStorage.Shared.Config.Locations)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Hud = {}

local PANEL_COLOUR = Color3.fromRGB(16, 16, 24)
local TEXT_COLOUR = Color3.fromRGB(255, 255, 255)
local COLLECT_COLOUR = Color3.fromRGB(120, 255, 160)
local FONT = Enum.Font.BuilderSansExtraBold
local FLOAT = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function label(name: string, parent: Instance, position: UDim2, size: UDim2, colour: Color3): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Position = position
	text.Size = size
	text.TextColor3 = colour
	text.TextScaled = true
	text.Font = FONT
	text.Parent = parent
	return text
end

local function number(value: unknown): number
	return if typeof(value) == "number" then value else 0
end

function Hud.start()
	local player = Players.LocalPlayer
	-- The dorm's accent for now; it follows the player's location once Move on exists (step 3).
	local accent = Locations[1].colour

	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false

	local panel = Instance.new("Frame")
	panel.Name = "Money"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 8)
	panel.Size = UDim2.fromOffset(220, 64)
	panel.BackgroundColor3 = PANEL_COLOUR
	panel.BackgroundTransparency = 0.15
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 2
	stroke.Transparency = 0.2
	stroke.Parent = panel

	local cash = label("Cash", panel, UDim2.new(0, 12, 0, 4), UDim2.new(1, -24, 0, 34), TEXT_COLOUR)
	local income = label("Income", panel, UDim2.new(0, 12, 0, 38), UDim2.new(1, -24, 0, 20), accent)

	local function update()
		cash.Text = Format.money(number(player:GetAttribute("Cash")))
		income.Text = Format.rate(number(player:GetAttribute("Income")))
	end
	player:GetAttributeChangedSignal("Cash"):Connect(update)
	player:GetAttributeChangedSignal("Income"):Connect(update)
	update()

	-- "+$X" rises from under the panel and fades out.
	Remotes.event("Collected").OnClientEvent:Connect(function(amount: unknown)
		if typeof(amount) ~= "number" then
			return
		end
		local popup = label("Collected", gui, UDim2.new(0.5, -80, 0, 76), UDim2.fromOffset(160, 32), COLLECT_COLOUR)
		popup.Text = "+" .. Format.money(amount)
		popup.TextStrokeTransparency = 0.5
		local tween = TweenService:Create(popup, FLOAT, {
			Position = popup.Position - UDim2.fromOffset(0, 40),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		tween.Completed:Connect(function()
			popup:Destroy()
		end)
		tween:Play()
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return Hud
