--!strict
-- Loads and saves every player's club on a DataStore (Data/SaveSchema), session-locked
-- (Data/SessionLock) so two servers never write the same player: the server that loaded a club
-- holds it until the player leaves. Saves every minute, when a player leaves and when the server
-- shuts down. Without DataStore access (the place isn't published, or Studio's "Enable Studio
-- Access to API Services" is off) the game runs with fresh, unsaved clubs and says so once.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local SaveSchema = require(ReplicatedStorage.Shared.Data.SaveSchema)
local SessionLock = require(ReplicatedStorage.Shared.Data.SessionLock)

local PlayerData = {}

-- "loaded": their club (or a new one) is claimed; "unsaved": no DataStore access, play without
-- saving; "locked": another server still holds their club; "failed": the DataStore didn't answer.
export type LoadResult = "loaded" | "unsaved" | "locked" | "failed"

local STORE_NAME = "PlayerData"
local SESSION = HttpService:GenerateGUID(false)
local ATTEMPTS = 3
local SHUTDOWN_WAIT = 25 -- seconds the server waits for saves when it shuts down

local store: DataStore? = nil
local available = true
local claimed: { [number]: boolean } = {} -- user ids this server holds the claim for
local inFlight = 0 -- saves running right now

local function key(userId: number): string
	return "player_" .. tostring(userId)
end

local function disable(reason: string)
	if available then
		available = false
		warn("[PlayerData] Saving is off on this server: " .. reason)
	end
end

-- Errors that mean there's no DataStore access at all, rather than a hiccup worth retrying.
local function noAccess(message: string): boolean
	return string.find(message, "StudioAccessToApisNotAllowed", 1, true) ~= nil
		or string.find(message, "publish", 1, true) ~= nil
		or string.find(message, "API Services", 1, true) ~= nil
end

local function getStore(): DataStore?
	if not available then
		return nil
	end
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if not ok then
		disable(tostring(result))
		return nil
	end
	store = result
	return result
end

-- UpdateAsync with retries; `transform` is a pure SessionLock callback. Returns its outcome, or
-- nil when the DataStore can't be reached.
local function update(
	userId: number,
	transform: (any) -> ({ [string]: any }?, SessionLock.Outcome)
): SessionLock.Outcome?
	local dataStore = getStore()
	if not dataStore then
		return nil
	end
	for attempt = 1, ATTEMPTS do
		local outcome: SessionLock.Outcome? = nil
		local ok, err = pcall(function()
			dataStore:UpdateAsync(key(userId), function(stored)
				local value: { [string]: any }?, result: SessionLock.Outcome = transform(stored)
				outcome = result
				if value == nil then
					return nil -- cancels the write
				end
				return value, { userId }
			end)
		end)
		if ok then
			return outcome
		end
		local message = tostring(err)
		if noAccess(message) then
			disable(message)
			return nil
		end
		warn(string.format("[PlayerData] Attempt %d for %d failed: %s", attempt, userId, message))
		task.wait(2 ^ attempt)
	end
	return nil
end

-- Claims and loads a joining player's club. Yields.
function PlayerData.load(player: Player): (SaveSchema.SaveData, LoadResult)
	if not getStore() then
		return SaveSchema.default(), "unsaved"
	end
	for _ = 1, Balance.Save.lockRetries do
		local loaded: any = nil
		local outcome = update(player.UserId, function(stored)
			local value: { [string]: any }?, result: SessionLock.Outcome =
				SessionLock.claim(stored, SESSION, os.time(), Balance.Save.staleSeconds, RunService:IsStudio())
			if value then
				loaded = value.data
			end
			return value, result
		end)
		if outcome == "claimed" then
			claimed[player.UserId] = true
			return SaveSchema.migrate(loaded), "loaded"
		elseif outcome == nil then
			-- In a live server a failed load asks the player to rejoin, so their real club is never
			-- replaced by a fresh one; in Studio it just plays unsaved.
			return SaveSchema.default(), if available and not RunService:IsStudio() then "failed" else "unsaved"
		end
		-- Locked: the server they just left may still be saving.
		task.wait(Balance.Save.lockRetrySeconds)
		if not player.Parent then
			break
		end
	end
	return SaveSchema.default(), "locked"
end

-- Writes a player's club if this server holds it; `release` lets go of it (they left). Yields.
function PlayerData.save(userId: number, data: SaveSchema.SaveData, release: boolean): boolean
	if not claimed[userId] then
		return false
	end
	if release then
		claimed[userId] = nil -- later saves for this player (autosave, shutdown) are skipped
	end
	inFlight += 1
	local outcome = update(userId, function(stored)
		return SessionLock.save(stored, SESSION, os.time(), data, release)
	end)
	inFlight -= 1
	if outcome == "lost" then
		claimed[userId] = nil
		warn(string.format("[PlayerData] Another server took over %d's club; this one stops saving it", userId))
	end
	return outcome == "saved"
end

-- Whether this server is saving the player's club.
function PlayerData.isSaving(player: Player): boolean
	return claimed[player.UserId] == true
end

-- Autosaves everyone `snapshots` returns (user id -> save) and saves them all at shutdown.
function PlayerData.start(snapshots: () -> { [number]: SaveSchema.SaveData })
	task.spawn(function()
		while true do
			task.wait(Balance.Save.autosaveSeconds)
			for userId, data in snapshots() do
				task.spawn(PlayerData.save, userId, data, false)
			end
		end
	end)

	game:BindToClose(function()
		for userId, data in snapshots() do
			task.spawn(PlayerData.save, userId, data, true)
		end
		local started = os.clock()
		task.wait() -- let the saves start
		while inFlight > 0 and os.clock() - started < SHUTDOWN_WAIT do
			task.wait(0.1)
		end
	end)
end

return PlayerData
