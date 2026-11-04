--!strict
-- The game's RemoteEvents, by name. The server creates them; the client waits for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"Collected", -- server -> owner: cash collected from the register
	"DropPress", -- client -> server: the owner pressed for a drop at the decks
	"DropResult", -- server -> owner: the press's grade and boost
	"DropHit", -- server -> everyone: a plot caught a drop (confetti, cheer, light blast)
}

local Remotes = {}

function Remotes.event(name: string): RemoteEvent
	assert(table.find(NAMES, name), "unknown remote " .. name)
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild("Remotes")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "Remotes"
			folder.Parent = ReplicatedStorage
		end
		local existing = (folder :: Instance):FindFirstChild(name)
		if existing then
			return existing :: RemoteEvent
		end
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(name) :: RemoteEvent
end

return Remotes
