--!strict
-- Client entry point. For the Milestone 1 prototype it goes straight into a set at the house
-- party; the dorm, tutorial and venue flow come in later build steps.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local SetDirector = require(script.Parent.Controllers.SetDirector)

-- The set screen covers everything; hide chat, the backpack and the player list.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
end)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local stopSet: (() -> ())? = nil

local function startSet()
	if stopSet then
		stopSet()
	end
	stopSet = SetDirector.run(playerGui, startSet)
end

startSet()
