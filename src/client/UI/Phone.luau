--!strict
-- The phone (docs/superpowers/specs/2026-11-05-truck-delivery-design.md): a button at the edge of
-- the screen (P on a keyboard, a tap on touch) that opens the list of what the player can order
-- next. They tick up to three items they can afford and press Order; the server takes the cash and
-- sends the truck. While a delivery is going the panel says where it stands instead. A plain,
-- working panel for now; Filip's phone UI references come later. The server decides everything:
-- the list is its "Shelf" attribute, the order's state comes from "OrderState" and friends.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Hud = require(script.Parent.Hud)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local OwnPlot = require(script.Parent.Parent.Controllers.OwnPlot)
local Pricing = require(ReplicatedStorage.Shared.Economy.Pricing)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(script.Parent.Parent.Controllers.Sfx)
local Style = require(script.Parent.Style)
local Types = require(ReplicatedStorage.Shared.Types)

local Phone = {}

local KEY = Enum.KeyCode.P
local ROW_HEIGHT = 56
local REFRESH = 0.2
local ICON = 64

local REFUSALS: { [string]: string } = {
	busy = "Your last delivery isn't done yet",
	cash = "Not enough cash yet",
	size = "Too many items in one order",
	locked = "That isn't available right now",
	away = "Go back to the street to order",
	empty = "Pick something to order first",
	["repeat"] = "Each item only once",
}

type Row = { frame: Frame, check: TextLabel, price: TextLabel, cost: number }

local player = Players.LocalPlayer
local gui: ScreenGui
local panel: Frame
local list: ScrollingFrame
local status: Frame
local statusTitle: TextLabel
local statusText: TextLabel
local footer: Frame
local totalLabel: TextLabel
local orderButton: TextButton
local iconButton: TextButton
local rows: { [string]: Row } = {}
local selected: { [string]: boolean } = {}
local shownShelf = ""
local plotRef: Model? = nil

local function number(value: unknown): number
	return if typeof(value) == "number" then value else 0
end

local function text(name: string): string
	local value = player:GetAttribute(name)
	return if typeof(value) == "string" then value else ""
end

local function ids(csv: string): { string }
	local result = {}
	for id in string.gmatch(csv, "[^,]+") do
		table.insert(result, id)
	end
	return result
end

local function itemFor(locationId: string, itemId: string): Types.Item?
	for _, item in Items[locationId] or {} do
		if item.id == itemId then
			return item
		end
	end
	return nil
end

local function locationId(): string?
	local plot = plotRef
	local id = if plot then plot:GetAttribute("LocationId") else nil
	return if typeof(id) == "string" then id else nil
end

local function selectedIds(): { string }
	local result = {}
	for _, id in ids(text("Shelf")) do
		if selected[id] then
			table.insert(result, id)
		end
	end
	return result
end

local function selectedTotal(): number
	local sum = 0
	for id in selected do
		local row = rows[id]
		if row then
			sum += row.cost
		end
	end
	return sum
end

-- Whether nothing has been placed yet: the phone pulses to say "start here".
local function nothingBuilt(): boolean
	local plot = plotRef
	local built = if plot then plot:FindFirstChild("Items") else nil
	return built ~= nil and #built:GetChildren() == 0
end

local function refresh()
	if not gui then
		return
	end
	local state = text("OrderState")
	local busy = state ~= ""
	status.Visible = panel.Visible and busy
	list.Visible = panel.Visible and not busy
	footer.Visible = panel.Visible and not busy

	if busy then
		if state == "transit" then
			local left = math.max(0, math.ceil(number(player:GetAttribute("OrderEta")) - workspace:GetServerTimeNow()))
			statusTitle.Text = "Truck on its way"
			statusText.Text = if left > 0
				then string.format("It stops at your door in %ds. Boxes come off on the pavement.", left)
				else "It's pulling up..."
		elseif state == "ready" then
			statusTitle.Text = "Your boxes are here"
			statusText.Text = "Walk up to a box on the pavement and press E to pick it up. One at a time."
		else
			local carrying = player:GetAttribute("Carrying")
			local item = if typeof(carrying) == "string" and locationId()
				then itemFor(locationId() :: string, carrying)
				else nil
			statusTitle.Text = "Carry it inside"
			statusText.Text = string.format(
				"Take the %s to its glowing outline in the room and press E to place it.",
				if item then item.name else "box"
			)
		end
		return
	end

	local cash = number(player:GetAttribute("Cash"))
	local total = selectedTotal()
	for id, row in rows do
		local picked = selected[id] == true
		row.check.Text = if picked then "✓" else ""
		row.frame.BackgroundTransparency = if picked then 0.05 else 0.2
		row.price.TextColor3 = if row.cost == 0 then Style.GOLD elseif cash >= row.cost then Style.GOOD else Style.BAD
	end
	totalLabel.Text = "Total " .. (if total == 0 then "-" else Format.money(total))
	local ok = #selectedIds() > 0 and total <= cash
	orderButton.TextColor3 = if ok then Style.GOOD else Style.MUTED
	orderButton.Text = if #selectedIds() == 0 then "Order" else string.format("Order (%d)", #selectedIds())
