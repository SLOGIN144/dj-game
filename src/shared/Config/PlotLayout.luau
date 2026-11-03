--!strict
-- Where things sit on every plot, in studs, relative to the plot's origin (centre of its base's
-- top face). Local -Z points at the street; the room stands in the back half.

return {
	size = Vector3.new(80, 1, 80),
	spawn = Vector3.new(0, 0, -32),
	sign = Vector3.new(0, 6, -38),
	register = Vector3.new(12, 0, -22),
	buttonSlots = { Vector3.new(-7, 0, -14), Vector3.new(0, 0, -14), Vector3.new(7, 0, -14) },
	padSize = 5, -- width and depth of a button pad
}
