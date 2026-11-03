--!strict
-- Guesses a track's sections (intro, build, drop, breakdown, outro) and cue point from its audio
-- features and beat grid. Pure logic.
--
-- Each bar gets two measurements: is the kick playing, and how loud is the bar. Bars are
-- grouped into 4-bar blocks (dance music changes on 4-, 8- and 16-bar boundaries), and blocks
-- are labelled with simple dance-music rules:
--   drop       kick playing and close to the loudest part of the track
--   build      the 8 bars just before a drop
--   intro      everything before the first build or drop
--   outro      everything after the last drop
--   breakdown  everything else between drops (no kick, or a quieter stretch)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioFeatures = require(script.Parent.AudioFeatures)
local GridDetect = require(script.Parent.GridDetect)
local Types = require(ReplicatedStorage.Shared.Types)

local SectionDetect = {}

SectionDetect.BLOCK_BARS = 4
SectionDetect.KICK_SHARE = 0.35 -- a bar has a kick when its kick strength is this share of a typical kick bar
SectionDetect.DROP_WITHIN_DB = 2.5 -- a kick block this close to the loudest blocks counts as a drop
SectionDetect.MIN_DROP_BLOCKS = 2 -- shorter loud stretches are fills, not drops
SectionDetect.MAX_DIP_BLOCKS = 1 -- quieter stretches this short between two drops belong to the drop
SectionDetect.BUILD_BLOCKS = 2 -- blocks before a drop that count as its build
SectionDetect.KICK_WINDOW = 0.02 -- seconds after each beat (plus half that before) to measure the kick

export type Result = {
	sections: { Types.Section },
	cuePoint: number, -- beats; the first bar with a kick
}

export type Block = { kick: boolean, level: number } -- level: average loudness in dB

