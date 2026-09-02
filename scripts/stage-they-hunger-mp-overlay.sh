#!/usr/bin/env bash
set -euo pipefail

usage() {
	printf '%s\n' \
		"usage: $0 --source-root STAGED_SVEN_ROOT --destination NEW_ROOT --archive FILE" \
		"          [--game DIR]"
}

source_root=
destination=
archive_path=
game_dir=sevenkewp

while (($#)); do
	case "$1" in
		--source-root|--destination|--archive|--game)
			(($# >= 2)) || { usage >&2; exit 2; }
			case "$1" in
				--source-root) source_root=$2 ;;
				--destination) destination=$2 ;;
				--archive) archive_path=$2 ;;
				--game) game_dir=$2 ;;
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

[[ -n "$source_root" && -n "$destination" && -n "$archive_path" ]] || {
	usage >&2
	exit 2
}
[[ "$game_dir" =~ ^[A-Za-z0-9_.-]+$ ]] || {
	printf 'invalid game directory name: %s\n' "$game_dir" >&2
	exit 2
}

for dependency in realpath unzip rsync mktemp mv find sort diff tr install; do
	command -v "$dependency" >/dev/null || {
		printf 'missing required command: %s\n' "$dependency" >&2
		exit 1
	}
done

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
package_dir=$(realpath -- "$script_dir/..")
source_root=$(realpath -- "$source_root")
destination=$(realpath -m -- "$destination")
archive_path=$(realpath -- "$archive_path")
manifest_path="$package_dir/templates/they-hunger-mp-maps.txt"
archive_root='They Hunger Multiplayer Map Conversion'

[[ -d "$source_root/$game_dir" && -x "$source_root/xash3d" ]] || {
	printf 'source is not a staged Sven/SevenKewp tree: %s\n' "$source_root" >&2
	exit 1
}
[[ -f "$archive_path" && -f "$manifest_path" ]] || {
	printf '%s\n' 'archive or They Hunger map manifest is missing' >&2
	exit 1
}
[[ "$destination" != / && ! -e "$destination" ]] || {
	printf 'overlay destination must be a new path (and not /): %s\n' "$destination" >&2
	exit 1
}
[[ "$destination" != "$source_root" && "$destination" != "$source_root/"* ]] || {
	printf 'overlay destination may not be inside the source tree: %s\n' "$destination" >&2
	exit 1
}

temp_dir=$(mktemp -d /tmp/lambda1vr-they-hunger-overlay.XXXXXX)
stage_dir="$temp_dir/stage"
entries_path="$temp_dir/archive-entries.txt"
cleanup() {
	case "$temp_dir" in
		/tmp/lambda1vr-they-hunger-overlay.*) rm -rf -- "$temp_dir" ;;
	esac
}
trap cleanup EXIT

# Validate names before extraction.  The archive is never changed, and its
# payload must be a single known directory with portable, case-stable paths.
unzip -tq "$archive_path" >/dev/null
unzip -Z1 "$archive_path" > "$entries_path"

lowercase() {
	LC_ALL=C tr '[:upper:]' '[:lower:]' <<<"$1"
}

declare -A source_case_paths=()
while IFS= read -r source_path; do
	[[ -n "$source_path" ]] || continue
	source_folded=$(lowercase "$source_path")
	source_case_paths["$source_folded"]=$source_path
done < <(cd "$source_root/$game_dir" && find . -mindepth 1 -printf '%P\n')

