#!/bin/bash
# Everything a cloud session can check without Studio, from the repo root: formatting (StyLua),
# lint (Selene), types against the Roblox API (luau-lsp), the specs (in Lune), the world build,
# and the server-and-client simulation. Run tools/cloud/setup.sh first.
# Usage: tools/cloud/check.sh [spec filter]
TOOLS="${DJ_TOOLS:-$HOME/.cache/dj-game-tools}"
BIN="$TOOLS/bin"
OUT="${TMPDIR:-/tmp}/dj-game-check"
mkdir -p "$OUT"
echo "== stylua"; "$BIN/stylua" --check src tools tests && echo ok
echo "== selene"; "$BIN/selene" --display-style quiet src tools tests | tail -40
"$BIN/rojo" sourcemap default.project.json -o "$OUT/sourcemap.json" >/dev/null 2>&1
"$BIN/rojo" sourcemap tagger.project.json -o "$OUT/sourcemap-tagger.json" >/dev/null 2>&1
echo "== types (game)"
"$BIN/luau-lsp" analyze --platform=roblox --definitions=@roblox="$TOOLS/globalTypes.d.luau" \
	--sourcemap="$OUT/sourcemap.json" src 2>&1 | grep -v "INFO\]\|WARN\]"
echo "== types (tests and tools; the Track Tagger's known errors are filtered out)"
"$BIN/luau-lsp" analyze --platform=roblox --definitions=@roblox="$TOOLS/globalTypes.d.luau" \
	--sourcemap="$OUT/sourcemap-tagger.json" tests tools 2>&1 | grep -v "INFO\]\|WARN\]" \
	| grep -v "tools/TrackTagger\|SyntheticTrack\|TrackExport.spec\|RunTests.server\|tools/cloud" \
	| grep -v "^caused by\|^  \|^Expected\|^Not all"
echo "== specs"
"$BIN/lune" run tools/cloud/runspecs.luau "$PWD" "$OUT/sourcemap-tagger.json" $1
echo "== world (every location)"
for location in dorm house club ibiza; do
	"$BIN/lune" run tools/cloud/buildworld.luau "$PWD" "$OUT/sourcemap.json" "$OUT/world.json" $location | tail -1
done
"$BIN/lune" run tools/cloud/buildworld.luau "$PWD" "$OUT/sourcemap.json" "$OUT/world.json" dorm check | tail -3
echo "== simulation (server and client)"
"$BIN/lune" run tools/cloud/simulate.luau "$PWD" "$OUT/sourcemap.json" | grep "FAIL\|ERROR\|checks passed\|failed:\|error:"
