# Tycoon Step 2: Street, Plots, Buttons, Income and Register — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A player joins, gets a plot on a night street, steps on buttons to build the dorm room piece by piece, and collects income from a register. This is GDD build order step 2.

**Architecture:** The pacing math lives in pure, tested modules in `src/shared/Economy` (Pricing, Income, Register, Unlocks) that read `Config/Items.luau`, `Config/Locations.luau` and `Balance.luau`. The server owns all money: it builds the street and the dorm blockout from data at start, assigns plots, ticks registers and handles button and register touches. The client only shows the HUD and colours button prices. The set-only prototype code is removed first (approved by Filip; kept under the git tag `set-prototype`).

**Tech Stack:** Luau `--!strict`, Rojo 7.7.1 (`default.project.json`, port 34872), Roblox Studio MCP for playtests, Selene + StyLua. Tests: `tests/*.spec.luau`, run on Play in the tagger place.

**Verified API names** (creator-docs, 2026-11-03): `BasePart.Touched`, `BasePart.CanTouch` (don't toggle it after connecting: that disconnects the event; create and destroy button pads instead), `Players.PlayerAdded`, `Players.PlayerRemoving`, `Players:GetPlayerFromCharacter`, `Player.RespawnLocation` (a Workspace `SpawnLocation` with `Neutral = true`), `Player.CharacterAdded`, `SpawnLocation.Duration`, `Instance:SetAttribute`, `Instance:GetAttribute`, `Instance:GetAttributeChangedSignal`, `BillboardGui.Adornee/Size/StudsOffset/AlwaysOnTop/MaxDistance`, `TweenService:Create`, `PVInstance:PivotTo/GetPivot`, `RunService.Heartbeat`, `Lighting.ClockTime/Ambient/OutdoorAmbient`.

---

## File structure

| File | Responsibility |
| --- | --- |
| `src/shared/Types.luau` (modify) | add `ItemKind`, `Item`, `Location`, `ItemEffect` |
| `src/shared/Config/Locations.luau` (create, replaces `Venues.luau`) | the location list in order (dorm only in this step) |
| `src/shared/Config/Items.luau` (create) | every button per location, in unlock order |
| `src/shared/Config/PlotLayout.luau` (create) | plot size and where the spawn, register, sign and button slots sit |
| `src/shared/Config/Blockouts/Dorm.luau` (create) | dorm room shell parts and each item's parts |
| `src/shared/Config/Balance.luau` (modify) | drop set-only numbers; add Start, Pricing, Register, Buttons, World |
| `src/shared/Economy/Pricing.luau` (create) | each item's cost and effect from the pacing numbers |
| `src/shared/Economy/Income.luau` (create) | a plot's income per second from its bought items |
| `src/shared/Economy/Register.luau` (create) | register fill with a cap |
| `src/shared/Economy/Unlocks.luau` (create) | which buttons show, can an item be bought, is the location done, next location |
| `src/shared/Util/Format.luau` (create) | `$1.2K` and `+$3.5/s` text |
| `src/shared/Remotes.luau` (create) | named RemoteEvents, made by the server |
| `src/shared/Music/` (move from `Set/`) | `TimingJudge`, `TrackInfo`, `TransitionPlanner`, `Crossfade` (kept for steps 4–5) |
| `src/server/World/PartFactory.luau` | one Part from a part spec, relative to a plot origin |
| `src/server/World/Street.luau` | ground, road, sidewalks, night lighting, the plot bases |
| `src/server/World/PlotView.luau` | everything visible on one plot: sign, shell, items, pads, register label |
| `src/server/Services/PlayerState.luau` | in-memory state per player; mirrors Cash and Income as Player attributes |
| `src/server/Services/Plots.luau` | assigns and frees plots, spawn point |
| `src/server/Services/Shop.luau` | shows the button pads and handles buying |
| `src/server/Services/Economy.luau` | register ticks and collecting |
| `src/server/Main.server.luau` (modify) | starts the services |
| `src/client/UI/Hud.luau` | cash, income per second, floating "+$" on collect |
| `src/client/UI/PadLabels.luau` | colours the price on your own pads by what you can afford |
| `src/client/Main.client.luau` (rewrite) | starts the HUD |
| `tests/Economy.spec.luau` (create) | Pricing, Income, Register, Unlocks, Format |
| `tests/Music.spec.luau` (from `SetLogic.spec.luau`) | the kept TimingJudge, Crossfade, TransitionPlanner tests |

---

### Task 1: Remove the set-only code and keep the music modules

**Files:**
- Delete: `src/client/Controllers/SetDirector.luau`, `src/client/Controllers/SetInput.luau`, `src/client/UI/SetUI.luau`, `src/client/UI/CrowdView.luau`, `src/shared/Set/BlendJudge.luau`, `src/shared/Set/ChallengeQueue.luau`, `src/shared/Set/CrowdEnergy.luau`, `src/shared/Set/HypePlanner.luau`, `src/shared/Set/TrackChoice.luau`, `src/shared/Config/Venues.luau`, `tests/ChallengeQueue.spec.luau`, `prototype.project.json`
- Move: `src/shared/Set/{TimingJudge,TrackInfo,TransitionPlanner}.luau` → `src/shared/Music/`
- Create: `src/shared/Music/Crossfade.luau`
- Modify: `src/client/Controllers/AudioEngine.luau:11,160`, `src/shared/Config/Balance.luau`, `src/shared/Music/TransitionPlanner.luau:33`
- Rename: `tests/SetLogic.spec.luau` → `tests/Music.spec.luau`, keeping only the TimingJudge, gains and TransitionPlanner tests

- [ ] **Step 1:** `git rm` the files above and `git mv` the three kept modules into `src/shared/Music/`.
- [ ] **Step 2:** Create `src/shared/Music/Crossfade.luau` with the equal-power curve from BlendJudge:

```lua
--!strict
-- Equal-power crossfade: the two decks' gains for a crossfader position from 0 (deck A) to 1 (deck B).

local Crossfade = {}

function Crossfade.gains(position: number): (number, number)
	local x = math.clamp(position, 0, 1) * math.pi / 2
	return math.cos(x), math.sin(x)
end

return Crossfade
```

- [ ] **Step 3:** In `AudioEngine.luau` require `ReplicatedStorage.Shared.Music.Crossfade` instead of BlendJudge and call `Crossfade.gains(position)`.
- [ ] **Step 4:** In `Balance.luau` keep `Timing` and `Transition` (drop `missOffsetBeats`, add `bassSwapAt = 0.5`, `tempoRange = 0.08` and `leadBeats = 32`); delete `Blend`, `Hype`, `Energy`, `Combo`, `Score`, `Grades`, `Cards`, `Set`. In `TransitionPlanner.luau:33` replace `Balance.Cards.showBeforeBeats` with `Balance.Transition.leadBeats`.
- [ ] **Step 5:** `git mv tests/SetLogic.spec.luau tests/Music.spec.luau`; delete the BlendJudge zone/grade, CrowdEnergy, HypePlanner and TrackChoice tests; point the requires at `Shared.Music.*`; the gains test uses `Crossfade.gains`.
- [ ] **Step 6:** Rewrite `src/client/Main.client.luau` as a stub (`--!strict` plus a comment; Task 8 fills it). Remove the "Old set prototype" line from `CLAUDE.md`.
- [ ] **Step 7:** Check: `selene src tools tests` and `stylua --check src tools tests` clean; `grep -r "Shared.Set\|BlendJudge\|Venues" src tests tools` finds nothing.
- [ ] **Step 8:** Run the tests in the tagger place (Rojo `tagger.project.json` synced into a scratch copy, Play, read `[Tests] N passed, 0 failed`).
- [ ] **Step 9:** Commit "Remove the set-only prototype code; keep the music modules".

### Task 2: Types, config and balance for the economy

**Files:** Modify `src/shared/Types.luau`, `src/shared/Config/Balance.luau`; create `src/shared/Config/Locations.luau`, `src/shared/Config/Items.luau`.

- [ ] **Step 1:** Add to `Types.luau`:

```lua
export type ItemKind = "income" | "gear" | "feature"

export type Item = {
	id: string, -- unique across all locations, prefixed with its location ("dorm_lamp")
	name: string, -- shown on the button
	kind: ItemKind, -- income and feature items add cash per second; gear multiplies the plot's income
}

export type Location = {
	id: string,
	name: string,
	colour: Color3, -- neon accent for this location's UI and lights
	guests: { min: number, max: number }, -- guests shown, from no income to a finished location
}

-- What one item costs and does to its plot's income.
export type ItemEffect = {
	cost: number,
	flat: number, -- cash per second it adds (0 for gear)
	multiplier: number, -- what it multiplies the plot's income by (1 unless gear)
}
```

- [ ] **Step 2:** Create `Config/Locations.luau`:

```lua
--!strict
-- The career's locations, in order. A new location is one more entry here, its items in
-- Items.luau, its pacing in Balance.Pricing and its blockout in Blockouts/.

local Types = require(script.Parent.Parent.Types)

local Locations: { Types.Location } = {
	{ id = "dorm", name = "Dorm Room", colour = Color3.fromRGB(150, 90, 255), guests = { min = 0, max = 5 } },
}

return Locations
```

- [ ] **Step 3:** Create `Config/Items.luau` (English names: the game's UI is in English):

```lua
--!strict
-- Every button, per location, in the order they unlock. A location's first item is free and
-- must be an income item. Costs and effects come from Economy/Pricing, not from here.

local Types = require(script.Parent.Parent.Types)

local Items: { [string]: { Types.Item } } = {
	dorm = {
		{ id = "dorm_laptop", name = "Laptop", kind = "income" },
		{ id = "dorm_lamp", name = "Desk Lamp", kind = "income" },
		{ id = "dorm_speaker", name = "Small Speaker", kind = "income" },
		{ id = "dorm_led", name = "LED Strip", kind = "income" },
		{ id = "dorm_controller", name = "Volt 2 Controller", kind = "gear" },
		{ id = "dorm_posters", name = "Posters", kind = "income" },
		{ id = "dorm_beanbags", name = "Bean Bags", kind = "income" },
		{ id = "dorm_discoball", name = "Disco Ball", kind = "income" },
		{ id = "dorm_partylights", name = "Party Lights", kind = "income" },
		{ id = "dorm_neon", name = "Neon Sign", kind = "income" },
	},
}

return Items
```

- [ ] **Step 4:** Add to `Balance.luau`:

```lua
Balance.Start = {
	cash = 50, -- enough for the first paid button right away
	locationId = "dorm",
}

-- Pacing per location. Buying a location's items in order takes its income from startIncome to
-- startIncome × incomeGrowth, and saving for all of them takes about `minutes` of active play.
Balance.Pricing = {
	activeFactor = 1.3, -- active play (drops, events) earns this much more than idling
	timeGrowth = 1.15, -- each button takes this much longer to save for than the one before
	carryOver = 1.0, -- a location's free first item earns this share of the previous location's end income
	locations = {
		dorm = { minutes = 10, startIncome = 1, incomeGrowth = 12 },
	} :: { [string]: { minutes: number, incomeGrowth: number, startIncome: number? } },
}

Balance.Register = {
	capMinutes = 10, -- the register stops filling at this many minutes of income
}

Balance.Buttons = {
	visible = 3, -- how many of the next items show as buttons
}

Balance.World = {
	plotCount = 2, -- 6 at launch; 2 for the prototype's two-player test
}
```

- [ ] **Step 5:** Commit "Add the economy types, the dorm items and pacing numbers".

### Task 3: Format (TDD)

**Files:** Create `src/shared/Util/Format.luau`; create `tests/Economy.spec.luau`.

- [ ] **Step 1: Write the failing tests** in `tests/Economy.spec.luau` (later tasks add to the same table):

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Items = require(Shared.Config.Items)
local Format = require(Shared.Util.Format)
local Income = require(Shared.Economy.Income)
local Pricing = require(Shared.Economy.Pricing)
local Register = require(Shared.Economy.Register)
local Unlocks = require(Shared.Economy.Unlocks)
local T = require(script.Parent.TestUtil)

-- The first `count` items of a location, as a bought set.
local function boughtFirst(locationId: string, count: number): { [string]: boolean }
	local bought = {}
	for index = 1, count do
		bought[Items[locationId][index].id] = true
	end
	return bought
end

return {
	["money reads short and never rounds up"] = function()
		T.equal(Format.money(0), "$0")
		T.equal(Format.money(950.7), "$950")
		T.equal(Format.money(1000), "$1K")
		T.equal(Format.money(1999), "$1.9K")
		T.equal(Format.money(250000), "$250K")
		T.equal(Format.money(3400000), "$3.4M")
	end,

	["income per second keeps one decimal while small"] = function()
		T.equal(Format.rate(1), "+$1/s")
		T.equal(Format.rate(1.32), "+$1.3/s")
		T.equal(Format.rate(12.8), "+$12/s")
		T.equal(Format.rate(1500), "+$1.5K/s")
	end,
}
```

- [ ] **Step 2:** Play in the tagger place; expect `Economy.spec failed to load` (modules missing).
- [ ] **Step 3: Implement** `src/shared/Util/Format.luau`:

```lua
--!strict
-- Short money text for the HUD and the buttons: $950, $1.2K, $3.4M. Always rounds down, so the
-- screen never shows more than the player has.

local Format = {}

local SUFFIXES = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }

-- One decimal at most, without a trailing ".0".
local function short(value: number): string
	local text = string.format("%.1f", math.floor(value * 10) / 10)
	return (string.gsub(text, "%.0$", ""))
end

function Format.money(value: number): string
	local whole = math.floor(value)
	for _, suffix in SUFFIXES do
		local size, letter = suffix[1] :: number, suffix[2] :: string
		if whole >= size then
			local scaled = whole / size
			return "$" .. (if scaled < 100 then short(scaled) else tostring(math.floor(scaled))) .. letter
		end
	end
	return "$" .. tostring(whole)
end

function Format.rate(perSecond: number): string
	if perSecond < 10 then
		return "+$" .. short(perSecond) .. "/s"
	end
	return "+" .. Format.money(perSecond) .. "/s"
end

return Format
```

- [ ] **Step 4:** Tasks 4–5 add the economy modules; the spec only loads once they exist, so run it after Task 5.

### Task 4: Pricing (TDD)

**Files:** Create `src/shared/Economy/Pricing.luau`; add tests to `tests/Economy.spec.luau`.

- [ ] **Step 1: Add the failing tests:**

```lua
	["a location's first item is free"] = function()
		T.equal(Pricing.effects("dorm")[Items.dorm[1].id].cost, 0)
	end,

	["costs round to two significant figures"] = function()
		T.equal(Pricing.roundCost(46.4), 46)
		T.equal(Pricing.roundCost(1234), 1200)
		T.equal(Pricing.roundCost(0.4), 1)
	end,

	["each button costs more than the one before"] = function()
		local effects = Pricing.effects("dorm")
		for index = 3, #Items.dorm do
			local previous = effects[Items.dorm[index - 1].id].cost
			T.truthy(effects[Items.dorm[index].id].cost > previous, Items.dorm[index].id)
		end
	end,

	["gear multiplies the income and everything else adds to it"] = function()
		local effects = Pricing.effects("dorm")
		for _, item in Items.dorm do
			local effect = effects[item.id]
			if item.kind == "gear" then
				T.truthy(effect.multiplier > 1 and effect.flat == 0, item.id)
			else
				T.truthy(effect.flat > 0 and effect.multiplier == 1, item.id)
			end
		end
	end,

	["buying everything in order goes from the start to the end income"] = function()
		T.near(Income.perSecond("dorm", boughtFirst("dorm", 1)), Pricing.startIncome("dorm"))
		T.near(Income.perSecond("dorm", boughtFirst("dorm", #Items.dorm)), Pricing.endIncome("dorm"), 1e-6)
	end,

	["saving for the whole dorm takes about its target time with active play"] = function()
		local effects = Pricing.effects("dorm")
		local seconds = 0
		for index = 2, #Items.dorm do
			local income = Income.perSecond("dorm", boughtFirst("dorm", index - 1))
			seconds += effects[Items.dorm[index].id].cost / income
		end
		local target = Balance.Pricing.locations.dorm.minutes * 60
		T.near(seconds / Balance.Pricing.activeFactor, target, target * 0.05)
	end,
```

- [ ] **Step 2: Implement** `src/shared/Economy/Pricing.luau`:

```lua
--!strict
-- Turns a location's pacing numbers (Balance.Pricing) into each item's cost and effect.
-- Bought in order, the items take the plot's income from startIncome to startIncome × incomeGrowth
-- in even steps, and saving for each one takes a little longer than the one before.

local Balance = require(script.Parent.Parent.Config.Balance)
local Items = require(script.Parent.Parent.Config.Items)
local Locations = require(script.Parent.Parent.Config.Locations)
local Types = require(script.Parent.Parent.Types)

local Pricing = {}

local function pacing(locationId: string)
	local found = Balance.Pricing.locations[locationId]
	assert(found, "no pacing for location " .. locationId)
	return found
end

-- Two significant figures, so prices read cleanly; never below $1.
function Pricing.roundCost(value: number): number
	if value < 10 then
		return math.max(1, math.floor(value + 0.5))
	end
	local scale = 10 ^ (math.floor(math.log10(value)) - 1)
	return math.floor(value / scale + 0.5) * scale
end

-- Income per second with only the location's free first item.
function Pricing.startIncome(locationId: string): number
	local start = pacing(locationId).startIncome
	if start then
		return start
	end
	for index, location in Locations do
		if location.id == locationId then
			assert(index > 1, "the first location needs a startIncome")
			return Pricing.endIncome(Locations[index - 1].id) * Balance.Pricing.carryOver
		end
	end
	error("unknown location " .. locationId)
end

-- Income per second once every item of the location is bought.
function Pricing.endIncome(locationId: string): number
	return Pricing.startIncome(locationId) * pacing(locationId).incomeGrowth
end

-- Seconds of active play spent saving for each paid item (index 2 onward), summing to the
-- location's minutes.
local function saveTimes(locationId: string, count: number): { [number]: number }
	local weights, sum = {}, 0
	for index = 2, count do
		weights[index] = Balance.Pricing.timeGrowth ^ (index - 2)
		sum += weights[index]
	end
	local times = {}
	for index = 2, count do
		times[index] = pacing(locationId).minutes * 60 * weights[index] / sum
	end
	return times
end

-- Every item of the location with what it costs and does, keyed by item id.
function Pricing.effects(locationId: string): { [string]: Types.ItemEffect }
	local items = Items[locationId]
	assert(items and #items > 0, "no items for location " .. locationId)
	assert(items[1].kind == "income", "a location's first item must be an income item")

	local start, growth = Pricing.startIncome(locationId), pacing(locationId).incomeGrowth
	local times = saveTimes(locationId, #items)
	local effects = {}
	local flatSum, multiplier = 0, 1
	for index, item in items do
		local before = flatSum * multiplier
		local after = if #items == 1 then start else start * growth ^ ((index - 1) / (#items - 1))
		local cost = if index == 1 then 0 else Pricing.roundCost(before * Balance.Pricing.activeFactor * times[index])
		local effect: Types.ItemEffect = { cost = cost, flat = 0, multiplier = 1 }
		if item.kind == "gear" then
			effect.multiplier = after / before
			multiplier *= effect.multiplier
		else
			effect.flat = after / multiplier - flatSum
			flatSum += effect.flat
		end
		effects[item.id] = effect
	end
	return effects
end

return Pricing
```

### Task 5: Income, Register, Unlocks (TDD)

**Files:** Create `src/shared/Economy/{Income,Register,Unlocks}.luau`; add tests.

- [ ] **Step 1: Add the failing tests:**

```lua
	["the register fills with income up to its cap"] = function()
		T.near(Register.fill(0, 2, 5), 10)
		local cap = Register.capacity(2)
		T.near(cap, 2 * Balance.Register.capMinutes * 60)
		T.near(Register.fill(cap - 1, 2, 5), cap)
	end,

	["the register never loses money when income drops"] = function()
		T.near(Register.fill(5000, 1, 1), 5000)
	end,

	["buttons show the next items not bought yet, in order"] = function()
		local shown = Unlocks.visible("dorm", boughtFirst("dorm", 2))
		T.equal(#shown, Balance.Buttons.visible)
		T.equal(shown[1].id, Items.dorm[3].id)
	end,

	["only a shown button can be bought"] = function()
		local bought = boughtFirst("dorm", 1)
		T.equal(Unlocks.canBuy("dorm", bought, Items.dorm[2].id), true)
		T.equal(Unlocks.canBuy("dorm", bought, Items.dorm[#Items.dorm].id), false)
		T.equal(Unlocks.canBuy("dorm", bought, Items.dorm[1].id), false)
	end,

	["a location is complete once every item is bought"] = function()
		T.equal(Unlocks.isComplete("dorm", boughtFirst("dorm", #Items.dorm - 1)), false)
		T.equal(Unlocks.isComplete("dorm", boughtFirst("dorm", #Items.dorm)), true)
		T.equal(Unlocks.nextLocation("dorm"), nil)
	end,
```

- [ ] **Step 2: Implement** `Income.luau`:

```lua
--!strict
-- A plot's income per second from the items bought at its current location.

local Pricing = require(script.Parent.Pricing)

local Income = {}

function Income.perSecond(locationId: string, bought: { [string]: boolean }): number
	local flat, multiplier = 0, 1
	for itemId, effect in Pricing.effects(locationId) do
		if bought[itemId] then
			flat += effect.flat
			multiplier *= effect.multiplier
		end
	end
	return flat * multiplier
end

return Income
```

- [ ] **Step 3: Implement** `Register.luau`:

```lua
--!strict
-- The register at a plot's entrance: income piles up until the owner collects it, up to a cap.

local Balance = require(script.Parent.Parent.Config.Balance)

local Register = {}

function Register.capacity(incomePerSecond: number): number
	return incomePerSecond * Balance.Register.capMinutes * 60
end

-- The register's amount after `dt` more seconds of income. Above the cap (income dropped) it
-- stays where it is rather than losing money.
function Register.fill(amount: number, incomePerSecond: number, dt: number): number
	local cap = Register.capacity(incomePerSecond)
	if amount >= cap then
		return amount
	end
	return math.min(cap, amount + incomePerSecond * dt)
end

return Register
```

- [ ] **Step 4: Implement** `Unlocks.luau`:

```lua
--!strict
-- Which items a plot shows as buttons next, and when its location is finished.

local Balance = require(script.Parent.Parent.Config.Balance)
local Items = require(script.Parent.Parent.Config.Items)
local Locations = require(script.Parent.Parent.Config.Locations)
local Types = require(script.Parent.Parent.Types)

local Unlocks = {}

-- The first few items not bought yet, in unlock order.
function Unlocks.visible(locationId: string, bought: { [string]: boolean }): { Types.Item }
	local shown = {}
	for _, item in Items[locationId] do
		if not bought[item.id] then
			table.insert(shown, item)
			if #shown == Balance.Buttons.visible then
				break
			end
		end
	end
	return shown
end

function Unlocks.canBuy(locationId: string, bought: { [string]: boolean }, itemId: string): boolean
	for _, item in Unlocks.visible(locationId, bought) do
		if item.id == itemId then
			return true
		end
	end
	return false
end

function Unlocks.isComplete(locationId: string, bought: { [string]: boolean }): boolean
	return #Unlocks.visible(locationId, bought) == 0
end

-- The location after this one, or nil after the last.
function Unlocks.nextLocation(locationId: string): string?
	for index, location in Locations do
		if location.id == locationId then
			local following = Locations[index + 1]
			return if following then following.id else nil
		end
	end
	return nil
end

return Unlocks
```

- [ ] **Step 5:** Play in the tagger place: expect all Economy and Music tests to pass and `0 failed`. Fix and re-run until they do.
- [ ] **Step 6:** Lint, format, commit "Add the tested economy: pricing, income, register, unlocks".

### Task 6: Layout and the dorm blockout data

**Files:** Create `src/shared/Config/PlotLayout.luau`, `src/shared/Config/Blockouts/Dorm.luau`, `src/shared/Remotes.luau`.

- [ ] **Step 1:** `PlotLayout.luau`: positions in studs, local to a plot's origin (the centre of the plot base's top face; local −Z faces the street):

```lua
--!strict
-- Where things sit on every plot, relative to the plot's origin (centre of its base, top face).
-- Local −Z points at the street.

return {
	size = Vector3.new(80, 1, 80),
	spawn = Vector3.new(0, 0, -34),
	sign = Vector3.new(0, 6, -39),
	register = Vector3.new(10, 0, -30),
	buttonSlots = { Vector3.new(-12, 0, -26), Vector3.new(-6, 0, -26), Vector3.new(0, 0, -26) },
}
```

- [ ] **Step 2:** `Blockouts/Dorm.luau`: a `shell` list (floor, back and side walls, a window with a night-blue neon pane, bed, desk) and an `items` map from item id to a list of part specs. Part spec type, declared here and exported:

```lua
export type PartSpec = {
	size: Vector3,
	offset: Vector3, -- centre of the part, local to the plot origin
	colour: Color3,
	material: Enum.Material?, -- SmoothPlastic when nil
	rotation: Vector3?, -- degrees, applied as CFrame.Angles in radians
	transparency: number?,
	light: { brightness: number, range: number }?, -- adds a PointLight (lamp, LED, neon)
}
```

Every one of the 10 dorm items gets 1–4 simple parts (e.g. Laptop: a thin dark slab and an angled screen with a faint neon glow on the desk; Disco Ball: a small sphere on a thin rod with a PointLight). Detailed art comes later; this is a blockout.

- [ ] **Step 3:** `Remotes.luau` (server creates, client waits):

```lua
--!strict
-- The game's RemoteEvents, by name. The server creates them; the client waits for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = { "Collected" }

local Remotes = {}

function Remotes.event(name: string): RemoteEvent
	assert(table.find(NAMES, name), "unknown remote " .. name)
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild("Remotes")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "Remotes"
			folder.Parent = ReplicatedStorage
		end
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing :: RemoteEvent
		end
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(name) :: RemoteEvent
end

return Remotes
```

- [ ] **Step 4:** Commit "Add the plot layout and the dorm blockout data".

### Task 7: The world on the server

**Files:** Create `src/server/World/{PartFactory,Street,PlotView}.luau`.

- [ ] **Step 1:** `PartFactory.build(spec, origin: CFrame, parent: Instance): Part`: an anchored Part with the spec's size, colour, material, transparency, `CFrame = origin * CFrame.new(offset) * CFrame.Angles(rad(rotation))`, and a PointLight child if `light` is set.
- [ ] **Step 2:** `Street.build(): { Model }`: a `Workspace.Street` folder with a dark ground plane, an asphalt road with lane marks, two sidewalks and a few neon street lamps; `Balance.World.plotCount` plot bases alternating on both sides of the road (each a Model named `Plot<n>` with a `Base` part and attribute `PlotIndex`, its pivot at the origin from PlotLayout, rotated so local −Z faces the road). Sets `Lighting.ClockTime = 0`, a low blue `Ambient`/`OutdoorAmbient`. Returns the plot models in order.
- [ ] **Step 3:** `PlotView` (functions take the plot Model):
  - `setup(plot)`: creates the `SpawnLocation` (Neutral, `Duration = 0`, at `PlotLayout.spawn`), the sign (Part + SurfaceGui text), the register (Part + BillboardGui with the amount) and empty `Shell`, `Items` and `Pads` folders.
  - `setOwner(plot, player?)`: sign text "<DisplayName>'s Club" or "Free plot"; sets attribute `OwnerUserId` (or nil).
  - `setShell(plot, locationId)`: clears `Shell` and builds the location's `shell` parts.
  - `showItem(plot, locationId, itemId, animate: boolean)`: builds the item's parts into `Items/<itemId>`; when `animate`, each part starts 0.5 studs lower and transparent and tweens into place over 0.4 s (TweenService, Back easing).
  - `clear(plot)`: destroys everything in `Shell`, `Items` and `Pads`, and resets the register label.
  - `setPads(plot, pads: { { item: Types.Item, effect: Types.ItemEffect } }, onTouched: (itemId: string, hit: BasePart) -> ())`: destroys the old pads and creates one per entry at `PlotLayout.buttonSlots[i]`: a flat neon green Part (CanCollide false, CanTouch true), attributes `ItemId` and `Price`, and a BillboardGui with the name, the price ("FREE" at 0) and the effect ("+$1.3/s" or "x1.32"). Its `Touched` calls `onTouched`.
  - `setRegister(plot, amount, cap)`: the register label shows `Format.money(amount)`, turning orange when full.
- [ ] **Step 4:** Commit "Build the street and plot visuals from data".

### Task 8: Server services and the client HUD

**Files:** Create `src/server/Services/{PlayerState,Plots,Shop,Economy}.luau`, `src/client/UI/{Hud,PadLabels}.luau`; modify both `Main` scripts.

- [ ] **Step 1:** `PlayerState`: `create(player, plot): State`, `get(player): State?`, `remove(player)`, `setCash(state, value)`, `setIncome(state, value)`. `State = { player, plot: Model, cash, locationId, bought: { [string]: boolean }, register, income }`. `setCash`/`setIncome` also set the Player attributes `Cash` and `Income`. New state: `Balance.Start.cash`, `Balance.Start.locationId`, nothing bought, register 0, income 0. (No saving yet: build step 7.)
- [ ] **Step 2:** `Plots.start(onAssigned: (State) -> ())`: `Street.build()`, `PlotView.setup` for each plot. On `PlayerAdded` (and for players already in the game): take the first plot without `OwnerUserId`, `PlotView.setOwner`, `player.RespawnLocation = plot.SpawnLocation`, `PlayerState.create`, `PlotView.setShell`, then `onAssigned(state)`. If the character already spawned elsewhere, `PivotTo` it onto the spawn. No free plot → `warn` and leave the player plotless. On `PlayerRemoving`: `PlotView.clear`, `setOwner(plot, nil)`, `PlayerState.remove`.
- [ ] **Step 3:** `Shop.refresh(state)`: `Unlocks.visible` → `PlotView.setPads` with `Pricing.effects`. The touch handler resolves the toucher with `Players:GetPlayerFromCharacter(hit:FindFirstAncestorOfClass("Model"))`, ignores anyone but the owner, and calls `Shop.buy(state, itemId)`. `buy`: return unless `Unlocks.canBuy` and `cash >= cost`; then `setCash(cash − cost)`, mark bought, `PlotView.showItem(…, true)`, `setIncome(Income.perSecond(…))`, `refresh`. A per-player 0.3 s lock stops double buys from one touch. `Unlocks.isComplete` → print "[Shop] <name> finished <location>" (Move on is build step 3).
- [ ] **Step 4:** `Economy.start()`: on `Heartbeat`, `state.register = Register.fill(state.register, state.income, dt)` for every state; every 0.25 s `PlotView.setRegister`. The register Part's `Touched` from its owner collects `math.floor(register)` (0.5 s lock): adds it to cash, subtracts it from the register, fires `Remotes.event("Collected"):FireClient(player, amount)`.
- [ ] **Step 5:** `Main.server.luau`: `Economy.start()` then `Plots.start(function(state) Shop.refresh(state) end)`.
- [ ] **Step 6:** `Hud.start()`: a ScreenGui (`ResetOnSpawn = false`) with a rounded dark panel top-centre: cash (`Format.money`) and income (`Format.rate`) from the LocalPlayer's `Cash` and `Income` attributes, updated on `GetAttributeChangedSignal`. On `Collected`, a "+$X" label rises 40 px and fades over 0.8 s. Uses the dorm's purple accent from `Locations`.
- [ ] **Step 7:** `PadLabels.start()`: finds the plot whose `OwnerUserId` is the LocalPlayer's, watches its `Pads` folder, and colours each pad's price text green if `Cash >= Price`, grey-red otherwise; re-checks on Cash change and on new pads.
- [ ] **Step 8:** `Main.client.luau`: `Hud.start()`, `PadLabels.start()`.
- [ ] **Step 9:** Lint, format, commit "Add plots, buttons, income and the register".

### Task 9: Playtest in the game place

- [ ] **Step 1:** `rojo build default.project.json -o Game.rbxl` (gitignored), open it in Studio (Filip has to be logged in; if a login form shows, stop and ask him), `rojo serve` (port 34872), connect the Rojo plugin.
- [ ] **Step 2:** Play through the MCP. Expect: no errors or warnings from our scripts; the player spawns at plot 1; HUD shows $50 and +$0/s; three pads: Laptop FREE, Desk Lamp, Small Speaker.
- [ ] **Step 3:** Through `execute_luau` (server), pivot the character onto each pad and the register in turn and read the attributes: laptop → income 1/s; wait 10 s → register ≈ $10; touch register → cash +$10 and the client "+$" label appears; desk lamp bought if affordable, refused otherwise; set cash high and buy all 10 → no pads left and the "[Shop] … finished dorm" line. Screenshot the plot and the HUD.
- [ ] **Step 4:** Check the dorm pacing in numbers: print every item's cost and income from `Pricing.effects("dorm")` and the idle/active save time; it should be ~13 min idle, ~10 min active.
- [ ] **Step 5:** Fix what failed, re-run, then update `CLAUDE.md` (current focus: step 3; game place commands) and the GDD's Milestone 1 checkboxes. Lint, format, commit "Playtest fixes for plots and the register".

---

## Out of this step (later build steps)

House party and Move on (step 3), music, guests and lights (step 4), the decks and drop bonus (step 5), track shop, events, star DJ, goals (step 6), saving and the two-player test (step 7).
