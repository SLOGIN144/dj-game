--!strict
-- The HUD: cash and income per second in a panel at the top, the active drop boost or star DJ
-- set with its timer under it, a banner while an event needs the player, and a floating "+$"
-- when cash comes in. Values come from the server through Player attributes and the player's
-- plot attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Booking = require(ReplicatedStorage.Shared.Economy.Booking)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local OwnPlot = require(script.Parent.Parent.Controllers.OwnPlot)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(script.Parent.Parent.Controllers.Sfx)
local Style = require(script.Parent.Style)
local WishConfig = require(ReplicatedStorage.Shared.Config.Wishes)

local Hud = {}

local FLOAT = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local REFRESH = 0.1 -- seconds between boost timer updates

local NOTICES: { [string]: string } = {
	speaker = "Your speaker blew! Hold Fix on it to repair it.",
	vip = "A VIP is at the door! Go greet them.",
	photographer = "A photographer is at the decks! Catch the next drop.",
}
local MISSED: { [string]: string } = {
	vip = "The VIP got tired of waiting.",
	photographer = "The photographer left. Next time!",
}

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
	Style.follow(Style.stroke(panel, accent), "Color")
	local cash = Style.label(panel, "Cash", "$0", UDim2.new(1, -24, 0, 34), UDim2.fromOffset(12, 4))
	local income = Style.label(panel, "Income", "", UDim2.new(1, -24, 0, 20), UDim2.fromOffset(12, 38), accent)
	Style.follow(income, "TextColor3")

	local function update()
		cash.Text = Format.money(number(player:GetAttribute("Cash")))
		income.Text = Format.rate(number(player:GetAttribute("Income")))
	end
	player:GetAttributeChangedSignal("Cash"):Connect(update)
	player:GetAttributeChangedSignal("Income"):Connect(update)
	update()

	-- A star DJ's set (it takes the boost's place: the two never stack).
	local starSet =
		Style.panel(gui, "StarSet", UDim2.fromOffset(300, 30), UDim2.new(0.5, 0, 0, 112), Vector2.new(0.5, 0))
	local starStroke = Style.stroke(starSet, Style.GOLD)
	starSet.Visible = false
	local starText = Style.label(starSet, "Text", "", UDim2.new(1, -16, 1, -8), UDim2.fromOffset(8, 4), Style.GOLD)
	local noticeText: TextLabel
	local noticeBase = ""
	local noticeEndsAt: number? = nil

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
		-- A star DJ's guest set and how long it has left.
		local djId = if plot then plot:GetAttribute("StarDj") else nil
		local dj = if typeof(djId) == "string" then Booking.find(djId) else nil
		local setLeft = if plot then number(plot:GetAttribute("StarDjEndsAt")) - workspace:GetServerTimeNow() else 0
		starSet.Visible = dj ~= nil and setLeft > 0
		if dj and starSet.Visible then
			starText.Text = string.format(
				"%s  x%s  %d:%02d",
				string.upper(dj.name),
				tostring(dj.multiplier),
				math.floor(setLeft / 60),
				math.ceil(setLeft) % 60
			)
			starStroke.Color = dj.colour
			starText.TextColor3 = dj.colour
		end
		if noticeEndsAt then
			local seconds = math.max(0, math.ceil(noticeEndsAt - os.clock()))
			noticeText.Text = noticeBase .. "  " .. seconds .. "s"
		end
	end)

	-- A banner while an event needs the player, with how long is left for the VIP and the photographer.
	local notice = Style.panel(gui, "Notice", UDim2.fromOffset(380, 30), UDim2.new(0.5, 0, 0, 146), Vector2.new(0.5, 0))
	Style.stroke(notice, Style.WARN)
	notice.Visible = false
	noticeText = Style.label(notice, "Text", "", UDim2.new(1, -16, 1, -8), UDim2.fromOffset(8, 4), Style.WARN)
	Remotes.event("EventNotice").OnClientEvent
		:Connect(function(kind: unknown, active: unknown, tip: unknown, seconds: unknown)
			if typeof(kind) ~= "string" or not NOTICES[kind] then
				return
			end
			if active == true then
				noticeBase = NOTICES[kind]
				noticeText.Text = noticeBase
				noticeEndsAt = if typeof(seconds) == "number" and seconds > 0 then os.clock() + seconds else nil
				notice.Visible = true
				Sfx.play(if kind == "speaker" then "speakerBlow" elseif kind == "vip" then "vip" else "notice")
				return
			end
			notice.Visible = false
			noticeEndsAt = nil
			local paid = typeof(tip) == "number" and tip > 0
			if kind == "speaker" and paid then
				Sfx.play("fix")
			elseif kind == "photographer" and paid then
				Sfx.play("camera")
			elseif not paid and MISSED[kind] then
				Hud.float(MISSED[kind], Style.MUTED)
			end
		end)

	-- "+$X" rises from under the panel when collecting.
	Remotes.event("Collected").OnClientEvent:Connect(function(amount: unknown)
		if typeof(amount) == "number" then
			Hud.float("+" .. Format.money(amount), Style.GOOD)
			Sfx.play("cash")
		end
	end)

	-- A guest's wish comes up, and is granted (Services/Wishes, the bubble over the guest is in
	-- Controllers/Guests).
	task.spawn(function()
		local plot = OwnPlot.wait()
		local granted = plot:GetAttribute("WishCount")
		plot:GetAttributeChangedSignal("Wish"):Connect(function()
			local kind = plot:GetAttribute("Wish")
			local wish = if typeof(kind) == "string" then WishConfig[kind] else nil
			if wish then
				Hud.float("A guest wants: " .. wish.text, Style.GOLD)
			end
		end)
		plot:GetAttributeChangedSignal("WishCount"):Connect(function()
			local count = plot:GetAttribute("WishCount")
			if typeof(count) == "number" and typeof(granted) == "number" and count > granted then
				Hud.float("Wish granted!", Style.GOOD)
			end
			granted = count
		end)
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return Hud
