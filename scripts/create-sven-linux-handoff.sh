#!/usr/bin/env bash
set -euo pipefail

usage() {
	printf '%s\n' \
		"usage: $0 --root STAGED_DIR --valve DIR --server HOST:PORT --output FILE.tar.zst"
}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root_dir=
valve_dir=
server=
output_path=

while (($#)); do
	case "$1" in
		--root|--valve|--server|--output)
			(($# >= 2)) || { usage >&2; exit 2; }
			case "$1" in
				--root) root_dir=$2 ;;
				--valve) valve_dir=$2 ;;
				--server) server=$2 ;;
				--output) output_path=$2 ;;
			esac
			shift 2
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

[[ -n "$root_dir" && -n "$valve_dir" && -n "$server" && -n "$output_path" ]] || {
	usage >&2
	exit 2
}
[[ "$server" =~ ^[A-Za-z0-9.-]+:[0-9]{1,5}$ ]] || {
	printf '%s\n' "--server must use HOST:PORT form" >&2
	exit 2
}
port=${server##*:}
(( port >= 1 && port <= 65535 )) || { printf '%s\n' "server port is out of range" >&2; exit 2; }

for dependency in realpath mktemp rsync install tar zstd sha256sum find; do
	command -v "$dependency" >/dev/null || {
		printf 'missing required command: %s\n' "$dependency" >&2
		exit 1
	}
done

root_dir=$(realpath -- "$root_dir")
valve_dir=$(realpath -- "$valve_dir")
output_path=$(realpath -m -- "$output_path")
checksum_path="$output_path.sha256"

[[ -x "$root_dir/xash3d" && -f "$root_dir/libxash.so" \
	&& -f "$root_dir/libref_gl.so" && -f "$root_dir/filesystem_stdio.so" \
	&& -f "$root_dir/sevenkewp/cl_dlls/client.so" \
	&& -f "$root_dir/sevenkewp/dlls/server.so" ]] || {
	printf 'not a complete staged Sven VR tree: %s\n' "$root_dir" >&2
	exit 1
}
[[ -f "$valve_dir/liblist.gam" && -f "$valve_dir/maps/c0a0.bsp" ]] || {
	printf 'Valve directory is missing Half-Life campaign data: %s\n' "$valve_dir" >&2
	exit 1
}
[[ ! -e "$output_path" && ! -e "$checksum_path" ]] || {
	printf 'output already exists: %s\n' "$output_path" >&2
	exit 1
}
[[ -d "$(dirname -- "$output_path")" ]] || {
	printf 'output directory does not exist: %s\n' "$(dirname -- "$output_path")" >&2
	exit 1
}

temp_parent=$(realpath -- "${TMPDIR:-/tmp}")
[[ -d "$temp_parent" ]] || { printf 'temporary directory not found: %s\n' "$temp_parent" >&2; exit 1; }
temp_dir=$(mktemp -d "$temp_parent/lambda1vr-sven-handoff.XXXXXX")
bundle_dir="$temp_dir/lambda1vr-sven-linux"
cleanup() {
	case "$temp_dir" in
		"$temp_parent"/lambda1vr-sven-handoff.*) find -P "$temp_dir" -xdev -depth -delete ;;
	esac
}
trap cleanup EXIT

mkdir -p -- "$bundle_dir/valve"
rsync -a --exclude=/valve --exclude=buffer.dat --exclude='*.log' "$root_dir/" "$bundle_dir/"
rsync -a "$valve_dir/" "$bundle_dir/valve/"
install -m 755 "$script_dir/run-sven-linux.sh" "$bundle_dir/run-sven-linux.sh"
install -m 755 "$script_dir/connect-sven-linux.sh" "$bundle_dir/connect-vr.sh"
install -m 644 "$script_dir/../templates/sven-linux-handoff-readme.md" "$bundle_dir/README.md"
install -m 644 "$script_dir/../SOURCES.md" "$bundle_dir/SOURCES.md"
printf '%s\n' "$server" > "$bundle_dir/server.conf"
(
	cd "$bundle_dir"
	for artifact in xash3d libxash.so libref_gl.so filesystem_stdio.so libmenu.so \
		libvgui_support.so vgui.so libopenxr_loader.so.1 \
		sevenkewp/cl_dlls/client.so sevenkewp/dlls/server.so; do
		[[ ! -f "$artifact" ]] || sha256sum "$artifact"
	done
) > "$bundle_dir/BINARY-SHA256SUMS"

tar --sort=name --owner=0 --group=0 --numeric-owner --mode='u+rwX,go+rX,go-w' -C "$temp_dir" -cf - lambda1vr-sven-linux \
	| zstd -T0 -10 -q -o "$output_path"
(
	cd "$(dirname -- "$output_path")"
	sha256sum "$(basename -- "$output_path")" > "$(basename -- "$checksum_path")"
)

printf 'created portable Sven VR handoff: %s\n' "$output_path"
printf 'checksum: %s\n' "$checksum_path"
