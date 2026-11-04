--!strict
-- The game's RemoteEvents, by name. The server creates them; the client waits for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"Collected", -- server -> owner: cash collected from the register
	"DropPress", -- client -> server: the owner pressed for a drop at the decks
	"DropResult", -- server -> owner: the press's grade and boost
	"DropHit", -- server -> everyone: a plot caught a drop (confetti, cheer, light blast)
	"BuyTrack", -- client -> server: buy a track in the shop
	"TrackResult", -- server -> buyer: whether it worked
	"Say", -- server -> player: a line from the location's host character
	"GoalDone", -- server -> player: a goal was finished, and its reward
	"EventNotice", -- server -> owner: an event started or ended on their plot
	"Travel", -- server -> player: fade the screen out ("out") or back in ("in"), with a line of text
	"OpenBoard", -- server -> owner: open the star DJ booking board
	"BookDj", -- client -> server: book a star DJ
	"DjNotice", -- server -> owner: a booking was refused, or a guest set started or ended
	"SetSettings", -- client -> server: the player's volume settings changed
	"DevCheat", -- client -> server, Studio only: a testing shortcut (Services/DevTools)
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
