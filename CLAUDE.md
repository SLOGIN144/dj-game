# DJ Club Tycoon

Roblox DJ club tycoon: build your club button by button, from a dorm room to an Ibiza beach club, with real music mixed on the beat.
**The full design and build spec is [docs/GDD.md](docs/GDD.md). Read it at the start of every session.**

## Current focus

Milestone 1 (tycoon prototype): the dorm. Step 1 (tooling, track data, Track Tagger) is done and the 7 tracks are tagged. Steps 2–6 are written, but steps 3–6 haven't run in Roblox yet.
On 2026-11-04 Filip asked for the whole game to be finished while he slept. That autonomous run went on to Milestone 2's content as a prototype: Move on, the house party, the club, Ibiza and the jet, star DJs, the VIP and photographer events, the leaderboard and settings. That whole version is on the branch `prototype`; the dorm-only version is on `prototype-m1`. Every decision Filip still has to OK, including save schema v2, is in `docs/decisions.md`.
Next: run `docs/studio-checklist.md` in Studio and fix what breaks, then Filip reviews `docs/decisions.md` and playtests. The old timing-set prototype is under the git tag `set-prototype`.
Art references live in `docs/concept/`. The model sheets for every model are on the Claude Design canvas, and `docs/art-pipeline.md` explains how imported models replace the blockouts.

## Stack

- Roblox Studio on Windows, with its built-in MCP server (Claude reads and playtests the place through it)
- Luau, `--!strict` at the top of every module
- Rojo syncs code from `src/` into Studio; the world (parts, lighting) lives in the place file
- Rokit pins the tools in `rokit.toml`: Rojo, Selene (linter), StyLua (formatter)
- New Audio API (`AudioPlayer`, `Wire`, `AudioDeviceOutput`, ...), not legacy `Sound`

## Layout and commands

| What | Where |
| --- | --- |
| Shared code and config | `src/shared` -> ReplicatedStorage.Shared |
| Server | `src/server` -> ServerScriptService.Server |
| Client | `src/client` -> StarterPlayerScripts.Client |
| Track Tagger (dev only) | `tools/TrackTagger`, in its own place via `tagger.project.json`. Analyses audio by itself (beat grid, sections, cue, energy); keys only fix results. New tracks go in `Picks.luau`, then "Auto-tag picks". |
| Tests | `tests/*.spec.luau`, run on Play in the tagger place |
| Checks without Studio | `tools/cloud/`: `setup.sh` fetches the tools, `check.sh` runs format, lint, types, specs, the world build and a server-and-client simulation in Lune (see its README) |

- Game: `rojo serve` (port 34872), connect from the Rojo plugin in the game place.
- Tagger: `rojo build tagger.project.json -o TrackTagger.rbxl` once, open it, then `rojo serve tagger.project.json` (port 34873).
- Check before committing: `selene src tools tests` and `stylua --check src tools tests`.
- Rokit tools live in `%USERPROFILE%\.rokit\bin`.

## Working rules for Claude Code

1. Read this file and `docs/GDD.md` at the start of every session. Work on the current milestone only.
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

Content and platform rules (GDD section of that name) override everything: no alcohol, no real brands or DJs, licensed music only.
