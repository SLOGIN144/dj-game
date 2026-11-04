--!strict
-- A small seeded random number generator (Park-Miller), the same on every machine, so a seeded
-- mix plan can be tested. Not for anything that must be unpredictable.

local Rng = {}
Rng.__index = Rng

local MODULUS = 2147483647
local MULTIPLIER = 48271 -- products stay below 2^53, so the maths is exact in doubles

export type Rng = typeof(setmetatable({} :: { _state: number }, Rng))

function Rng.new(seed: number): Rng
	local state = math.floor(math.abs(seed)) % MODULUS
	return setmetatable({ _state = if state == 0 then 1 else state }, Rng)
end

-- A whole number from 1 to `count`.
function Rng.nextInt(self: Rng, count: number): number
	self._state = (self._state * MULTIPLIER) % MODULUS
	return self._state % math.max(1, count) + 1
end

return Rng
