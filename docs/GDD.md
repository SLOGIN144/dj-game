# DJ Career Game — Design & Build Spec

Nov 3, 2026

## How to use this doc

This is the source of truth for building a Roblox DJ career game with Claude Code. Read all of it before writing code, then build only the current milestone (see Milestone 1).

- **Owner:** Filip, solo developer, about 2–3 hours a day. This is his first Roblox game. He knows Python, C++, JavaScript, PHP and SQL, but is new to Roblox Studio and Luau, so explain Studio steps in plain words.
- **Stack:** Roblox Studio on Windows with its built-in MCP server, Claude Code (Pro plan), Rojo, Luau.
- **Where it lives:** this file is `docs/GDD.md` in the repo. `CLAUDE.md` points to it.
- **When things conflict:** 1) Content and platform rules, 2) the current milestone's scope, 3) the design pillars, 4) everything else.
- **Unknowns:** anything marked TBD or listed under Open questions gets a proposed default and a question to Filip. Never decide it silently.
- **Names:** every character, gear, venue and game name here is a placeholder unless marked final.

## Vision, pillars and audience

**Pitch:** start as a college kid DJing on a laptop in your dorm room, play for friends, and grind your way through frat parties and clubs until you headline Ibiza.

**Audience:** teens 14–17 who love parties and electronic music, plus 17+. PC first, but every control must also work on touch from day one.

### Pillars

Every feature must serve at least one of these.

1. **Earned career.** You start at the very bottom. Every venue and every piece of gear is earned, so Ibiza means something.
2. **The set is the game.** A 3–5 minute set must be fun on its own, even with no progression around it.
3. **Immersion.** Lights, crowd, sound and camera feel like real club footage. Players should love the clubs and the party.
4. **Easy to start, room to master.** Sync, EQ and the filter are run by the game. Skill shows in timing the start, the blend and the drop, and in reading the crowd; timing gets tighter as venues grow.
5. **Real stakes.** Bad sets cost rep and bookings and can get you demoted.

### Feel references

- **GTA V's rags-to-riches arc:** your life visibly upgrades — room, gear, transport, venues.
- **Real club footage:** dark rooms, one dominant colour, beams through haze, hands up, shot from behind the DJ over the decks.

### Anti-goals

- Starting the player on a big stage. Existing Roblox DJ games do this and it's boring.
- Nonstop button-prompt rhythm gameplay (hit the falling arrows). Timing challenges sit on real DJ moments (start, blend, drop, build) and the music reacts to them.
- Generic, AI-looking visuals.
- Alcohol, real brands, real DJ names.

## Core loop

The set is the game; every other step feeds the next set.

1. **Get booked** — gig offers arrive on your phone.
2. **Prep your crate** — pick tracks for this crowd.
3. **Travel to the gig** — bus, then van, then plane as you grow.
4. **Play the set** — 3–5 minutes, crowd energy judged live.
5. **Get results** — grade, rep, cash, followers.
6. **Spend and upgrade** — gear, tracks, apartment, manager. Then back to step 1.

Good sets raise rep; rep unlocks the next venue tier.

Inside a set, the micro loop is: pick the next track, time its start, ride the crossfader through the blend, hit the drop, and watch the crowd react (see The DJ set).

## The DJ set

A set lasts 3–5 minutes, has 3–4 transitions, and is judged live by the crowd's energy. It is the heart of the game, so it gets the most polish.

The set is a timing minigame built on real DJ moments, not a realistic mixer. Sync, EQ and the filter are run by the game. The player times the moments that make a mix feel good (starting the next track, riding the crossfader through the blend, hitting the drop) and reads the crowd to pick the next track. The music reacts to every input, so a good run sounds like a good mix and a miss is heard, but nothing ever stops the music.

### Structure of a set

1. **Before:** the player picks tracks for their crate (6 slots at the start). The prototype skips this and uses every tagged track.
2. **Start:** the first track plays from its cue point; the crowd starts at the venue's start energy.
3. **While a track plays (about a minute):** hype challenges come up on its builds and drops. About 15 seconds before the next transition, 2–3 track cards appear for choosing the next track.
4. **Transition (about 20 seconds):** three moments: start, blend, drop.
5. **Repeat:** 3–4 transitions per set.
6. **End:** when the venue's set timer runs out, the playing track fades over 8 bars, then the results screen opens. A transition in progress finishes first (max 16 bars).

The game decides when each transition happens, from the tagged track data. The outgoing track mixes out once it has played its drop for a while (about 16 bars, in `Balance.luau`), on a phrase boundary. The incoming track starts 8 bars before its first drop, so the drop lands exactly at the end of the blend.

### The transition: three moments

The **main button** is Space on PC (or a click on the on-screen button) and a big round button on touch. The **crossfader** is dragged with the mouse or a finger, or moved with ← / → on PC.

