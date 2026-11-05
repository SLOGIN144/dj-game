# DJ Club Tycoon — Design & Build Spec

Nov 3, 2026 (redesigned as a tycoon; the timing-set design is kept in git under the tag `set-prototype`)

## How to use this doc

This is the source of truth for building a Roblox DJ club tycoon with Claude Code. Read all of it before writing code, then build only the current milestone (see Milestone 1).

- **Owner:** Filip, solo developer, about 2–3 hours a day. This is his first Roblox game. He knows Python, C++, JavaScript, PHP and SQL, but is new to Roblox Studio and Luau, so explain Studio steps in plain words.
- **Stack:** Roblox Studio on Windows with its built-in MCP server, Claude Code (Pro plan), Rojo, Luau.
- **Where it lives:** this file is `docs/GDD.md` in the repo. `CLAUDE.md` points to it.
- **When things conflict:** 1) Content and platform rules, 2) the current milestone's scope, 3) the design pillars, 4) everything else.
- **Unknowns:** anything marked TBD or listed under Open questions gets a proposed default and a question to Filip. Never decide it silently.
- **Names:** every character, DJ, gear, location and game name here is a placeholder unless marked final.

## Vision, pillars and audience

**Pitch:** start with a laptop in your dorm room and build a party, then a club, then an Ibiza beach club, one bought piece at a time. Real music plays in every club, mixed on the beat, and you catch the drops to make the crowd go wild.

**Audience:** teens 14–17 who love parties and electronic music, plus 17+. PC first, but every control must also work on touch from day one.

### Pillars

Every feature must serve at least one of these.

1. **Earned career.** You start at the very bottom. Every part of every club is bought, so Ibiza means something.
2. **Always a next step.** The next button is always in sight, and while saving up for it there's always something active to do: a drop, an event, a goal. Active play is clearly faster than idling.
3. **The music is real.** Every club plays real licensed tracks, mixed on the beat by the game. Lights and guests move with the music, and the drop is the big moment.
4. **Easy to start.** A new player understands the loop in 30 seconds without reading anything. Character goals teach the rest.
5. **Show it off.** Other players walk into your club, hear your music and see what you've built.

### Feel references

- **GTA V's rags-to-riches arc:** your life visibly upgrades, from a dorm room to a beach club.
- **Classic Roblox tycoons (the genre):** buttons on the floor, a part appears, money comes in, the next button lights up.
- **Real club footage:** dark rooms, one dominant colour, beams through haze, hands up.

### Anti-goals

- Starting the player on a big stage. Existing Roblox DJ games do this and it's boring.
- A realistic DJ simulator: no mixer knobs, no crossfader, no long sets that need full attention. The game mixes; the player catches the drop.
- Generic, AI-looking visuals.
- Alcohol, real brands, real DJ names.

## Core loop

The club is the game. Every 10–60 seconds the player has something to do:

1. **Guests pay** — guests arrive and dance; their entry money piles up in the register.
2. **Collect** — walk to the register to pick up the money.
3. **Buy** — step on the next button; a new part of the club appears with an animation, more guests come and income per second rises.
4. **Catch the drop** — at the decks, press on the drop for a boost (see The decks).

Around it, every few minutes: a club event, a goal from the location's character, a star DJ to book, a new track to buy. When every button of a location is bought, the player moves on to the next location.

## Building the club

### Plots

- The street is the hub: a night-time city street with tall buildings and 6 plots, 3 on each side of the road. A server has at most 6 players.
- On join, the player gets a free plot and spawns on the street at its building. When they leave, the plot is cleared.
- **Each plot is one building, and it grows with the career:** a small, worn student dorm, then an apartment block, then a tall tower with a neon sign and stairs down to an underground club. Anyone on the street can see how far a player has come.
- **Small locations are interiors** behind the building's door: the dorm room, the apartment and the underground club.
- **Big locations leave the street.** At the far end, the street stops at a closed gate with a small airstrip and a white private jet behind it, in sight from the start as the big goal. When Ibiza is unlocked, the jet takes the player to a large open-air venue with a plaza and pools.
- Other players can walk into any building and hear its music.

