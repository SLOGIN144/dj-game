--!strict
-- Sound effect asset IDs. Roblox library SFX only; never invent IDs: Filip picks each sound in
-- the Creator Store and pastes its ID here. 0 means not chosen yet, and that sound stays silent.

local Sounds: { [string]: number } = {
	cheer = 0, -- crowd cheer swell on a Perfect drop
	cash = 0, -- collecting from the register
	buildPop = 0, -- a bought item popping in
	speakerBlow = 0, -- the speaker blowing
	fix = 0, -- the speaker fixed
	goal = 0, -- a goal done
	knock = 0, -- a door knock when a friend arrives
	buy = 0, -- buying a track in the shop
	moveOn = 0, -- a whoosh when moving on to the next location
	jet = 0, -- the jet taking off, during the travel fade
	vip = 0, -- a VIP arriving at the door (a short fanfare)
	camera = 0, -- the photographer's camera shutter and flash
	notice = 0, -- a soft ping when an event needs the player
	starDj = 0, -- a star DJ taking over the decks (crowd roar)
	co2 = 0, -- a CO2 jet's hiss on a drop
	firework = 0, -- a firework bursting
	click = 0, -- UI buttons
}

return Sounds
