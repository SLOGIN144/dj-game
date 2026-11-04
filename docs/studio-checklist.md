# Studio checklist for the prototype

Written on 2026-11-04 by cloud sessions with no Roblox Studio. It covers build steps 3–6 (the
dorm) and everything the autonomous run added after them: Move on, the house party, the club,
Ibiza and the jet, star DJs, the VIP and photographer events, the leaderboard and settings (see
`docs/decisions.md`).

Every file is formatted (StyLua), linted (Selene) and type-checked against the Roblox API
(luau-lsp with the Roblox definitions). The pure modules pass their specs: 147 tests, run outside
Roblox with Lune. The server's world building ran on Lune's Roblox instances, and renders of
each room were checked against the concept images. **None of it has run in Roblox yet.** Work
through this list from the top, read the Output after each part, and fix what breaks before
Filip's playtest.

**Testing shortcuts (Studio only):** press **F2** for the debug overlay. While it's open:

- **F3** gives ten minutes of the location's full income;
- **F4** buys the rest of the location;
- **F6** starts an event at the next check;
- **F7** rests every star DJ.

## 0. Start

- [ ] `rojo serve`, connect the plugin, Play. The Output has no errors or warnings from `Server` or `Client`, and prints `[DevTools] Studio shortcuts on`.
- [ ] Tagger place: Play runs the specs and prints `[Tests] 147 passed, 0 failed`.
- [ ] Lighting › Technology is **Future** (a script can't set it).
- [ ] Note whether Workspace › StreamingEnabled is on. The code asks the server to stream the destination before every trip (`Travel.place`). If anything at the venue is missing on arrival, say so before trying fixes.

## 1. Music that mixes itself (step 3)

- [ ] On spawning, your plot's music starts within about 5 s. The first track starts 8 bars before its drop, so the first drop comes about 15 s in.
- [ ] The F2 overlay shows the plan, both decks (ready, playing), each deck's drift and the next drop.
- [ ] Drift settles within ±12 ms a few seconds after each track starts. If every new track starts with a big drift and a seek, `AudioPlayer:Play(atTime)` isn't scheduling as expected (see `AudioEngine.playAt`).
- [ ] During a blend, "Blend phase error (heard)" stays under 0.0625 beats (the GDD limit). Listen too: one kick, never two, the bass swaps halfway, and the incoming drop lands as the blend ends.
- [ ] Walk off your plot: the mix gets quieter and muffled and fades out by about 60 studs. Halfway across the road, the other plot's mix takes over (when that plot has an owner).
- [ ] A deck that stutters at the very end of a track means its audio is shorter than its last tagged section.
- [ ] Test → Clients and Servers with 2 players: both clients hear the same plot in step, and each hears the plot they stand on.

## 2. Lights and guests on the beat (step 3)

- [ ] Dorm lights (LED strip, party lights, disco ball, neon sign) pulse on the beat, rise through builds, flip colour each bar on drops and flash white on a drop's first beat. The disco ball spins.
- [ ] Guests: none with just the laptop, then more with each purchase up to 5. They walk in from the door, bounce on the beat and put their hands up on drops. A knock plays when a friend arrives (once `knock` has a sound).
- [ ] Compare each room with its concept image in `docs/concept/`. Tune the spots' aim, the decks camera shot (`decks.camera`, `decks.cameraLookAt`) and the guest spots in `Config/Blockouts/`.

## 3. The decks and the drop bonus (step 4)

- [ ] E at the decks ("Play") opens the decks view: the camera behind the DJ facing the room, the round main button, the track title and the bar with its drops marked.
- [ ] Space doesn't jump at the decks. Before each drop, the ring closes in with 4-3-2-1.
- [ ] A press on the drop shows PERFECT or GOOD and the HUD shows `x2 BOOST 30s` (or x1.5 for 20 s). With 2 players, the other one sees the confetti and the light blast.
- [ ] An early or late press shows MISS, and a second press for the same drop is ignored.
- [ ] E, the Leave button and walking away all leave, and the camera comes back.
- [ ] Touch (Device Emulator): tap the prompt and the main button.
- [ ] If presses feel early or late, calibrate `Balance.Timing.latencyOffset`.

## 4. Track shop, blown speaker, Max (step 5)

- [ ] The Tracks button at the decks opens the shop. Buying a track takes the cash, shows "New track in your mix!" and adds +5% income.
- [ ] Blown speaker (F6 until it comes up): smoke, sparks, sputtering rings, quieter music, -25% income, an "!" marker and the HUD banner. Holding E for 2 s fixes it and pays a tip. A second player doesn't see the Fix prompt.
- [ ] Max says hello on a first join, his 3 goals tick off with a line each, and after the last button he points to Move On.

## 5. Moving on

- [ ] F4 in the dorm: Max's last line plays and a gold **MOVE ON** pad appears in the middle slot, saying "to House Party".
- [ ] Step on it: the screen fades with "Moving on to the House Party...". The room becomes the living room, the building behind it grows, and you're back on the spawn facing the room. Cash, tracks and the register carry over.
- [ ] Lena says hello, the tracker shows her goals, and the free DJ Table pad is there. The UI accent turns warm orange.
- [ ] Repeat for the club: the tower with "BASEMENT" on the roof, blue accents, Rosa.
- [ ] The house party's guests reach 25, the club's 40 (the render budget).
- [ ] Leave and rejoin at each location: the right room, items and building come back.

## 6. The house party and the club

- [ ] Confetti Popper (house): confetti shoots up on every drop, pressed or not.
- [ ] Club: the moving heads sweep their beams through the haze on drops, the CO2 jets blast on every drop, the strobes and the LED floor follow the beat.
- [ ] Four-Deck Setup replaces the Players and Mixer: the old one disappears.
- [ ] Bigger Register: the register fills to twice as much before it stops.
- [ ] The decks shot of each location looks right. Tune `decks.camera` if a wall or speaker blocks it.

## 7. Ibiza and the jet

- [ ] Before Ibiza, the gate at the end of the street shows a red light and its prompt says "Locked". Trying it gets a line from your host.
- [ ] F4 in the club, then Move On: "Flying to Ibiza Beach Club...", and you land on the venue's path facing the entrance arch. The sky turns to a sunset.
- [ ] The venue: the plaza, pools, palms, cabanas, juice bar, the stage by the sea and the LED wall. The register, buttons and spawn are here. The Beach Stage pad is free.
- [ ] Back on the street (the jet at the venue: "Fly to the city"), your plot shows the finished club, and it still lights up to your mix. The gate's light is green: "Fly to Ibiza".
- [ ] Fireworks (Ibiza): rockets go up from the beach on every drop and burst in colour.
- [ ] Rejoin while at Ibiza: you spawn at the venue.
- [ ] With 2 players, the other one can't use your jet prompts.

## 8. Star DJs

- [ ] Buy the DJ Booking Board (house): E on it ("Book a DJ") opens the board, listing Kiko (bookable), Tamsin and Ondra (unlock at the club) and Mira (Ibiza).
- [ ] Book Kiko: the cash goes, the HUD shows `KIKO WAVELENGTH x3 2:59` counting down, Kiko's figure plays at the decks, the crowd grows, and every drop fires the full payoff. Lena's "Book your first star DJ" goal finishes.
- [ ] The decks prompt says "Star DJ playing" and can't be used. Anyone at the decks is moved off.
- [ ] After 3 minutes the set ends with a message. Kiko shows "Resting 15:00" (F7 rests them).
- [ ] Rejoin: the rest timer carries over.

## 9. VIP and photographer

- [ ] Club or Ibiza, F6 until a VIP comes: a figure in gold at the entrance with a VIP marker, the banner with a 60 s countdown, and Rosa's line. E ("Greet") pays a big tip and counts for Rosa's goal. Waiting out the 60 s: "The VIP got tired of waiting".
- [ ] Photographer (house party and later): a figure with a camera in front of the decks, a 30 s countdown. Catching a drop flashes the camera and pays a bonus.

## 10. Leaderboard and settings

- [ ] The billboard at the near end of the street lists the players in the server by total earned, with their location, every 5 s.
- [ ] Settings (top right): the master, music and SFX sliders change the volume at once. Rejoin and they're as you left them.

## 11. Saving

- [ ] Without API access (an unpublished place, or the setting off), the Output warns once that saving is off, and the game plays normally.
- [ ] After Filip publishes the place and turns on Game Settings › Security › Enable Studio Access to API Services, everything comes back after Stop and Play: the location, items, cash, register, tracks, goals with their counts, DJ rests and volume.
- [ ] Quick rejoin, or two servers: nobody gets the "still being saved" kick in normal play.

## 12. Performance

- [ ] F2 shows the FPS. With both plots built to the club, aim for 60 FPS on Filip's PC.
- [ ] Device Emulator (a phone): at most 15 guests in view, still playable.

## Known gaps (not bugs)

- Every sound effect ID in `Config/Sounds.luau` is 0 (silent) until Filip picks Creator Store sounds.
- Guests, star DJs, the VIP and the photographer are figures built from parts. R15 rigs with dance animations need animation IDs.
- Nothing is tuned by ear or eye yet: the blend gains, the street muffle, light levels, the sunset, beams and the guests' moves.
- There's no graphics-quality setting yet.