### Buttons

- **Phone orders (built for the dorm first; the other locations follow):** the player opens the phone (P, or a tap), ticks up to 3 of the next items they can afford and presses Order. The cash is taken, a delivery truck drives down the street to their kerb and leaves a labelled box per item on the pavement. The player picks a box up (E), carries it into the room and places it on its glowing outline (E): only then does the item appear, with the build animation and sound, and only then does it earn. One box at a time; no new order while boxes are still out. The design is in `docs/superpowers/specs/2026-11-05-truck-delivery-design.md`. The Move On pad stays a pad on the floor.
- Locations not yet converted still use pads on the floor with a name and a price (stepping on one with enough cash buys it).
- Items unlock in a fixed order. The next 2–3 are always visible, so the player has a choice and a goal in sight; later ones stay hidden.
- Each button is one entry in `Config/Items.luau`: id, location, order, display name, kind, and the look it shows. Costs and incomes come from `Pricing` (see Money).
- Blockouts are built from code at server start (layout data in `Config/`), so the whole world is in git. Imported art later goes into ServerStorage as models named after their item and replaces the blockout parts.

| Item kind | Gives | Examples |
| --- | --- | --- |
| Income | +cash per second | sofa, dance floor, LED strip, merch stand, soda bar |
| Gear | a multiplier on the whole plot's income | laptop, controller, media players and mixer, 4-deck setup |
| Feature | unlocks a system | DJ booking board, track shop, bigger register |

- The first button of each location is free, and alone it earns about as much as the whole previous location, so moving on never feels like a step back.

### Locations

| Location | Buttons | Target time (active play) | Guests shown | Colour |
| --- | --- | --- | --- | --- |
| Dorm room | ~10 | ~10 min | 0–5 friends | warm lamp + purple LED |
| House party | ~15 | ~40 min | 10–25 | warm + party colours |
| Club | ~20 | 2–3 h | 30–80 (fewer rendered) | blue |
| Ibiza beach club | ~25 | 5–6 h | 100+ (fewer rendered) | sunset orange + magenta |

- About 10 hours from the dorm to a finished Ibiza.
- **Many more locations later.** Filip wants far more than these four (between them and after Ibiza). The four are the spine for the prototype and launch planning; the full list is an open question, and every system must take a new location as one more `Locations.luau` entry with its items.
- When every button is bought, a **Move on** button appears. The building grows to its next stage, the next location opens behind its door (or the jet unlocks, for Ibiza), and building starts again with pricier parts that pay more. Cash, tracks, star DJs and goals carry over.
- **Rebirth (world tour):** after Ibiza, in a later update.
- Launch ships all four locations; Milestone 1 builds only the first.

### Money

- **Income per second** = sum of income items × gear multipliers × track bonus × active boosts. The server computes it; the client only shows it.
- **Register:** income piles up in the register at the entrance, with the amount shown above it. It fills to at most ~10 minutes of income, then stops, so the player comes back. Walking into it collects.
- **Pricing:** item costs and incomes come from a few curve numbers per location in `Balance.luau` (a pure `Pricing` module), not 70 hand-typed prices. The curve targets the location times above with active play; idle play should be about 30% slower.
- One currency: cash. No rep or followers.
- Income only while the player is in the game. Offline earnings are an open question.

## The decks

The DJ booth is part of every location (the laptop on the dorm desk, later real decks). The music plays by itself; the player can step in to catch drops.

### Music that mixes itself

- Each plot plays a nonstop mix of the owner's tracks, mixed on the beat by the game: the next track starts 8 bars before its drop, blends over 8 bars, and the drop lands on the beat (the same rules the set prototype proved, run automatically).
- The **server** plans each plot's mix from the tagged track data: which track, when it starts and when it hands over, against `workspace:GetServerTimeNow()`. A pure `MixPlanner` module does the planning, so it's deterministic and tested.
- Each **client** plays the mix of the location the player is in, so everyone in a club hears the same thing at the same moment, and lights and guests move on its beat.
- Tracks are only mixed with tracks within ±8% tempo; otherwise the next one starts after a short fade.
- About one drop every 1–2 minutes.

