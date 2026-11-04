--!strict
-- Where things sit on every plot, in studs, relative to the plot's origin (centre of its base's
-- top face). Local -Z points at the street; the room stands in the back half.

return {
	size = Vector3.new(80, 1, 80),
	spawn = Vector3.new(0, 0, -32),
	sign = Vector3.new(-25, 3.4, -37), -- to the side, so it never blocks the view into the room
	register = Vector3.new(12, 0, -22),
	buttonSlots = { Vector3.new(-7, 0, -14), Vector3.new(0, 0, -14), Vector3.new(7, 0, -14) },
	padSize = 5, -- width and depth of a button pad
	moveOnSlot = 2, -- the button slot the Move On pad takes once a location is finished
	-- Venues (Ibiza) are far from the street, out of sight of it: the first plot's at `start`,
	-- each next one `spacing` further on. World positions, not plot-relative.
	venues = { start = Vector3.new(3000, 0, 0), spacing = Vector3.new(900, 0, 0) },
}
