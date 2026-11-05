# Decisions log: the autonomous run of 2026-11-04

Filip went to sleep and asked for the whole game to be finished without questions ("finish the
game to the end ... don't ask me anything"). Some of the working rules say to ask him first, so
every decision that would normally wait for his OK is listed here: what was decided, why, and how
to change it. Nothing here touches monetization. **Each point still needs his OK.**

As Filip asked, the whole game from this run is on the branch `prototype` (it was built on
`claude/step2-plots-shop-hud`, which holds the same). The version from before the run
(Milestone 1, the dorm only) is kept on the branch `prototype-m1`. Nothing was merged into `main`.
None of it has run in Roblox yet: the cloud session had no Studio. Every module passes StyLua,
Selene, a type check against the Roblox API and the Lune specs, and a simulation ran the real
server and client together through a whole session. `docs/studio-checklist.md` is the list to
work through in Studio. `docs/renders/blockouts.png` shows every location as the code builds it
(an offline render, not Roblox's lighting).

## Needs Filip's OK first (working rule 9)

| # | Decision | Why | How to change it |
| --- | --- | --- | --- |
| 1 | **Save schema version 2** adds `goalProgress` (counted goals like "3 Perfect drops"), `djRestUntil` (star DJ rest times) and `settings` (master, music and SFX volume, low graphics). Version 1 saves load with all three empty. | Without them a rejoin would forget goal counts and DJ rests, and settings wouldn't follow the player. Nothing is published yet, so no real save exists to break. | `Data/SaveSchema.luau` (`VERSION`, `default`, `sanitize`, `migrate`). Dropping v2 means removing the three fields and the step. |
| 2 | **Building past Milestone 1**: the house party, club and Ibiza, Move on, the jet, star DJs, the VIP and photographer, the leaderboard and settings. | Filip asked for the whole game. The GDD says to build only the current milestone, so the dorm-only version stays on `prototype-m1`. | Use the `prototype-m1` branch for the M1 playtest. |

## Design calls the GDD left open

| # | Decision | Why | Where |
| --- | --- | --- | --- |
| 3 | **The house party and the club are open-front rooms on the plot**, like the dorm. Moving on replaces the room; the building behind it grows. They aren't separate spaces behind a door. | Players walking past see each club and hear it, the street stays lively, and it reuses everything the dorm already does. The open question "How doors work" proposed separate spaces; that's still possible. | `Config/Locations.luau` (`space = "plot"`). `"venue"` puts a location away from the street. |
| 4 | **Ibiza is a venue of its own per plot**, far from the street (from x = 3000, 900 studs apart). The register, buttons and spawn move there. While the owner is away, the street plot keeps the finished club up as a showcase that still lights up to the mix. | Each player needs their own Ibiza at full size. The street mustn't go dark. | `Shared/Util/PlotSpace.luau`, `World/PlotView.setLocation`, `Config/PlotLayout.venues` |
| 5 | **The jet**: a prompt at the airstrip gate at the end of the street. It's locked (the host says why) until the player reaches Ibiza, then it flies them there. A second jet at the venue flies them back. No visiting other players' venues yet (the open question's proposed default). | It keeps the jet in sight as the big goal from the start. | `Services/Travel.luau`, `Controllers/JetGate.luau` |
| 6 | **Move on**: once every button is bought, a gold Move On pad takes the middle slot. Moving on keeps cash, the register, tracks, finished goals and DJ rests, and resets the bought items and goal counts. The screen fades while the room changes. | The GDD's "Move on" rule, with a fade so the rebuild isn't seen. | `Services/Progression.luau`, `Services/Shop.luau` |
| 7 | **Pacing**: house 40 min, club 150 min, Ibiza 330 min of active play; incomes grow ×15, ×20, ×25. That's about 8.8 hours from the dorm to a finished Ibiza (GDD: about 10). Each location's free first item earns what the last one ended on. | The GDD's target times per location. | `Config/Balance.luau` → `Pricing.locations` |
| 8 | **Item lists**: 15 items for the house party, 20 for the club, 25 for Ibiza, taken from the model sheets on the design canvas. | GDD: about 15, 20 and 25 buttons. | `Config/Items.luau` |
| 9 | **Solenne's Ibiza goals** (the GDD said TBD): 5 Perfect drops at sunset, buy the fireworks, book Mira Sundial, own every track. Lena's and Rosa's are the GDD's examples. Rewards are 1–2 minutes of the location's income. | A short, fitting end to the career. | `Config/Goals.luau` |
| 10 | **Star DJs**: Kiko Wavelength (house party, ×3, $15K), Tamsin Flux (club, ×3.5, $200K), Ondra Voltz (club, ×4, $450K) and Mira Sundial (Ibiza, ×5, $8M). A set lasts 3 minutes, then the DJ rests for 15. **Check that no name matches a real artist before launch** (open question). | Names and looks are made up; a set pays back two to four times its price at the income a player has when they buy the board. | `Config/StarDjs.luau`, `Balance.StarDjs` |
| 11 | **A star DJ's set counts like a boost**: the stronger one applies and they never stack. The star catches every drop, so everyone sees the payoff, but the owner gets no extra drop boost and can't use the decks. The crowd is 25% bigger. | The GDD's "×3 income" and "a new boost replaces a weaker one". | `Services/PlayerState.updateIncome`, `Services/StarDjs.luau` |
| 12 | **Events per location**: the dorm has only the blown speaker; the house party adds the photographer; the club and Ibiza have all three. VIP: wait 60 s, tip 2 min of income. Photographer: wait 30 s, a caught drop pays 3 min. | The GDD's table; the dorm stays the simple tutorial. | `Config/Locations.luau` (`events`), `Balance.Events` |
| 13 | **Leaderboard**: this server only, on the billboard at the near end of the street, by total cash earned. | The GDD at launch; a global board comes later. | `Services/Leaderboard.luau` |
| 14 | **Settings**: master, music and SFX volume sliders and a High/Low graphics switch behind a Settings button at the top left (the top right is where Roblox shows its player list), all saved. Low graphics draws at most 15 guests (as on touch devices), turns the light beams off and thins the particles. | GDD: settings, and "a graphics-quality setting scales guests, particles and beams". | `UI/SettingsPanel.luau`, `Controllers/Preferences.luau`, `Balance.Guests` |
| 15 | **Ibiza's sunset**: the client blends the sky to a sunset (`Config/Skies.luau`) while the camera is at a venue. The time of day jumps, hidden by the travel fade. | The concept art's sunset. Lighting set on a client only affects that client. | `Controllers/Ambience.luau` |
| 16 | **Drop payoffs from bought features**: the confetti popper, CO2 jets and fireworks fire on every drop of the mix, pressed or not. A Perfect press also gives confetti over the dance floor. | GDD: "confetti and CO2 are payoffs on drops, never constant decoration". | `Controllers/Effects.luau`, `PartSpec.fx` |
| 17 | **Moving heads sweep their beams** on the beat. Beams are `Beam` instances made from `PartSpec.beam`. | GDD: "beams cutting through haze from a rig above the booth". | `World/PartFactory.luau`, `Controllers/LightShow.luau` |
| 18 | **Content rules**: every bar serves soda, juice or water only. The concept art's bottles and red cups became soda cans and juice. There are no brands, no logos and no real DJs. | Content and platform rules. | the blockouts in `Config/Blockouts/` |
| 19 | **New sound slots** (`moveOn`, `jet`, `vip`, `camera`, `notice`, `starDj`, `co2`, `firework`, `click`, `crowd`) are all 0, so they're silent until Filip picks Creator Store sounds. | Never invent asset IDs. | `Config/Sounds.luau` |
| 20 | **Studio-only testing shortcuts**: with the F2 overlay open, F3 gives cash, F4 finishes the location, F6 starts an event and F7 rests the DJs. The server only listens in Studio. | Testing four locations by playing through them would take about 9 hours. | `Services/DevTools.luau`, `UI/DebugOverlay.luau` |
| 21 | **Cloud checks in the repo** (`tools/cloud/`): the Lune spec runner, the world build, a renderer, and a simulation that runs the real server and client together through a whole session. They're dev tools, not packages, and nothing in them ships. | They found a real start-up bug (the client waiting for remotes the server made late) that no type check could. Future sessions without Studio can run them. | `tools/cloud/README.md` |

## Polish added on top (tune freely)

These need no OK, but they're Filip's to like or change:

| What | Where to tune |
| --- | --- |
| A gold guide arrow over the next thing to do (the free button, the register, the decks, Move On) | `UI/Guide.luau` |
| The camera takes a short look at each new part when you buy standing still | `Controllers/Camera.luau` (`PEEK_*`) |
| Each room has its own light while you're inside: purple dorm, warm house party, deep blue club with thicker haze | `Config/Skies.luau` |
| Ibiza's sea is terrain water right behind the stage; the LED wall shows level bars to the music | `World/WaterLook.luau`, `Controllers/LedWall.luau` |
| The street's empty lots have apartment blocks with shopfronts (VINYL, NOODLES, ARCADE, LAUNDRY); lamps glow warm orange | `World/StreetBlocks.luau`, `World/Street.luau` |
| Guests have hair; they dance bigger during a star DJ's set | `Controllers/Guests.luau` |
| A crowd sound that follows the guest count (silent until it has an ID) | `Controllers/CrowdAmbience.luau`, `Config/Sounds.luau` |
| The club's bar shelves hold soda cans | `Config/Blockouts/Club.luau` |
| Total cash earned also shows in Roblox's player list | `Services/Leaderboard.luau` |
| The star DJs wear their signature hats from the model sheet (Kiko's bucket hat, Ondra's visor, Mira's sun hat) | `Config/StarDjs.luau`, `Controllers/StarDjView.luau` |
| The club is laid out like its concept: the soda bar along the left wall from the stairs, the lounge and VIP booth on the right | `Config/Blockouts/Club.luau` |

## Not done (later, or needs Filip)

- Rebirth and the world tour, offline earnings, a global leaderboard, B2B, club likes.
- Monetization: untouched, as the rules say.
- Real art: everything is a code blockout. `docs/art-pipeline.md` explains how imported models replace it, and the design canvas has a sheet for every model.
- Guests and characters with R15 rigs and dance animations need animation IDs.
- Sound effect IDs and a latency calibration screen.
- Tuning by eye and ear in Studio: light levels, the sunset, beams, guest moves and the decks camera shots of the new locations.