### Drop bonus

- A **ProximityPrompt** ("Play", E on PC, tap on touch) puts the owner at the decks. The camera moves behind the DJ, facing the dance floor.
- Before each drop a ring closes in time with the beat, with a 4-3-2-1 count. The **main button** (Space, a click or a big touch button) on the drop:

| Grade | Window (starting values) | Effect |
| --- | --- | --- |
| Perfect | within 60 ms | ×2 income for 30 s, confetti, light blast, cheer, slight camera shake |
| Good | within 140 ms | ×1.5 income for 20 s, a smaller payoff |
| Miss | later or no press | nothing; no penalty |

- Windows are wider than the set prototype's, since this is a bonus, not a test. They live in `Balance.luau`, with an audio latency offset to calibrate later.
- The client judges the press and sends it to the server; the server checks it against its own drop time (within a lag allowance) before granting the boost. A new boost replaces a weaker one; it doesn't stack.
- Walking away or pressing E leaves the decks. Away from the decks, drops still fire the lights, but give no boost.

### Tracks

- A **track shop** at the decks sells tracks for cash (never Robux). Each owned track joins the plot's mix and adds a permanent income bonus (starting at +5%).
- A new player owns 2 tracks. All 7 tagged tracks are in the shop; more come later through the Track Tagger.

## Club life

### Events

About every 3–5 minutes while the owner is on their plot, one event happens. Each is short and has an on-screen marker.

| Event | What happens | What the player does | Reward |
| --- | --- | --- | --- |
| VIP guest | a VIP arrives at the entrance | walk up and greet them (ProximityPrompt) within 60 s | a big tip (~2 min of income) |
| Blown speaker | a speaker smokes; music gets quieter and income drops 25% | hold E on the speaker for 2 s | income back to normal, a small tip |
| Photographer | a photographer stands in front of the decks | catch a drop within 30 s | a bonus (~3 min of income) |

The prototype builds only the blown speaker.

### Star DJs (fictional)

- A **DJ booking board** on the plot (a Feature button) lists fictional star DJs. Each has their own name, look and style; never real DJs.
- Booking costs cash. The DJ plays a 3-minute guest set at your decks: a bigger crowd and ×3 income. Then they need a rest (starting at 15 minutes) before they can be booked again.
- Each location unlocks 1–2 new DJs, pricier and stronger. During a guest set the player can't use the decks; the star catches every drop.

### Characters and goals

The story is light: each location has a host character who gives 3–5 goals, shown in a small tracker. Each finished goal pays cash and plays a short dialogue line. No cutscenes at launch.

| Location | Character (placeholder) | Example goals |
| --- | --- | --- |
| Dorm room | Max, your roommate and hype man | buy the speaker, collect from the register, catch your first drop |
| House party | Lena, your best friend, throws the party | catch 3 Perfect drops, book your first star DJ, fix a blown speaker |
| Club | Rosa, the club owner | buy the media players, own 5 tracks, greet 3 VIPs |
| Ibiza | Solenne, a star DJ who invites you to Ibiza | TBD |

The dorm goals are the tutorial. **Tone:** aspirational and fun, with small funny moments. Never edgy.

## Controls and UI

### PC defaults (rebindable later)

| Action | Key |
| --- | --- |
| Move, jump | WASD, Space (normal Roblox) |
| Buy a button, collect | walk onto it |
| Interact (decks, VIP, speaker, boards) | E (ProximityPrompt) |
| Main button at the decks | Space, or click the on-screen button |
| Leave the decks | E, or walk away |

### Touch

- Normal Roblox thumbstick and jump; ProximityPrompts are tapped.
- At the decks, a big round main button (about 96 px), bottom centre.

### Screens

