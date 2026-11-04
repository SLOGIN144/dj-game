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
}

return Sounds
