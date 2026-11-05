--!strict
-- Phone orders and the delivery truck (docs/superpowers/specs/2026-11-05-truck-delivery-design.md).
-- The owner orders up to a few shelf items on the phone and the cash is taken at once. A truck
-- drives down the street to their kerb and leaves one labelled box per item on the pavement. The
-- owner picks a box up (E), carries it into their room, and places it on its glowing outline (E):
-- only then is the item built, and only then does it earn. One box is carried at a time. The server
-- owns every step: who may order, pick up and place, how close they must stand, and in which order
-- (Economy/Orders). Cash paid for boxes not yet placed is kept in `state.inFlight`, which a save
-- adds back, so leaving or a crash mid-delivery never costs the player anything.
--
-- What the client sees, as attributes on the player: OrderState ("transit", "ready", "carrying"),
-- OrderItems (the ids not placed yet), OrderEta (server time the truck stops) and Carrying (the id
-- of the box in their hands). Boxes, outlines and the truck are real parts everyone sees.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Items = require(ReplicatedStorage.Shared.Config.Items)
local Orders = require(ReplicatedStorage.Shared.Economy.Orders)
local PlayerState = require(script.Parent.PlayerState)
local PlotSpace = require(ReplicatedStorage.Shared.Util.PlotSpace)
local PlotView = require(script.Parent.Parent.World.PlotView)
local Pricing = require(ReplicatedStorage.Shared.Economy.Pricing)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(script.Parent.Shop)
local Truck = require(script.Parent.Parent.World.Truck)
local Types = require(ReplicatedStorage.Shared.Types)

local Delivery = {}

local REQUEST_LOCK = 0.25 -- seconds between two requests from one player
local TOSS_SECONDS = 0.6 -- a box flying from the tailgate to its spot on the pavement
local CARRY_OFFSET = CFrame.new(0, 0.3, -2.6) -- where a carried box floats, in front of the character's middle

type Active = {
	order: Orders.Order,
	boxes: { [string]: Model },
	outlines: { [string]: BasePart },
}

local active: { [Player]: Active } = {}
local lastRequest: { [Player]: number } = {}

local function item(locationId: string, itemId: string): Types.Item?
	for _, candidate in Items[locationId] or {} do
		if candidate.id == itemId then
			return candidate
		end
	end
	return nil
end

local function rootPart(player: Player): BasePart?
	local character = player.Character
	local part = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if part and part:IsA("BasePart") then part else nil
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

-- Tells the client where the order stands.
local function publish(state: PlayerState.State, current: Active?)
	local player = state.player
	if not current then
		player:SetAttribute("OrderState", nil)
		player:SetAttribute("OrderItems", nil)
		player:SetAttribute("OrderEta", nil)
		player:SetAttribute("Carrying", nil)
		return
	end
	local carried = Orders.carried(current.order)
	local name = if carried
		then "carrying"
		elseif Orders.count(current.order, "delivered") > 0 then "ready"
		else "transit"
	local left = {}
	for _, id in current.order.items do
		if current.order.states[id] ~= "placed" then
			table.insert(left, id)
		end
	end
	player:SetAttribute("OrderState", name)
	player:SetAttribute("OrderItems", table.concat(left, ","))
	player:SetAttribute("Carrying", carried)
	if name ~= "transit" then
		player:SetAttribute("OrderEta", nil)
	end
end

local function slotOf(current: Active, itemId: string): number
	return table.find(current.order.items, itemId) or 1
end

-- Anchors every part of a box and flies it to `target` (or sets it there at once).
local function setDown(box: Model, target: CFrame)
	for _, part in box:GetDescendants() do
		if part:IsA("WeldConstraint") then
			part:Destroy()
		end
	end
	for _, part in box:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end
	box:PivotTo(target)
end

-- The truck has stopped: boxes come off its tailgate onto the pavement and the outlines light up.
local function unload(state: PlayerState.State, current: Active, tailgate: CFrame)
	local plot = state.plot
	for index, itemId in current.order.items do
		local thing = item(state.locationId, itemId)
		if not thing or not Orders.advance(current.order, itemId, "delivered") then
			continue
		end
		local box = PlotView.addBox(plot, thing, index, tailgate)
		current.boxes[itemId] = box
		current.outlines[itemId] = PlotView.addOutline(plot, state.locationId, thing)
		-- A short toss from the tailgate to the pavement, one box after the other.
		task.spawn(function()
			task.wait((index - 1) * 0.25)
			local from = box:GetPivot()
			local to = PlotView.boxSpot(plot, index)
			local began = os.clock()
			while box.Parent and active[state.player] == current and Orders.carried(current.order) ~= itemId do
				local alpha = math.min(1, (os.clock() - began) / TOSS_SECONDS)
				local lift = Vector3.new(0, math.sin(alpha * math.pi) * 3, 0)
				box:PivotTo(from:Lerp(to, alpha) + lift)
				if alpha >= 1 then
					break
				end
				RunService.Heartbeat:Wait()
			end
		end)
	end
	publish(state, current)
end

