#!/usr/bin/env bash
set -euo pipefail

package_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
archive_path=${TH_MP_ARCHIVE:-'/home/obesecatlord/Backup/Downloads/They Hunger Multiplayer Map Conversion.zip'}

if [[ ! -f "$archive_path" ]]; then
	printf 'SKIP: set TH_MP_ARCHIVE to the authorized They Hunger MP archive\n'
	exit 0
fi

temp_dir=$(mktemp -d /tmp/lambda1vr-they-hunger-overlay-test.XXXXXX)
cleanup() {
	case "$temp_dir" in
		/tmp/lambda1vr-they-hunger-overlay-test.*) rm -rf -- "$temp_dir" ;;
	esac
}
trap cleanup EXIT

source_root="$temp_dir/source"
destination="$temp_dir/overlay"
mkdir -p -- "$source_root/sevenkewp/maps"
mkdir -p -- "$source_root/sevenkewp/models"
install -m 755 /bin/true "$source_root/xash3d"
install -m 644 /dev/null "$source_root/sevenkewp/maps/base.bsp"
printf '%s\n' source-lower-player > "$source_root/sevenkewp/models/p_9mmar.mdl"
printf '%s\n' source-upper-player > "$source_root/sevenkewp/models/p_9mmAR.mdl"
printf '%s\n' source-lower-clip > "$source_root/sevenkewp/models/w_9mmarclip.mdl"
printf '%s\n' source-upper-clip > "$source_root/sevenkewp/models/w_9mmARclip.mdl"

archive_digest_before=$(sha256sum "$archive_path" | awk '{print $1}')
source_digest_before=$(sha256sum "$source_root/sevenkewp/maps/base.bsp" | awk '{print $1}')
"$package_dir/scripts/stage-they-hunger-mp-overlay.sh" \
	--source-root "$source_root" \
	--destination "$destination" \
	--archive "$archive_path"

[[ -d "$destination/sevenkewp/maps" ]]
[[ -f "$destination/sevenkewp/maps/thintro.bsp" ]]
[[ -f "$destination/sevenkewp/events/ap9.sc" ]]
[[ -f "$destination/sevenkewp/maps/base.bsp" ]]
[[ -f "$destination/sevenkewp/models/p_9mmar.mdl" ]]
[[ -f "$destination/sevenkewp/models/w_9mmarclip.mdl" ]]
[[ ! -e "$destination/sevenkewp/models/p_9mmAR.mdl" ]]
[[ ! -e "$destination/sevenkewp/models/w_9mmARclip.mdl" ]]
cmp <(unzip -p "$archive_path" 'They Hunger Multiplayer Map Conversion/models/p_9mmar.mdl') \
	"$destination/sevenkewp/models/p_9mmar.mdl"
cmp <(unzip -p "$archive_path" 'They Hunger Multiplayer Map Conversion/models/w_9mmarclip.mdl') \
	"$destination/sevenkewp/models/w_9mmarclip.mdl"
[[ ! -e "$source_root/sevenkewp/maps/they1.bsp" ]]
[[ "$(sha256sum "$archive_path" | awk '{print $1}')" == "$archive_digest_before" ]]
[[ "$(sha256sum "$source_root/sevenkewp/maps/base.bsp" | awk '{print $1}')" == "$source_digest_before" ]]
cmp "$package_dir/templates/they-hunger-mp-maps.txt" \
	"$destination/sevenkewp/they-hunger-mp-maps.txt"

map_count=$(find "$destination/sevenkewp/maps" -maxdepth 1 -type f \
	\( -iname 'they*.bsp' -o -name 'thintro.bsp' \) | wc -l)
[[ "$map_count" -eq 58 ]] || {
	printf 'expected 58 They Hunger BSPs, found %s\n' "$map_count" >&2
	exit 1
}

negative_source="$temp_dir/negative-source"
negative_destination="$temp_dir/negative-overlay"
rsync -a -- "$source_root/" "$negative_source/"
mkdir -p -- "$negative_source/sevenkewp/events"
printf '%s\n' unapproved-case-collision > "$negative_source/sevenkewp/events/AP9.sc"
if "$package_dir/scripts/stage-they-hunger-mp-overlay.sh" \
	--source-root "$negative_source" \
	--destination "$negative_destination" \
	--archive "$archive_path" >"$temp_dir/negative.log" 2>&1; then
	printf '%s\n' 'unapproved case collision was accepted' >&2
	exit 1
fi
grep -Fq 'archive path differs only by case from staged content' "$temp_dir/negative.log"
[[ ! -e "$negative_destination" ]]
printf 'PASS: staged 58-map They Hunger MP overlay without changing inputs\n'
