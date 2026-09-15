#!/usr/bin/env bash
set -euo pipefail

# Companion launcher for a directory containing the extracted handoff.
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
bundle_dir="$script_dir/lambda1vr-sven-linux"
[[ -x "$bundle_dir/connect-vr.sh" ]] || {
	printf 'Extract the Sven Linux handoff beside this launcher first: %s\n' "$script_dir" >&2
	exit 1
}
IFS= read -r server < "$script_dir/server.conf" || true
[[ -n "${server:-}" ]] || {
	printf '%s\n' 'server.conf must contain HOST:PORT' >&2
	exit 1
}
exec "$bundle_dir/connect-vr.sh" --server "$server" "$@"
