--!strict
-- Fake dance-track audio with a known tempo, first downbeat and section layout, for testing the
-- automatic tagger without real music. Deterministic: the same input always gives the same samples.

local SyntheticTrack = {}

SyntheticTrack.SAMPLE_RATE = 4000

export type Part = "intro" | "build" | "drop" | "breakdown" | "outro"
export type Layout = { { kind: Part, bars: number } }

-- How loud each sound is in each part (0 = silent).
type Mix = { kick: number, bass: number, hats: number, noise: number, pad: number, riser: number }

local MIX: { [Part]: Mix } = {
	intro = { kick = 0.6, bass = 0, hats = 0.08, noise = 0, pad = 0, riser = 0 },
	build = { kick = 0, bass = 0, hats = 0, noise = 0, pad = 0.05, riser = 0.35 },
	drop = { kick = 0.9, bass = 0.3, hats = 0.15, noise = 0.12, pad = 0, riser = 0 },
	breakdown = { kick = 0, bass = 0, hats = 0, noise = 0, pad = 0.2, riser = 0 },
	outro = { kick = 0.6, bass = 0, hats = 0.05, noise = 0, pad = 0, riser = 0 },
}

-- Renders the layout: silence until `firstBeat`, then the parts back to back, then 1 s of silence.
-- Kicks hit on every beat, hats on the off-beats, risers grow bar by bar.
function SyntheticTrack.render(bpm: number, firstBeat: number, layout: Layout): { number }
	local rate = SyntheticTrack.SAMPLE_RATE
	local beat = 60 / bpm

	local barParts: { Part } = {}
	local barProgress: { number } = {}
	for _, part in layout do
		for i = 0, part.bars - 1 do
			table.insert(barParts, part.kind)
			table.insert(barProgress, (i + 1) / part.bars)
		end
	end

	local count = math.floor((firstBeat + #barParts * 4 * beat + 1) * rate)
	local samples = table.create(count, 0)
	local noise = 1
	for i = 1, count do
		noise = (noise * 16807) % 2147483647
		local white = noise / 2147483647 * 2 - 1
		local t = (i - 1) / rate
		local beatPosition = (t - firstBeat) / beat
		local bar = math.floor(beatPosition / 4) + 1
		local kind = if beatPosition >= 0 then barParts[bar] else nil
		if kind then
			local mix = MIX[kind]
			local sinceBeat = (beatPosition - math.floor(beatPosition)) * beat
			local value = 0
			if mix.kick > 0 then
				value += mix.kick * math.sin(2 * math.pi * 55 * sinceBeat) * math.exp(-sinceBeat / 0.05)
			end
			if mix.bass > 0 then
				value += mix.bass * math.sin(2 * math.pi * 45 * t)
			end
			local sinceOffbeat = sinceBeat - beat / 2
			if mix.hats > 0 and sinceOffbeat >= 0 then
				value += mix.hats * white * math.exp(-sinceOffbeat / 0.01)
			end
			value += mix.noise * white + mix.riser * barProgress[bar] * white
			if mix.pad > 0 then
				value += mix.pad * math.sin(2 * math.pi * 330 * t)
			end
			samples[i] = value
		end
	end
	return samples
end

return SyntheticTrack