- **HUD:** cash and income per second (top), the active boost and its timer, the goal tracker with the character's portrait.
- **At the decks:** the drop ring and countdown above the main button, the playing track's title, a small track bar with the drop marked.
- **Track shop and DJ board:** simple lists with price and a Buy button.
- **Dialogue:** a small panel with the character's portrait and one line.
- Floating "+$" text when collecting, and "Perfect" / "Good" on drops. No other number spam.

### UI style

Dark, clean and rounded, with a neon accent taken from the current location's colour. One clean built-in sans font.

## Camera

- The normal Roblox third-person camera everywhere.
- At the decks: a fixed shot behind the DJ over the decks, facing the dance floor, with a slow drift and a slight shake on drops.
- A purchase briefly frames the new part only if the player isn't moving (later polish).

## Locations and guests

Each location is a hand-tuned space defined in `Config/Locations.luau`: id, name, order, colour, guest range, item list, character, star DJs, and its folder in the place.

| Location | Look | FX unlocked by buttons |
| --- | --- | --- |
| Dorm room | desk, laptop, bed, LED strip, posters, night window | none |
| House party | apartment living room, sofa pushed aside, string lights, your own speaker, a balcony over the city | confetti popper |
| Club | small underground club in a basement, concrete and brick, booth on a riser, a real rig, haze | moving heads, CO2 jets on drops |
| Ibiza beach club | open-air venue by the sea: arrival airstrip, plaza with palms, pools, dance deck, stage with a big LED wall | fireworks, full light show |

### Guests

- The number of guests follows the plot's income, within the location's range. Guests walk in through the location's entrance and dance on the floor.
- Guests are client-side visuals built from replicated plot state, so every player sees them in every club.
- **Rendering:** front rows are full R15 rigs with varied dance animations, random start offsets and ±10% speed; further back, simpler figures moved by one shared bob script. Budget about 40 full rigs on PC and 15 on mobile across all plots in view, scaled by graphics quality.
- **Prototype:** the dorm's 0–5 friends are figures built from parts and moved on the beat by code (`Controllers/Guests`), since dance animations need animation IDs. R15 rigs replace them once Filip provides the IDs.
- **Reactions:** dancing on the beat, hands up on drops, a cheer burst on a Perfect drop, bigger moves during a boost or a star DJ set.

## Visual style and lighting

Stylized geometry, realistic lighting. Shapes stay clean and simple; immersion comes from light, haze, colour and motion. The final look uses smooth, well-modelled 3D assets with rounded edges, not plain cubes; simple parts are only for blockouts.

Concept images (the city, then each location, as an isometric series in one shared style) are references for layout, colour and mood, not for exact measurements.

They live in `docs/concept/`: `street.webp` (the hub), `dorm.webp`, `house-party.webp`, `club.webp` and `ibiza.webp`. The content rules still win over them: the bottles behind the club's bar and the red cups at the house party become soda, energy drinks and water when those locations are built.

### Rules from Filip's reference photos

- A dark room with one dominant colour per location, plus white beams as accents.
- Beams cutting through haze from a rig above the booth.
- The crowd as silhouettes with hands up, lit from behind and above.
- Confetti and CO2 are payoffs on drops, never constant decoration.

### Roblox implementation

Verify each property in the docs before use.

- **Lighting:** Future lighting technology, Atmosphere for haze, Bloom and ColorCorrection. A night street, and a sunset at Ibiza; the client switches the look when the player changes space.
- **Beams:** Beam objects with gradient textures from moving-head fixtures, plus a few SpotLights for real light on the crowd.
- **Particles:** ParticleEmitters for CO2 jets, confetti, sparks and haze puffs.
- **Light show:** driven by the plot's beat clock and the playing track's section: idle, build, drop (full blast, colour flip, FX), breakdown. Lights a player hasn't bought yet stay off.
- **Performance:** at most about 4 shadow-casting SpotLights per plot, a particle budget and a part budget per location. The graphics quality setting scales guests, particles and beams.

### Asset workflow

1. Claude builds blockouts through the Studio MCP: layout, simple parts, lighting and effects, with every button's part in place.
2. Detailed props come from Roblox's Cube 3D/mesh generation, low-cost asset packs, or Creator Store models, only after Filip approves. Check every free model for scripts first; they can hide malicious code.
3. Filip polishes by hand.

