--!strict
-- Where a position is relative to a plot's footprint (Config/PlotLayout.size), in studs.

local PlotLayout = require(script.Parent.Parent.Config.PlotLayout)

local PlotArea = {}

-- Studs from `position` to the footprint of the plot whose origin is `origin`: 0 on the plot.
function PlotArea.distance(origin: CFrame, position: Vector3): number
	local relative = origin:PointToObjectSpace(position)
	local dx = math.max(0, math.abs(relative.X) - PlotLayout.size.X / 2)
	local dz = math.max(0, math.abs(relative.Z) - PlotLayout.size.Z / 2)
	return math.sqrt(dx * dx + dz * dz)
end

function PlotArea.contains(origin: CFrame, position: Vector3): boolean
	return PlotArea.distance(origin, position) <= 0
end

return PlotArea
