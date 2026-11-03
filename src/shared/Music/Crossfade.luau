--!strict
-- Equal-power crossfade: the two decks' gains for a crossfader position from 0 (deck A) to 1 (deck B).

local Crossfade = {}

function Crossfade.gains(position: number): (number, number)
	local x = math.clamp(position, 0, 1) * math.pi / 2
	return math.cos(x), math.sin(x)
end

return Crossfade
