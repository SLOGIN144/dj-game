--!strict
-- Checks every entry in src/shared/Config/Tracks.luau with the tagger's own validation.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local TrackExport = require(StarterPlayer.StarterPlayerScripts.TrackTagger.TrackExport)
local Tracks = require(ReplicatedStorage.Shared.Config.Tracks)
local T = require(script.Parent.TestUtil)

return {
	["every track passes validation"] = function()
		for _, track in Tracks do
			local warnings = TrackExport.validate(track)
			T.equal(#warnings, 0, track.id .. ": " .. table.concat(warnings, "; "))
		end
	end,

	["ids and asset IDs are unique"] = function()
		local ids, assets = {}, {}
		for _, track in Tracks do
			T.equal(ids[track.id], nil, "duplicate id " .. track.id)
			T.equal(assets[track.assetId], nil, "duplicate assetId for " .. track.id)
			ids[track.id], assets[track.assetId] = true, true
		end
	end,

	["sections are in order"] = function()
		for _, track in Tracks do
			for i = 2, #track.sections do
				T.truthy(track.sections[i].startBeat > track.sections[i - 1].startBeat, track.id .. " section " .. i)
			end
		end
	end,
}
