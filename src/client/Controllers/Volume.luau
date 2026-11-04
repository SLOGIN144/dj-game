--!strict
-- The player's volume settings on this client (GDD: settings: master, music and SFX), from the
-- "Settings" Player attribute the server keeps in the save. The music and the sound effects ask
-- here for how loud to play; the settings panel changes them and tells the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(script.Parent.Sfx)

local Volume = {}

export type Levels = { master: number, music: number, sfx: number }

local levels: Levels = { master = 1, music = 1, sfx = 1 }

local function apply()
	Sfx.setVolume(levels.master * levels.sfx)
end

-- How loud the music plays, 0..1.
function Volume.music(): number
	return levels.master * levels.music
end

function Volume.get(): Levels
	return table.clone(levels)
end

local SEND_AFTER = 0.5 -- seconds of no more changes before the server hears (a slider sends many)
local ECHO_IGNORE = 2 -- seconds after a change here in which the server's copy coming back is ignored
local pending = 0
local changedAt = -math.huge

-- Changes the levels here at once, and on the server (which saves them) once they settle.
function Volume.set(changed: Levels)
	levels = {
		master = math.clamp(changed.master, 0, 1),
		music = math.clamp(changed.music, 0, 1),
		sfx = math.clamp(changed.sfx, 0, 1),
	}
	apply()
	changedAt = os.clock()
	pending += 1
	local mine = pending
	task.delay(SEND_AFTER, function()
		if mine == pending then
			Remotes.event("SetSettings"):FireServer(levels.master, levels.music, levels.sfx)
		end
	end)
end

function Volume.start()
	local player = Players.LocalPlayer
	local function read()
		local text = player:GetAttribute("Settings")
		if typeof(text) ~= "string" or os.clock() - changedAt < ECHO_IGNORE then
			return
		end
		for key, value in string.gmatch(text, "(%a+)=([%d%.]+)") do
			local number = tonumber(value)
			if number and (key == "master" or key == "music" or key == "sfx") then
				levels[key] = math.clamp(number, 0, 1)
			end
		end
		apply()
	end
	player:GetAttributeChangedSignal("Settings"):Connect(read)
	read()
end

return Volume
