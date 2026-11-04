--!strict
-- One-shot sound effects on the Audio API (AudioPlayer -> AudioFader -> AudioDeviceOutput). The
-- IDs live in Config/Sounds; a sound without an ID yet is skipped silently.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

local Sfx = {}

local LIFETIME = 10 -- seconds before a finished one-shot is cleaned up

local folder: Folder? = nil
local bus: AudioFader? = nil

local function setup(): (Folder, AudioFader)
	if folder and bus then
		return folder, bus
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = "Sfx"
	local fader = Instance.new("AudioFader")
	fader.Name = "SfxBus"
	fader.Parent = newFolder
	local output = Instance.new("AudioDeviceOutput")
	output.Name = "Output"
	output.Parent = newFolder
	local link = Instance.new("Wire")
	link.SourceInstance = fader
	link.TargetInstance = output
	link.Parent = newFolder
	newFolder.Parent = SoundService
	folder, bus = newFolder, fader
	return newFolder, fader
end

function Sfx.play(name: string, volume: number?)
	local id = Sounds[name]
	if not id or id == 0 then
		return
	end
	local parent, fader = setup()
	local player = Instance.new("AudioPlayer")
	player.Name = name
	player.Asset = string.format("rbxassetid://%d", id)
	player.Volume = volume or 1
	player.Parent = parent
	local link = Instance.new("Wire")
	link.SourceInstance = player
	link.TargetInstance = fader
	link.Parent = player
	player:Play()
	task.delay(LIFETIME, function()
		player:Destroy()
	end)
end

-- The SFX volume, 0..1 (for a settings slider later).
function Sfx.setVolume(volume: number)
	local _, fader = setup()
	fader.Volume = math.clamp(volume, 0, 1)
end

return Sfx