| Moment | What the player sees | What the player does | Perfect | Miss |
| --- | --- | --- | --- | --- |
| Start | a 4-3-2-1 countdown on the beat and a ring closing on the "1" | press the main button on the 1 | the next track comes in clean | the track still starts, but sounds off-beat for one bar before sync pulls it in |
| Blend | a green zone moving along the crossfader from deck A to deck B over 8 bars | keep the crossfader inside the zone | 90%+ of the time in the zone: a seamless blend | under 60%: the blend sounds bumpy (the audio follows the real crossfader position) |
| Drop | a ring closing on the incoming track's drop | press the main button on the drop | **Perfect drop:** confetti or CO2, a light blast, a camera hit and a cheer | the drop plays without the payoff |

**Good** sits between Perfect and Miss: a smaller reward, and it keeps the combo.

- The bass swap happens by itself halfway through the blend: the outgoing low EQ goes down as the incoming one comes up.
- Timing windows (starting values in `Balance.luau`): Perfect within 50 ms of the target beat, Good within 120 ms. An audio latency offset is applied, with a calibration step in Settings.
- No input ever stops the music: a missed or skipped moment always resolves on its own.

### Hype challenges

While a track plays, its tagged sections create short challenges between transitions:

- **Release:** during a build, hold the main button (the filter sweeps up and the tension rises) and let go exactly on the drop.
- **Hit:** one press on a marked beat for an effect: a confetti popper at the house party, CO2 in clubs.
- At most one hype challenge per section and none during a transition. They are graded Perfect / Good / Miss like the moments, with smaller energy changes.

### Picking the next track

- About 15 seconds before a transition, 2–3 cards appear, each showing title, genre and energy (1–5). Keys 1–3 or a tap pick one; if the player doesn't pick, the game takes the first card.
- Cards only offer tracks the current gear can sync (within its tempo range: ±8% on starter gear) that haven't been played earlier in the set.
- **Crowd wishes:** now and then a speech bubble over the crowd asks for a genre or for "more energy" (a higher energy rating). Picking a card that matches gives a bonus.

### Audio signal chain

Use the new Audio API, not legacy `Sound` objects. Verify exact class and property names in the Roblox docs before coding.

```
Deck A: AudioPlayer -> AudioEqualizer -> AudioFilter -> AudioFader (channel) -> AudioFader (xfade A) --+
Deck B: AudioPlayer -> AudioEqualizer -> AudioFilter -> AudioFader (channel) -> AudioFader (xfade B) --+
                                                                                                       |
          AudioFader (master) <---------------------------------------------------------------------+
          -> AudioCompressor (limiter) -> AudioDeviceOutput
          -> AudioAnalyzer (loudness for visuals)
```

- The crossfader uses an equal-power curve and follows the player's crossfader exactly.
- The game drives the EQs (the bass swap) and the filters (Release challenges); the player never turns a knob.
- FX insert after the filter on each channel (later, with gear).
- `PlaybackSpeed` changes tempo and pitch together. Key lock (a gear unlock) compensates with `AudioPitchShifter`.

### Beat clock and sync

- Every track has a tagged BPM and first-beat offset (see Audio and music).
- Beat position in a track = (TimePosition − firstBeat) × BPM / 60. Effective BPM = BPM × PlaybackSpeed.
- The master tempo comes from the outgoing deck.
- **Sync is always on:** the incoming deck's PlaybackSpeed is set so its effective BPM matches the master, then TimePosition is nudged to the nearest beat. It's re-checked every bar to correct drift. A Miss on the Start moment offsets the phase for one bar, then sync pulls it back.
- **Tempo range:** if two tracks' BPMs are further apart than the gear's range, sync can't match them, so they are never offered together on cards (124 to 128 works on ±8%; 124 to 140 doesn't).

### Crowd energy

Crowd energy runs from 0 to 100, updates every beat, and is shown on a meter and in the crowd itself. All numbers below live in `Balance.luau` and are starting points for tuning.

- **Drift (every beat):** energy moves 2% of the gap toward the current section's pull (intro low, build rising, drop high, breakdown medium), scaled by genre match. The crowd lives with the music even between inputs.

| Event | When | Effect |
| --- | --- | --- |
| Start or Blend moment | graded | Perfect +6, Good +3, Miss −4 |
| Drop moment | graded | Perfect +12, Good +5, Miss −4 |
| Hype challenge | graded | Perfect +3, Good +1, Miss −1 |
| Crowd wish met | the picked card matches the speech bubble | +5 |
| Genre match | track genre is in the venue's preferred list | ×1.2 on all gains |
| Repeat track | track used in the last 3 sets at this venue | ×0.7 on all gains |

### Combo