## Audio and music

All music is Roblox-licensed audio from the Creator Store, and everything the game knows about a track comes from a tagged data file (see Track Tagger).

### Licensing rules (hard requirements)

- Use only licensed music from the Creator Store (APM, Monstercat, DistroKid releases and similar) or audio Filip owns.
- At most 250 distinct licensed tracks in the experience at any one time.
- Never charge Robux to listen to a specific track, and never build a general music library or streaming feature. Tracks unlock with in-game cash.
- Licensed audio never leaves Roblox (no export or download).
- Check each source's credit requirements.
- Never invent asset IDs. Use only IDs Filip provides.

### Genres

House and tech house at the start (the 7 tagged tracks). Techno and EDM later, after checking what the library has.

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

### Track Tagger (dev-only tool)

- Runs in its own Studio place in Play mode and is never shipped.
- Works a track out from its audio by itself (`AudioPlayer:GetWaveformAsync`): exact BPM, first downbeat, sections, cue point and a starting energy rating, and shows the real waveform. Keys stay for fixing a result by ear.
- "Auto-tag picks" runs through `tools/TrackTagger/Picks.luau` and prints the finished entries to paste into `Tracks.luau`.
- Without accurate BPM and drops, the mix and the drop bonus break, so every track goes through it.

### Audio signal chain

Use the new Audio API, not legacy `Sound` objects. Verify exact class and property names in the Roblox docs before coding.

```
Deck A: AudioPlayer -> AudioEqualizer -> AudioFilter -> AudioFader (xfade A) --+
Deck B: AudioPlayer -> AudioEqualizer -> AudioFilter -> AudioFader (xfade B) --+
                                                                               |
          AudioFader (master, by distance to the plot) <----------------------+
          -> AudioCompressor (limiter) -> AudioDeviceOutput
```

- The game drives the crossfade (equal power), the bass swap and the filter; the player never touches them.
- Beat position in a track = (TimePosition − firstBeat) × BPM / 60. The incoming deck's PlaybackSpeed matches the outgoing tempo and is re-checked every bar; after a blend the tempo eases back.
- The incoming deck starts on the mixer clock (`AudioPlayer:Play(atTime)` with `SoundService:GetMixerTime()`) so it lands on the beat.

### Sound effects

Build pops for purchases, a cash sound for collecting, cheer swells on drops, crowd ambience by guest count, a door knock for the dorm. Roblox library SFX only.

### Mix safety

- A master limiter (AudioCompressor) so two loud decks never clip.
- Settings: master volume, plus separate music and SFX sliders.

## Monetization

**Needs a rework for the tycoon. Decide with Filip before building any of it** (see Open questions). The rules below still hold; the old pass list from the set design is gone.

- Free players can reach everything and have fun; Robux buys speed, comfort and style. Pay-to-win is allowed only as speed, never as skipping a location.
- **Never:** sell a specific track or music access for Robux; paid random loot boxes; let Robux skip a location or a story goal.
- Sponsors (banners in clubs) only after checking Roblox's current rules on in-experience ads.

## Content and platform rules

These rules override everything else in this doc.

- **No alcohol.** Bars serve soda, energy drinks and water. Alcohol has to be disclosed in Roblox's maturity questionnaire and has pushed games into the 17+ category, which would cut most of the 14–17 audience. Target maturity label: Mild or lower.
- **No real brands or people.** No real brand names, logos, exact product designs, or real DJs and artists as characters or star DJs.
- **Music:** follow the licensing rules in Audio and music.
- **Player text:** anything a player types (club name, later) goes through Roblox text filtering (TextService) before anyone else sees it.
- **Free models:** inspect for scripts before use; no third-party code without review.
- **Before publishing:** fill out the content maturity questionnaire honestly.
- **Purchases:** follow Roblox's rules for passes and products, with clear prices.

## Multiplayer and social

### At launch

- Servers of 6 players, one plot each, on a shared street.
- Visit any club: walk in, hear its music, see its guests.
- A board on the street ranks the players in the server by total cash earned. A global leaderboard comes later.