end

-- Rebuilds the list from the server's shelf.
local function rebuild()
	local id = locationId()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	rows = {}
	if not id then
		shownShelf = "" -- not ready yet: the next open tries again
		return
	end
	shownShelf = text("Shelf")
	local effects = Pricing.effects(id)
	for order, itemId in ids(shownShelf) do
		local item = itemFor(id, itemId)
		local effect = effects[itemId]
		if not item or not effect then
			continue
		end
		local frame = Instance.new("Frame")
		frame.Name = itemId
		frame.LayoutOrder = order
		frame.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
		frame.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
		frame.BackgroundTransparency = 0.2
		frame.BorderSizePixel = 0
		frame.Parent = list
		Style.corner(frame, UDim.new(0, 10))

		local box = Style.button(frame, "Tick", "", UDim2.fromOffset(40, 40), UDim2.fromOffset(8, 8))
		box.Text = ""
		local check = Style.label(box, "Check", "", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Style.GOOD)
		local name = Style.label(frame, "Name", item.name, UDim2.new(0.5, -60, 0, 24), UDim2.fromOffset(58, 6))
		name.TextXAlignment = Enum.TextXAlignment.Left
		local detail = Style.label(
			frame,
			"Detail",
			if item.kind == "gear" then string.format("x%.2f income", effect.multiplier) else Format.rate(effect.flat),
			UDim2.new(0.5, -60, 0, 16),
			UDim2.fromOffset(58, 32),
			Style.MUTED,
			Style.BODY
		)
		detail.TextXAlignment = Enum.TextXAlignment.Left
		local price = Style.label(
			frame,
			"Price",
			if effect.cost == 0 then "FREE" else Format.money(effect.cost),
			UDim2.new(0.34, 0, 0, 30),
			UDim2.new(0.66, -8, 0, 13),
			Style.GOOD
		)
		price.TextXAlignment = Enum.TextXAlignment.Right
		rows[itemId] = { frame = frame, check = check, price = price, cost = effect.cost }

		local function toggle()
			if selected[itemId] then
				selected[itemId] = nil
			elseif #selectedIds() >= Balance.Delivery.maxItems then
				Hud.float(string.format("Up to %d items per order", Balance.Delivery.maxItems), Style.WARN)
			else
				selected[itemId] = true
			end
			refresh()
		end
		box.Activated:Connect(toggle)
		local hit = Instance.new("TextButton")
		hit.Name = "Hit"
		hit.Size = UDim2.new(1, -60, 1, 0)
		hit.Position = UDim2.fromOffset(56, 0)
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.Parent = frame
		hit.Activated:Connect(toggle)
	end
	for stale in selected do
		if not rows[stale] then
			selected[stale] = nil
		end
	end
	refresh()
end

function Phone.open()
	panel.Visible = true
	if text("Shelf") ~= shownShelf then
		rebuild()
	end
	refresh()
end

function Phone.close()
	panel.Visible = false
	refresh()
end

function Phone.toggle()
	if panel.Visible then
		Phone.close()
	else
		Phone.open()
	end
end

local function sendOrder()
	local cart = selectedIds()
	if #cart == 0 then
		Hud.float(REFUSALS.empty, Style.WARN)
		return
	end
	if selectedTotal() > number(player:GetAttribute("Cash")) then
		Hud.float(REFUSALS.cash, Style.BAD)
		return
	end
	Remotes.event("PlaceOrder"):FireServer(cart)
end

