#!/usr/bin/env bash
set -euo pipefail

[[ $# == 1 ]] || { printf 'usage: %s STAGED_SERVER_ROOT\n' "$0" >&2; exit 2; }
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root_dir=$(realpath -- "$1")
game_dir="$root_dir/sevenkewp"
[[ -d "$game_dir/maps" && -d "$root_dir/valve" ]] || {
	printf '%s\n' 'Expected a staged Sven/SevenKewp server with Valve data.' >&2
	exit 1
}

install -m 644 "$script_dir/server.cfg" "$game_dir/server.cfg"
install -m 644 "$script_dir/mapcycle.txt" "$game_dir/mapcycle.txt"

# Sven's supplied map CFGs override server.cfg. Disable their timed rotation
# so campaign progression is driven by the maps' existing changelevel triggers.
while IFS= read -r map; do
	[[ "$map" =~ ^[a-z0-9_]+$ ]] || exit 2
	if [[ -f "$game_dir/maps/$map.cfg" ]]; then
		sed -i -E 's/^([[:space:]]*mp_timelimit[[:space:]]+)[^[:space:]]+/\10/' "$game_dir/maps/$map.cfg"
	fi
done < <(awk '!/^\/\// { for (i=1; i<=NF; ++i) print $i }' "$script_dir/mapcycle.txt")