- Each Perfect raises the combo one step: ×1 → ×1.5 → ×2 → ×3 (max). Good keeps it, Miss resets it to ×1.
- The combo multiplies energy gains, not losses.
- It is a small number next to the energy meter; no points fly across the screen.

### Grading and rewards

The set's score is 0.6 × average energy + 0.25 × peak energy + 4 per Perfect drop − 3 per Miss, clamped to 0–100.

| Grade | Score | Rep multiplier |
| --- | --- | --- |
| S | 90+ | 1.5 |
| A | 80–89 | 1.2 |
| B | 65–79 | 1.0 |
| C | 50–64 | 0.6 |
| D | 35–49 | −0.3 (lose rep) |
| F | under 35 | −0.8 (lose rep) |

- **Rep** = venue base rep × grade multiplier.
- **Cash** = full venue pay at C or better, half below.
- **Followers** = venue capacity × a per-grade rate.
- **Demotion:** three D/F sets in a row at a tier trigger a warning from the manager. A fourth means bookings only at the previous tier until you get a B or better there.
- The server computes rewards from the set report and never trusts client totals (see Technical architecture).

### Feedback

- The crowd reacts in tiers by energy (see Venues and crowd).
- Lights follow the beat and energy; drops trigger the venue's big moment.
- The camera cuts faster and shakes slightly on drops.
- Small floating text only for grades and key events ("Perfect", "Good", "Miss", "Perfect drop"). No score spam.
- The crowd cheer swells on drops; whistles at peaks; a groan on a missed drop.

### Difficulty

Set per venue tier in `Balance.luau`:

- Timing windows are wide in the dorm and at the house party and tighten in clubs.
- The blend zone gets narrower and moves less evenly.
- Bigger venues have more transitions per set and more frequent crowd wishes.
- Better gear adds new challenge types (see Gear).

### Helping beginners

- **Track overview bar** per deck: coloured sections (intro, build, drop, breakdown, outro), beat ticks, playhead, drop markers and the real waveform, read in the background with `AudioPlayer:GetWaveformAsync` as soon as a track is picked.
- **Readable challenges:** every challenge shows what to press and when (ring, countdown, zone), so it works without reading instructions.
- **Dorm tutorial** teaches in 5 steps: the Start moment, the blend, the Drop moment, a Release challenge, picking a card.

## Controls and UI

During a set, a 2D DJ panel sits at the bottom of the screen while the 3D scene plays above it. Timing challenges pop up over the panel. The same panel works with mouse, keyboard and touch.

### Set screen layout

- **Bottom ~35%:** DJ panel styled like the player's current controller. Deck A on the left, deck B on the right, the crossfader with its blend zone in the centre, and the main button. Timing rings and countdowns pop up over the panel.
- **Above the panel, right:** the track cards when it's time to pick.
- **Top strip:** two stacked track overview bars.
- **Top right:** crowd energy meter, combo and set timer.
- **Rest of the screen:** the 3D scene with the camera director.
- **H** hides the panel (clip mode); only the energy meter stays and challenges resolve on their own.

### PC defaults (rebindable later)

| Action | Key |
| --- | --- |
| Main button (start, drop, hype challenges) | Space, or click the on-screen button |
| Crossfader | hold ← / →, or drag |
| Pick a track card | 1 / 2 / 3, or click |
| Hide the panel (clip mode) | H |
| Camera | C cycles or locks a shot |

### Touch

- Minimum touch target about 48 px on a phone; the main button is bigger (about 96 px), bottom centre.
- One thumb on the main button, the other on the crossfader: multi-touch must work.
- Cards are tapped.

### Other screens

- **Phone** (outside sets): Messages (story), Bookings (gig offers), Social (followers, posts, clips), Shop, Map/Travel, Settings.
- **Crate prep:** choose tracks for the gig; each shows BPM, genre and energy.
- **Results:** grade, an energy graph over the set, rewards, and a one-line comment from the manager.
- **HUD outside sets:** cash, rep and followers, small in the top-left.

### UI style

Dark, clean and rounded, with a neon accent taken from the current venue's colour. One clean built-in sans font. No clutter during a set: the only pop-ups are the timing challenges and the track cards, over the DJ panel, never over the middle of the 3D scene.

## Camera and cutscenes

During a set, an automatic director cuts between angles like a live club stream. Outside sets, the normal Roblox third-person camera is used.

### Shots

Each venue defines its camera points as named Parts or Attachments in a `CameraPoints` folder.

| Shot | Framing | Used for |
| --- | --- | --- |
| Hero | behind the DJ, over the decks, facing the crowd | default; every drop |
| Wide | back of the room toward the booth | builds and breakdowns |
| Hands | side angle on the controller | transitions |
| Crowd | low, in the front rows | right after drops |
| Rig | high, lights and crowd | big venues only |

### Rules

