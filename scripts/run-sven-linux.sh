#!/usr/bin/env bash
set -euo pipefail

usage() {
	printf '%s\n' "usage: $0 --root DIR [--runtime FILE] [-- XASH_ARGUMENTS...]"
}

root_dir=
runtime_json=${XR_RUNTIME_JSON:-}
while (($#)); do
	case "$1" in
		--root|--runtime)
			(($# >= 2)) || { usage >&2; exit 2; }
			if [[ "$1" == --root ]]; then root_dir=$2; else runtime_json=$2; fi
			shift 2
			;;
		--)
			shift
			break
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			printf 'unknown argument: %s\n' "$1" >&2
			usage >&2
			exit 2
			;;
	esac
done

[[ -n "$root_dir" ]] || { usage >&2; exit 2; }
root_dir=$(realpath -- "$root_dir")
[[ -x "$root_dir/xash3d" && -d "$root_dir/sevenkewp" ]] || {
	printf 'not a staged Sven tree: %s\n' "$root_dir" >&2
	exit 1
}

declare -a runtime_env=()
if [[ -n "$runtime_json" ]]; then
	runtime_json=$(realpath -- "$runtime_json")
	runtime_env=(env XR_RUNTIME_JSON="$runtime_json")
fi

cd "$root_dir"
exec "${runtime_env[@]}" "$root_dir/xash3d" -bugcomp gsmrf -game sevenkewp \
	+set vr_enable 1 +set sv_precache_bspmodels 0 "$@"
