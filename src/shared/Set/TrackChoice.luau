--!strict
-- The track cards: which tracks can be offered next, and the crowd's occasional wish.

local Balance = require(script.Parent.Parent.Config.Balance)
local Types = require(script.Parent.Parent.Types)

local TrackChoice = {}

export type Wish = { kind: "genre", genre: string } | { kind: "energy", above: number }

local function shuffled<T>(items: { T }, random: Random): { T }
	local copy = table.clone(items)
	for i = #copy, 2, -1 do
		local j = random:NextInteger(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

local function withinRange(track: Types.Track, currentBpm: number): boolean
	return math.abs(track.bpm / currentBpm - 1) <= Balance.Cards.tempoRange
end

-- Up to `count` tracks the gear can sync to `currentBpm`. Never the playing track (`currentId`);
-- tracks already played (`played`) only come back when fewer than two fresh ones fit.
function TrackChoice.candidates(
	tracks: { Types.Track },
	currentId: string,
	currentBpm: number,
	played: { [string]: boolean },
	count: number,
	random: Random
): { Types.Track }
	local fresh, used = {}, {}
	for _, track in tracks do
		if track.id ~= currentId and withinRange(track, currentBpm) then
			table.insert(if played[track.id] then used else fresh, track)
		end
	end
	local offered = shuffled(fresh, random)
	if #offered < 2 then
		for _, track in shuffled(used, random) do
			table.insert(offered, track)
		end
	end
	while #offered > count do
		table.remove(offered)
	end
	return offered
end

-- Sometimes (`chance`, default from Balance) the crowd asks for a genre or for more energy.
-- The wish is always one that at least one card can meet.
function TrackChoice.makeWish(cards: { Types.Track }, current: Types.Track, random: Random, chance: number?): Wish?
	if #cards == 0 or random:NextNumber() >= (chance or Balance.Cards.wishChance) then
		return nil
	end
	local livelier = false
	for _, card in cards do
		livelier = livelier or card.energy > current.energy
	end
	if livelier and random:NextNumber() < 0.5 then
		return { kind = "energy", above = current.energy }
	end
	return { kind = "genre", genre = cards[random:NextInteger(1, #cards)].genre }
end

function TrackChoice.matches(track: Types.Track, wish: Wish): boolean
	if wish.kind == "genre" then
		return track.genre == wish.genre
	end
	return track.energy > wish.above
end

-- Short text for the crowd's speech bubble.
function TrackChoice.describe(wish: Wish): string
	if wish.kind == "genre" then
		return string.upper(wish.genre) .. "!"
	end
	return "MORE ENERGY!"
end

return TrackChoice
