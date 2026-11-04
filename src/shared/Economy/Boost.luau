--!strict
-- The drop bonus: what a graded press earns, how a new boost meets the one already running (a
-- stronger one takes over, an equal one extends it, a weaker one is ignored; boosts never stack),
-- and the server's check of a press a client sent.

local Balance = require(script.Parent.Parent.Config.Balance)
local MixTimeline = require(script.Parent.Parent.Music.MixTimeline)
local TimingJudge = require(script.Parent.Parent.Music.TimingJudge)

local Boost = {}

-- An income multiplier until `endsAt` (server time).
export type Boost = { multiplier: number, endsAt: number }

function Boost.forGrade(grade: TimingJudge.Grade, now: number): Boost?
	local spec = if grade == "perfect" then Balance.Boost.perfect elseif grade == "good" then Balance.Boost.good else nil
	if not spec then
		return nil
	end
	return { multiplier = spec.multiplier, endsAt = now + spec.seconds }
end

-- The boost in effect after earning `new` at `now`.
function Boost.combine(current: Boost?, new: Boost?, now: number): Boost?
	local running = if current and current.endsAt > now then current else nil
	if not new then
		return running
	end
	if not running or new.multiplier > running.multiplier then
		return new
	end
	if new.multiplier == running.multiplier then
		return { multiplier = new.multiplier, endsAt = math.max(new.endsAt, running.endsAt) }
	end
	return running
end

function Boost.multiplier(current: Boost?, now: number): number
	return if current and current.endsAt > now then current.multiplier else 1
end

-- A drop's key, so each drop counts once per player.
function Boost.dropKey(drop: MixTimeline.Drop): string
	return string.format("%d:%d", drop.n, math.round(drop.beat))
end

-- The server's check of a drop press. `pressTime` is the press on the client's copy of the server
-- clock, `receivedAt` when the message reached the server, and `used` the drops this player has
-- already pressed for (updated here). The grade comes from the press time, never from the client's
-- own verdict; a press away from every drop returns "miss" and no drop.
function Boost.judgePress(
	drops: { MixTimeline.Drop },
	pressTime: number,
	receivedAt: number,
	used: { [string]: boolean }
): (TimingJudge.Grade, MixTimeline.Drop?)
	local delay = receivedAt - pressTime
	if delay < -Balance.Boost.clockSlack or delay > Balance.Boost.lagAllowance then
		return "miss", nil
	end
	local drop, offset = MixTimeline.nearestDrop(drops, pressTime)
	if not drop or math.abs(offset) > Balance.Boost.pressWindow then
		return "miss", nil
	end
	local key = Boost.dropKey(drop)
	if used[key] then
		return "miss", drop
	end
	used[key] = true
	return TimingJudge.grade(offset), drop
end

return Boost
