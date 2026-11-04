--!strict
-- The gate at the end of the street, on this client: once the player's own location is a venue
-- (Ibiza), its lock light turns green and its prompt offers the flight. Until then the prompt
-- says it's locked; trying anyway gets a line from the host (Services/Travel on the server).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Locations = require(ReplicatedStorage.Shared.Config.Locations)
local OwnPlot = require(script.Parent.OwnPlot)
local PlotSpace = require(ReplicatedStorage.Shared.Util.PlotSpace)

local JetGate = {}

local OPEN = Color3.fromRGB(80, 255, 140)
local SHUT = Color3.fromRGB(255, 60, 90)

local function venueName(): string
	for _, location in Locations do
		if location.space == "venue" then
			return location.name
		end
	end
	return "the venue"
end

function JetGate.start()
	task.spawn(function()
		local props = workspace:WaitForChild("Street"):WaitForChild("Props")
		local prompt = props:WaitForChild("GatePrompt"):WaitForChild("TravelPrompt") :: ProximityPrompt
		local gate = props:FindFirstChild("street_gate")
		local lock = if gate then gate:FindFirstChild("Locked", true) else nil
		local plot = OwnPlot.wait()
		local name = venueName()
		local function update()
			local open = PlotSpace.away(plot)
			prompt.ActionText = if open then "Fly to " .. name else "Locked"
			if lock and lock:IsA("BasePart") then
				lock.Color = if open then OPEN else SHUT
			end
		end
		plot:GetAttributeChangedSignal("SpaceOrigin"):Connect(update)
		update()
	end)
end

return JetGate
