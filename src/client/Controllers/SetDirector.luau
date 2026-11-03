--!strict
-- Runs one set at the house party: plays tracks on two decks, plans the timing challenges from the
-- tagged track data, judges the player's input, feeds the crowd's energy and drives the set screen.
--
-- Flow per track: it comes in on a drop (Drop moment), plays its drop with a hype challenge or two,
-- track cards appear, and the next transition runs: Start on the 1, an 8-bar Blend, the next Drop.
-- All targets are beats of the playing ("master") deck, so they stay locked to the music.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local BeatMath = require(Shared.Util.BeatMath)
local BlendJudge = require(Shared.Set.BlendJudge)
local ChallengeQueue = require(Shared.Set.ChallengeQueue)
local CrowdEnergy = require(Shared.Set.CrowdEnergy)
local HypePlanner = require(Shared.Set.HypePlanner)
local TrackChoice = require(Shared.Set.TrackChoice)
local TrackInfo = require(Shared.Set.TrackInfo)
local Tracks = require(Shared.Config.Tracks)
local TransitionPlanner = require(Shared.Set.TransitionPlanner)
local Types = require(Shared.Types)
local Venues = require(Shared.Config.Venues)

local AudioEngine = require(script.Parent.AudioEngine)
local BeatClock = require(script.Parent.BeatClock)
local SetInput = require(script.Parent.SetInput)
local SetUI = require(script.Parent.Parent.UI.SetUI)

local SetDirector = {}

local LOAD_TIMEOUT = 15 -- seconds to wait for a track's audio
local ASSIST_SPEED = 2.5 -- crossfader travel per second when the game finishes a crossfade
local BLEND_GRADE_EARLY_BEATS = 2 -- the blend is graded this many beats before the drop
local AUTOPLAY_ATTRIBUTE = "SetAutoPlay" -- set on Workspace to let the game play itself (testing)
local VENUE = Venues.house_party

type Deck = { track: Types.Track?, clock: BeatClock.BeatClock, lengthBeats: number }

type Incoming = {
	track: Types.Track,
	startBeat: number, -- incoming beat that plays at the Start moment
	dropBeat: number, -- incoming beat of the Drop moment
	ready: boolean,
	failed: boolean, -- its audio didn't load
	scheduled: boolean,
	missOffset: number, -- extra beats the deck is pushed off for one bar after a missed start
}

type Phase = "loading" | "playing" | "blend" | "ending" | "results"

local function energyKind(kind: ChallengeQueue.Kind): CrowdEnergy.Kind
	if kind == "start" then
		return "moment"
	elseif kind == "drop" then
		return "drop"
	end
	return "hype"
end

local LABELS: { [ChallengeQueue.Kind]: string } = { start = "START", drop = "DROP", hit = "HIT", release = "RELEASE" }

