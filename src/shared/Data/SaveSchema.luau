--!strict
-- The save file, version 1 (approved by Filip on 2026-11-04): what a player's club is when they
-- leave, so rejoining restores it. `migrate` turns anything loaded (nothing, an older version, a
-- damaged value) into a valid current save; `sanitize` drops ids the game no longer knows and
-- keeps numbers in range. Adding a field means a new version and a migration step here.

local Balance = require(script.Parent.Parent.Config.Balance)
local Goals = require(script.Parent.Parent.Config.Goals)
local Items = require(script.Parent.Parent.Config.Items)
local Locations = require(script.Parent.Parent.Config.Locations)
local Tracks = require(script.Parent.Parent.Config.Tracks)
local Types = require(script.Parent.Parent.Types)

local SaveSchema = {}

SaveSchema.VERSION = 1

export type Stats = { perfectDrops: number, goodDrops: number, eventsDone: number, playSeconds: number }

export type SaveData = {
	version: number,
	cash: number,
	totalEarned: number,
	location: string,
	boughtItems: { string }, -- item ids at the current location
	ownedTracks: { string },
	goalsDone: { string },
	register: number, -- cash waiting in the register
	stats: Stats,
}

function SaveSchema.default(): SaveData
	return {
		version = SaveSchema.VERSION,
		cash = Balance.Start.cash,
		totalEarned = 0,
		location = Balance.Start.locationId,
		boughtItems = {},
		ownedTracks = table.clone(Balance.Start.tracks),
		goalsDone = {},
		register = 0,
		stats = { perfectDrops = 0, goodDrops = 0, eventsDone = 0, playSeconds = 0 },
	}
end

local function number(value: any, fallback: number): number
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return fallback
	end
	return math.max(0, value)
end

-- The strings in `list` that `known` accepts, once each, in their original order.
local function strings(list: any, known: (string) -> boolean): { string }
	local result = {}
	if typeof(list) ~= "table" then
		return result
	end
	for _, value in list do
		if typeof(value) == "string" and known(value) and not table.find(result, value) then
			table.insert(result, value)
		end
	end
	return result
end

local function isLocation(id: string): boolean
	for _, location in Locations do
		if location.id == id then
			return true
		end
	end
	return false
end

local function isTrack(id: string): boolean
	for _, track in Tracks do
		if track.id == id then
			return true
		end
	end
	return false
end

-- Any loaded value as a valid current save. Unknown items, tracks and goals are dropped, the
-- starter tracks are always owned, and broken numbers fall back to their defaults.
function SaveSchema.sanitize(raw: { [string]: any }): SaveData
	local defaults = SaveSchema.default()
	local location = if typeof(raw.location) == "string" and isLocation(raw.location)
		then raw.location
		else defaults.location
	local items: { Types.Item } = Items[location] or {}
	local goals = Goals[location]

	local owned = strings(raw.ownedTracks, isTrack)
	for _, trackId in Balance.Start.tracks do
		if not table.find(owned, trackId) then
			table.insert(owned, trackId)
		end
	end

	local stats = if typeof(raw.stats) == "table" then raw.stats else {}
	return {
		version = SaveSchema.VERSION,
		cash = number(raw.cash, defaults.cash),
		totalEarned = number(raw.totalEarned, 0),
		location = location,
		boughtItems = strings(raw.boughtItems, function(id)
			for _, item in items do
				if item.id == id then
					return true
				end
			end
			return false
		end),
		ownedTracks = owned,
		goalsDone = strings(raw.goalsDone, function(id)
			if goals then
				for _, goal in goals.goals do
					if goal.id == id then
						return true
					end
				end
			end
			return false
		end),
		register = number(raw.register, 0),
		stats = {
			perfectDrops = number(stats.perfectDrops, 0),
			goodDrops = number(stats.goodDrops, 0),
			eventsDone = number(stats.eventsDone, 0),
			playSeconds = number(stats.playSeconds, 0),
		},
	}
end

-- Whatever was loaded (nil for a new player) as a valid current save.
function SaveSchema.migrate(raw: any): SaveData
	if typeof(raw) ~= "table" then
		return SaveSchema.default()
	end
	-- Version 1 is the first; later versions add their steps here, oldest first, e.g.
	-- if raw.version < 2 then raw.newField = ... end
	return SaveSchema.sanitize(raw)
end

return SaveSchema
