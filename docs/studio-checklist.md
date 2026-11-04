# Studio checklist for build steps 3–6

Written on 2026-11-04 by a cloud session with no Roblox Studio. Every file below is formatted
(StyLua), linted (Selene), type-checked against the Roblox API (luau-lsp with the Roblox
definitions) and the pure modules pass their specs (125 tests, run outside Roblox with Lune).
**None of it has run in Roblox yet.** Work through this list from the top, read the Output after
each part, and fix what breaks before Filip's playtest.

## 0. Start

- [ ] `rojo serve`, connect the plugin, Play. Output has no errors or warnings from `Server` or `Client`.
- [ ] Tagger place: Play runs the specs and prints `[Tests] 125 passed, 0 failed`.

## 1. Music that mixes itself (step 3)

- [ ] On spawning, your plot's music starts within about 5 s. The first track starts 8 bars before its drop, so the first drop comes about 15 s in.
- [ ] Press **F2** (Studio only) for the debug overlay. It shows the plan, both decks (ready, playing), each deck's drift and the next drop.
- [ ] Drift settles within ±12 ms a few seconds after each track starts. If every new track starts with a big drift and a seek, `AudioPlayer:Play(atTime)` isn't scheduling as expected (see `AudioEngine.playAt`).
- [ ] During a blend, "Blend phase error (heard)" stays under 0.0625 beats (the GDD limit). Listen too: one kick, never two, the bass swaps halfway, and the incoming drop lands as the blend ends.
- [ ] Walk off your plot: the mix gets quieter and muffled and fades out by about 60 studs. Halfway across the road, the other plot's mix takes over (when that plot has an owner).
- [ ] A deck that stutters at the very end of a track means its audio is shorter than its last tagged section. The plan assumes every track reaches the start of its last section.
- [ ] Test → Clients and Servers with 2 players: both clients hear the same plot in step, and each hears the plot they stand on.

## 2. Lights and guests on the beat (step 3)

- [ ] Buy the LED strip, party lights, disco ball and neon sign. They pulse on the beat, rise through builds, flip colour each bar on drops and flash white on a drop's first beat. The disco ball spins.
- [ ] Guests: none with just the laptop, then more with each purchase up to 5. They walk in from the door, bounce on the beat and put their hands up on drops.
- [ ] Compare the dorm with `docs/concept/dorm.webp`. Tune positions in `Config/Blockouts/Dorm.luau`: the spot fixtures' aim, the decks camera shot (`decks.camera`, `decks.cameraLookAt`), and the guest spots.

## 3. The decks and the drop bonus (step 4)

- [ ] E at the laptop ("Play") opens the decks view: the camera over the desk facing the room, the round main button, the track title and the bar with its drops marked.
- [ ] Space doesn't jump at the decks. Before each drop, the ring closes in with 4-3-2-1.
- [ ] A press on the drop shows PERFECT or GOOD, the HUD shows `x2 BOOST 30s` (or x1.5 for 20 s), and income goes up. With 2 players, the other one also sees the confetti and the light blast.
- [ ] An early or late press shows MISS with no boost, and a second press for the same drop is ignored.
- [ ] E, the Leave button and walking away all leave, and the camera comes back.
- [ ] Touch (Device Emulator): tap the prompt and the main button.
- [ ] If presses feel early or late, calibrate `Balance.Timing.latencyOffset`.

## 4. Track shop, blown speaker, Max (step 5)

- [ ] The Tracks button at the decks opens the shop. Buying a track takes the cash, shows "New track in your mix!", adds +5% income and plays from a later transition.
- [ ] Blown speaker: to test quickly, set `Balance.Events.minSeconds` and `maxSeconds` to about 20 for a moment. Check:
  - smoke, sparks and sputtering rings;
  - quieter music and -25% income;
  - an "!" marker and the HUD banner;
  - holding E for 2 s fixes it and pays a tip;
  - a second player doesn't see the Fix prompt.
- [ ] Max says hello on a first join. The tracker shows his 3 goals, each pays its reward and plays a line, and after the last button he says bigger places are coming. Music, drops and income keep going.

## 5. Saving (step 6)

- [ ] Without API access (an unpublished place, or the setting off), the Output warns once that saving is off, and the game plays normally.
- [ ] After Filip publishes the place and turns on Game Settings → Security → Enable Studio Access to API Services:
  - buy some items, collect, buy a track, finish a goal;
  - Stop, then Play again;
  - the club comes back as it was: items without the pop-in, cash, the register, tracks and goals.
- [ ] Quick rejoin, or two servers: nobody gets the "still being saved" kick in normal play.

## Known gaps (not bugs)

- Every sound effect ID in `Config/Sounds.luau` is 0 (silent) until Filip picks Creator Store sounds.
- Guests are figures built from parts. R15 rigs with dance animations need animation IDs.
- Nothing is tuned by ear or eye yet: the blend gains, the street muffle, light intensities and the guests' moves.
- There's no settings panel (volume sliders) and no graphics-quality scaling yet.