- Cut only on bar boundaries. Hold each shot 4–8 bars.
- On a drop, cut to Hero exactly on the beat with a slight shake.
- Every shot slowly drifts or dollies; no static shots.
- C cycles or locks a favourite shot; an Auto Director toggle turns cuts back on.
- The mixer panel stays on top whatever the shot.
- The dorm room uses only two shots: over the shoulder at the desk, and a room wide.

### Cutscenes

- 10–25 seconds, always skippable.
- Built from camera tweens, character animations and on-screen phone messages.
- Used for chapter starts and milestones: the first party invite, the first opening slot, the Ibiza call.
- Build a small data-driven cutscene runner: a list of steps (move camera, wait, show message, play animation).

## Career and progression

The player climbs from a dorm room to Ibiza. Every step is earned with rep, cash, gear and a better manager. Launch ships tiers 0–3; the rest arrive as updates.

### Stats

| Stat | Means | Earned by | Spent on / unlocks |
| --- | --- | --- | --- |
| Rep | respect in the scene | good sets | venue tiers |
| Followers | fame | sets, clips, remix hits | bigger crowds, better pay, more offers |
| Cash | money | gig pay | gear, tracks, apartment, manager |

### Venue tiers

| Tier | Venue | Crowd (fiction) | Unlock | Ships in |
| --- | --- | --- | --- | --- |
| 0 | Dorm room (practice + tutorial) | 0–3 friends | start | launch |
| 1 | Friend's house party | 10–20 | finish tutorial | launch |
| 2 | Frat party | 30–60 | rep + gear tier 1 | launch |
| 3 | Local club | 100–150 | rep + gear tier 2 + manager level 1 | launch |
| 4 | Popular city club | 300–500 | TBD | update |
| 5 | Headliner nights (people come for you) | 500+ | TBD | update |
| 6 | Big city tour (New York and others) | 1,000+ | TBD | update |
| 7 | Ibiza | 2,000+ | TBD | update |
| — | World tour | — | after Ibiza | later update |

Rep thresholds live in `Balance.luau`. Rendered NPCs are far fewer than the fiction numbers (see crowd rendering).

### Bookings

- Gig offers arrive on the phone: venue, in-game date, pay, crowd size, preferred genres, set length and required gear tier.
- **Overreach gigs:** sometimes an offer is above your gear tier. Accept it and the missing challenges and effects stay locked and the crowd's energy decays faster. A B or better pays ×2 rep. High risk, high reward.
- **Opening slots (tier 3+):** you open for a fictional headliner. Your goal is to warm the crowd, keeping energy in a 50–75 band. Holding it over 85 too long costs a "stole the headliner's thunder" penalty. Reward: big rep, followers, and the headliner's favour in the story.
- **Later (tier 5+):** NPC DJs open for you, so your set starts with a warmed-up crowd.

### Gear

Designs are inspired by real gear, with fictional names and logos. Never use real brand names, logos or exact product designs.

| Tier | Placeholder name | Inspired by | Unlocks |
| --- | --- | --- | --- |
| 0 | Laptop + Volt 2 | beginner 2-deck controller | the three transition moments, Release and Hit challenges, ±8% tempo |
| 1 | Volt 4 | mid-range controller | Echo-out challenge (end a track on an echo), bigger payoffs |
| 2 | CDX-3000 players + MX-900 mixer | club-standard media players and mixer | key lock, ±16% tempo (more tracks fit the cards), CO2 and strobe challenges, club respect bonus |
| 3 | Nexus 4-deck setup | 4-channel club setup | double drop challenge (two tracks drop together), more FX |
| 4 | Flagship rig | top-end club setup | all FX, custom light cues |

Gear tiers 1–4 unlock new challenge types instead of new knobs. The exact challenges above tier 0 are first proposals (TBD).

- **Party gear (tiers 1–2):** you bring your own speaker and party lights. A better speaker raises crowd capacity; better lights raise energy gain.
- **Headphones:** cosmetic.

### Tracks and crate

- Tracks are bought with in-game cash only, never Robux (see Audio and music).
- The crate is the set of tracks you bring to a gig: 6 slots at the start, more with progression.
- Each track has a genre, BPM, energy (1–5) and tier. Bigger venues reward high-energy tracks played at the right moment.

### Manager

- **Start:** your roommate handles bookings, but only tiers 0–2.
- **Upgrades** cost cash and need rep. They bring better offers and more followers per set, and level 1 is required for tier 3.

### Apartment

- Dorm room → shared flat → studio apartment → loft → villa (Ibiza era).
- It's where you practice (free sets, no rewards), prep tracks (hot cues and loops, later), and show off gear, posters and awards.
- Furniture and decor are cosmetic shop items.

### Remixes and hits (after launch)

