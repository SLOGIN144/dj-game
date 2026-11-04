--!strict
-- The star DJ booking board (GDD: track shop and DJ board: simple lists with price and a Buy
-- button). It opens when the owner uses their location's booking board (the server sends
-- OpenBoard) and lists every star DJ: who they are and their sound, what a set does and costs,
-- and whether they can be booked now (the same check as the server's, Economy/Booking; the server
-- decides). Booking sends BookDj; the answer comes back as DjNotice.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Booking = require(ReplicatedStorage.Shared.Economy.Booking)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Hud = require(script.Parent.Hud)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local OwnPlot = require(script.Parent.Parent.Controllers.OwnPlot)
local PlotSpace = require(ReplicatedStorage.Shared.Util.PlotSpace)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(script.Parent.Parent.Controllers.Sfx)
local StarDjs = require(ReplicatedStorage.Shared.Config.StarDjs)
local Style = require(script.Parent.Style)
local Types = require(ReplicatedStorage.Shared.Types)

local DjBoard = {}

local REFRESH = 0.5
local ROW_HEIGHT = 64

local player = Players.LocalPlayer
local gui: ScreenGui
local rows: { [string]: { button: TextButton, status: TextLabel } } = {}

local function number(value: unknown): number
	return if typeof(value) == "number" then value else 0
end

local function rests(): { [string]: number }
	local result = {}
	local text = player:GetAttribute("DjRest")
	if typeof(text) == "string" then
		for id, at in string.gmatch(text, "([^,=]+)=(%d+)") do
			result[id] = tonumber(at) or 0
		end
	end
	return result
end

local function hasBoard(plot: Model, locationId: string): boolean
	local items: { Types.Item } = Items[locationId] or {}
	local folder = plot:FindFirstChild("Items")
	for _, item in items do
		if item.feature == "booking" and folder and folder:FindFirstChild(item.id) then
			return true
		end
	end
	return false
end

local function refresh()
	if not gui or not gui.Enabled then
		return
	end
	local plot = OwnPlot.get()
	local locationId = if plot then PlotSpace.locationId(plot) else nil
	if not plot or not locationId then
		return
	end
	local resting = rests()
	local now = workspace:GetServerTimeNow()
	local situation: Booking.Situation = {
		locationId = locationId,
		hasBoard = hasBoard(plot, locationId),
		cash = number(player:GetAttribute("Cash")),
		playing = plot:GetAttribute("StarDj") ~= nil,
		restUntil = nil,
		now = math.floor(now),
	}
	for _, dj in StarDjs do
		local row = rows[dj.id]
		situation.restUntil = resting[dj.id]
		local refusal: Booking.Refusal? = Booking.refusal(dj, situation)
		local playingNow = plot:GetAttribute("StarDj") == dj.id
		row.button.Visible = refusal == nil or refusal == "cash"
		row.button.Text = "Book " .. Format.money(dj.price)
		row.button.TextColor3 = if refusal == "cash" then Style.MUTED else Style.TEXT
		row.status.Visible = not row.button.Visible
		if playingNow then
			row.status.Text = "On the decks now!"
			row.status.TextColor3 = Style.GOOD
		elseif refusal == "resting" then
			local left = math.max(0, (resting[dj.id] or 0) - now)
			row.status.Text = string.format("Resting %d:%02d", math.floor(left / 60), math.floor(left) % 60)
			row.status.TextColor3 = Style.MUTED
		elseif refusal then
			row.status.Text = Booking.explain(refusal, dj)
			row.status.TextColor3 = Style.MUTED
		end
	end
end

