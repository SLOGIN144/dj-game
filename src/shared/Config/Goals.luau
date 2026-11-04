--!strict
-- Each location's host character, their goals and their lines (GDD: characters and goals). The
-- dorm's goals are the tutorial; each one pays cash and plays a short line. Tone: aspirational and
-- fun, with small funny moments, never edgy. Names are placeholders.

local Types = require(script.Parent.Parent.Types)

local Goals: { [string]: Types.Host } = {
	dorm = {
		name = "Max",
		role = "Your roommate",
		colour = Color3.fromRGB(255, 170, 60),
		goals = {
			{
				id = "dorm_collect",
				text = "Collect cash from the register",
				kind = "collect",
				reward = 40,
				line = "Cha-ching! Guests pay, the register fills up. Grab it often, it stops when it's full.",
			},
			{
				id = "dorm_speaker",
				text = "Buy the Small Speaker",
				kind = "buy",
				target = "dorm_speaker",
				reward = 100,
				line = "Now THAT's bass. The neighbours are gonna love us. Probably.",
			},
			{
				id = "dorm_drop",
				text = "Catch a drop at the laptop",
				kind = "drop",
				reward = 250,
				line = "YOU CAUGHT IT! Hit the drop right on the beat and the whole room goes off.",
			},
		},
		lines = {
			intro = "Yo, roomie! Step on the glowing pads to build our setup. The laptop's free!",
			done = "This room is maxed out! Bigger places are coming soon. Keep the party going till then.",
			speakerBlown = "Uh... is the speaker supposed to smoke? Hold E on it, quick!",
			speakerFixed = "Good as new. Mostly. Let's not tell the landlord.",
		},
	},
}

return Goals
