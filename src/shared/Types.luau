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

return {}
