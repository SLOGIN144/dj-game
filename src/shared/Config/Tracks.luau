--!strict
-- Every track the game knows about, one entry per track. Entries come from the Track Tagger
-- (tools/TrackTagger): never type BPM or offsets by hand, and never invent asset IDs.
-- Section positions are in beats from the first downbeat.

local Types = require(script.Parent.Parent.Types)

local Tracks: { Types.Track } = {}

return Tracks
