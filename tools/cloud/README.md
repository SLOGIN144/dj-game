# Checking the game without Studio

Cloud sessions can't run Roblox Studio, so they check the game with these tools. They're dev
tools only: nothing here ships with the game, and none of it is a package.

```bash
tools/cloud/setup.sh
```

```bash
tools/cloud/check.sh
```

`setup.sh` downloads the pinned tools into `~/.cache/dj-game-tools` (or `$DJ_TOOLS`): StyLua,
Selene and Rojo at the versions `rokit.toml` pins, plus Lune 0.10.4 and luau-lsp 1.70.0.
`check.sh` then runs every check:

| Step | What it does |
| --- | --- |
| stylua, selene | Formatting and lint, as before every commit. Where Roblox's API dump can't be downloaded, Selene uses `roblox-offline.yml`: permissive, with no class or property checks. |
| types | luau-lsp type-checks the code against the Roblox API definitions, so a wrong class, property or enum name fails here. |
| specs | `runspecs.luau` runs `tests/*.spec.luau` in Lune, on a stand-in for the script tree built from the Rojo sourcemap. |
| world | `buildworld.luau` builds the street and each location with the real server code on Lune's Roblox instances. That checks property names and types, and the `check` pass walks a plot through every location and back. |
| simulation | `simulate.luau` runs the real server (`Main.server.luau`) and the real client (`Main.client.luau`) together in one process, with stand-ins for what Lune lacks (engine events, remotes, a fake clock and scheduler, an in-memory DataStore). It then plays a whole session: join, collect, a drop press, buying every item, every event, moving on through all four locations, a star DJ set, the jets, a second player, settings, leaving and rejoining. Every error a handler raises fails the run. |

To look at a location, render it from the world dump (needs Python with numpy and Pillow):

```bash
lune run tools/cloud/buildworld.luau "$PWD" sourcemap.json world.json club
```

```bash
python3 tools/cloud/render.py world.json renders club_ "room,cam=decks:0/11/29.6:0/3/2:70"
```

A `cam=` shot is `name:eye:target[:fov[:radius]]`, in studs relative to the location's origin.

## What this can't check

These only show in Studio, with `docs/studio-checklist.md`:

- sound and timing by ear: the Audio API is stubbed here;
- lighting, rendering and performance;
- the physics of touching pads and walking;
- the real network: replication order and latency;
- DataStores.
