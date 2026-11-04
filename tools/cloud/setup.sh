#!/bin/bash
# Fetches the tools a cloud session (no Studio, no Rokit) needs to check the game: the versions
# rokit.toml pins (Rojo, Selene, StyLua) plus Lune and luau-lsp, into $DJ_TOOLS (default
# ~/.cache/dj-game-tools). Run once per session from the repo root: tools/cloud/setup.sh
set -euo pipefail
TOOLS="${DJ_TOOLS:-$HOME/.cache/dj-game-tools}"
mkdir -p "$TOOLS/bin" "$TOOLS/dl"
fetch() { # name url
	if [ ! -x "$TOOLS/bin/$1" ]; then
		curl -sSfL -o "$TOOLS/dl/$1.zip" "$2"
		unzip -o -q "$TOOLS/dl/$1.zip" -d "$TOOLS/dl/$1"
		find "$TOOLS/dl/$1" -type f -name "$1" -exec cp {} "$TOOLS/bin/$1" \;
		chmod +x "$TOOLS/bin/$1"
	fi
}
fetch stylua https://github.com/JohnnyMorganz/StyLua/releases/download/v2.6.0/stylua-linux-x86_64.zip
fetch selene https://github.com/Kampfkarren/selene/releases/download/0.32.0/selene-0.32.0-linux.zip
fetch rojo https://github.com/rojo-rbx/rojo/releases/download/v7.7.1/rojo-7.7.1-linux-x86_64.zip
fetch lune https://github.com/lune-org/lune/releases/download/v0.10.4/lune-0.10.4-linux-x86_64.zip
fetch luau-lsp https://github.com/JohnnyMorganz/luau-lsp/releases/download/1.70.0/luau-lsp-linux-x86_64.zip
if [ ! -f "$TOOLS/globalTypes.d.luau" ]; then
	curl -sSfL -o "$TOOLS/globalTypes.d.luau" https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
fi
# Selene builds its Roblox standard library from the API dump on Roblox's servers. Where those are
# blocked, use the permissive copy kept here (no class or property checks; luau-lsp does those).
if [ ! -f roblox.yml ]; then
	cp tools/cloud/roblox-offline.yml roblox.yml
fi
echo "Tools ready in $TOOLS/bin"