declare -A archive_case_paths=()
declare -a archive_maps=()
while IFS= read -r archive_entry; do
	[[ "$archive_entry" == "$archive_root/" ]] && continue
	[[ -n "$archive_entry" && "$archive_entry" != *$'\r'* && "$archive_entry" != *\\* ]] || {
		printf 'unsafe archive entry: %q\n' "$archive_entry" >&2
		exit 1
	}
	[[ "$archive_entry" == "$archive_root/"* ]] || {
		printf 'unexpected archive layout entry: %q\n' "$archive_entry" >&2
		exit 1
	}
	relative_path=${archive_entry#"$archive_root/"}
	[[ -n "$relative_path" && "$relative_path" != /* && "$relative_path" != */../* \
		&& "$relative_path" != ../* && "$relative_path" != */.. && "$relative_path" != . ]] || {
		printf 'unsafe archive entry: %q\n' "$archive_entry" >&2
		exit 1
	}
	archive_folded=$(lowercase "$relative_path")
	if [[ -v "archive_case_paths[$archive_folded]" ]]; then
		printf 'archive contains duplicate or case-colliding path: %s / %s\n' \
			"${archive_case_paths[$archive_folded]}" "$relative_path" >&2
		exit 1
	fi
	archive_case_paths["$archive_folded"]=$relative_path
	if [[ -v "source_case_paths[$archive_folded]" \
		&& "${source_case_paths[$archive_folded]}" != "$relative_path" ]]; then
		printf 'archive path differs only by case from staged content: %s / %s\n' \
			"${source_case_paths[$archive_folded]}" "$relative_path" >&2
		exit 1
	fi
	if [[ "$relative_path" == maps/*.bsp && "${relative_path#maps/}" != */* ]]; then
		archive_maps+=("${relative_path#maps/}")
	fi
done < "$entries_path"

declare -a manifest_maps=()
while IFS= read -r manifest_map; do
	manifest_map=${manifest_map%%#*}
	manifest_map=${manifest_map//[[:space:]]/}
	[[ -z "$manifest_map" ]] || manifest_maps+=("$manifest_map")
done < "$manifest_path"
(( ${#archive_maps[@]} > 0 && ${#manifest_maps[@]} > 0 )) || {
	printf '%s\n' 'archive or manifest contains no maps' >&2
	exit 1
}
for manifest_map in "${manifest_maps[@]}"; do
	[[ "$manifest_map" =~ ^[A-Za-z0-9_.-]+\.bsp$ ]] || {
		printf 'invalid map manifest entry: %s\n' "$manifest_map" >&2
		exit 1
	}
done
if ! diff -u \
	<(printf '%s\n' "${manifest_maps[@]}" | LC_ALL=C sort -u) \
	<(printf '%s\n' "${archive_maps[@]}" | LC_ALL=C sort -u); then
	printf '%s\n' 'archive map list does not match they-hunger-mp-maps.txt' >&2
	exit 1
fi

mkdir -p -- "$stage_dir"
rsync -a --exclude=/.git --exclude=/.gitignore -- "$source_root/" "$stage_dir/"
unzip -q "$archive_path" "$archive_root/*" -d "$temp_dir/extracted"
payload_dir="$temp_dir/extracted/$archive_root"
[[ -d "$payload_dir/maps" && -f "$payload_dir/maps/thintro.bsp" ]] || {
	printf '%s\n' 'archive payload is missing required They Hunger map layout' >&2
	exit 1
}
if find "$payload_dir" -type l -print -quit | grep -q .; then
	printf '%s\n' 'refusing archive payload containing symbolic links' >&2
	exit 1
fi
rsync -a -- "$payload_dir/" "$stage_dir/$game_dir/"

for manifest_map in "${manifest_maps[@]}"; do
	[[ -f "$stage_dir/$game_dir/maps/$manifest_map" ]] || {
		printf 'staged overlay is missing map: %s\n' "$manifest_map" >&2
		exit 1
	}
done
install -m 644 "$manifest_path" "$stage_dir/$game_dir/they-hunger-mp-maps.txt"

mkdir -p -- "$(dirname -- "$destination")"
[[ ! -e "$destination" ]] || {
	printf 'overlay destination appeared while staging: %s\n' "$destination" >&2
	exit 1
}
mv -- "$stage_dir" "$destination"
printf 'staged They Hunger MP overlay: %s\n' "$destination"
printf '%s\n' "smoke with scripts/smoke-they-hunger-mp-linux.sh --root '$destination' --runtime <openxr-runtime.json>"
