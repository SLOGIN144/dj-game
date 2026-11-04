--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local SaveSchema = require(Shared.Data.SaveSchema)
local SessionLock = require(Shared.Data.SessionLock)
local T = require(script.Parent.TestUtil)

local STALE = 300

return {
	-- SaveSchema
	["a new player starts with the starting cash, the dorm and the starter tracks"] = function()
		local data = SaveSchema.migrate(nil)
		T.equal(data.version, SaveSchema.VERSION)
		T.equal(data.cash, Balance.Start.cash)
		T.equal(data.location, Balance.Start.locationId)
		T.equal(#data.boughtItems, 0)
		T.equal(table.concat(data.ownedTracks, ","), table.concat(Balance.Start.tracks, ","))
	end,

	["a saved club loads back as it was"] = function()
		local saved = {
			version = 1,
			cash = 1234.5,
			totalEarned = 9000,
			location = "dorm",
			boughtItems = { "dorm_laptop", "dorm_lamp", "dorm_speaker" },
			ownedTracks = { "until_sunrise", "london_loves", "neon_ruins" },
			goalsDone = { "dorm_collect" },
			register = 42.25,
			stats = { perfectDrops = 3, goodDrops = 1, eventsDone = 2, playSeconds = 600 },
		}
		local data = SaveSchema.migrate(saved)
		T.equal(data.cash, 1234.5)
		T.equal(data.totalEarned, 9000)
		T.equal(table.concat(data.boughtItems, ","), "dorm_laptop,dorm_lamp,dorm_speaker")
		T.equal(table.concat(data.ownedTracks, ","), "until_sunrise,london_loves,neon_ruins")
		T.equal(table.concat(data.goalsDone, ","), "dorm_collect")
		T.equal(data.register, 42.25)
		T.equal(data.stats.perfectDrops, 3)
		T.equal(data.stats.playSeconds, 600)
	end,

	["unknown ids, duplicates and broken numbers are cleaned up"] = function()
		local data = SaveSchema.migrate({
			version = 1,
			cash = -50,
			totalEarned = 0 / 0,
			location = "moon_base",
			boughtItems = { "dorm_laptop", "dorm_laptop", "dorm_rocket", 7 :: any },
			ownedTracks = { "not_a_track", "neon_ruins" },
			goalsDone = { "dorm_drop", "fly_to_the_moon" },
			stats = { perfectDrops = "lots" },
		})
		T.equal(data.cash, 0, "never negative")
		T.equal(data.totalEarned, 0, "NaN falls back")
		T.equal(data.location, Balance.Start.locationId, "unknown location")
		T.equal(table.concat(data.boughtItems, ","), "dorm_laptop")
		T.truthy(table.find(data.ownedTracks, "neon_ruins"), "a known track stays")
		T.equal(table.find(data.ownedTracks, "not_a_track"), nil)
		for _, trackId in Balance.Start.tracks do
			T.truthy(table.find(data.ownedTracks, trackId), "starter tracks are always owned")
		end
		T.equal(table.concat(data.goalsDone, ","), "dorm_drop")
		T.equal(data.stats.perfectDrops, 0)
	end,

	["a version 1 save loads with no goal progress, rested DJs and full volume"] = function()
		local data =
			SaveSchema.migrate({ version = 1, cash = 10, location = "house", boughtItems = { "house_djtable" } })
		T.equal(data.version, 2)
		T.equal(data.location, "house")
		T.equal(next(data.goalProgress), nil)
		T.equal(next(data.djRestUntil), nil)
		T.equal(data.settings.musicVolume, 1)
		T.equal(data.settings.sfxVolume, 1)
	end,

	["goal progress, DJ rests and settings load back, cleaned up"] = function()
		local data = SaveSchema.migrate({
			version = 2,
			location = "house",
			goalProgress = { house_perfect = 2.7, dorm_drop = 1, made_up = 4, house_fix = -3 },
			djRestUntil = { dj_kiko = 1800000000, dj_nobody = 5 },
			settings = { masterVolume = 0 / 0, musicVolume = 0.4, sfxVolume = 7, lowGraphics = "yes" },
		})
		T.equal(data.goalProgress.house_perfect, 2, "whole counts")
		T.equal(data.goalProgress.dorm_drop, nil, "another location's goal")
		T.equal(data.goalProgress.made_up, nil)
		T.equal(data.goalProgress.house_fix, 0, "never negative")
		T.equal(data.djRestUntil.dj_kiko, 1800000000)
		T.equal(data.djRestUntil.dj_nobody, nil)
		T.near(data.settings.musicVolume, 0.4)
		T.equal(data.settings.sfxVolume, 1, "capped at full volume")
		T.equal(data.settings.masterVolume, 1, "NaN falls back to full volume")
		T.equal(data.settings.lowGraphics, false, "only true turns low graphics on")
	end,

	["anything that isn't a table loads as a new player"] = function()
		T.equal(SaveSchema.migrate("oops").cash, Balance.Start.cash)
		T.equal(SaveSchema.migrate(5).location, Balance.Start.locationId)
	end,

	-- SessionLock
	["a free record is claimed"] = function()
		local value, outcome = SessionLock.claim(nil, "a", 1000, STALE)
		T.equal(outcome, "claimed")
		T.equal((value :: any).session.id, "a")
	end,

	["another server's fresh claim blocks, a stale one doesn't"] = function()
		local stored = { data = { cash = 5 }, session = { id = "b", time = 1000 } }
		local value, outcome = SessionLock.claim(stored, "a", 1100, STALE)
		T.equal(outcome, "locked")
		T.equal(value, nil, "nothing is written")
		value, outcome = SessionLock.claim(stored, "a", 1000 + STALE + 1, STALE)
		T.equal(outcome, "claimed")
		T.equal((value :: any).data.cash, 5, "the data is kept")
		T.equal(stored.session.id, "b", "the stored value isn't changed in place")
		T.equal(select(2, SessionLock.claim(stored, "a", 1100, STALE, true)), "claimed", "forced in Studio")
	end,

	["only the claiming server can save, and releasing lets go"] = function()
		local stored = (SessionLock.claim(nil, "a", 1000, STALE)) :: any
		local saved, outcome = SessionLock.save(stored, "a", 1060, { cash = 99 }, false)
		T.equal(outcome, "saved")
		T.equal((saved :: any).data.cash, 99)
		T.equal((saved :: any).session.time, 1060, "the claim is refreshed")
		local _, lost = SessionLock.save(saved, "b", 1070, { cash = 1 }, false)
		T.equal(lost, "lost")
		local released = (SessionLock.save(saved, "a", 1080, { cash = 100 }, true)) :: any
		T.equal(released.session, nil)
		T.equal(select(2, SessionLock.save(released, "a", 1090, { cash = 0 }, false)), "lost", "after letting go")
	end,
}
