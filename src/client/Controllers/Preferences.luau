--!strict
-- The player's settings on this client (GDD: master, music and SFX volume, and a graphics-quality
-- setting), from the "Settings" Player attribute the server keeps in the save. The music and the
-- sound effects ask here how loud to play, and the guests, lights and effects whether to draw
-- less. The settings panel changes them and tells the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(script.Parent.Sfx)

local Preferences = {}

export type Levels = { master: number, music: number, sfx: number, low: boolean }

local levels: Levels = { master = 1, music = 1, sfx = 1, low = false }

local SEND_AFTER = 0.5 -- seconds of no more changes before the server hears (a slider sends many)
local ECHO_IGNORE = 2 -- seconds after a change here in which the server's copy coming back is ignored
local pending = 0
local changedAt = -math.huge

local function apply()
	Sfx.setVolume(levels.master * levels.sfx)
end

-- How loud the music plays, 0..1.
function Preferences.music(): number
	return levels.master * levels.music
end

-- Whether to draw less: fewer guests, no light beams, fewer particles.
function Preferences.lowGraphics(): boolean
	return levels.low
end

function Preferences.get(): Levels
	return table.clone(levels)
end

-- Changes the settings here at once, and on the server (which saves them) once they settle.
function Preferences.set(changed: Levels)
	levels = {
		master = math.clamp(changed.master, 0, 1),
		music = math.clamp(changed.music, 0, 1),
		sfx = math.clamp(changed.sfx, 0, 1),
		low = changed.low == true,
	}
	apply()
	changedAt = os.clock()
	pending += 1
	local mine = pending
	task.delay(SEND_AFTER, function()
		if mine == pending then
			Remotes.event("SetSettings"):FireServer(levels.master, levels.music, levels.sfx, levels.low)
		end
	end)
end

function Preferences.start()
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
			elseif number and key == "low" then
				levels.low = number == 1
			end
		end
		apply()
	end
	player:GetAttributeChangedSignal("Settings"):Connect(read)
	read()
end

return Preferences
