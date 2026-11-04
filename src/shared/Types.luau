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

export type Item = {
	id: string, -- unique across all locations, prefixed with its location ("dorm_lamp")
	name: string, -- shown on the button
	kind: ItemKind, -- income and feature items add cash per second; gear multiplies the plot's income
}

export type Location = {
	id: string,
	name: string,
	colour: Color3, -- neon accent for this location's UI and lights
	guests: { min: number, max: number }, -- guests shown, from no income to a finished location
}

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
	light: { colour: Color3?, brightness: number, range: number }?, -- a PointLight in the part
	text: { text: string, colour: Color3 }?, -- glowing text on the part's front (-Z) face
}

-- A location's look: the room that's always there, and what each bought item adds.
export type Blockout = {
	shell: { PartSpec },
	items: { [string]: { PartSpec } },
}

-- What one item costs and does to its plot's income.
export type ItemEffect = {
	cost: number,
	flat: number, -- cash per second it adds (0 for gear)
	multiplier: number, -- what it multiplies the plot's income by (1 unless gear)
}

return {}
