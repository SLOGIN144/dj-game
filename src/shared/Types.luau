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

-- What one item costs and does to its plot's income.
export type ItemEffect = {
	cost: number,
	flat: number, -- cash per second it adds (0 for gear)
	multiplier: number, -- what it multiplies the plot's income by (1 unless gear)
}

return {}
