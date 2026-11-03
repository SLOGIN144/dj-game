--!strict
-- Every button, per location, in the order they unlock. A location's first item is free and
-- must be an income item. Costs and effects come from Economy/Pricing, not from here.

local Types = require(script.Parent.Parent.Types)

local Items: { [string]: { Types.Item } } = {
	dorm = {
		{ id = "dorm_laptop", name = "Laptop", kind = "income" },
		{ id = "dorm_lamp", name = "Desk Lamp", kind = "income" },
		{ id = "dorm_speaker", name = "Small Speaker", kind = "income" },
		{ id = "dorm_led", name = "LED Strip", kind = "income" },
		{ id = "dorm_controller", name = "Volt 2 Controller", kind = "gear" },
		{ id = "dorm_posters", name = "Posters", kind = "income" },
		{ id = "dorm_beanbags", name = "Bean Bags", kind = "income" },
		{ id = "dorm_discoball", name = "Disco Ball", kind = "income" },
		{ id = "dorm_partylights", name = "Party Lights", kind = "income" },
		{ id = "dorm_neon", name = "Neon Sign", kind = "income" },
	},
}

return Items
