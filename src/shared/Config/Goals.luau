--!strict
-- Each location's host character, their goals and their lines (GDD: characters and goals). The
-- dorm's goals are the tutorial; each one pays cash and plays a short line. Tone: aspirational and
-- fun, with small funny moments, never edgy. Names are placeholders. Solenne's goals are a proposed
-- default (the GDD leaves Ibiza's goals open).

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
			done = "This room is maxed out! Lena says her place is way bigger. Step on Move On!",
			speakerBlown = "Uh... is the speaker supposed to smoke? Hold E on it, quick!",
			speakerFixed = "Good as new. Mostly. Let's not tell the landlord.",
			jetLocked = "That jet? One day, roomie. One day. Let's fill this room first.",
		},
	},
	house = {
		name = "Lena",
		role = "Your best friend",
		colour = Color3.fromRGB(255, 70, 200),
		goals = {
			{
				id = "house_perfect",
				text = "Catch 3 Perfect drops",
				kind = "perfect",
				count = 3,
				reward = 2500,
				line = "Three perfect drops! People are filming this. You're officially a thing.",
			},
			{
				id = "house_book",
				text = "Book your first star DJ",
				kind = "book",
				reward = 5000,
				line = "A real star DJ in my living room. I'm framing this night.",
			},
			{
				id = "house_fix",
				text = "Fix a blown speaker",
				kind = "fix",
				reward = 3000,
				line = "Speaker saved, party saved. You're basically a superhero with a screwdriver.",
			},
		},
		lines = {
			intro = "Welcome to my place! Same deal as the dorm: build it up, keep the beat, I'll bring the crowd.",
			done = "Best party this block has ever seen. Rosa wants to meet you at her club. Move On!",
			speakerBlown = "Nooo, the speaker! Hold E on it before the neighbours think we stopped!",
			speakerFixed = "And we're back! Nobody noticed. Okay, everybody noticed. But we're back!",
			photographer = "There's a photographer here! Catch the next drop and we're famous.",
			jetLocked = "A private jet? Ha! Throw the best party on the block first.",
		},
	},
	club = {
		name = "Rosa",
		role = "The club owner",
		colour = Color3.fromRGB(60, 100, 255),
		goals = {
			{
				id = "club_players",
				text = "Buy the media players",
				kind = "buy",
				target = "club_mixer",
				reward = 40000,
				line = "Proper club gear. Now you play like you mean it.",
			},
			{
				id = "club_tracks",
				text = "Own 5 tracks",
				kind = "tracks",
				count = 5,
				reward = 60000,
				line = "Five tracks deep. The crowd never knows what's coming. Good.",
			},
			{
				id = "club_vips",
				text = "Greet 3 VIPs",
				kind = "vip",
				count = 3,
				reward = 80000,
				line = "The VIPs keep coming back. That's how a club gets a name.",
			},
		},
		lines = {
			intro = "So you're the kid everyone's talking about. This basement is yours. Make it loud.",
			done = "You filled my club every night. A friend of mine has a stage in Ibiza. The jet's waiting.",
			speakerBlown = "A stack just blew. Hold E on it. A silent club is a dead club.",
			speakerFixed = "Fixed. Keep the bass, lose the smoke.",
			vip = "VIP at the door. Go say hi before they wander off.",
			photographer = "Photographer by the booth. Give them a drop worth printing.",
			jetLocked = "Fill my club every night, and that jet is yours. Not before.",
		},
	},
	ibiza = {
		name = "Solenne",
		role = "Star DJ",
		colour = Color3.fromRGB(255, 122, 60),
		goals = {
			{
				id = "ibiza_perfect",
				text = "Catch 5 Perfect drops at sunset",
				kind = "perfect",
				count = 5,
				reward = 1500000,
				line = "Five perfect drops with the sun going down. That's the Ibiza feeling.",
			},
			{
				id = "ibiza_fireworks",
				text = "Buy the fireworks",
				kind = "buy",
				target = "ibiza_fireworks",
				reward = 2000000,
				line = "Fireworks over the sea on every drop. Now we're talking.",
			},
			{
				id = "ibiza_book",
				text = "Book Mira Sundial",
				kind = "book",
				target = "dj_mira",
				reward = 2500000,
				line = "Mira on your stage! You've come a long way from that dorm laptop.",
			},
			{
				id = "ibiza_tracks",
				text = "Own every track",
				kind = "tracks",
				count = 7,
				reward = 3000000,
				line = "Every track in the crate. A real selector.",
			},
		},
		lines = {
			intro = "Welcome to the island. Build me a stage worth flying for, and the sunset does the rest.",
			done = "The best beach club on the island, and it's yours. More stops on the world tour are coming!",
			speakerBlown = "A line array's smoking! Hold E on it, the whole beach can hear that.",
			speakerFixed = "Perfect. The sea breeze will clear the smoke.",
			vip = "A VIP just landed. Go welcome them at the entrance.",
			photographer = "A photographer from a magazine! Catch a drop for the cover.",
		},
	},
}

return Goals
