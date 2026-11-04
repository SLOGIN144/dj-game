--!strict
-- The local player's own plot: the server names it with the player's "PlotIndex" attribute.

local Players = game:GetService("Players")

local OwnPlot = {}

function OwnPlot.get(): Model?
	local index = Players.LocalPlayer:GetAttribute("PlotIndex")
	if typeof(index) ~= "number" then
		return nil
	end
	local street = workspace:FindFirstChild("Street")
	local plots = if street then street:FindFirstChild("Plots") else nil
	local plot = if plots then plots:FindFirstChild("Plot" .. tostring(index)) else nil
	return if plot and plot:IsA("Model") then plot else nil
end

-- Waits until the player has a plot and it has replicated.
function OwnPlot.wait(): Model
	local player = Players.LocalPlayer
	local index = player:GetAttribute("PlotIndex")
	while typeof(index) ~= "number" do
		player:GetAttributeChangedSignal("PlotIndex"):Wait()
		index = player:GetAttribute("PlotIndex")
	end
	local plots = workspace:WaitForChild("Street"):WaitForChild("Plots")
	return plots:WaitForChild("Plot" .. tostring(index)) :: Model
end

return OwnPlot
