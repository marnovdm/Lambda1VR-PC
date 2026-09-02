#!/usr/bin/env bash
set -euo pipefail

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
workspace=${1:-$(cd -- "$package_dir/.." && pwd)}

compare_copy() {
	local canonical=$1
	local copy=$2

	if ! cmp -s -- "$canonical" "$copy"; then
		printf 'VR interface drift: %s differs from %s\n' "$copy" "$canonical" >&2
		return 1
	fi
}

game_repos=(
	hlsdk-portable-vr
	hlsdk-portable-vr-bshift
	hlsdk-portable-vr-opfor
	hlsdk-portable-vr-theyhunger
	SevenKewp
)

for repo in "${game_repos[@]}"; do
	compare_copy "$workspace/xash3d-fwgs/public/vr_client_api.h" \
		"$workspace/$repo/public/vr_client_api.h"
	compare_copy "$workspace/xash3d-fwgs/engine/common/vr_usercmd_sidecar.h" \
		"$workspace/$repo/public/vr_usercmd_sidecar.h"
done

for repo in hlsdk-portable-vr-bshift hlsdk-portable-vr-opfor hlsdk-portable-vr-theyhunger; do
	compare_copy "$workspace/hlsdk-portable-vr/cl_dll/vr_client.h" \
		"$workspace/$repo/cl_dll/vr_client.h"
done

printf 'VR interface copies match across engine and game repositories\n'
