#!/usr/bin/env bash
set -euo pipefail

usage() {
	printf '%s\n' \
		"usage: $0 --root DIR --game NAME (--map NAME | --maps-file FILE | --all-maps)" \
		"          [--xash FILE] [--runtime FILE] [--seconds N] [--set NAME=VALUE]" \
		"          [--keep-logs DIR]"
}

root_dir=
game_dir=
single_map=
maps_file=
all_maps=0
xash_path=
runtime_json=${XR_RUNTIME_JSON:-}
seconds=12
keep_logs=
declare -a cvar_settings=()

while (($#)); do
	case "$1" in
		--root|--game|--map|--maps-file|--xash|--runtime|--seconds|--set|--keep-logs)
			(($# >= 2)) || { usage >&2; exit 2; }
			case "$1" in
				--root) root_dir=$2 ;;
				--game) game_dir=$2 ;;
				--map) single_map=$2 ;;
				--maps-file) maps_file=$2 ;;
				--xash) xash_path=$2 ;;
				--runtime) runtime_json=$2 ;;
				--seconds) seconds=$2 ;;
				--set) cvar_settings+=("$2") ;;
				--keep-logs) keep_logs=$2 ;;
			esac
			shift 2
			;;
		--all-maps)
			all_maps=1
			shift
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

[[ -n "$root_dir" && -n "$game_dir" ]] || { usage >&2; exit 2; }
selection_count=$all_maps
[[ -z "$single_map" ]] || ((selection_count += 1))
[[ -z "$maps_file" ]] || ((selection_count += 1))
(( selection_count == 1 )) || {
	printf '%s\n' "select exactly one of --map, --maps-file, or --all-maps" >&2
	exit 2
}
[[ "$seconds" =~ ^[1-9][0-9]*$ ]] || { printf '%s\n' "--seconds must be a positive integer" >&2; exit 2; }
[[ "$game_dir" =~ ^[A-Za-z0-9_.-]+$ ]] || { printf '%s\n' "invalid game directory name" >&2; exit 2; }

for dependency in realpath timeout mktemp sed grep find install tail; do
	command -v "$dependency" >/dev/null || {
		printf 'missing required command: %s\n' "$dependency" >&2
		exit 1
	}
done

root_dir=$(realpath -- "$root_dir")
[[ -d "$root_dir/$game_dir/maps" ]] || {
	printf 'game maps directory not found: %s\n' "$root_dir/$game_dir/maps" >&2
	exit 1
}
if [[ -z "$xash_path" ]]; then
	xash_path="$root_dir/xash3d"
fi
xash_path=$(realpath -- "$xash_path")
[[ -x "$xash_path" ]] || { printf 'Xash executable not found: %s\n' "$xash_path" >&2; exit 1; }
[[ -n "$runtime_json" && -f "$runtime_json" ]] || {
	printf '%s\n' "OpenXR runtime JSON not found; pass --runtime or set XR_RUNTIME_JSON" >&2
	exit 1
}
runtime_json=$(realpath -- "$runtime_json")

declare -a maps=()
if [[ -n "$single_map" ]]; then
	maps+=("$single_map")
elif [[ -n "$maps_file" ]]; then
	while IFS= read -r line || [[ -n "$line" ]]; do
		line=${line%%#*}
		line=${line//[[:space:]]/}
		[[ -z "$line" ]] || maps+=("$line")
	done < "$maps_file"
else
	while IFS= read -r map_path; do
		map_path=${map_path##*/}
		maps+=("${map_path%.bsp}")
	done < <(find "$root_dir/$game_dir/maps" -maxdepth 1 -type f -iname '*.bsp' -print | LC_ALL=C sort)
fi
(( ${#maps[@]} > 0 )) || { printf '%s\n' "no maps selected" >&2; exit 1; }

for map_name in "${maps[@]}"; do
	[[ "$map_name" =~ ^[A-Za-z0-9_.-]+$ ]] || {
		printf 'invalid map name: %s\n' "$map_name" >&2
		exit 2
	}
	[[ -f "$root_dir/$game_dir/maps/$map_name.bsp" ]] || {
		printf 'map not found: %s\n' "$map_name" >&2
		exit 1
	}
done

temp_dir=$(mktemp -d /tmp/lambda1vr-openxr-smoke.XXXXXX)
cleanup() {
	case "$temp_dir" in
		/tmp/lambda1vr-openxr-smoke.*) rm -rf -- "$temp_dir" ;;
	esac
}
trap cleanup EXIT

declare -a extra_args=()
for setting in "${cvar_settings[@]}"; do
	[[ "$setting" == *=* && "${setting%%=*}" =~ ^[A-Za-z0-9_.-]+$ ]] || {
		printf 'invalid --set value: %s\n' "$setting" >&2
		exit 2
	}
	extra_args+=(+set "${setting%%=*}" "${setting#*=}")
done

required_patterns=(
	"OpenXR: initialized"
	"Game started"
	"client connected"
	"OpenXR: first stereo frame submitted"
	"OpenXR: first head-relative UI layer submitted"
)
fatal_pattern='Host_Error|Sys_Error|illegible server message|BAD:|Segmentation fault|Assertion failed|dumped core'
passed=0
failed=0

for map_name in "${maps[@]}"; do
	raw_log="$temp_dir/$map_name.raw.log"
	clean_log="$temp_dir/$map_name.log"
	set +e
	(
		cd "$root_dir"
		timeout --signal=INT --kill-after=3s "${seconds}s" \
			env XR_RUNTIME_JSON="$runtime_json" \
			"$xash_path" -dev 2 -game "$game_dir" +set vr_enable 1 \
			"${extra_args[@]}" +map "$map_name"
	) >"$raw_log" 2>&1
	run_status=$?
	set -e
	sed -r 's/\x1B\[[0-9;]*[mK]//g' "$raw_log" > "$clean_log"

	map_ok=1
	for pattern in "${required_patterns[@]}"; do
		grep -Fq "$pattern" "$clean_log" || map_ok=0
	done
	if grep -Eq "$fatal_pattern" "$clean_log"; then
		map_ok=0
	fi
	if (( run_status != 0 && run_status != 124 )); then
		map_ok=0
	fi

	resource_errors=$(grep -Eic 'precache failed|File not found|Missing WAVE' "$clean_log" || true)
	if (( map_ok )); then
		printf 'PASS %-24s resource_warnings=%d\n' "$map_name" "$resource_errors"
		((passed += 1))
	else
		printf 'FAIL %-24s status=%d resource_warnings=%d\n' "$map_name" "$run_status" "$resource_errors"
		grep -E "$fatal_pattern|OpenXR: initialized|Game started|client connected|first stereo frame|first head-relative UI" "$clean_log" \
			| sed "s|$root_dir|<ROOT>|g" | tail -40 || true
		((failed += 1))
	fi

	if [[ -n "$keep_logs" ]]; then
		mkdir -p -- "$keep_logs"
		install -m 600 "$clean_log" "$keep_logs/$map_name.log"
	fi
done

printf 'summary: passed=%d failed=%d total=%d\n' "$passed" "$failed" "${#maps[@]}"
(( failed == 0 ))
