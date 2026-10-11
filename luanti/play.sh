#!/bin/sh
# Launch Diablocks in Luanti without installing it: ./play.sh  (extra args go to luanti)
D="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$D/world"
[ -f "$D/world/world.mt" ] || printf 'gameid = diablocks\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n' > "$D/world/world.mt"
LUANTI_GAME_PATH="$D/games" exec luanti --go --world "$D/world" --gameid diablocks "$@"