local function run(state: PlayerState.State, current: Active)
	local seconds = Orders.deliverySeconds(#current.order.items)
	state.player:SetAttribute("OrderEta", workspace:GetServerTimeNow() + seconds)
	Truck.run(state.plot, seconds, function(tailgate)
		if active[state.player] == current then
			unload(state, current, tailgate)
		end
	end, function()
		return active[state.player] ~= current or PlayerState.get(state.player) ~= state
	end)
end

-- Orders the cart for the owner if they may: takes the cash and sends the truck. Returns whether it
-- went through, and why not.
function Delivery.order(state: PlayerState.State, requested: unknown): (boolean, string?)
	if active[state.player] then
		return false, "busy"
	end
	if PlotSpace.away(state.plot) then
		return false, "away" -- the room is at a venue; a truck on the street couldn't reach it
	end
	local effects = Pricing.effects(state.locationId)
	local cart, why = Orders.validate(state.locationId, state.bought, state.cash, requested, effects)
	if not cart then
		return false, why
	end
	local order = Orders.new(cart, effects)
	local current: Active = { order = order, boxes = {}, outlines = {} }
	active[state.player] = current
	state.inFlight += order.total
	PlayerState.setCash(state, state.cash - order.total)
	publish(state, current)
	task.spawn(run, state, current)
	return true, nil
end

-- The carried box goes back on the pavement (its carrier died, or the order was cancelled).
local function dropBox(state: PlayerState.State, current: Active)
	local carried = Orders.carried(current.order)
	if not carried then
		return
	end
	Orders.advance(current.order, carried, "delivered")
	local box = current.boxes[carried]
	if box then
		setDown(box, PlotView.boxSpot(state.plot, slotOf(current, carried)))
	end
	publish(state, current)
end

local function pickUp(state: PlayerState.State, current: Active, itemId: string)
	if Orders.carried(current.order) or current.order.states[itemId] ~= "delivered" then
		return
	end
	local box = current.boxes[itemId]
	local root = rootPart(state.player)
	local body = if box then box.PrimaryPart else nil
	if not box or not body or not root then
		return
	end
	if flatDistance(root.Position, body.Position) > Balance.Delivery.pickupRange then
		return
	end
	if not Orders.advance(current.order, itemId, "carried") then
		return
	end
	-- Weld the box to the character, in front of them: everyone sees it, and nothing runs on a client.
	for _, part in box:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
		end
	end
	box:PivotTo(root.CFrame * CARRY_OFFSET)
	for _, part in box:GetDescendants() do
		if part:IsA("BasePart") and part ~= body then
			local tie = Instance.new("WeldConstraint")
			tie.Part0 = body
			tie.Part1 = part
			tie.Parent = body
		end
	end
	local hold = Instance.new("WeldConstraint")
	hold.Part0 = root
	hold.Part1 = body
	hold.Parent = body
	publish(state, current)
end

local function place(state: PlayerState.State, current: Active, itemId: string)
	if Orders.carried(current.order) ~= itemId then
		return
	end
	local outline = current.outlines[itemId]
	local root = rootPart(state.player)
	if not outline or not root then
		return
	end
	if flatDistance(root.Position, outline.Position) > Balance.Delivery.placeRange then
		return
	end
	if not Orders.advance(current.order, itemId, "placed") then
		return
	end
	local box = current.boxes[itemId]
	if box then
		box:Destroy()
	end
	outline:Destroy()
	current.boxes[itemId] = nil
	current.outlines[itemId] = nil
	state.inFlight -= current.order.costs[itemId]
	local done = Orders.isDone(current.order)
	if done then
		active[state.player] = nil
	end
	publish(state, if done then nil else current)
	Shop.place(state, itemId, true)
end

-- Cancels the owner's order: the boxes and outlines go and the unplaced items are paid back.
-- (Studio shortcuts use this; leaving doesn't need it, see `stop`.)
function Delivery.cancel(state: PlayerState.State)
	local current = active[state.player]
	if not current then
		return
	end
	active[state.player] = nil
	local refund = Orders.unplacedCost(current.order)
	state.inFlight -= refund
	PlayerState.setCash(state, state.cash + refund)
	PlotView.clearDelivery(state.plot)
	publish(state, nil)
end

-- Forgets the order of a player who is leaving. Their save already counts `inFlight` as cash.
function Delivery.stop(state: PlayerState.State)
	active[state.player] = nil
	lastRequest[state.player] = nil
end

-- Whether the player has an order going (the Studio shortcuts check this).
function Delivery.busy(player: Player): boolean
	return active[player] ~= nil
end

local function onPrompt(prompt: ProximityPrompt, player: Player)
	local boxItem = prompt:GetAttribute("BoxItem")
	local outlineItem = prompt:GetAttribute("OutlineItem")
	if typeof(boxItem) ~= "string" and typeof(outlineItem) ~= "string" then
		return
	end
	local state = PlayerState.get(player)
	local current = active[player]
	if not state or not current or prompt:GetAttribute("OwnerUserId") ~= player.UserId then
		return
	end
	local now = os.clock()
	if now - (lastRequest[player] or 0) < REQUEST_LOCK then
		return
	end
	lastRequest[player] = now
	if typeof(boxItem) == "string" then
		pickUp(state, current, boxItem)
	elseif typeof(outlineItem) == "string" then
		place(state, current, outlineItem)
	end
end

function Delivery.start()
	local result = Remotes.event("OrderResult")
	Remotes.event("PlaceOrder").OnServerEvent:Connect(function(player, requested)
		local state = PlayerState.get(player)
		local now = os.clock()
		if not state or now - (lastRequest[player] or 0) < REQUEST_LOCK then
			return
		end
		lastRequest[player] = now
		local ok, why = Delivery.order(state, requested)
		result:FireClient(player, ok, why)
	end)
	ProximityPromptService.PromptTriggered:Connect(onPrompt)

	-- A character that's removed (died, respawned) puts its box back on the pavement first.
	local function watch(player: Player)
		player.CharacterRemoving:Connect(function()
			local state = PlayerState.get(player)
			local current = active[player]
			if state and current then
				dropBox(state, current)
			end
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
end

return Delivery
