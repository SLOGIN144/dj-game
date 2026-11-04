--!strict
-- The box a set of blockout parts fills (rotation ignored), and where an imported model of the
-- same thing goes: its pivot sits at the bottom centre of that box (see the model sheets).

local Types = require(script.Parent.Parent.Types)

local Bounds = {}

function Bounds.ofSpecs(specs: { Types.PartSpec }): (Vector3, Vector3)
	if #specs == 0 then
		return Vector3.zero, Vector3.zero
	end
	local low = Vector3.new(math.huge, math.huge, math.huge)
	local high = -low
	for _, spec in specs do
		local half = spec.size / 2
		low = low:Min(spec.offset - half)
		high = high:Max(spec.offset + half)
	end
	return low, high
end

-- The bottom centre of the specs' box, in plot space.
function Bounds.anchor(specs: { Types.PartSpec }): Vector3
	local low, high = Bounds.ofSpecs(specs)
	local centre = (low + high) / 2
	return Vector3.new(centre.X, low.Y, centre.Z)
end

return Bounds