### Later updates

- Friends DJ together at one plot (B2B).
- Like a club; the most-liked clubs get a spotlight on the street.
- Weekly themed nights and genre weeks.

## Technical architecture

Code lives in files synced by Rojo, and the world lives in the Studio place file. Claude Code edits files directly and the place through the Studio MCP.

### Tools

- **Roblox Studio (Windows)** with the built-in MCP server on.
- **Claude Code** in the repo folder.
- **Rokit** to install and pin Rojo, Selene (linter) and StyLua (formatter). Wally only if a package is truly needed; ask Filip first.
- **luau-lsp** in the editor, **Git + GitHub** for history.
- **Language:** Luau with `--!strict` at the top of every module.

### Repo layout

```
dj-game/
  CLAUDE.md                -- short: stack, rules, points to docs/GDD.md
  docs/GDD.md              -- this doc
  docs/decisions.md        -- the calls made without Filip in the autonomous run, to review
  docs/studio-checklist.md -- what to check in Studio
  docs/art-pipeline.md     -- how imported models replace the blockouts
  default.project.json     -- Rojo mapping for the game place
  tagger.project.json      -- the Track Tagger place
  rokit.toml  selene.toml  stylua.toml
  src/
    shared/   -> ReplicatedStorage.Shared
      Config/   Tracks, Locations, Items, StarDjs, Goals, Balance, Blockouts/, Buildings, PlotLayout, Skies, Sounds
      Economy/  Pricing, Income, Crowd, Register, Unlocks, Boost, GoalCheck, Booking (pure, tested)
      Music/    MixPlanner, MixTimeline, TrackInfo, TimingJudge (pure, tested)
      Data/     SaveSchema, SessionLock (pure, tested)
      Types.luau  Remotes.luau  Util/ (PlotSpace, PlotArea, BeatMath, Signal, Rng, Bounds, Format)
    server/   -> ServerScriptService.Server
      Services/ Plots, PlayerData, PlayerState, Economy, Shop, Progression, Travel, Music, Decks,
                Events, StarDjs, Goals, TrackShop, Leaderboard, Settings, DevTools (Studio only)
      World/    Street, StreetProps, StreetBlocks, Skyline, NightLook, WaterLook, Building, PlotView,
                PartFactory, Builder, Figures, Art
    client/   -> StarterPlayer.StarterPlayerScripts.Client
      Controllers/ AudioEngine, BeatClock, PlotMixes, PlotMusic, Decks, Guests, LightShow, LedWall,
                   Effects, StarDjView, Ambience, CrowdAmbience, JetGate, Camera, OwnPlot, Sfx,
                   Preferences, PromptFilter
      UI/ Hud, DecksUI, TrackShop, DjBoard, Dialogue, GoalTracker, Guide, PadLabels, SettingsPanel,
          Fade, Style, DebugOverlay
  tools/
    TrackTagger/           -- dev-only, never shipped
    cloud/                 -- checks without Studio: Lune specs, world build, renderer, simulation
  tests/                   -- *.spec.luau, run on Play in the tagger place
```

From the set prototype, `AudioEngine`, `BeatClock`, `TimingJudge`, `TrackInfo`, the transition rules (into `MixPlanner`) and the crowd figures carry over; the set-only modules (blend zone, track cards, hype challenges, grades, set screen) are removed when the tycoon replaces them.

### Client and server

- **Server:** plots, player data, income and registers, purchases, mix plans, drop validation and boosts, events, star DJs, goals, leaderboard. The server owns every cash value.
- **Client:** audio, beat clock, guests, lights, camera, UI, and judging the drop press. Anything timing-critical stays local.
- Plot state the clients need (location, bought items, guest count, mix plan, active boost) replicates through attributes or a small state remote.
- Never trust client cash values. Type-check and rate-limit every remote.

### Data