function Phone.start()
	plotRef = OwnPlot.wait()
	gui = Instance.new("ScreenGui")
	gui.Name = "Phone"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6

	-- The button at the right edge: a little phone.
	iconButton = Style.button(gui, "Open", "", UDim2.fromOffset(ICON, ICON), UDim2.new(1, -14, 0.5, 0))
	iconButton.AnchorPoint = Vector2.new(1, 0.5)
	iconButton.Text = ""
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.46)
	body.Size = UDim2.fromOffset(26, 42)
	body.BorderSizePixel = 0
	body.Parent = iconButton
	Style.corner(body, UDim.new(0, 6))
	Style.follow(body, "BackgroundColor3")
	local screen = Instance.new("Frame")
	screen.Name = "Screen"
	screen.AnchorPoint = Vector2.new(0.5, 0.5)
	screen.Position = UDim2.fromScale(0.5, 0.5)
	screen.Size = UDim2.new(1, -6, 1, -10)
	screen.BackgroundColor3 = Style.PANEL
	screen.BorderSizePixel = 0
	screen.Parent = body
	Style.corner(screen, UDim.new(0, 3))
	if not UserInputService.TouchEnabled then
		Style.label(iconButton, "Key", "P", UDim2.fromOffset(20, 14), UDim2.new(0.5, -10, 1, -18), Style.MUTED)
	end
	iconButton.Activated:Connect(Phone.toggle)

	-- The panel.
	panel = Style.panel(gui, "Panel", UDim2.fromScale(0.9, 0.85), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	Style.follow(Style.stroke(panel, Style.accent()), "Color")
	panel.Visible = false
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(460, 470)
	limit.Parent = panel
	Style.label(panel, "Title", "Phone", UDim2.new(1, -80, 0, 30), UDim2.fromOffset(16, 10)).TextXAlignment =
		Enum.TextXAlignment.Left
	local subtitle = Style.label(
		panel,
		"Subtitle",
		string.format("Order up to %d things. A truck brings them to your door.", Balance.Delivery.maxItems),
		UDim2.new(1, -32, 0, 16),
		UDim2.fromOffset(16, 42),
		Style.MUTED,
		Style.BODY
	)
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	local close = Style.button(panel, "Close", "X", UDim2.fromOffset(40, 40), UDim2.new(1, -52, 0, 8))
	close.Activated:Connect(Phone.close)

	list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(12, 68)
	list.Size = UDim2.new(1, -24, 1, -158)
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

	status = Instance.new("Frame")
	status.Name = "Status"
	status.Position = UDim2.fromOffset(12, 68)
	status.Size = UDim2.new(1, -24, 1, -80)
	status.BackgroundTransparency = 1
	status.Visible = false
	status.Parent = panel
	statusTitle = Style.label(status, "Title", "", UDim2.new(1, 0, 0, 40), UDim2.fromScale(0, 0.18), Style.GOLD)
	statusText =
		Style.label(status, "Text", "", UDim2.new(1, -24, 0, 70), UDim2.new(0, 12, 0.18, 52), Style.TEXT, Style.BODY)
	statusText.TextWrapped = true
	statusText.TextScaled = false
	statusText.TextSize = 22

	footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.new(0, 12, 1, -10)
	footer.Size = UDim2.new(1, -24, 0, 70)
	footer.BackgroundTransparency = 1
	footer.Parent = panel
	totalLabel = Style.label(footer, "Total", "Total -", UDim2.new(0.5, 0, 0, 34), UDim2.fromOffset(4, 18), Style.TEXT)
	totalLabel.TextXAlignment = Enum.TextXAlignment.Left
	orderButton = Style.button(footer, "Order", "Order", UDim2.new(0.46, 0, 0, 54), UDim2.new(0.54, 0, 0, 8))
	orderButton.Activated:Connect(sendOrder)

	Remotes.event("OrderResult").OnClientEvent:Connect(function(ok: unknown, why: unknown)
		if ok == true then
			table.clear(selected)
			Sfx.play("buy")
			Hud.float("Truck's on its way!", Style.GOLD)
			Phone.close()
		else
			Hud.float(REFUSALS[tostring(why)] or "That order didn't go through", Style.BAD)
		end
		refresh()
	end)

	for _, name in { "Shelf", "Cash", "OrderState", "OrderItems", "OrderEta", "Carrying" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if name == "Shelf" and panel.Visible and text("Shelf") ~= shownShelf then
				rebuild()
			end
			refresh()
		end)
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == KEY then
			Phone.toggle()
		end
	end)

	-- A pulse on the button until the first thing is built, and the countdown while the truck drives.
	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		local pulse = nothingBuilt() and text("OrderState") == "" and not panel.Visible
		local grow = if pulse then 1 + math.abs(math.sin(os.clock() * 3)) * 0.14 else 1
		iconButton.Size = UDim2.fromOffset(ICON * grow, ICON * grow)
		if since >= REFRESH then
			since = 0
			if panel.Visible then
				refresh()
			end
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
	rebuild()
end

return Phone
