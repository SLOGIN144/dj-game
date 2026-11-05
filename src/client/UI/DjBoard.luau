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
local CrateConfig = require(ReplicatedStorage.Shared.Config.Crates)
local CrateRules = require(ReplicatedStorage.Shared.Economy.Crates)
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
local crateButtons: { [string]: TextButton } = {}
local reveal: Frame
local revealToken = 0

-- How rare a DJ is, in the colour the board shows it in.
local RARITY_COLOUR: { [string]: Color3 } = {
	common = Color3.fromRGB(190, 190, 206),
	rare = Color3.fromRGB(80, 160, 255),
	epic = Color3.fromRGB(190, 100, 255),
	legendary = Color3.fromRGB(255, 190, 60),
}
local CRATE_REFUSALS: { [string]: string } = {
	cash = "Not enough cash for that crate",
	noBoard = "Buy this location's booking board first",
	complete = "You already have every DJ available here",
}

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

-- The DJs the server says the player has found in crates.
local function ownedDjs(): { [string]: boolean }
	local result = {}
	local text = player:GetAttribute("OwnedDjs")
	if typeof(text) == "string" then
		for id in string.gmatch(text, "[^,]+") do
			result[id] = true
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
	local owned = ownedDjs()
	local now = workspace:GetServerTimeNow()
	local situation: Booking.Situation = {
		locationId = locationId,
		hasBoard = hasBoard(plot, locationId),
		owned = false,
		cash = number(player:GetAttribute("Cash")),
		playing = plot:GetAttribute("StarDj") ~= nil,
		restUntil = nil,
		now = math.floor(now),
	}
	for _, dj in StarDjs do
		local row = rows[dj.id]
		situation.restUntil = resting[dj.id]
		situation.owned = CrateRules.isOwned(dj, owned)
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
			row.status.Text = if refusal == "notOwned" then "Find in crates" else Booking.explain(refusal, dj)
			row.status.TextColor3 = Style.MUTED
		end
	end
	-- What each crate costs here, and whether the player can pay it.
	local cash = number(player:GetAttribute("Cash"))
	for _, crate in CrateConfig do
		local button = crateButtons[crate.id]
		if button then
			local price = CrateRules.price(crate, locationId)
			button.Text = string.format("%s  %s", crate.name, Format.money(price))
			button.TextColor3 = if cash >= price then crate.colour else Style.MUTED
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
	Style.stroke(row, RARITY_COLOUR[dj.rarity], 1.5)

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
			"%s · %s · x%s for %d min",
			string.upper(dj.rarity),
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
	limit.MaxSize = Vector2.new(480, 500)
	limit.Parent = panel

	Style.label(panel, "Title", "DJ Board", UDim2.new(1, -80, 0, 30), UDim2.fromOffset(16, 10)).TextXAlignment =
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
	list.Position = UDim2.fromOffset(12, 156)
	list.Size = UDim2.new(1, -24, 1, -168)
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

	-- The crates: two buttons above the list, with the odds under each (they are shown, not hidden).
	local crateBar = Instance.new("Frame")
	crateBar.Name = "Crates"
	crateBar.Position = UDim2.fromOffset(12, 66)
	crateBar.Size = UDim2.new(1, -24, 0, 84)
	crateBar.BackgroundTransparency = 1
	crateBar.Parent = panel
	local barLayout = Instance.new("UIListLayout")
	barLayout.FillDirection = Enum.FillDirection.Horizontal
	barLayout.SortOrder = Enum.SortOrder.LayoutOrder
	barLayout.Padding = UDim.new(0, 8)
	barLayout.Parent = crateBar
	for crateOrder, crate in CrateConfig do
		local cell = Instance.new("Frame")
		cell.Name = crate.id
		cell.LayoutOrder = crateOrder
		cell.Size = UDim2.new(0.5, -4, 1, 0)
		cell.BackgroundTransparency = 1
		cell.Parent = crateBar
		local button = Style.button(cell, "Open", crate.name, UDim2.new(1, 0, 0, 40), UDim2.fromOffset(0, 0))
		button.TextColor3 = crate.colour
		button.Activated:Connect(function()
			Sfx.play("click")
			Remotes.event("OpenCrate"):FireServer(crate.id)
		end)
		crateButtons[crate.id] = button
		local odds = Style.label(
			cell,
			"Odds",
			string.format(
				"%s%% common · %s%% rare · %s%% epic · %s%% legendary",
				tostring(crate.odds.common),
				tostring(crate.odds.rare),
				tostring(crate.odds.epic),
				tostring(crate.odds.legendary)
			),
			UDim2.new(1, 0, 0, 38),
			UDim2.fromOffset(0, 44),
			Style.MUTED,
			Style.BODY
		)
		odds.TextWrapped = true
		odds.TextScaled = false
		odds.TextSize = 13
		odds.TextYAlignment = Enum.TextYAlignment.Top
	end

	-- The reveal when a crate opens: who came out, how rare, what they do.
	reveal = Instance.new("Frame")
	reveal.Name = "Reveal"
	reveal.AnchorPoint = Vector2.new(0.5, 0.5)
	reveal.Position = UDim2.fromScale(0.5, 0.45)
	reveal.Size = UDim2.fromOffset(340, 150)
	reveal.BackgroundColor3 = Style.PANEL
	reveal.BorderSizePixel = 0
	reveal.Visible = false
	reveal.ZIndex = 20
	reveal.Parent = gui
	Style.corner(reveal, UDim.new(0, 18))
	local revealStroke = Style.stroke(reveal, Style.GOLD, 3)
	revealStroke.Name = "Stroke"
	for _, name in { "Rarity", "Dj", "Info" } do
		local label = Style.label(
			reveal,
			name,
			"",
			UDim2.new(1, -24, 0, if name == "Dj" then 44 else 28),
			UDim2.fromOffset(12, 0)
		)
		label.ZIndex = 21
	end
	reveal.Rarity.Position = UDim2.fromOffset(12, 12)
	reveal.Dj.Position = UDim2.fromOffset(12, 44)
	reveal.Info.Position = UDim2.fromOffset(12, 98)
	reveal.Info.Font = Style.BODY
	reveal.Info.TextColor3 = Style.MUTED
	Remotes.event("CrateResult").OnClientEvent:Connect(function(ok: unknown, _crateId: unknown, a: unknown, b: unknown)
		if ok ~= true then
			local text = if typeof(a) == "string" then CRATE_REFUSALS[a] else nil
			Hud.float(text or "That crate couldn't be opened", Style.BAD)
			return
		end
		local dj = if typeof(a) == "string" then Booking.find(a) else nil
		if not dj then
			return
		end
		local refund = number(b)
		local colour = RARITY_COLOUR[dj.rarity]
		Sfx.play(if dj.rarity == "legendary" or dj.rarity == "epic" then "starDj" else "buy")
		reveal.Rarity.Text = if refund > 0 then "ALREADY YOURS" else string.upper(dj.rarity) .. "!"
		reveal.Rarity.TextColor3 = colour
		reveal.Dj.Text = dj.name
		reveal.Dj.TextColor3 = dj.colour
		reveal.Info.Text = if refund > 0
			then string.format("%s pays back %s", "The crate", Format.money(refund))
			else string.format(
				"%s · x%s income for %d min",
				dj.style,
				tostring(dj.multiplier),
				math.round(Balance.StarDjs.setSeconds / 60)
			)
		reveal.Stroke.Color = colour
		reveal.Visible = true
		revealToken += 1
		local mine = revealToken
		task.delay(3.5, function()
			if revealToken == mine then
				reveal.Visible = false
			end
		end)
		refresh()
	end)
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
