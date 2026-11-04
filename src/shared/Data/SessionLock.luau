--!strict
-- Session locking for save files, without a package (the pattern ProfileStore uses): the stored
-- record is { data = <save>, session = { id, time } }. A server claims the record when a player
-- joins, and only the server holding the claim may write it, so two servers never overwrite each
-- other. These are the pure callbacks for GlobalDataStore:UpdateAsync, which may call them more
-- than once and cancels the write when they return nil.

local SessionLock = {}

export type Lock = { id: string, time: number }

export type Outcome = "claimed" | "locked" | "saved" | "lost"

local function record(stored: any): { [string]: any }
	return if typeof(stored) == "table" then table.clone(stored) else {}
end

-- Claims the record for `sessionId` at `now` (os.time()). Another session's claim blocks it
-- unless that claim is older than `staleAfter` seconds (its server stopped without letting go)
-- or `force` is set (Studio testing).
function SessionLock.claim(
	stored: any,
	sessionId: string,
	now: number,
	staleAfter: number,
	force: boolean?
): ({ [string]: any }?, Outcome)
	local value = record(stored)
	local lock = value.session
	if typeof(lock) == "table" and lock.id ~= sessionId and not force then
		local age = now - (if typeof(lock.time) == "number" then lock.time else 0)
		if age < staleAfter then
			return nil, "locked"
		end
	end
	value.session = { id = sessionId, time = now }
	return value, "claimed"
end

-- Writes `data` while this session holds the claim, refreshing it, or letting go with `release`.
-- If another session took the record over (or let it go), nothing is written: "lost".
function SessionLock.save(
	stored: any,
	sessionId: string,
	now: number,
	data: any,
	release: boolean
): ({ [string]: any }?, Outcome)
	local value = record(stored)
	local lock = value.session
	if typeof(lock) ~= "table" or lock.id ~= sessionId then
		return nil, "lost"
	end
	value.data = data
	value.session = if release then nil else { id = sessionId, time = now }
	return value, "saved"
end

return SessionLock
