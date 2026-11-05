--!strict
-- Types shared by the client, the server and the dev tools.

export type SectionKind = "intro" | "build" | "drop" | "breakdown" | "outro"

export type Section = {
	kind: SectionKind,
	startBeat: number, -- beats from the first downbeat, always on a bar (a multiple of 4)
}

export type Track = {
	id: string, -- internal key, snake_case
	assetId: number, -- rbxassetid, provided by Filip
	title: string,
	artist: string,
	genre: string,
	bpm: number,
	firstBeat: number, -- seconds to the first downbeat
	sections: { Section },
	cuePoint: number, -- beat where an incoming mix starts
	energy: number, -- 1..5
	tier: number,
	price: number,
}

-- How a track came into a plot's mix: the first track, a beat-synced blend, or a short fade.
export type MixIn = "start" | "sync" | "fade"

-- One track's turn in a plot's mix. The server plans these (Music/MixPlanner) and replicates them;
-- times are server times (workspace:GetServerTimeNow()), beats count from the track's first downbeat.
export type MixSegment = {
	n: number, -- running number on the plot; the two decks take turns by it
	trackId: string,
	startTime: number, -- when the track starts playing, at fromBeat
	fromBeat: number,
	dropBeat: number, -- the drop it comes in on, at the end of its blend
	speed: number, -- playback speed while it blends in (the outgoing tempo); eases back to 1 after the drop
	mixIn: MixIn,
	outBeat: number, -- where the transition to the next track starts
	endBeat: number?, -- where it stops; set once the next segment is planned
}

export type ItemKind = "income" | "gear" | "feature"

-- What a feature item switches on.
--   booking: the star DJ board; confetti, co2, fireworks: a payoff on every drop;
--   register: the register holds more.
export type Feature = "booking" | "confetti" | "co2" | "fireworks" | "register"

export type Item = {
	id: string, -- unique across all locations, prefixed with its location ("dorm_lamp")
	name: string, -- shown on the button
	kind: ItemKind, -- income and feature items add cash per second; gear multiplies the plot's income
	feature: Feature?, -- what a feature item switches on
	replaces: string?, -- an item of the same location this one takes the place of (its parts are hidden)
}

-- Where a location is built: on the plot by the street, or in a venue of its own (reached by the jet).
export type Space = "plot" | "venue"

-- Club events (GDD: club life). speaker: a speaker blows and has to be fixed; vip: a VIP waits
-- at the entrance to be greeted; photographer: a photographer by the decks wants a caught drop.
export type EventKind = "speaker" | "vip" | "photographer"

export type Location = {
	id: string,
	name: string,
	colour: Color3, -- neon accent for this location's UI and lights
	lights: { Color3 }, -- the light show's palette; the first is the location's own colour
	guests: { min: number, max: number }, -- guests shown, from no income to a finished location
	space: Space,
	spaceSize: Vector3, -- the area the location's music and events cover, around its origin
	events: { EventKind }, -- the club events that can happen here
	sky: string?, -- a look from Config/Skies while the camera is in the location's room or venue
}

-- A fictional star DJ the player can book for a guest set (GDD: star DJs). Never a real DJ.
export type StarDj = {
	id: string,
	name: string,
	style: string, -- a few words about their sound, for the booking board
	location: string, -- the location that unlocks them; they stay bookable after it
	price: number, -- cash per booking
	multiplier: number, -- the plot's income multiplier during their set
	colour: Color3, -- their signature colour: the board, their portrait, the lights in their set
	look: { skin: Color3, hair: Color3, top: Color3, accent: Color3, hat: StarDjHat? }, -- their figure at the decks
}

-- A star DJ's signature hat (model sheet "Characters").
export type StarDjHat = "bucket" | "sun" | "visor"

-- What the client's light show does with a part on the beat (see Controllers/LightShow).
--   led: the main colour wash; speaker: pumps on every kick; spot: alternating fixtures that
--   strobe on drops; disco: spins and sparkles; screen: flickers; neon: a sign that flashes on drops;
--   wall: a big LED wall that shows level bars on the beat (Controllers/LedWall).
export type LightRole = "led" | "speaker" | "spot" | "disco" | "screen" | "neon" | "wall"

