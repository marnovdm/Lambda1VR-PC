#!/usr/bin/env bash
# One-shot installer for Lambda1VR-PC on Linux with SteamVR: builds the engine and game code, stages a game tree
# from your Steam copy of Half-Life (plus Blue Shift / Opposing Force when installed), adds the Lambda1VR VR
# models, optionally the Half-Life: VR mod's HD textures, the `lambda1vr-pc` launcher and Steam library shortcuts.
#
# Re-running it updates the build and keeps your configs, saves and installed assets. See docs/linux-steamvr.md.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

usage() {
	cat <<'EOF'
usage: install-linux-steamvr.sh [options]

  --root DIR          game tree to create/update (default: ~/Games/lambda1vr-pc)
  --steam DIR         Steam folder (default: ~/.local/share/Steam)
  --half-life DIR     Half-Life install with valve/ (default: found in your Steam libraries)
  --bin-dir DIR       where the lambda1vr-pc launcher goes (default: ~/.local/bin)
  --work DIR          build tree (default: ~/.cache/lambda1vr-pc)
  --apk FILE          local copy of lambda1vr-v1.6.2.apk (default: download it)
  --no-build          use the existing build output in --work
  --no-assets         skip the Lambda1VR VR models/sprites/sounds
  --no-textures       skip linking the Half-Life: VR mod's HD textures
  --no-shortcuts      skip the Steam library shortcuts and artwork
  --no-launcher       skip installing the launcher
  --skip-deps         do not check system packages
  Build options are passed on to build-linux-steamvr.sh:
  --engine-repo URL --engine-branch NAME --hlsdk-repo URL --hlsdk-branch-prefix NAME --no-update --jobs N
EOF
}

root=$HOME/Games/lambda1vr-pc
steam=$HOME/.local/share/Steam
half_life=
bin_dir=$HOME/.local/bin
work=${XDG_CACHE_HOME:-$HOME/.cache}/lambda1vr-pc
apk=
build=1 assets=1 textures=1 shortcuts=1 launcher=1 deps=1
build_args=()

while (($#)); do
	case "$1" in
		--root) root=$2; shift 2 ;;
		--steam) steam=$2; shift 2 ;;
		--half-life) half_life=$2; shift 2 ;;
		--bin-dir) bin_dir=$2; shift 2 ;;
		--work) work=$2; shift 2 ;;
		--apk) apk=$2; shift 2 ;;
		--no-build) build=0; shift ;;
		--no-assets) assets=0; shift ;;
		--no-textures) textures=0; shift ;;
		--no-shortcuts) shortcuts=0; shift ;;
		--no-launcher) launcher=0; shift ;;
		--skip-deps) deps=0; shift ;;
		--engine-repo|--engine-branch|--hlsdk-repo|--hlsdk-branch-prefix|--jobs) build_args+=("$1" "$2"); shift 2 ;;
		--no-update) build_args+=("$1"); shift ;;
		-h|--help) usage; exit 0 ;;
		*) printf 'unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
	esac
done