- Make an edit of an owned track in your apartment studio and release it.
- A small chance, based on skill, genre trend and followers, turns it into a hit: a big rep and follower spike, and NPC DJs start playing it.
- Licensed audio can't leave Roblox, so remixes stay in-game. The exact mechanic is TBD.

### Life sim scope

Medium. The phone, apartment, manager and short travel scenes (bus, then van, then plane). No driving, no hunger or needs, no chores.

## Story

The story is light and told in chapters, mostly through phone messages plus a few short cutscenes. All names are placeholders.

**Setup:** you're a first-year college student. DJing is your hobby: a laptop and a cheap controller in your dorm room.

### Cast

| Character | Role |
| --- | --- |
| Max (roommate) | your hype man, then your first manager |
| Lena (best friend) | throws the house party that becomes your first gig |
| Tyler (frat president) | books you for frat parties |
| VEXX (rival DJ) | from your campus, always a step ahead early on |
| Solenne (headliner) | gives you your first opening slot, later invites you to Ibiza |
| Pro manager | takes over at club level (TBD) |

### Chapters

1. **Dorm Days (tiers 0–1):** practice, your first house party, a neighbour knocking about the noise, Max posting your first clip.
2. **Frat Season (tier 2):** frat bookings, VEXX shows up, your first big crowd.
3. **Club Debut (tier 3):** your first club night, the opening slot for Solenne, a manager upgrade.
4. **Later updates:** city clubs, headliner nights, New York, the Ibiza finale.

Each chapter runs: intro message → 3–5 gigs → a story gig with a special goal → a short cutscene → unlock.

**Tone:** aspirational and fun, with small funny moments. Never edgy. No alcohol and no real DJs.

## Venues and crowd

Each venue is a hand-tuned space with its own colour, crowd taste and lighting rig, defined in `Venues.luau`.

**Venue config fields:** id, name, tier, fiction capacity, rendered NPC count, preferred genres, start energy, decay rate, pay range, base rep, set length, camera points, lighting rig level, special FX, dominant colour.

### Launch venues

| Venue | Look | Colour | Crowd taste | FX |
| --- | --- | --- | --- | --- |
| Dorm room | desk, laptop, bed, LED strip, posters, night window | warm lamp + purple LED | none (practice) | none |
| Friend's house party | living room, sofa pushed aside, string lights, your own speaker | warm + party colours | house, dance-pop | confetti popper (buyable) |
| Frat party | basement, flags, game tables, cheap party lights | red | EDM / big room, house | party lights, small fog machine |
| Local club | small dark club, booth on a riser, first real rig, haze | blue | house, tech house, techno | CO2 jets on drops |

### Crowd rendering

- **Front rows:** full R15 rigs with varied dance animations, random start offsets and ±10% speed.
- **Middle rows:** simpler rigs with fewer animations.
- **Back rows:** cheap low-part silhouettes moved by one shared bob script.
- **Budget:** about 40 full rigs on PC and 15 on mobile, scaled by graphics quality.
- Crowd NPCs are client-side visuals only during solo sets.

### Crowd reactions

| Energy | What the crowd does |
| --- | --- |
| 0–25 | standing, arms crossed; some walk to the drinks bar (soft drinks) or leave |
| 25–50 | light sway, chatting |
| 50–75 | bouncing, heads nodding |
| 75–90 | jumping, hands up |
| 90+ | full jump, phones up on drops, cheering |

- **Perfect drop:** a cheer burst on the beat.
- **Train wreck:** boos, people turning around.
- **Requests:** an occasional speech bubble asking for a genre.
- **House party:** named friends (story characters) dance in front.

## Visual style and lighting

Stylized geometry, realistic lighting. Shapes stay clean and simple; immersion comes from light, haze, colour and motion.

### Rules from Filip's reference photos

- A dark room with one dominant colour per venue (blue, red, magenta), plus white beams as accents.
- Beams cutting through haze from a rig above the booth.
- The crowd as silhouettes with hands up, lit from behind and above.
- The best angle is behind the DJ, over the decks, looking at the crowd.
- Confetti and CO2 are payoffs on drops, never constant decoration.

### Roblox implementation

Verify each property in the docs before use.

- **Lighting:** Future lighting technology, Atmosphere for haze, Bloom and ColorCorrection. No sun indoors.
- **Beams:** Beam objects with gradient textures from moving-head fixtures, plus a few SpotLights for real light on the crowd.
- **LED walls:** neon parts and SurfaceGui panels with simple animated patterns. At headliner tier they show the player's DJ name.
- **Particles:** ParticleEmitters for CO2 jets, confetti, sparks and haze puffs.
- **Light show engine:** driven by BeatClock (beat, bar, phrase), the track's current section and crowd energy. Each venue has cue presets: idle, build (strobe rate up, beams tilt), drop (full blast, colour flip, FX), breakdown (slow sweeps, low intensity).
- **Performance:** at most about 4 shadow-casting SpotLights, a particle budget and a part budget per venue. The graphics quality setting scales crowd, particles and beams.

