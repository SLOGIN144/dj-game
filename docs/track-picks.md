# Milestone 1 track picks

The 7 tracks Filip picked on 2026-11-03 for the prototype, slowest first (also a natural warm-up-to-peak set order).
The same list, as data, is `tools/TrackTagger/Picks.luau`. "Auto-tag picks" in the Track Tagger analyses all of them and prints their `Tracks.luau` entries.

All 7 are free on the Creator Store. None of the store pages lists a credit requirement; APM's own track descriptions end with "Courtesy of APM Music", so the in-game credits should say that for the APM tracks.

| Tagged | Asset ID | Title | Artist | Uploader | id | genre | Length | BPM | First downbeat from |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [x] | 1836798379 | Until Sunrise | Andy Danza | APM | `until_sunrise` | house | 2:56 | 122 | first kick |
| [x] | 1836800628 | London Loves | George Gwinnell | APM | `london_loves` | house | 4:13 | 123 | first kick |
| [x] | 99266731124568 | Chili Mexican | Feelyno Dj | DistroKid | `chili_mexican` | tech house | 3:34 | 124 | both clues agree |
| [x] | 128840312200418 | The Sound of Endless Summer | Love Sleep Repeat | DistroKid | `endless_summer` | house | 4:03 | 125 | both clues agree |
| [x] | 93443738890753 | The Angelic Choir | Dixon Live | DistroKid | `angelic_choir` | tech house | 3:58 | 125 | both clues agree |
| [x] | 86067233920375 | Neon Ruins | George Kraniotakis | DistroKid | `neon_ruins` | tech house | 4:00 | 128 | both clues agree |
| [x] | 82604702163302 | Heatwave Circuit | George Kraniotakis | DistroKid | `heatwave_circuit` | tech house | 4:00 | 129 | both clues agree |

Notes:

- All 7 were **auto-tagged** from their audio on 2026-11-03. Grid drift over each whole track is 0–12 ms (a 1/16 beat is about 30 ms), so sync stays tight.
- **First downbeat:** the tagger uses two clues, where sections change and where the kick first comes in. For Until Sunrise and London Loves they disagreed and the section changes were unclear, so the first kick decided. Those two are the ones worth a listen if a drop ever feels a beat off.
- **Sections** are a guess from kick and loudness, per 4-bar block. Good enough to drive crowd energy; fix by ear in the tagger if one is clearly wrong.
- **Titles** drop the "(Deep House)" / "(Tech House)" tags and the "Industrial ... :" prefixes from the store names, so they read well in game. **Genre** uses the GDD's launch genres (deep house counts as house).
- **Energy** (1–5) is a first guess from tempo. Tier and price stay at 1 and 250 until the shop is designed in Milestone 2.
- Store pages: `https://create.roblox.com/store/asset/<Asset ID>`.
