--!strict
-- The player's volume settings (GDD: settings: master, music and SFX). The client's settings
-- panel sends them; the server cleans them up, keeps them in the save and mirrors them back as
-- the "Settings" Player attribute, so they follow the player to any server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerState = require(script.Parent.PlayerState)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SaveSchema = require(ReplicatedStorage.Shared.Data.SaveSchema)

local Settings = {}

local LOCK = 0.25 -- seconds between two changes a player can send

local lastChange: { [Player]: number } = {}

function Settings.start()
	Remotes.event("SetSettings").OnServerEvent:Connect(function(player, master: unknown, music: unknown, sfx: unknown)
		local clock = os.clock()
		local state = PlayerState.get(player)
		if not state or clock - (lastChange[player] or 0) < LOCK then
			return
		end
		lastChange[player] = clock
		state.settings = SaveSchema.cleanSettings({ masterVolume = master, musicVolume = music, sfxVolume = sfx })
		PlayerState.mirror(state)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastChange[player] = nil
	end)
end

return Settings
