#!/usr/bin/env bash
# Build the Linux/SteamVR flavour of Lambda1VR-PC from source: the 32-bit OpenXR loader, the Xash3D FWGS engine
# with OpenXR, and the Half-Life / Blue Shift / Opposing Force game libraries.
#
# Output: <work>/out/ with engine/ (xash3d, libxash.so, renderers, menu, OpenXR loader) and
# valve/, bshift/, gearbox/ (cl_dlls/client.so + dlls/<game>.so).
# Re-running updates the checkouts (fast-forward only) and rebuilds incrementally.
set -euo pipefail

usage() {
	cat <<'EOF'
usage: build-linux-steamvr.sh [--work DIR] [--engine-repo URL] [--engine-branch NAME]
                              [--hlsdk-repo URL] [--hlsdk-branch-prefix NAME] [--no-update] [--jobs N]

  --work DIR                  build tree (default: ${XDG_CACHE_HOME:-~/.cache}/lambda1vr-pc)
  --engine-repo URL           Xash3D FWGS fork (default: git.marno.org/marnom/xash3d-fwgs)
  --engine-branch NAME        default: steamvr-linux
  --hlsdk-repo URL            hlsdk-portable fork (default: git.marno.org/marnom/hlsdk-portable)
  --hlsdk-branch-prefix NAME  branches NAME, NAME-bshift, NAME-opfor (default: steamvr-linux)
  --no-update                 build the existing checkouts as they are (no fetch/pull)
  --jobs N                    parallel build jobs (default: nproc)
EOF
}

work=${XDG_CACHE_HOME:-$HOME/.cache}/lambda1vr-pc
engine_repo=https://git.marno.org/marnom/xash3d-fwgs.git
engine_branch=steamvr-linux
hlsdk_repo=https://git.marno.org/marnom/hlsdk-portable.git
hlsdk_prefix=steamvr-linux
openxr_repo=https://github.com/KhronosGroup/OpenXR-SDK.git
openxr_tag=release-1.1.63
update=1
jobs=$(nproc)

while (($#)); do
	case "$1" in
		--work) work=$2; shift 2 ;;
		--engine-repo) engine_repo=$2; shift 2 ;;
		--engine-branch) engine_branch=$2; shift 2 ;;
		--hlsdk-repo) hlsdk_repo=$2; shift 2 ;;
		--hlsdk-branch-prefix) hlsdk_prefix=$2; shift 2 ;;
		--no-update) update=0; shift ;;
		--jobs) jobs=$2; shift 2 ;;
		-h|--help) usage; exit 0 ;;
		*) printf 'unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
	esac
done

log() { printf '\033[1m==> %s\033[0m\n' "$*"; }

# run LOG CMD...: run a build step with its output in $work/logs/LOG.log; show the tail if it fails
run() {
	local name=$1; shift
	if ! "$@" >>"$work/logs/$name.log" 2>&1; then
		printf 'FAILED: %s (log: %s)\n' "$*" "$work/logs/$name.log" >&2
		tail -n 30 "$work/logs/$name.log" >&2
		exit 1
	fi
}

for tool in git gcc g++ cmake make python3 pkg-config; do
	command -v "$tool" >/dev/null || { printf 'missing required command: %s\n' "$tool" >&2; exit 1; }
done

mkdir -p "$work"
work=$(realpath "$work")
src=$work/src
prefix=$work/prefix   # 32-bit OpenXR loader
out=$work/out
mkdir -p "$src" "$out" "$work/logs"
rm -f "$work"/logs/*.log

# checkout DIR URL BRANCH: clone, or fast-forward an existing clone (unless --no-update)
checkout() {
	local dir=$1 url=$2 branch=$3
	if [[ ! -d $dir/.git ]]; then
		log "cloning $url ($branch)"
		git clone --branch "$branch" "$url" "$dir"
	elif ((update)); then
		log "updating $dir ($branch)"
		git -C "$dir" fetch origin
		git -C "$dir" checkout -q "$branch"
		git -C "$dir" merge --ff-only "origin/$branch"
	fi
}

# 1. 32-bit OpenXR loader (the game is a 32-bit x86 build; SteamVR ships a 32-bit OpenXR runtime)
if [[ ! -f $prefix/lib/pkgconfig/openxr.pc ]]; then
	if [[ ! -d $src/OpenXR-SDK ]]; then
		log "cloning OpenXR-SDK $openxr_tag"
		git -c advice.detachedHead=false clone --depth 1 --branch "$openxr_tag" "$openxr_repo" "$src/OpenXR-SDK"
	fi
	log "building the 32-bit OpenXR loader"
	run openxr cmake -S "$src/OpenXR-SDK" -B "$work/build/openxr" -DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_C_FLAGS=-m32 -DCMAKE_CXX_FLAGS=-m32 -DCMAKE_INSTALL_PREFIX="$prefix" \
		-DDYNAMIC_LOADER=ON -DBUILD_TESTS=OFF -DBUILD_API_LAYERS=OFF -DBUILD_CONFORMANCE_TESTS=OFF \
		-DPRESENTATION_BACKEND=xlib -DBUILD_WITH_WAYLAND_HEADERS=OFF -DBUILD_WITH_SYSTEM_JSONCPP=OFF
	run openxr cmake --build "$work/build/openxr" -j "$jobs"
	run openxr cmake --install "$work/build/openxr"
fi

# 2. Engine
checkout "$src/xash3d-fwgs" "$engine_repo" "$engine_branch"
log "updating engine submodules"
run engine git -C "$src/xash3d-fwgs" submodule update --init --recursive
log "building the engine"
(
	cd "$src/xash3d-fwgs"
	export PKG_CONFIG_PATH=$prefix/lib/pkgconfig
	export PKG_CONFIG_LIBDIR=/usr/lib32/pkgconfig:/usr/share/pkgconfig
	run engine ./waf configure -o "$work/build/xash" -T release --enable-openxr
	run engine ./waf build -j "$jobs"
	rm -rf "$out/engine"
	run engine ./waf install --destdir="$out/engine"
)
cp -P "$prefix"/lib/libopenxr_loader.so* "$out/engine/"

# 3. Game libraries: one clone, one worktree per game branch
checkout "$src/hlsdk-portable" "$hlsdk_repo" "$hlsdk_prefix"
for game in bshift opfor; do
	branch=$hlsdk_prefix-$game
	tree=$src/hlsdk-$game
	if [[ ! -d $tree ]]; then
		git -C "$src/hlsdk-portable" fetch -q origin "$branch:$branch" 2>/dev/null || true
		git -C "$src/hlsdk-portable" worktree add -q "$tree" "$branch"
	elif ((update)); then
		git -C "$tree" merge -q --ff-only "origin/$branch"
	fi
done
for game in portable bshift opfor; do
	tree=$src/hlsdk-$game
	[[ $game == portable ]] && tree=$src/hlsdk-portable
	log "building game code: $game"
	(
		cd "$tree"
		run "game-$game" ./waf configure -o "$work/build/hlsdk-$game" -T release
		run "game-$game" ./waf build -j "$jobs"
		rm -rf "$work/build/game-$game"
		run "game-$game" ./waf install --destdir="$work/build/game-$game"
	)
done
for dir in valve bshift gearbox; do
	rm -rf "${out:?}/$dir"
done
cp -a "$work/build/game-portable/valve" "$out/valve"
cp -a "$work/build/game-bshift/bshift" "$out/bshift"
cp -a "$work/build/game-opfor/gearbox" "$out/gearbox"

log "build output: $out (logs: $work/logs)"
