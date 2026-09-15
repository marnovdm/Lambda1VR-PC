#!/usr/bin/env bash
set -euo pipefail

usage() {
	printf '%s\n' \
		"usage: $0 [--root DIR] [--server HOST:PORT] [--runtime FILE]" \
		"          [--display N] [--ipc-ignore-version] [-- XASH_ARGUMENTS...]"
}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root_dir=
server=
runtime_json=
display_index=
ipc_ignore_version=0

while (($#)); do
	case "$1" in
		--root|--server|--runtime|--display)
			(($# >= 2)) || { usage >&2; exit 2; }
			case "$1" in
				--root) root_dir=$2 ;;
				--server) server=$2 ;;
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

if [[ -z "$root_dir" ]]; then
	root_dir=$script_dir
fi
root_dir=$(realpath -- "$root_dir")

if [[ -z "$server" && -f "$root_dir/server.conf" ]]; then
	IFS= read -r server < "$root_dir/server.conf" || true
fi
[[ "$server" =~ ^[A-Za-z0-9.-]+:[0-9]{1,5}$ ]] || {
	printf '%s\n' "a server in HOST:PORT form is required" >&2
	exit 2
}
port=${server##*:}
(( port >= 1 && port <= 65535 )) || {
	printf 'server port is out of range: %s\n' "$port" >&2
	exit 2
}

run_script="$script_dir/run-sven-linux.sh"
[[ -x "$run_script" ]] || {
	printf 'run-sven-linux.sh is not executable beside this script: %s\n' "$script_dir" >&2
	exit 1
}

declare -a run_args=(--root "$root_dir")
[[ -z "$runtime_json" ]] || run_args+=(--runtime "$runtime_json")
[[ -z "$display_index" ]] || run_args+=(--display "$display_index")
(( !ipc_ignore_version )) || run_args+=(--ipc-ignore-version)

exec "$run_script" "${run_args[@]}" -- +connect "$server" "$@"