### Asset workflow

1. Claude builds blockouts through the Studio MCP: layout, simple parts, lighting and effects.
2. Detailed props come from Roblox's Cube 3D/mesh generation, low-cost asset packs, or Creator Store models, only after Filip approves. Check every free model for scripts first; they can hide malicious code.
3. Filip polishes by hand.
4. The dorm room and the local club are built first and become templates for every other venue.

## Audio and music

All music is Roblox-licensed audio from the Creator Store, and everything the game knows about a track comes from a tagged data file (see Track Tagger).

### Licensing rules (hard requirements)

- Use only licensed music from the Creator Store (APM, Monstercat, DistroKid releases and similar) or audio Filip owns.
- At most 250 distinct licensed tracks in the experience at any one time.
- Never charge Robux to listen to a specific track, and never build a general music library or streaming feature. Tracks unlock with in-game cash earned by playing.
- Licensed audio never leaves Roblox (no export or download).
- Check each source's credit requirements.
- Never invent asset IDs. Use only IDs Filip provides.

### Genres

- **Launch:** house, tech house, techno, and an EDM / big room bucket for frat parties. Check how many tracks of each exist in the library before locking the list.
- **Later:** drum & bass and others.

### Track data

One entry per track in `src/shared/Config/Tracks.luau`. Section positions are in beats from the first downbeat.

```lua
{
    id = "deep_sunrise",        -- internal key
    assetId = 0,                -- rbxassetid, provided by Filip
    title = "...", artist = "...",
    genre = "house",
    bpm = 124,
    firstBeat = 0.48,           -- seconds to the first downbeat
    sections = {
        { kind = "intro", startBeat = 0 },
        { kind = "build", startBeat = 64 },
        { kind = "drop", startBeat = 96 },
        { kind = "breakdown", startBeat = 160 },
        { kind = "drop", startBeat = 224 },
        { kind = "outro", startBeat = 288 },
    },
    cuePoint = 0,               -- beat where an incoming mix starts
    energy = 3,                 -- 1..5
    tier = 1,
    price = 250,
}
```

### Track Tagger (dev-only tool, build first)

- Runs in its own Studio place in Play mode and is never shipped.
- Works a track out from its audio by itself (`AudioPlayer:GetWaveformAsync`): exact BPM, first downbeat, sections, cue point and a starting energy rating, and shows the real waveform. Keys stay for fixing a result by ear (tap tempo, mark the downbeat, mark sections snapped to bars).
- "Auto-tag picks" runs through `tools/TrackTagger/Picks.luau` and prints the finished entries to paste into `Tracks.luau`.
- Without accurate BPM and offsets, sync and the timing challenges break, so every track goes through it.

### Sound effects

Crowd ambience per energy tier (looping), cheer swells, whistles, boos, a door knock for the dorm, and applause at set end. Use Roblox library SFX only.

### Mix safety

- A master limiter (AudioCompressor) so two loud decks never clip.
- Settings: master volume, plus separate music and SFX sliders.

## Monetization

Free players can reach everything and have fun; Robux buys speed, comfort and style. Pay-to-win is allowed only as speed, never as skipping the career.

### Game passes (prices TBD)

| Pass | Gives |
| --- | --- |
| 2x Cash | double gig pay |
| Bigger Crate | +4 crate slots |
| VIP | VIP tag, VIP lounge in the hub, small daily cash bonus |
| Light Show Pack | custom light colours and patterns in your sets |

### Developer products

- Cash packs.
- Cosmetics: booth and controller skins, apartment furniture, confetti and CO2 colours.
- Short boosts, such as 30 minutes of 2x followers.
- Cheap private servers.

### Never

- Sell a specific track or music access for Robux.
- Paid random loot boxes.
- Let Robux skip a venue tier or a story gig.

### Sponsors (later)

Banners and booth branding in clubs, like real life. Check Roblox's current rules on in-experience ads and brand integrations before building it.

## Content and platform rules

These rules override everything else in this doc.

- **No alcohol.** Bars serve soda, energy drinks and water. Alcohol has to be disclosed in Roblox's maturity questionnaire and has pushed games into the 17+ category, which would cut most of the 14–17 audience. Target maturity label: Mild or lower.
- **No real brands or people.** No real brand names, logos, exact product designs, or real DJs and artists as characters.
- **Music:** follow the licensing rules in Audio and music.
- **Player text:** anything a player types (DJ name, crate names) goes through Roblox text filtering (TextService) before anyone else sees it.
- **Free models:** inspect for scripts before use; no third-party code without review.
- **Before publishing:** fill out the content maturity questionnaire honestly.
- **Purchases:** follow Roblox's rules for passes and products, with clear prices.