- Saving uses a small session-locking layer on DataStoreService instead of a package (Filip, 2026-11-04: no packages): `Data/SessionLock` claims a player's record with `UpdateAsync` when they join, and only the claiming server may write it. It's the same pattern ProfileStore uses.
- **Schema v1 (approved 2026-11-04, in `Data/SaveSchema`):** version, cash, totalEarned, location, boughtItems (ids at the current location), ownedTracks, goalsDone, register, stats (Perfect and Good drops, events done, play time).
- **Schema v2 (written in the autonomous run of 2026-11-04, waiting for Filip's OK, see `docs/decisions.md`):** adds goalProgress (counted goals), djRestUntil (star DJ rests, Unix time) and settings (master, music and SFX volume). Version 1 saves migrate with all three empty. Unlocked DJs follow from the location, so they aren't saved; purchases come with monetization.
- A version field and a migration function from day one.
- DataStores only work in a place published to Roblox with "Enable Studio Access to API Services" turned on (Game Settings → Security). Filip does this once, when saving is built.

### Performance targets

- 60 FPS on a mid-range PC with all 6 plots built; 30+ FPS on a mid-range phone.
- A graphics-quality setting scales guests, particles and beams.
- **Debug overlay** (dev only, toggled): income breakdown, mix plan, phase error, FPS.

### Testing

- Economy, pricing, mix planning and timing logic live in pure Luau modules with spec tests.
- After every feature: playtest through the Studio MCP, read the console output, and fix errors and warnings before moving on.
- Two-player checks use Studio's Test tab → Clients and Servers with 2 players.

## Milestone 1: prototype

Goal: prove the tycoon loop is fun in one room. It's done when a new player builds the whole dorm room without help and wants the next room. The dorm stays the open-front room on its plot for now.

### In scope

- [x] Repo and tooling: Rojo project, Rokit, Selene, StyLua, `CLAUDE.md`, `docs/GDD.md`, git.
- [x] Track Tagger tool, and 7 licensed house/tech house tracks tagged.
- [ ] A night street with 2 plots, plot assignment on join.
- [ ] Buttons, income and the register, data-driven from `Items.luau` and `Balance.luau`.
- [ ] Dorm room blockout (~10 buttons).
- [ ] Each plot's self-mixing music, heard on that plot; lights and guests on the beat.
- [ ] The decks and the drop bonus.
- [ ] Track shop (2 owned at start, the rest buyable).
- [ ] One event (blown speaker), Max's 3 dorm goals.
- [ ] HUD, the decks UI, simple shop and dialogue panels, for mouse, keyboard and touch.
- [ ] After the last button, Max says more is coming; the music, drops and income keep going.
- [ ] Saving (after Filip publishes the place and approves the data package and schema).

**Out of scope:** the house party, club and Ibiza locations, Move on, the growing buildings, interiors and the jet, star DJs, the VIP and photographer events, more characters, rebirth, monetization, global leaderboards, offline earnings.

### Acceptance criteria

- A first-time player knows what to do within 30 seconds, without outside help.
- The dorm takes about 10 minutes with active play (tunable in `Balance.luau`).
- The music never stops, and mixes stay on the beat (phase error under 1/16 beat).
- A Perfect drop fires confetti, a cheer and a light blast on the exact beat, and doubles income.
- Two players in one server see each other's clubs and each hears the music of the plot they stand on.
- Leaving and rejoining restores the club as it was.
- No errors in the output, and 60 FPS on Filip's PC.
- Filip plays through the whole dorm and wants the next room. This is the real test.

### Build order

1. [x] Tooling, track data and the Track Tagger.
2. Street, plots, buttons, income and the register, with the economy modules tested, and the dorm blockout with all its items.
3. Self-mixing music per plot (`MixPlanner` on the server, playback on the client), guests and lights on the beat.
4. The decks and the drop bonus.
5. Track shop, blown speaker event, Max's goals, dialogue.
6. Saving, then a polish pass and a two-player test.

Steps 2–6 are written: step 2 earlier, and steps 3–6 on 2026-11-04 in a cloud session without Studio. Each passes the format, lint and type checks and the pure specs, but steps 3–6 haven't run in Roblox yet. Next is a Studio pass with `docs/studio-checklist.md`; tick the boxes above only after it.

**The autonomous run (2026-11-04).** Filip asked for the whole game to be finished while he slept, without questions. The whole result is on the branch `prototype`, and the dorm-only Milestone 1 version on `prototype-m1`. It goes on to Milestone 2's content, as a prototype that still needs Filip's review: Move on, the house party, the club, Ibiza with the jet, star DJs, the VIP and photographer events, the leaderboard and settings. Every decision that would normally wait for Filip is in `docs/decisions.md`. Model sheets for the art are on the Claude Design canvas (`docs/art-pipeline.md`).

## Roadmap after the prototype

Launch happens only when the core loop is polished and has no known bugs; big content comes after as updates.

1. **Milestone 2 — Full launch content:** the new street (growing buildings, interiors, the jet), Move on, the house party, club and Ibiza locations, all three events, all characters and goals, star DJs, more tracks. (A first version was written ahead in the autonomous run; it needs Filip's review and a Studio pass.)
2. **Milestone 3 — Launch prep:** monetization (decided with Filip), settings, mobile performance pass, leaderboards, analytics events, maturity questionnaire, icon and thumbnails, trailer clips for TikTok. Then launch v1.0.
3. **Updates:** phone orders and truck delivery instead of floor pads (designed 2026-11-05, not built, no implementation plan yet: see `docs/superpowers/specs/2026-11-05-truck-delivery-design.md`), rebirth and the world tour, offline earnings, B2B at one plot, club likes, themed nights, new genres.

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
- [ ] The full location list (Filip wants many more than four).
- [ ] Monetization for the tycoon: which passes and products, and prices.
- [ ] Offline earnings: yes or no, and how much.
- [ ] Rebirth: what it resets, what it keeps, and the world tour.
- [ ] Star DJ names and looks; check none matches a real artist. (Proposed in `Config/StarDjs.luau`: Kiko Wavelength, Tamsin Flux, Ondra Voltz, Mira Sundial.)
- [ ] Ibiza goals and the ending. (Proposed in `Config/Goals.luau`: 5 Perfect drops at sunset, the fireworks, booking Mira Sundial, owning every track.)
- [ ] Genre list beyond house and tech house, after checking the Creator Store.
- [ ] What Roblox allows for sponsor banners.
- [ ] More art references: a colour palette per location.
- [ ] How doors work. Proposed default: an interior is a separate space away from the street, reached with a short fade, so it can be any size. (The autonomous run keeps the house party and the club as open-front rooms on the plot, like the dorm, and builds only Ibiza as a separate space: see `docs/decisions.md`. `Locations.space` switches a location between the two.)
- [ ] What the street sounds like. Proposed default: a quiet, muffled mix from the nearest building, with the full mix only inside. (The prototype does this: `Balance.Music`.)
- [ ] Visiting a friend's Ibiza before unlocking your own. Proposed default: the jet stays locked until you unlock Ibiza yourself. (Built that way.)
- [ ] Building stages for locations beyond the first four.

## Glossary

| Term | Meaning in this game |
| --- | --- |
| Plot | a player's place on the street: one building that grows with the career |
| Location | one stage of the career: dorm room, house party, club, Ibiza |
| Jet | the plane at the end of the street that takes players to big locations |
| Button | a pad on the floor that buys the next part of the club |
| Register | where income piles up until the player collects it |
| Boost | a short income multiplier from a drop or a star DJ |
| Move on | the button that turns a finished location into the next one |
| Star DJ | a fictional famous DJ the player books for a short guest set |
| Beat / bar / phrase | 4 beats = 1 bar; phrases are 8, 16 or 32 bars. Mixes start on these boundaries. |
| BPM | tempo in beats per minute |
| Drop | high-energy payoff section of a track; the moment the player presses |
| Build-up | rising section before a drop |
| Breakdown | quiet section without the kick |
| Blend | the 8 bars where two tracks play together during a mix |
| Bass swap | cutting the bass on one deck while bringing it in on the other |
| Perfect / Good / Miss | the grade for a drop press |
