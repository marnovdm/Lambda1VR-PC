#!/usr/bin/env bash
set -euo pipefail

usage() {
	printf '%s\n' \
		"usage: $0 --root OVERLAY_ROOT --runtime FILE [--representative | --all-maps]" \
		"          [--xash FILE] [--seconds N] [--keep-logs DIR] [--bugcomp FLAGS]" \
		"          [--display N] [--ipc-ignore-version] [--set NAME=VALUE]"
}

root_dir=
runtime_json=
mode=representative
mode_set=0
xash_path=
seconds=
keep_logs=
bugcomp_flags=gsmrf
display_index=
ipc_ignore_version=0
declare -a cvar_settings=()

while (($#)); do
	case "$1" in
		--root|--runtime|--xash|--seconds|--keep-logs|--bugcomp|--display|--set)
			(($# >= 2)) || { usage >&2; exit 2; }
			case "$1" in
				--root) root_dir=$2 ;;
				--runtime) runtime_json=$2 ;;
				--xash) xash_path=$2 ;;
				--seconds) seconds=$2 ;;
				--keep-logs) keep_logs=$2 ;;
				--bugcomp) bugcomp_flags=$2 ;;
				--display) display_index=$2 ;;
				--set) cvar_settings+=("$2") ;;
			esac
			shift 2
			;;
		--representative|--all-maps)
			requested_mode=${1#--}
			(( mode_set == 0 )) || {
				printf '%s\n' 'select only one of --representative or --all-maps' >&2
				exit 2
			}
			mode=$requested_mode
			mode_set=1
			shift
			;;
		--ipc-ignore-version)
			ipc_ignore_version=1
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

[[ -n "$root_dir" && -n "$runtime_json" ]] || { usage >&2; exit 2; }
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
package_dir=$(realpath -- "$script_dir/..")
if [[ "$mode" == all-maps ]]; then
	maps_file="$package_dir/templates/they-hunger-mp-maps.txt"
else
	maps_file="$package_dir/templates/they-hunger-mp-representative-maps.txt"
fi

declare -a smoke_args=(--root "$root_dir" --game sevenkewp --maps-file "$maps_file" \
	--runtime "$runtime_json" --bugcomp "$bugcomp_flags" --set sv_precache_bspmodels=0)
[[ -z "$xash_path" ]] || smoke_args+=(--xash "$xash_path")
[[ -z "$seconds" ]] || smoke_args+=(--seconds "$seconds")
[[ -z "$keep_logs" ]] || smoke_args+=(--keep-logs "$keep_logs")
[[ -z "$display_index" ]] || smoke_args+=(--display "$display_index")
(( ipc_ignore_version == 0 )) || smoke_args+=(--ipc-ignore-version)
for setting in "${cvar_settings[@]}"; do
	smoke_args+=(--set "$setting")
done
exec "$package_dir/scripts/linux-openxr-smoke.sh" "${smoke_args[@]}"