log() { printf '\033[1m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[[ $(uname -m) == x86_64 ]] || die "x86_64 Linux only (the game is a 32-bit x86 build)"

# --- system packages ---------------------------------------------------------------------------------------
if ((deps)); then
	if command -v pacman >/dev/null; then
		# pacman -T resolves "provides" (lib32-sdl2 is provided by lib32-sdl2-compat)
		missing=$(pacman -T git gcc cmake make python pkgconf rsync curl unzip lib32-gcc-libs lib32-glibc \
			lib32-sdl2 lib32-libglvnd lib32-mesa lib32-freetype2 lib32-fontconfig lib32-libvorbis lib32-libogg \
			lib32-opus lib32-bzip2 lib32-libx11 lib32-libxcb python-pillow || true)
		if [[ -n $missing ]]; then
			die "missing packages (multilib repository needed): sudo pacman -S --needed $(echo $missing)"
		fi
	else
		for tool in git gcc g++ cmake make python3 pkg-config rsync curl unzip sha256sum; do
			command -v "$tool" >/dev/null || die "missing command: $tool"
		done
		warn "not Arch: make sure the 32-bit (i386) development libraries listed in docs/linux-steamvr.md are installed"
	fi
fi

# --- find Steam libraries and Half-Life -------------------------------------------------------------------
[[ -d $steam/steamapps ]] || die "no Steam folder at $steam (use --steam)"
steam_libraries() {
	echo "$steam"
	sed -n 's/^\s*"path"\s*"\(.*\)"\s*$/\1/p' "$steam/steamapps/libraryfolders.vdf" 2>/dev/null
}
find_app_dir() { # find_app_dir INSTALLDIR -> first library containing steamapps/common/INSTALLDIR
	local lib
	while read -r lib; do
		[[ -d $lib/steamapps/common/$1 ]] && { echo "$lib/steamapps/common/$1"; return 0; }
	done < <(steam_libraries | awk '!seen[$0]++')
	return 1
}
if [[ -z $half_life ]]; then
	half_life=$(find_app_dir Half-Life) || die "Half-Life (Steam app 70) not found - install it or pass --half-life"
fi
[[ -d $half_life/valve ]] || die "$half_life/valve does not exist"
games=(valve)
for game in bshift gearbox; do
	[[ -f $half_life/$game/liblist.gam ]] && games+=("$game")
done
log "Half-Life: $half_life (games: ${games[*]})"

# --- build --------------------------------------------------------------------------------------------------
if ((build)); then
	"$here/build-linux-steamvr.sh" --work "$work" "${build_args[@]}"
fi
out=$work/out
[[ -x $out/engine/xash3d ]] || die "no build output in $out (run without --no-build)"

# install_file SRC DST: as a new file, so a running game keeps its loaded copy instead of crashing
install_file() {
	mkdir -p "$(dirname "$2")"
	install -m "${3:-755}" "$1" "$2.new"
	mv -f "$2.new" "$2"
}

# --- stage the game tree ----------------------------------------------------------------------------------
log "staging $root"
mkdir -p "$root"
for f in "$out"/engine/*; do
	[[ -f $f && ! -L $f ]] && install_file "$f" "$root/$(basename "$f")"
done
for f in "$out"/engine/libopenxr_loader.so*; do
	[[ -L $f ]] && ln -sfn "$(readlink "$f")" "$root/$(basename "$f")"
done
for game in "${games[@]}"; do
	# Game data: only files not already there, so configs, saves and installed VR assets are never overwritten.
	# Steam's own game libraries are not needed (ours are installed below).
	rsync -a --ignore-existing --exclude='cl_dlls/' --exclude='dlls/' --exclude='SAVE/' \
		"$half_life/$game/" "$root/$game/"
	# Desktop window 1280x720 on a fresh install: the HUD is drawn at the window size into the 1280x720 VR UI
	# texture, so this maps HUD pixels 1:1 (sharp, not stretched). The engine keeps it in video.cfg afterwards.
	[[ -f $root/$game/video.cfg ]] || printf 'fullscreen "0"\nwidth "1280"\nheight "720"\n' >"$root/$game/video.cfg"
	for lib in "$out/$game"/cl_dlls/*.so "$out/$game"/dlls/*.so; do
		install_file "$lib" "$root/$game/${lib#"$out/$game/"}"
	done
done
install_file "$out/engine/valve/extras.pk3" "$root/valve/extras.pk3" 644

# --- Lambda1VR VR models, sprites and sounds ---------------------------------------------------------------
if ((assets)); then
	asset_args=(--root "$root" --base valve)
	[[ " ${games[*]} " == *" bshift "* ]] && asset_args+=(--bshift bshift)
	[[ " ${games[*]} " == *" gearbox "* ]] && asset_args+=(--opfor gearbox)
	[[ -n $apk ]] && asset_args+=(--apk "$apk")
	if [[ -f $root/.lambda1vr-assets-installed ]]; then
		log "Lambda1VR assets already installed (delete $root/.lambda1vr-assets-installed to reinstall)"
	else
		log "installing the Lambda1VR assets (downloads the official v1.6.2 APK, SHA-256 checked)"
		"$here/install-lambda-assets.sh" "${asset_args[@]}"
		touch "$root/.lambda1vr-assets-installed"
	fi
fi

# Flashlight model: paint its orange lambda-VR logo and button over with the handle's black (the hand HUD's
# health/suit panel sits on the handle). Idempotent, so it also runs on installs whose assets were already there.
if [[ -f $root/valve/models/v_torch.mdl ]]; then
	log "flashlight model: plain handle"
	python3 "$here/patch-torch-model.py" "$root"
fi
log "weapon models: missing reload sounds, stray shotgun shell"
python3 "$here/patch-weapon-models.py" "$root"

# --- HD world textures from the free Half-Life: VR mod (Steam app 1908720) -----------------------------------
if ((textures)); then
	if hlvr=$(find_app_dir "Half-Life VR Mod") && [[ -d $hlvr/valve/textures/game ]]; then
		mkdir -p "$root/valve/materials"
		ln -sfn "$hlvr/valve/textures/game" "$root/valve/materials/common"
		log "HD textures linked from $hlvr"
	else
		warn "Half-Life: VR mod not installed - no HD world textures (optional: install it in Steam, re-run)"
	fi
fi

# --- launcher -------------------------------------------------------------------------------------------------
if ((launcher)); then
	mkdir -p "$bin_dir"
	sed "s|^root=\${LAMBDA1VR_ROOT:-\$HOME/Games/lambda1vr-pc}|root=\${LAMBDA1VR_ROOT:-$root}|" "$here/lambda1vr-pc" >"$bin_dir/lambda1vr-pc.new"
	chmod 755 "$bin_dir/lambda1vr-pc.new"
	mv -f "$bin_dir/lambda1vr-pc.new" "$bin_dir/lambda1vr-pc"
	log "launcher: $bin_dir/lambda1vr-pc"
	[[ :$PATH: == *":$bin_dir:"* ]] || warn "$bin_dir is not on your PATH"
fi

# --- Steam library shortcuts ---------------------------------------------------------------------------------
if ((shortcuts && launcher)); then
	shortcut_cmd=("$here/steam-shortcuts.py" --root "$root" --launcher "$bin_dir/lambda1vr-pc" --steam "$steam")
	if pgrep -x steam >/dev/null; then
		warn "Steam is running: close it and run  ${shortcut_cmd[*]}  to add the library shortcuts"
	else
		log "adding Steam library shortcuts"
		"${shortcut_cmd[@]}"
	fi
fi

log "done. Start SteamVR with the headset on, then: lambda1vr-pc   (or 'Half-Life VR' in the Steam library)"
