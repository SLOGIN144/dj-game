--!strict
-- Where a position is relative to a footprint around an origin, in studs: a plot's
-- (Config/PlotLayout.size) unless a size is given.

local PlotLayout = require(script.Parent.Parent.Config.PlotLayout)

local PlotArea = {}

-- Studs from `position` to the footprint of `size` (X by Z) centred on `origin`: 0 inside it.
function PlotArea.distance(origin: CFrame, position: Vector3, size: Vector3?): number
	local footprint = size or PlotLayout.size
	local relative = origin:PointToObjectSpace(position)
	local dx = math.max(0, math.abs(relative.X) - footprint.X / 2)
	local dz = math.max(0, math.abs(relative.Z) - footprint.Z / 2)
	return math.sqrt(dx * dx + dz * dz)
end

function PlotArea.contains(origin: CFrame, position: Vector3, size: Vector3?): boolean
	return PlotArea.distance(origin, position, size) <= 0
end

return PlotArea
