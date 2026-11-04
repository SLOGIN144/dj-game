--!strict
-- The HUD: cash and income per second in a panel at the top, the active drop boost with its
-- timer under it, and a floating "+$" when the player collects from their register. Values come
-- from the server through Player attributes and the player's plot attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local OwnPlot = require(script.Parent.Parent.Controllers.OwnPlot)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(script.Parent.Parent.Controllers.Sfx)
local Style = require(script.Parent.Style)

local Hud = {}

local FLOAT = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local REFRESH = 0.1 -- seconds between boost timer updates

local gui: ScreenGui
local floating = 0 -- floats on screen right now, so new ones stack under them

local function number(value: unknown): number
	return if typeof(value) == "number" then value else 0
end

-- Floating text that rises from `position` and fades out. Several at once stack.
function Hud.float(text: string, colour: Color3, position: UDim2?)
	local start = (position or UDim2.new(0.5, -100, 0, 104)) + UDim2.fromOffset(0, floating * 30)
	floating += 1
	local popup = Style.label(gui, "Float", text, UDim2.fromOffset(200, 32), start, colour)
	popup.TextStrokeTransparency = 0.5
	local tween = TweenService:Create(popup, FLOAT, {
		Position = popup.Position - UDim2.fromOffset(0, 40),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween.Completed:Connect(function()
		floating -= 1
		popup:Destroy()
	end)
	tween:Play()
end

-- The HUD's ScreenGui, for other panels that sit in it.
function Hud.gui(): ScreenGui
	return gui
end

function Hud.start()
	local player = Players.LocalPlayer
	local accent = Style.accent()

	gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false

	local panel = Style.panel(gui, "Money", UDim2.fromOffset(220, 64), UDim2.new(0.5, 0, 0, 8), Vector2.new(0.5, 0))
	Style.stroke(panel, accent)
	local cash = Style.label(panel, "Cash", "$0", UDim2.new(1, -24, 0, 34), UDim2.fromOffset(12, 4))
	local income = Style.label(panel, "Income", "", UDim2.new(1, -24, 0, 20), UDim2.fromOffset(12, 38), accent)

	local function update()
		cash.Text = Format.money(number(player:GetAttribute("Cash")))
		income.Text = Format.rate(number(player:GetAttribute("Income")))
	end
	player:GetAttributeChangedSignal("Cash"):Connect(update)
	player:GetAttributeChangedSignal("Income"):Connect(update)
	update()

	-- The drop boost and how long it has left.
	local boost = Style.panel(gui, "Boost", UDim2.fromOffset(170, 30), UDim2.new(0.5, 0, 0, 78), Vector2.new(0.5, 0))
	Style.stroke(boost, Style.GOLD)
	boost.Visible = false
	local boostText = Style.label(boost, "Text", "", UDim2.new(1, -16, 1, -8), UDim2.fromOffset(8, 4), Style.GOLD)
	local sinceRefresh = 0
	RunService.Heartbeat:Connect(function(dt)
		sinceRefresh += dt
		if sinceRefresh < REFRESH then
			return
		end
		sinceRefresh = 0
		local plot = OwnPlot.get()
		local multiplier = if plot then number(plot:GetAttribute("Boost")) else 0
		local left = if plot then number(plot:GetAttribute("BoostEndsAt")) - workspace:GetServerTimeNow() else 0
		boost.Visible = multiplier > 1 and left > 0
		if boost.Visible then
			boostText.Text = string.format("x%s BOOST  %ds", tostring(multiplier), math.ceil(left))
		end
	end)

	-- A banner while an event needs the player (the blown speaker).
	local notice = Style.panel(gui, "Notice", UDim2.fromOffset(330, 30), UDim2.new(0.5, 0, 0, 114), Vector2.new(0.5, 0))
	Style.stroke(notice, Style.WARN)
	notice.Visible = false
	Style.label(
		notice,
		"Text",
		"Your speaker blew! Hold Fix on it to repair it.",
		UDim2.new(1, -16, 1, -8),
		UDim2.fromOffset(8, 4),
		Style.WARN
	)
	Remotes.event("EventNotice").OnClientEvent:Connect(function(kind: unknown, active: unknown)
		if kind == "speaker" then
			notice.Visible = active == true
			Sfx.play(if active == true then "speakerBlow" else "fix")
		end
	end)

	-- "+$X" rises from under the panel when collecting.
	Remotes.event("Collected").OnClientEvent:Connect(function(amount: unknown)
		if typeof(amount) == "number" then
			Hud.float("+" .. Format.money(amount), Style.GOOD)
			Sfx.play("cash")
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return Hud