local function buildRow(list: ScrollingFrame, order: number, dj: Types.StarDj)
	local row = Instance.new("Frame")
	row.Name = dj.id
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
	row.BackgroundColor3 = Color3.fromRGB(26, 26, 38)
	row.BorderSizePixel = 0
	row.Parent = list
	Style.corner(row, UDim.new(0, 10))
	Style.stroke(row, dj.colour, 1)

	local portrait = Instance.new("Frame")
	portrait.Size = UDim2.fromOffset(44, 44)
	portrait.Position = UDim2.fromOffset(10, 10)
	portrait.BackgroundColor3 = dj.colour
	portrait.BorderSizePixel = 0
	portrait.Parent = row
	Style.corner(portrait, UDim.new(0.5, 0))
	Style.label(
		portrait,
		"Initial",
		string.sub(dj.name, 1, 1),
		UDim2.fromScale(0.6, 0.6),
		UDim2.fromScale(0.2, 0.2),
		Style.PANEL
	)

	local name = Style.label(row, "Name", dj.name, UDim2.new(0.5, -64, 0, 22), UDim2.fromOffset(64, 8), dj.colour)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local details = Style.label(
		row,
		"Details",
		string.format(
			"%s · x%s income for %d min",
			dj.style,
			tostring(dj.multiplier),
			math.round(Balance.StarDjs.setSeconds / 60)
		),
		UDim2.new(0.62, -64, 0, 16),
		UDim2.fromOffset(64, 34),
		Style.MUTED,
		Style.BODY
	)
	details.TextXAlignment = Enum.TextXAlignment.Left

	local button = Style.button(row, "Book", "Book", UDim2.new(0.36, 0, 0, 38), UDim2.new(0.64, -8, 0, 13))
	button.Activated:Connect(function()
		Sfx.play("click")
		Remotes.event("BookDj"):FireServer(dj.id)
	end)
	local status = Style.label(row, "Status", "", UDim2.new(0.36, 0, 0, 22), UDim2.new(0.64, -8, 0, 21), Style.MUTED)
	status.Visible = false
	rows[dj.id] = { button = button, status = status }
end

function DjBoard.open()
	gui.Enabled = true
	refresh()
end

function DjBoard.close()
	gui.Enabled = false
end

function DjBoard.start()
	gui = Instance.new("ScreenGui")
	gui.Name = "DjBoard"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 10

	local panel = Style.panel(gui, "Panel", UDim2.fromScale(0.9, 0.8), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	Style.follow(Style.stroke(panel, Style.accent()), "Color")
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(480, 400)
	limit.Parent = panel

	Style.label(panel, "Title", "Book a Star DJ", UDim2.new(1, -80, 0, 30), UDim2.fromOffset(16, 10)).TextXAlignment =
		Enum.TextXAlignment.Left
	local subtitle = Style.label(
		panel,
		"Subtitle",
		string.format(
			"A guest set at your decks: a bigger crowd and more income. Then they rest for %d min.",
			math.round(Balance.StarDjs.restSeconds / 60)
		),
		UDim2.new(1, -32, 0, 16),
		UDim2.fromOffset(16, 42),
		Style.MUTED,
		Style.BODY
	)
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	local close = Style.button(panel, "Close", "X", UDim2.fromOffset(40, 40), UDim2.new(1, -52, 0, 8))
	close.Activated:Connect(DjBoard.close)

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(12, 68)
	list.Size = UDim2.new(1, -24, 1, -80)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	for order, dj in StarDjs do
		buildRow(list, order, dj)
	end

	Remotes.event("OpenBoard").OnClientEvent:Connect(DjBoard.open)
	Remotes.event("DjNotice").OnClientEvent:Connect(function(kind: unknown, djId: unknown, reason: unknown)
		local dj = if typeof(djId) == "string" then Booking.find(djId) else nil
		if not dj then
			return
		end
		if kind == "started" then
			DjBoard.close()
			Sfx.play("starDj")
			Hud.float(dj.name .. " is on the decks!", dj.colour)
		elseif kind == "ended" then
			Hud.float(dj.name .. "'s set is over. What a night!", Style.MUTED)
		elseif kind == "refused" and typeof(reason) == "string" then
			Hud.float(Booking.explain(reason :: Booking.Refusal, dj), Style.BAD)
		end
		refresh()
	end)
	player:GetAttributeChangedSignal("Cash"):Connect(refresh)
	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since >= REFRESH then
			since = 0
			refresh()
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return DjBoard