local function percentile(values: { number }, share: number): number
	local sorted = table.clone(values)
	table.sort(sorted)
	return sorted[math.clamp(math.round(#sorted * share), 1, #sorted)]
end

-- Kick strength and loudness for every whole bar on the grid.
local function measureBars(features: AudioFeatures.Features, grid: GridDetect.Grid): ({ number }, { number })
	local rate = features.frameRate
	local beatLength = 60 / grid.bpm
	local before = math.ceil(SectionDetect.KICK_WINDOW / 2 * rate)
	local after = math.ceil(SectionDetect.KICK_WINDOW * 1.5 * rate)
	local kicks, levels = {}, {}
	local bar = 0
	while grid.firstBeat + (bar + 1) * 4 * beatLength <= features.duration do
		-- Kick strength: how much the low end rises right at each beat, averaged over the bar.
		local kick = 0
		for beat = 0, 3 do
			local frame = math.floor((grid.firstBeat + (bar * 4 + beat) * beatLength) * rate) + 1
			for f = math.max(1, frame - before), math.min(#features.lowRise, frame + after) do
				kick += features.lowRise[f] / 4
			end
		end

		local first = math.floor((grid.firstBeat + bar * 4 * beatLength) * rate) + 1
		local last = math.floor((grid.firstBeat + (bar + 1) * 4 * beatLength) * rate)
		local level, count = 0, 0
		for frame = math.max(1, first), math.min(#features.fullLevel, last) do
			level += features.fullLevel[frame]
			count += 1
		end
		table.insert(kicks, kick)
		table.insert(levels, if count > 0 then level / count else -100)
		bar += 1
	end
	return kicks, levels
end

local function measureBlocks(kicks: { number }, levels: { number }): ({ Block }, number?)
	local kickReference = percentile(kicks, 0.9)
	local firstKickBar = nil
	local blocks = {}
	for start = 1, #kicks, SectionDetect.BLOCK_BARS do
		local withKick, level, count = 0, 0, 0
		for bar = start, math.min(#kicks, start + SectionDetect.BLOCK_BARS - 1) do
			if kicks[bar] >= SectionDetect.KICK_SHARE * kickReference then
				withKick += 1
				firstKickBar = firstKickBar or bar
			end
			level += levels[bar]
			count += 1
		end
		table.insert(blocks, { kick = withKick * 2 >= count, level = level / count })
	end
	return blocks, firstKickBar
end

local function findDrops(blocks: { Block }): { boolean }
	local kickLevels = {}
	for _, block in blocks do
		if block.kick then
			table.insert(kickLevels, block.level)
		end
	end
	local isDrop = table.create(#blocks, false)
	if #kickLevels == 0 then
		return isDrop
	end

	local loudest = percentile(kickLevels, 0.9)
	for i, block in blocks do
		isDrop[i] = block.kick and block.level >= loudest - SectionDetect.DROP_WITHIN_DB
	end

	-- First: loud stretches shorter than a real drop are fills; drop them unless nothing would be left.
	local cleaned = table.clone(isDrop)
	local i = 1
	while i <= #blocks do
		if isDrop[i] then
			local runEnd = i
			while runEnd < #blocks and isDrop[runEnd + 1] do
				runEnd += 1
			end
			if runEnd - i + 1 < SectionDetect.MIN_DROP_BLOCKS then
				for j = i, runEnd do
					cleaned[j] = false
				end
			end
			i = runEnd + 1
		else
			i += 1
		end
	end
	local drops = if table.find(cleaned, true) then cleaned else isDrop

	-- Then: a short dip between two real drops is a variation inside one drop, not a new build.
	for gapStart = 2, #blocks - 1 do
		if drops[gapStart - 1] and not drops[gapStart] then
			local gapEnd = gapStart
			while gapEnd < #blocks and not drops[gapEnd + 1] do
				gapEnd += 1
			end
			if gapEnd < #blocks and gapEnd - gapStart + 1 <= SectionDetect.MAX_DIP_BLOCKS then
				for j = gapStart, gapEnd do
					drops[j] = true
				end
			end
		end
	end
	return drops
end

-- Labels 4-bar blocks (exposed for tests).
function SectionDetect.labelBlocks(blocks: { Block }): { Types.SectionKind }
	local isDrop = findDrops(blocks)
	local firstDrop = table.find(isDrop, true)
	local lastDrop = nil
	for i = #isDrop, 1, -1 do
		if isDrop[i] then
			lastDrop = i
			break
		end
	end

	local labels: { Types.SectionKind } = {}
	for i = 1, #blocks do
		if isDrop[i] then
			labels[i] = "drop"
		elseif not firstDrop or i < firstDrop then
			labels[i] = "intro"
		elseif lastDrop and i > lastDrop then
			labels[i] = "outro"
		else
			labels[i] = "breakdown"
		end
	end

	-- The blocks just before each drop are its build (the first block always stays the intro).
	for i = 2, #blocks do
		if labels[i] == "drop" and labels[i - 1] ~= "drop" then
			for j = i - 1, math.max(2, i - SectionDetect.BUILD_BLOCKS), -1 do
				if labels[j] == "drop" then
					break
				end
				labels[j] = "build"
			end
		end
	end
	labels[1] = "intro"
	return labels
end

function SectionDetect.detect(features: AudioFeatures.Features, grid: GridDetect.Grid): Result
	local kicks, levels = measureBars(features, grid)
	if #kicks == 0 then
		return { sections = { { kind = "intro", startBeat = 0 } }, cuePoint = 0 }
	end
	local blocks, firstKickBar = measureBlocks(kicks, levels)
	local labels = SectionDetect.labelBlocks(blocks)

	local sections: { Types.Section } = {}
	for i, label in labels do
		if i == 1 or label ~= labels[i - 1] then
			table.insert(sections, { kind = label, startBeat = (i - 1) * SectionDetect.BLOCK_BARS * 4 })
		end
	end
	return {
		sections = sections,
		cuePoint = if firstKickBar then (firstKickBar - 1) * 4 else 0,
	}
end

return SectionDetect
