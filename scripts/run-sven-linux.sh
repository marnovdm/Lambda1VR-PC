#!/usr/bin/env bash
set -euo pipefail

usage() {
	printf '%s\n' \
		"usage: $0 --root DIR [--runtime FILE] [--display N] [--ipc-ignore-version]" \
		"          [-- XASH_ARGUMENTS...]"
}

root_dir=
runtime_json=${XR_RUNTIME_JSON:-}
display_index=
ipc_ignore_version=0
while (($#)); do
	case "$1" in
		--root|--runtime|--display)
			(($# >= 2)) || { usage >&2; exit 2; }
			case "$1" in
				--root) root_dir=$2 ;;
				--runtime) runtime_json=$2 ;;
				--display) display_index=$2 ;;
			esac
			shift 2
			;;
		--ipc-ignore-version)
			ipc_ignore_version=1
			shift
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
[[ -z "$display_index" || "$display_index" =~ ^[0-9]+$ ]] || {
	printf '%s\n' "--display must be a non-negative SDL display index" >&2
	exit 2
}
root_dir=$(realpath -- "$root_dir")
[[ -x "$root_dir/xash3d" && -d "$root_dir/sevenkewp" ]] || {
	printf 'not a staged Sven tree: %s\n' "$root_dir" >&2
	exit 1
}

declare -a runtime_env=(env)
if [[ -n "$runtime_json" ]]; then
	runtime_json=$(realpath -- "$runtime_json")
	runtime_env+=(XR_RUNTIME_JSON="$runtime_json")
fi
if (( ipc_ignore_version )); then
	runtime_env+=(IPC_IGNORE_VERSION=1)
fi

declare -a display_args=()
[[ -z "$display_index" ]] || display_args=(-display "$display_index")

cd "$root_dir"
exec "${runtime_env[@]}" "$root_dir/xash3d" -bugcomp gsmrf -game sevenkewp \
	"${display_args[@]}" +set vr_enable 1 +set sv_precache_bspmodels 0 "$@"
