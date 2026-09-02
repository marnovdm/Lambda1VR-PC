#!/usr/bin/env bash
set -euo pipefail

usage() {
	printf '%s\n' \
		"usage: $0 --root DIR --archive FILE --valve DIR --xash-build DIR" \
		"          --seven-build DIR --seven-content DIR --vgui FILE [--apk FILE]"
}

root_dir=
archive_path=
valve_dir=
xash_build=
seven_build=
seven_content=
vgui_path=
apk_path=

while (($#)); do
	case "$1" in
		--root|--archive|--valve|--xash-build|--seven-build|--seven-content|--vgui|--apk)
			(($# >= 2)) || { usage >&2; exit 2; }
			case "$1" in
				--root) root_dir=$2 ;;
				--archive) archive_path=$2 ;;
				--valve) valve_dir=$2 ;;
				--xash-build) xash_build=$2 ;;
				--seven-build) seven_build=$2 ;;
				--seven-content) seven_content=$2 ;;
				--vgui) vgui_path=$2 ;;
				--apk) apk_path=$2 ;;
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

[[ -n "$root_dir" && -n "$archive_path" && -n "$valve_dir" && -n "$xash_build" \
	&& -n "$seven_build" && -n "$seven_content" && -n "$vgui_path" ]] || { usage >&2; exit 2; }

for dependency in realpath unzip rsync mktemp install ln mv; do
	command -v "$dependency" >/dev/null || {
		printf 'missing required command: %s\n' "$dependency" >&2
		exit 1
	}
done

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
package_dir=$(realpath -- "$script_dir/..")
archive_path=$(realpath -- "$archive_path")
valve_dir=$(realpath -- "$valve_dir")
xash_build=$(realpath -- "$xash_build")
seven_build=$(realpath -- "$seven_build")
seven_content=$(realpath -- "$seven_content")
vgui_path=$(realpath -- "$vgui_path")
root_dir=$(realpath -m -- "$root_dir")

[[ "$root_dir" != / ]] || { printf '%s\n' "refusing to stage at /" >&2; exit 2; }
[[ ! -e "$root_dir" ]] || {
	printf 'staging destination already exists: %s\n' "$root_dir" >&2
	exit 1
}
[[ -f "$archive_path" && -d "$valve_dir" && -d "$seven_content" && -f "$vgui_path" ]] || {
	printf '%s\n' "archive, Valve directory, SevenKewp content, or VGUI library is missing" >&2
	exit 1
}

declare -a required_xash=(
	game_launch/xash3d
	engine/libxash.so
	filesystem/filesystem_stdio.so
	ref/gl/libref_gl.so
	3rdparty/mainui/libmenu.so
	3rdparty/vgui_support/libvgui_support.so
)
for relative_path in "${required_xash[@]}"; do
	[[ -f "$xash_build/$relative_path" ]] || {
		printf 'missing Xash build artifact: %s\n' "$xash_build/$relative_path" >&2
		exit 1
	}
done
[[ -f "$seven_build/dlls/server.so" && -f "$seven_build/cl_dlls/client.so" ]] || {
	printf '%s\n' "SevenKewp build must contain dlls/server.so and cl_dlls/client.so" >&2
	exit 1
}

temp_dir=$(mktemp -d /tmp/lambda1vr-sven-stage.XXXXXX)
stage_dir="$temp_dir/stage"
cleanup() {
	case "$temp_dir" in
		/tmp/lambda1vr-sven-stage.*) rm -rf -- "$temp_dir" ;;
	esac
}
trap cleanup EXIT

unzip -q "$archive_path" 'SvenCoop/*' -x 'SvenCoop/Half-Life_PAK0/*' -d "$temp_dir/extracted"
[[ -d "$temp_dir/extracted/SvenCoop/maps" ]] || {
	printf '%s\n' "archive does not contain SvenCoop/maps" >&2
	exit 1
}

mkdir -p -- "$stage_dir"
mv -- "$temp_dir/extracted/SvenCoop" "$stage_dir/sevenkewp"
ln -s -- "$valve_dir" "$stage_dir/valve"
rsync -a --exclude=/.git --exclude=/.gitignore --exclude=/unused_mod_files/ \
	"$seven_content/" "$stage_dir/sevenkewp/"
install -m 644 "$package_dir/templates/sven3-liblist.gam" "$stage_dir/sevenkewp/liblist.gam"

install -m 755 "$xash_build/game_launch/xash3d" "$stage_dir/xash3d"
install -m 755 "$xash_build/engine/libxash.so" "$stage_dir/libxash.so"
install -m 755 "$xash_build/filesystem/filesystem_stdio.so" "$stage_dir/filesystem_stdio.so"
install -m 755 "$xash_build/ref/gl/libref_gl.so" "$stage_dir/libref_gl.so"
install -m 755 "$xash_build/3rdparty/mainui/libmenu.so" "$stage_dir/libmenu.so"
install -m 755 "$xash_build/3rdparty/vgui_support/libvgui_support.so" "$stage_dir/libvgui_support.so"
install -m 755 "$vgui_path" "$stage_dir/vgui.so"
mkdir -p -- "$stage_dir/sevenkewp/cl_dlls" "$stage_dir/sevenkewp/dlls"
install -m 755 "$xash_build/3rdparty/mainui/libmenu.so" "$stage_dir/sevenkewp/cl_dlls/libmenu.so"
install -m 755 "$seven_build/cl_dlls/client.so" "$stage_dir/sevenkewp/cl_dlls/client.so"
install -m 755 "$seven_build/dlls/server.so" "$stage_dir/sevenkewp/dlls/server.so"

declare -a asset_args=(--root "$stage_dir" --sven sevenkewp)
[[ -z "$apk_path" ]] || asset_args+=(--apk "$apk_path")
"$package_dir/scripts/install-lambda-assets.sh" "${asset_args[@]}"

mkdir -p -- "$(dirname -- "$root_dir")"
mv -- "$stage_dir" "$root_dir"
printf 'staged Sven 3 Linux OpenXR tree: %s\n' "$root_dir"
printf '%s\n' "launch with scripts/run-sven-linux.sh --root '$root_dir'"