-- One blockout part, placed relative to a plot's origin (centre of the plot base's top face,
-- local -Z towards the street).
export type PartSpec = {
	size: Vector3,
	offset: Vector3, -- centre of the part
	colour: Color3,
	material: Enum.Material?, -- SmoothPlastic when nil
	shape: Enum.PartType?, -- Block when nil
	rotation: Vector3?, -- degrees around X, Y, Z
	transparency: number?,
	collide: boolean?, -- true when nil
	-- A PointLight in the part, or a SpotLight shining out of its front (-Z) face with `spot`.
	light: { colour: Color3?, brightness: number, range: number, spot: number? }?,
	text: { text: string, colour: Color3 }?, -- glowing text on the part's front (-Z) face
	lightRole: LightRole?, -- the client's light show drives this part on the beat
	beam: { length: number, width: number }?, -- a light beam out of the front face (moving heads, lasers)
	smoke: { colour: Color3, opacity: number, size: number, rise: number }?, -- haze or smoke from the part
	fx: DropFx?, -- the client fires this effect from the part on every drop
	-- Fill the part's box with smooth terrain of this material instead (the sea: real water). An
	-- invisible marker part keeps the box, so the terrain goes when its room is cleared.
	terrain: Enum.Material?,
}

-- Payoffs a part fires on every drop, once its feature item is bought.
export type DropFx = "confetti" | "co2" | "fireworks"

-- A location's look: the room that's always there, what each bought item adds, and where the
-- guests, the decks and the event props are. Positions are relative to the plot origin.
export type Blockout = {
	shell: { PartSpec },
	items: { [string]: { PartSpec } },
	guests: {
		entrance: Vector3, -- where friends walk in from
		spots: { Vector3 }, -- where they dance, in the order they arrive
		lookAt: Vector3, -- what they face (the DJ)
	},
	decks: {
		itemId: string, -- the item that is the DJ booth
		stand: Vector3, -- where the DJ stands, on the floor
		camera: Vector3, -- the shot while playing
		cameraLookAt: Vector3,
	},
	speakerItem: string?, -- the item the blown speaker event happens to
	-- Where the buttons, the register and the spawn go, when not where Config/PlotLayout says,
	-- and for a venue, where its jet back to the street stands (nose towards -X).
	layout: { buttonSlots: { Vector3 }, register: Vector3, spawn: Vector3, jet: Vector3? }?,
}

-- What a goal counts: collecting from the register, buying a given item, catching a drop
-- (Perfect or Good) or a Perfect one at the decks, fixing the blown speaker, owning a number of
-- tracks, greeting VIPs, or booking a star DJ (a given one, or any).
export type GoalKind = "collect" | "buy" | "drop" | "perfect" | "fix" | "tracks" | "vip" | "book"

export type Goal = {
	id: string, -- unique across locations, prefixed with its location
	text: string, -- shown in the tracker
	kind: GoalKind,
	target: string?, -- the item id for "buy", the DJ id for "book" (any DJ when nil)
	count: number?, -- how many: tracks owned, or times for "perfect", "vip", "drop", "collect", "fix"
	reward: number, -- cash
	line: string, -- what the host says when it's done
}

-- A location's host character: their goals and the lines they say.
export type Host = {
	name: string,
	role: string,
	colour: Color3, -- their portrait colour
	goals: { Goal },
	lines: {
		intro: string, -- a new player's first line
		done: string, -- after the location's last button
		speakerBlown: string,
		speakerFixed: string,
		vip: string?, -- when a VIP arrives
		photographer: string?, -- when a photographer turns up
		jetLocked: string?, -- when the player asks for the jet before they've earned it
	},
}

-- What one item costs and does to its plot's income.
export type ItemEffect = {
	cost: number,
	flat: number, -- cash per second it adds (0 for gear)
	multiplier: number, -- what it multiplies the plot's income by (1 unless gear)
}

return {}
