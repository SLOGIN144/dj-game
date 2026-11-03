--!strict
-- Turns a tagged track into the Lua text that gets pasted into src/shared/Config/Tracks.luau,
-- and lists anything that looks missing or wrong before it gets there.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

local TrackExport = {}

-- Whole numbers print without decimals; others print up to `decimals` places, trailing zeros removed.
local function formatNumber(value: number, decimals: number): string
	if value == math.floor(value) then
		return string.format("%d", value)
	end
	local text = string.format("%." .. decimals .. "f", value)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	return text
end

-- "Deep Sunrise (Original Mix)" -> "deep_sunrise_original_mix"
function TrackExport.makeId(title: string): string
	local id = string.lower(title)
	id = string.gsub(id, "[^a-z0-9]+", "_")
	id = string.gsub(id, "^_+", "")
	id = string.gsub(id, "_+$", "")
	return id
end

function TrackExport.toLua(track: Types.Track): string
	local lines = {
		"{",
		string.format("\tid = %q,", track.id),
		string.format("\tassetId = %s,", formatNumber(track.assetId, 0)),
		string.format("\ttitle = %q,", track.title),
		string.format("\tartist = %q,", track.artist),
		string.format("\tgenre = %q,", track.genre),
		string.format("\tbpm = %s,", formatNumber(track.bpm, 2)),
		string.format("\tfirstBeat = %s,", formatNumber(track.firstBeat, 3)),
		"\tsections = {",
	}
	for _, section in track.sections do
		table.insert(
			lines,
			string.format("\t\t{ kind = %q, startBeat = %s },", section.kind, formatNumber(section.startBeat, 0))
		)
	end
	table.insert(lines, "\t},")
	table.insert(lines, string.format("\tcuePoint = %s,", formatNumber(track.cuePoint, 0)))
	table.insert(lines, string.format("\tenergy = %s,", formatNumber(track.energy, 0)))
	table.insert(lines, string.format("\ttier = %s,", formatNumber(track.tier, 0)))
	table.insert(lines, string.format("\tprice = %s,", formatNumber(track.price, 0)))
	table.insert(lines, "},")
	return table.concat(lines, "\n")
end

local function isWhole(value: number): boolean
	return value == math.floor(value)
end

-- Plain-English warnings; an empty list means the entry is ready to paste.
function TrackExport.validate(track: Types.Track): { string }
	local warnings = {}
	local function warnIf(condition: boolean, message: string)
		if condition then
			table.insert(warnings, message)
		end
	end

	warnIf(track.assetId <= 0, "assetId is missing")
	warnIf(not string.match(track.id, "^[a-z0-9_]+$"), "id should be snake_case (a-z, 0-9 and _)")
	warnIf(track.title == "", "title is empty")
	warnIf(track.artist == "", "artist is empty")
	warnIf(track.genre == "", "genre is empty")
	warnIf(
		track.bpm < 90 or track.bpm > 180,
		string.format("bpm %s is unusual: did you tap on every beat?", formatNumber(track.bpm, 2))
	)
	warnIf(track.firstBeat < 0, "firstBeat is negative")

	warnIf(#track.sections == 0, "no sections marked")
	if #track.sections > 0 then
		warnIf(track.sections[1].startBeat ~= 0, "the first section should start at beat 0")
	end
	local hasDrop = false
	for i, section in track.sections do
		hasDrop = hasDrop or section.kind == "drop"
		warnIf(section.startBeat % 4 ~= 0, string.format("section at beat %s is not on a bar", section.startBeat))
		if i > 1 then
			warnIf(
				section.startBeat == track.sections[i - 1].startBeat,
				string.format("two sections start at beat %s", section.startBeat)
			)
		end
	end
	warnIf(not hasDrop, "no drop marked")

	warnIf(track.cuePoint < 0 or track.cuePoint % 4 ~= 0, "the cue point should be on a bar")
	warnIf(
		not isWhole(track.energy) or track.energy < 1 or track.energy > 5,
		"energy must be a whole number from 1 to 5"
	)
	warnIf(not isWhole(track.tier) or track.tier < 0, "tier must be a whole number, 0 or more")
	warnIf(track.price < 0, "price can't be negative")
	return warnings
end

return TrackExport
