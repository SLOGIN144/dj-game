--!strict
-- The tracks picked for the prototype (the same list as docs/track-picks.md), with the details
-- the audio can't tell us. Artists come from each track's Creator Store page.
-- "Auto-tag picks" in the tagger analyses all of them and prints their Tracks.luau entries.

export type Pick = {
	assetId: number,
	id: string,
	title: string,
	artist: string,
	genre: string,
}

local Picks: { Pick } = {
	{ assetId = 1836798379, id = "until_sunrise", title = "Until Sunrise", artist = "Andy Danza", genre = "house" },
	{
		assetId = 1836800628,
		id = "london_loves",
		title = "London Loves",
		artist = "George Gwinnell",
		genre = "house",
	},
	{
		assetId = 99266731124568,
		id = "chili_mexican",
		title = "Chili Mexican",
		artist = "Feelyno Dj",
		genre = "tech house",
	},
	{
		assetId = 128840312200418,
		id = "endless_summer",
		title = "The Sound of Endless Summer",
		artist = "Love Sleep Repeat",
		genre = "house",
	},
	{
		assetId = 93443738890753,
		id = "angelic_choir",
		title = "The Angelic Choir",
		artist = "Dixon Live",
		genre = "tech house",
	},
	{
		assetId = 86067233920375,
		id = "neon_ruins",
		title = "Neon Ruins",
		artist = "George Kraniotakis",
		genre = "tech house",
	},
	{
		assetId = 82604702163302,
		id = "heatwave_circuit",
		title = "Heatwave Circuit",
		artist = "George Kraniotakis",
		genre = "tech house",
	},
}

return Picks