## Multiplayer and social

The launch is a solo career. Social features come once there are enough players to support them.

### At launch

- Small servers of 8–12 players.
- **Dorm hub:** players spawn in a shared dorm building, each with their own room that others can visit. Higher-tier players live in better buildings (later).
- Sets are solo: audio and crowd run on the player's client.
- Global leaderboards: best set score per venue tier, and followers.

### Later updates

- **B2B:** two friends share the decks and take turns.
- **DJ battles:** two players play short sets and the server votes.
- **Real crowd:** friends join your club night as the crowd.
- **Events:** weekly themed nights and genre weeks.

## Technical architecture

Code lives in files synced by Rojo, and the world lives in the Studio place file. Claude Code edits files directly and the place through the Studio MCP.

### Tools

- **Roblox Studio (Windows)** with the built-in MCP server on: Assistant → Manage MCP Servers → Enable Studio as MCP server, then Quick Connect → Claude Code.
- **Claude Code** in the repo folder.
- **Rokit** to install and pin Rojo, Selene (linter) and StyLua (formatter). Wally only if a package is truly needed; ask Filip first.
- **luau-lsp** in the editor, **Git + GitHub** for history.
- **Language:** Luau with `--!strict` at the top of every module.

### Repo layout

```
dj-game/
  CLAUDE.md                -- short: stack, rules, points to docs/GDD.md
  docs/GDD.md              -- this doc
  default.project.json     -- Rojo mapping
  rokit.toml  selene.toml  stylua.toml
  src/
    shared/   -> ReplicatedStorage.Shared
      Config/   Tracks, Venues, Gear, Balance, Passes
      Types.luau  Remotes.luau  Util/ (Signal, cleanup helper)
    server/   -> ServerScriptService.Server
      Services/ PlayerData, Career, Booking, Shop, SetResults, Monetization, Leaderboard
    client/   -> StarterPlayer.StarterPlayerScripts.Client
      Controllers/ AudioEngine, BeatClock, SetDirector, Minigame, Scoring, Crowd,
                   LightShow, CameraDirector, Cutscene, UI, Phone
      UI/ (components)
  tools/
    TrackTagger/           -- dev-only, never shipped
```

### Client and server

- **Client:** audio engine, beat clock, set minigame, live scoring, crowd, lights, camera and UI. Anything timing-critical stays local.
- **Server:** player data, career state, bookings, shop, rewards and leaderboards.
- **Set flow:** the server issues a set token (venue, tracks, set length, start time) → the client plays the set → the client sends a set report (event list + summary stats) → the server validates it (plausible duration, owned tracks, gear-allowed actions, score consistent with events) → the server computes and grants rewards.
- Never trust client cash or rep values. Type-check and rate-limit every remote.

### Data

- Use ProfileStore (a session-locked DataStore wrapper) or an equivalent session-locking pattern. Ask Filip before adding the package.
- **Schema v1:** version, cash, rep, followers, tier, managerLevel, ownedGear, equippedGear, ownedTracks, crate, apartmentTier, storyFlags, venueHistory (recent tracks per venue, bad-set streak), stats, settings, purchases.
- A version field and a migration function from day one.

### Performance targets

- 60 FPS on a mid-range PC during the biggest drop; 30+ FPS on a mid-range phone.
- A graphics-quality setting scales crowd, particles and beams.
- **Debug overlay** (dev only, toggled): both BPMs, phase error, energy, recent events, FPS.

### Testing

- Scoring and energy logic live in pure Luau modules so they can be tested with simple test scripts.
- After every feature: playtest through the Studio MCP, read the console output, and fix errors and warnings before moving on.

## Milestone 1: prototype

Goal: prove that one 4-minute set is fun. It's done when a new player can mix two tracks at a house party, hit a drop, and want to play again.

### In scope

- [x] Repo and tooling: Rojo project, Rokit, Selene, StyLua, `CLAUDE.md`, `docs/GDD.md`, git.
- [x] Track Tagger tool, and 6–8 licensed house/tech house tracks tagged (Filip picks the tracks).
- [ ] Audio engine: 2 decks, crossfader, 3-band EQ and filter (driven by the game), always-on sync, master limiter.
- [ ] BeatClock and sync.
- [ ] Set minigame and its UI for mouse, keyboard and touch: the three transition moments, hype challenges, track cards, combo, and track overview bars.
- [ ] Crowd energy model, events, grade and results screen (no saving yet).
- [ ] Dorm room blockout with practice mode and a 5-step tutorial.
- [ ] Friend's house party blockout: about 15 NPC dancers with 5 reaction tiers, party lights reacting to beat and energy, confetti on a Perfect drop.
- [ ] Camera director with 3 shots (Hero, Wide, Hands).
- [ ] Debug overlay.