-- Starts a set on `playerGui`. Returns a function that tears it down.
function SetDirector.run(playerGui: Instance, onRestart: () -> ()): () -> ()
	local engine = AudioEngine.new(Workspace)
	local ui = SetUI.new(playerGui, VENUE.name, VENUE.colour)
	local input = SetInput.new(ui)
	local random = Random.new()
	local energy = CrowdEnergy.new(VENUE.startEnergy)
	local queue = ChallengeQueue.new()

	local decks: { Deck } = {
		{ track = nil, clock = BeatClock.new(), lengthBeats = 0 },
		{ track = nil, clock = BeatClock.new(), lengthBeats = 0 },
	}
	local master = 1
	local phase: Phase = "loading"
	local played: { [string]: boolean } = {}
	local enteredAt = 0 -- master beat of the drop the playing track came in on
	local mixOut: number? = nil -- master beat of the next Start moment
	local endAt: number? = nil -- master beat where the set starts to fade out instead
	local cards: { Types.Track }? = nil
	local wish: TrackChoice.Wish? = nil
	local picked: number? = nil
	local incoming: Incoming? = nil
	local blendInZone, blendTotal = 0, 0
	local blendDone = false
	local assistTarget: number? = nil
	local tempoFrom: number? = nil -- speed the master eases back from after a blend
	local fadeFrom = 0
	local setStart = os.clock()
	local lastWholeBeat = -math.huge
	local lastBar = -math.huge
	local positions = { 0, 0 } -- smoothed deck positions this frame, seconds

	local function idle(): number
		return 3 - master
	end

	local function masterTrack(): Types.Track
		return decks[master].track :: Types.Track
	end

	local function deckBeat(deck: number): number
		local track = decks[deck].track
		if not track then
			return 0
		end
		return BeatMath.timeToBeat(positions[deck], track.bpm, track.firstBeat)
	end

	local function beatSeconds(deck: number): number
		local track = decks[deck].track
		return if track then 60 / (track.bpm * engine:speed(deck)) else 0.5
	end

	local function effectiveBpm(deck: number): number
		local track = decks[deck].track
		return if track then track.bpm * engine:speed(deck) else 120
	end

	local function genreBoost(track: Types.Track?): number
		return if track and table.find(VENUE.preferredGenres, track.genre) then Balance.Energy.genreMatch else 1
	end

	local function seekToBeat(deck: number, beat: number)
		local track = decks[deck].track :: Types.Track
		local seconds = BeatMath.beatToTime(beat, track.bpm, track.firstBeat)
		engine:seek(deck, seconds)
		decks[deck].clock:reset(seconds)
		positions[deck] = seconds
	end

	local function loadDeck(deck: number, track: Types.Track): boolean
		if not engine:load(deck, track.assetId, LOAD_TIMEOUT) then
			return false
		end
		decks[deck].track = track
		decks[deck].lengthBeats = BeatMath.timeToBeat(engine:length(deck), track.bpm, track.firstBeat)
		ui:setDeck(deck, track, engine:length(deck))
		return true
	end

	-- Plans what happens while the master track plays: its next mix-out and its hype challenges.
	local function planTrack(nowBeat: number)
		local track = masterTrack()
		mixOut = TransitionPlanner.mixOutBeat(track, enteredAt, nowBeat, decks[master].lengthBeats)
		local hype = Balance.Hype
		local quietUntil = (mixOut :: number) - Balance.Cards.showBeforeBeats - hype.quietBeforeCardsBeats
		for _, challenge in HypePlanner.plan(track, enteredAt + hype.quietAfterDropBeats, quietUntil) do
			ChallengeQueue.add(queue, challenge.kind, challenge.beat, challenge.holdFrom)
		end
	end

	local function cardViews(): { SetUI.Card }
		local views = {}
		for _, track in cards or {} do
			table.insert(views, {
				title = track.title,
				genre = track.genre,
				energy = track.energy,
				bpm = track.bpm,
				wished = wish ~= nil and TrackChoice.matches(track, wish),
			})
		end
		return views
	end

	local function celebrate(kind: ChallengeQueue.Kind, grade: string)
		if grade == "miss" then
			return
		end
		local perfect = grade == "perfect"
		if kind == "drop" then
			ui.crowd:flash(if perfect then 1 else 0.5)
			ui.crowd:confetti(if perfect then 160 else 50)
		elseif kind == "release" or kind == "hit" then
			ui.crowd:flash(if perfect then 0.6 else 0.3)
			if perfect then
				ui.crowd:confetti(40)
			end
		end
	end

	local function applyMissedStart()
		local coming = incoming
		if coming and coming.ready then
			coming.missOffset = Balance.Transition.missOffsetBeats
			local desired = coming.startBeat + (deckBeat(master) - (mixOut :: number)) + coming.missOffset
			seekToBeat(idle(), desired)
		end
	end

	local function resolve(result: ChallengeQueue.Result)
		local kind = result.challenge.kind
		local boost = genreBoost(if kind == "drop" and incoming then incoming.track else decks[master].track)
		CrowdEnergy.applyGrade(energy, energyKind(kind), result.grade, boost)
		ui:popGrade(result.grade, LABELS[kind])
		celebrate(kind, result.grade)
		if kind == "release" then
			engine:setSweep(master, 0)
		elseif kind == "start" and result.grade == "miss" then
			applyMissedStart()
		elseif kind == "drop" then
			ui:setStatus("")
		end
	end

	local function onPress()
		if phase == "results" then
			return
		end
		local result = ChallengeQueue.press(queue, deckBeat(master), beatSeconds(master))
		if result then
			resolve(result)
		end
	end

	local function onRelease()
		local result = ChallengeQueue.release(queue, deckBeat(master), beatSeconds(master))
		if result then
			resolve(result)
		end
	end

	local function loadIncoming(track: Types.Track)
		local deck = idle()
		local start, drop = TransitionPlanner.entry(track)
		local coming: Incoming = {
			track = track,
			startBeat = start,
			dropBeat = drop,
			ready = false,
			failed = false,
			scheduled = false,
			missOffset = 0,
		}
		incoming = coming
		task.spawn(function()
			local loaded = loadDeck(deck, track)
			if incoming ~= coming then
				return
			elseif not loaded then
				coming.failed = true
				return
			end
			engine:setSpeed(deck, effectiveBpm(master) / track.bpm)
			engine:setBass(deck, 0)
			engine:setSweep(deck, 0)
			seekToBeat(deck, start)
			coming.ready = true
		end)
	end

	local function pick(index: number)
		local offered = cards
		if not offered or picked or not offered[index] or not mixOut then
			return
		end
		picked = index
		local track = offered[index]
		ui:setCards(cardViews(), index)
		if wish and TrackChoice.matches(track, wish) then
			CrowdEnergy.applyBonus(energy, Balance.Energy.wishMet, 1)
			ui:popGrade("CROWD LOVES IT!")
		end
		ui:setWish(nil)
		loadIncoming(track)
		ChallengeQueue.add(queue, "start", mixOut :: number)
		ChallengeQueue.add(queue, "drop", (mixOut :: number) + TransitionPlanner.blendBeats())
		ui:setStatus("Get ready to start it on the 1")
	end

	-- Cards appear before a transition, unless the set is nearly over: then the track plays out.
	local function offerCards(beat: number)
		local secondsToEnd = ((mixOut :: number) - beat + TransitionPlanner.blendBeats()) * beatSeconds(master)
		if os.clock() - setStart + secondsToEnd > VENUE.setLengthSeconds + 15 then
			endAt = mixOut
			mixOut = nil
			ui:setStatus("Last track: enjoy the drop!")
			return
		end
		local track = masterTrack()
		cards = TrackChoice.candidates(Tracks, track.id, effectiveBpm(master), played, Balance.Cards.count, random)
		wish = TrackChoice.makeWish(cards :: { Types.Track }, track, random)
		ui:setCards(cardViews(), nil)
		ui:setWish(if wish then TrackChoice.describe(wish) else nil)
		ui:setStatus("Pick the next track: 1, 2 or 3")
	end

	-- Starts the incoming deck exactly on the Start beat, on the audio clock.
	local function scheduleStart(beat: number)
		local coming = incoming :: Incoming
		coming.scheduled = true
		seekToBeat(idle(), coming.startBeat)
		engine:playAt(idle(), math.max(0, ((mixOut :: number) - beat) * beatSeconds(master)))
	end

	-- The picked track didn't load: drop this transition and offer cards again a little later.
	local function abandonTransition()
		incoming, cards, picked = nil, nil, nil
		ChallengeQueue.clear(queue)
		ui:setCards(nil)
		mixOut = (mixOut :: number) + 2 * Balance.Transition.phraseBeats
		ui:setStatus("That track didn't load; pick another one")
	end

	local function startBlend()
		phase = "blend"
		blendDone = false
		blendInZone, blendTotal = 0, 0
		cards, picked = nil, nil
		ui:setCards(nil)
		ui:setStatus("Keep the crossfader in the green zone (← → or drag)")
	end

	local function finishBlend()
		blendDone = true
		local share = if blendTotal > 0 then blendInZone / blendTotal else 0
		local grade = BlendJudge.grade(share)
		CrowdEnergy.applyGrade(energy, "moment", grade, genreBoost((incoming :: Incoming).track))
		ui:popGrade(grade, "BLEND")
		ui:setZone(nil)
		assistTarget = if idle() == 2 then 1 else 0
	end

	local function switchMaster(beat: number)
		local coming = incoming :: Incoming
		local old = master
		master = idle()
		enteredAt = coming.dropBeat
		played[coming.track.id] = true
		engine:setBass(master, 1)
		tempoFrom = engine:speed(master)
		incoming = nil
		ui:setLive(master)
		ui:setStatus("")
		local newBeat = coming.dropBeat + (beat - ((mixOut :: number) + TransitionPlanner.blendBeats()))
		decks[old].clock:reset(0)
		phase = "playing"
		planTrack(newBeat)
		-- The previous deck is silent by now (crossfader on the new side); it stops in two beats.
		task.delay(2 * beatSeconds(master), function()
			if master ~= old then
				engine:stop(old)
			end
		end)
	end

	local function showResults()
		phase = "results"
		engine:stop(1)
		engine:stop(2)
		ChallengeQueue.clear(queue)
		ui:setPrompt(nil)
		ui:setCards(nil)
		ui:setWish(nil)
		ui:setStatus("")
		local score = CrowdEnergy.score(energy)
		ui:showResults({
			grade = CrowdEnergy.letter(score),
			score = score,
			average = if energy.beats > 0 then energy.total / energy.beats else energy.energy,
			peak = energy.peak,
			perfectDrops = energy.perfectDrops,
			misses = energy.misses,
		})
	end

	local function autoplay(beat: number)
		if not Workspace:GetAttribute(AUTOPLAY_ATTRIBUTE) then
			return
		end
		local challenge = ChallengeQueue.active(queue, beat)
		if challenge then
			if challenge.kind == "release" then
				if not challenge.holding and beat >= (challenge.holdFrom or challenge.beat) then
					onPress()
				elseif challenge.holding and beat >= challenge.beat then
					onRelease()
				end
			elseif beat >= challenge.beat then
				onPress()
			end
		end
		if cards and not picked then
			pick(1)
		end
	end

	-- One frame of the set.
	local function step(dt: number)
		input:update(dt)
		for deck = 1, 2 do
			positions[deck] =
				decks[deck].clock:update(engine:position(deck), engine:isPlaying(deck), engine:speed(deck))
		end
		if phase == "loading" or phase == "results" then
			return
		end
		local beat = deckBeat(master)
		autoplay(beat)

		-- The crowd lives with the music, one beat at a time.
		local whole = math.floor(beat)
		if whole > lastWholeBeat and phase ~= "ending" then
			lastWholeBeat = whole
			CrowdEnergy.drift(energy, TrackInfo.sectionAt(masterTrack(), beat).kind)
		end

		-- Challenges: misses for what passed, then the prompt for what's next.
		for _, result in ChallengeQueue.expire(queue, beat, beatSeconds(master)) do
			resolve(result)
		end
		local active = ChallengeQueue.active(queue, beat)
		if active then
			local text, number, ring, hold = ChallengeQueue.prompt(active, beat)
			ui:setPrompt(text, number, ring, hold)
			if active.kind == "release" and active.holding then
				engine:setSweep(master, hold * 0.9)
			end
		else
			ui:setPrompt(nil)
		end

		if phase == "playing" then
			if tempoFrom then
				local t = math.clamp((beat - enteredAt) / (Balance.Transition.tempoReturnBars * 4), 0, 1)
				engine:setSpeed(master, tempoFrom + (1 - tempoFrom) * t)
				if t >= 1 then
					tempoFrom = nil
				end
			end
			if mixOut and not cards and beat >= mixOut - Balance.Cards.showBeforeBeats then
				offerCards(beat)
			end
			if mixOut and cards and not picked and beat >= mixOut - Balance.Cards.autoPickBeforeBeats then
				pick(1)
			end
			local coming = incoming
			if coming and coming.failed then
				abandonTransition()
				coming = nil
			end
			if mixOut and coming and beat >= mixOut - 1 and not coming.scheduled then
				if coming.ready then
					scheduleStart(beat)
				else
					-- The next track isn't loaded yet: push the transition back a phrase.
					ChallengeQueue.shift(queue, mixOut, Balance.Transition.phraseBeats)
					mixOut += Balance.Transition.phraseBeats
				end
			end
			if mixOut and coming and coming.scheduled and beat >= mixOut then
				startBlend()
			end
			if endAt and beat >= endAt then
				phase = "ending"
				fadeFrom = beat
				ChallengeQueue.clear(queue)
				ui:setStatus("")
			end
		elseif phase == "blend" then
			local coming = incoming :: Incoming
			local start = mixOut :: number
			local blendBeats = TransitionPlanner.blendBeats()
			local progress = (beat - start) / blendBeats
			local towardsB = idle() == 2
			if Workspace:GetAttribute(AUTOPLAY_ATTRIBUTE) then
				input.crossfader = BlendJudge.zoneCentre(progress, towardsB)
			end
			if not blendDone then
				local inside = BlendJudge.inZone(input.crossfader, progress, towardsB)
				blendTotal += dt
				if inside then
					blendInZone += dt
				end
				ui:setZone(BlendJudge.zoneCentre(progress, towardsB), inside)
			end

			-- Bass swap halfway through.
			local swap = math.clamp((progress - Balance.Blend.bassSwapAt) / 0.06, 0, 1)
			engine:setBass(master, 1 - swap)
			engine:setBass(idle(), swap)

			-- Keep the incoming deck locked to the master, checked once per bar.
			local bar = math.floor(beat / 4)
			if bar > lastBar then
				lastBar = bar
				if coming.missOffset ~= 0 and beat >= start + 4 then
					coming.missOffset = 0
				end
				local desired = coming.startBeat + (beat - start) + coming.missOffset
				local drift = (deckBeat(idle()) - desired) * beatSeconds(idle())
				if math.abs(drift) > Balance.Transition.syncToleranceSeconds and engine:isPlaying(idle()) then
					seekToBeat(idle(), desired)
				end
			end

			-- The blend is graded two beats before the drop, so its result and the Drop's don't overlap.
			if beat >= start + blendBeats - BLEND_GRADE_EARLY_BEATS and not blendDone then
				finishBlend()
			end
			if beat >= start + blendBeats + 1 then
				switchMaster(beat)
			end
		elseif phase == "ending" then
			local t = (beat - fadeFrom) / (Balance.Set.outroFadeBars * 4)
			engine:setMasterVolume(1 - t)
			if t >= 1 then
				showResults()
			end
		end

		-- The crossfader belongs to the player during a blend; otherwise it rests on the playing deck.
		local target = assistTarget
		if target then
			local moveBy = ASSIST_SPEED * dt
			input.crossfader += math.clamp(target - input.crossfader, -moveBy, moveBy)
			if math.abs(input.crossfader - target) < 0.001 then
				assistTarget = nil
			end
		elseif phase ~= "blend" then
			input.crossfader = if master == 2 then 1 else 0
		end
		engine:setCrossfader(input.crossfader)
		ui:setCrossfader(input.crossfader)

		for deck = 1, 2 do
			local length = engine:length(deck)
			if decks[deck].track and length > 0 then
				ui:setPlayhead(deck, positions[deck] / length)
			end
		end
		ui:setEnergy(energy.energy, CrowdEnergy.comboMultiplier(energy))
		ui:setTimer(VENUE.setLengthSeconds - (os.clock() - setStart))
		ui.crowd:update(beat, energy.energy)
	end

	input.onPress = onPress
	input.onRelease = onRelease
	input.onCard = pick
	input.onRestart = function()
		if phase == "results" then
			onRestart()
		end
	end

	local connection = RunService.RenderStepped:Connect(step)

	-- Open with a random track, starting 8 bars before its drop: the first challenge is that drop.
	task.spawn(function()
		ui:setStatus("Loading the first track...")
		local first = Tracks[random:NextInteger(1, #Tracks)]
		if not loadDeck(1, first) then
			ui:setStatus("Couldn't load the first track. Check the asset IDs in Tracks.luau.")
			return
		end
		local start, drop = TransitionPlanner.entry(first)
		seekToBeat(1, start)
		engine:setCrossfader(0)
		engine:play(1)
		played[first.id] = true
		enteredAt = drop
		ChallengeQueue.add(queue, "drop", drop)
		planTrack(start)
		ui:setLive(1)
		ui:setStatus("Press SPACE on the drop when the ring closes")
		setStart = os.clock()
		phase = "playing"
	end)

	return function()
		connection:Disconnect()
		input:destroy()
		engine:destroy()
		ui.gui:Destroy()
	end
end

return SetDirector
