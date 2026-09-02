#!/usr/bin/env bash
set -euo pipefail

readonly release_url="https://github.com/Team-Beef-Studios/Lambda1VR/releases/download/v1.6.2/lambda1vr-v1.6.2.apk"
readonly release_sha256="73ad8d81b36acfd92992039cbbc3da0386fe93450b1182f7b52f39e2e701d5ad"

usage() {
	printf '%s\n' \
		"usage: $0 --root DIR [--apk FILE] [--base DIR] [--bshift DIR]" \
		"          [--opfor DIR] [--hunger DIR] [--sven DIR]"
}

root_dir=
apk_path=
base_dir=
bshift_dir=
opfor_dir=
hunger_dir=
sven_dir=

while (($#)); do
	case "$1" in
		--root|--apk|--base|--bshift|--opfor|--hunger|--sven)
			(($# >= 2)) || { usage >&2; exit 2; }
			case "$1" in
				--root) root_dir=$2 ;;
				--apk) apk_path=$2 ;;
				--base) base_dir=$2 ;;
				--bshift) bshift_dir=$2 ;;
				--opfor) opfor_dir=$2 ;;
				--hunger) hunger_dir=$2 ;;
				--sven) sven_dir=$2 ;;
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

[[ -n "$root_dir" ]] || { usage >&2; exit 2; }
[[ -n "$base_dir$bshift_dir$opfor_dir$hunger_dir$sven_dir" ]] || {
	printf '%s\n' "select at least one destination" >&2
	exit 2
}

for dependency in curl sha256sum unzip rsync mktemp realpath; do
	command -v "$dependency" >/dev/null || {
		printf 'missing required command: %s\n' "$dependency" >&2
		exit 1
	}
done

root_dir=$(realpath -m -- "$root_dir")
mkdir -p -- "$root_dir"

validate_relative_destination() {
	local destination=$1
	[[ "$destination" != /* && "$destination" != ".." && "$destination" != ../* && "$destination" != */../* && "$destination" != */.. ]] || {
		printf 'destination must stay below --root: %s\n' "$destination" >&2
		exit 2
	}
}

for destination in "$base_dir" "$bshift_dir" "$opfor_dir" "$hunger_dir" "$sven_dir"; do
	[[ -z "$destination" ]] || validate_relative_destination "$destination"
done

temp_dir=$(mktemp -d /tmp/lambda1vr-pc-assets.XXXXXX)
cleanup() {
	case "$temp_dir" in
		/tmp/lambda1vr-pc-assets.*) rm -rf -- "$temp_dir" ;;
	esac
}
trap cleanup EXIT

if [[ -z "$apk_path" ]]; then
	apk_path="$temp_dir/lambda1vr-v1.6.2.apk"
	curl -fL --retry 3 -o "$apk_path" "$release_url"
fi

[[ -f "$apk_path" ]] || {
	printf 'APK not found: %s\n' "$apk_path" >&2
	exit 1
}

actual_sha256=$(sha256sum "$apk_path" | awk '{print $1}')
[[ "$actual_sha256" == "$release_sha256" ]] || {
	printf 'Lambda1VR APK checksum mismatch\nexpected: %s\nactual:   %s\n' \
		"$release_sha256" "$actual_sha256" >&2
	exit 1
}

unzip -q "$apk_path" \
	'assets/models/*' \
	'assets/sprites/*' \
	'assets/sound/*' \
	'assets/bshift/models/*' \
	'assets/gearbox/models/*' \
	'assets/Hunger/models/*' \
	-d "$temp_dir/extracted"

install_common() {
	local destination=$1
	mkdir -p -- "$destination/models" "$destination/sprites" "$destination/sound"
	rsync -a "$temp_dir/extracted/assets/models/" "$destination/models/"
	rsync -a "$temp_dir/extracted/assets/sprites/" "$destination/sprites/"
	rsync -a "$temp_dir/extracted/assets/sound/" "$destination/sound/"
}

install_variant() {
	local relative_destination=$1
	local variant=$2
	local destination
	destination=$(realpath -m -- "$root_dir/$relative_destination")
	case "$destination/" in
		"$root_dir"/*) ;;
		*)
			printf 'resolved destination escapes --root: %s\n' "$relative_destination" >&2
			exit 2
			;;
	esac
	install_common "$destination"
	if [[ -n "$variant" ]]; then
		rsync -a "$temp_dir/extracted/assets/$variant/models/" "$destination/models/"
	fi
	printf 'installed Lambda1VR assets: %s\n' "$destination"
}

[[ -z "$base_dir" ]] || install_variant "$base_dir" ""
[[ -z "$bshift_dir" ]] || install_variant "$bshift_dir" "bshift"
[[ -z "$opfor_dir" ]] || install_variant "$opfor_dir" "gearbox"
[[ -z "$hunger_dir" ]] || install_variant "$hunger_dir" "Hunger"
[[ -z "$sven_dir" ]] || install_variant "$sven_dir" ""