**Out of scope:** saving, shop, phone, story, other venues, monetization, multiplayer, remixes.

### Acceptance criteria

- A first-time player finishes the tutorial and a full house party set without outside help.
- Every challenge reads at a glance: a first-time player can tell what to press and when.
- A synced transition holds phase error under 1/16 beat for 30+ seconds.
- A Perfect drop fires confetti, a cheer, a light blast and a camera hit on the exact beat.
- No errors in the output during a full set, and 60 FPS on Filip's PC.
- Filip plays it three times in a row and wants to keep going. This is the real test.

### Build order

1. Tooling, track data and the Track Tagger.
2. Audio engine and BeatClock, tested with the debug overlay only.
3. Set minigame (transition moments, hype challenges, track cards) and its UI.
4. Scoring and results.
5. Venue blockouts, crowd, lights and camera.
6. Tutorial and a polish pass.

## Roadmap after the prototype

Launch happens only when the core loop is polished and has no known bugs; big content comes after as updates.

1. **Milestone 2 — Career skeleton:** saving, phone (messages and bookings), results paying rep/cash/followers, gear shop (tiers 0–1), track shop, crate prep, frat party venue.
2. **Milestone 3 — Chapters 1–3:** story messages and 3 cutscenes, roommate manager, local club with full rig and CO2, opening slots, demotion, dorm hub with visitable rooms.
3. **Milestone 4 — Launch prep:** tutorial polish, settings, mobile performance pass, passes and products, leaderboards, analytics events, maturity questionnaire, icon and thumbnails, trailer clips for TikTok. Then launch v1.0.
4. **Updates:** popular club and headliner nights, New York, the Ibiza finale, remixes and hits, B2B, DJ battles, world tour.

## Working rules for Claude Code

1. Read `CLAUDE.md` and this doc at the start of every session. Work on the current milestone only.
2. Before each feature, write a short plan (files, APIs, how you'll test it). Wait for Filip's OK on anything big.
3. Check every Roblox class, property and event name against the official docs before using it. The Audio API is newer and changes; prefer it over legacy `Sound` objects.
4. Keep logic data-driven: tuning numbers in `Balance.luau`, content in the `Config` files.
5. Write small, typed, single-purpose modules with English comments. No giant scripts.
6. After every change, playtest through the Studio MCP, read the console output, and fix errors and warnings.
7. Commit to git after every working step with a clear message.
8. Build blockouts and lighting with code and the MCP. Don't attempt detailed art out of parts; mark where imported assets go.
9. Ask Filip before adding packages, changing the data schema, touching monetization or the content rules, or deleting work.
10. Explain Studio steps to Filip in plain words; he's new to Roblox.
11. If stuck after two attempts, stop and explain the problem and the options.
12. Never invent track asset IDs.

## Open questions

- [ ] Game name.
- [ ] Venue list and rep thresholds after tier 3.
- [ ] Story names, the rival's arc, and the Ibiza ending.
- [ ] Genre list, after checking how much house and techno the Creator Store has.
- [ ] Remix and hit mechanic.
- [ ] Pass and product prices.
- [ ] A pass to replace Pro Sync (removed when the set became a timing minigame).
- [ ] What Roblox allows for sponsor banners.
- [ ] More art references: a colour palette per venue.

## DJ glossary

| Term | Meaning in this game |
| --- | --- |
| Beat / bar / phrase | 4 beats = 1 bar; phrases are 8, 16 or 32 bars. Transitions and camera cuts land on these boundaries. |
| BPM | tempo in beats per minute |
| Beatmatch | aligning two tracks' tempo and beat phase |
| Sync | automatic beatmatch; always on in this game |
| Moment | one of the three timing challenges in a transition: start, blend, drop |
| Hype challenge | a short timing challenge while a track plays: Release (hold through a build, let go on the drop) or Hit |
| Perfect / Good / Miss | the grade for a timing challenge |
| Combo | a multiplier on energy gains that grows with each Perfect and resets on a Miss |
| Phase | position inside a beat; matched phase means the kicks land together |
| Crossfader | slider blending deck A and deck B |
| EQ (low / mid / high) | bass, mids and treble per channel; a bass swap cuts the bass on one deck while bringing it in on the other |
| Filter | low-pass or high-pass sweep, used for builds |
| Build-up | rising section before a drop |
| Drop | high-energy payoff section |
| Breakdown | quiet section without the kick |
| Train wreck | two tracks audibly out of sync |
| Cue / hot cue | stored start points in a track |
| Loop | a section of N beats repeating |
| Key lock | keeps pitch steady when tempo changes |
| Crate | the tracks you bring to a gig |
| Opening / warm-up set | the set before the headliner; keeps energy moderate |
| Headliner | the main DJ of the night |
| B2B | two DJs taking turns in one set |
