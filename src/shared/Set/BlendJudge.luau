--!strict
-- The blend moment: where the green zone is on the crossfader, whether the crossfader is in it,
-- the grade for the share of time spent in it, and how loud each deck is at a crossfader position.

local Balance = require(script.Parent.Parent.Config.Balance)
local TimingJudge = require(script.Parent.TimingJudge)

local BlendJudge = {}

-- Centre of the zone (0 = deck A, 1 = deck B) at `progress` (0..1) through the blend.
-- It eases in and out so the move feels like a real crossfade.
function BlendJudge.zoneCentre(progress: number, towardsB: boolean): number
	local p = math.clamp(progress, 0, 1)
	local eased = p * p * (3 - 2 * p)
	return if towardsB then eased else 1 - eased
end

function BlendJudge.inZone(crossfader: number, progress: number, towardsB: boolean): boolean
	return math.abs(crossfader - BlendJudge.zoneCentre(progress, towardsB)) <= Balance.Blend.zoneWidth / 2
end

function BlendJudge.grade(shareInZone: number): TimingJudge.Grade
	if shareInZone >= Balance.Blend.perfectShare then
		return "perfect"
	elseif shareInZone >= Balance.Blend.goodShare then
		return "good"
	end
	return "miss"
end

-- Equal-power crossfade: deck A and deck B gains at a crossfader position (0 = A only, 1 = B only).
function BlendJudge.gains(crossfader: number): (number, number)
	local x = math.clamp(crossfader, 0, 1) * math.pi / 2
	return math.cos(x), math.sin(x)
end

return BlendJudge
