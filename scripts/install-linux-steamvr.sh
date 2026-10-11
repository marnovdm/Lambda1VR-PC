#!/usr/bin/env bash
# One-shot installer for Lambda1VR-PC on Linux with SteamVR: builds the engine and game code, stages a game tree
# from your Steam copy of Half-Life (plus Blue Shift / Opposing Force when installed), adds the Lambda1VR VR
# models, the HD texture mix (textures/picks.tsv), the `lambda1vr-pc` launcher and Steam library shortcuts.
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
  --no-textures       no HD textures or skies (original look)
  --resrced DIR       where you unpacked the Half-Life: ReSrced download: its world/model textures and skies
                      join the HD mix, and its detail textures are installed and switched on
  --no-bm-skies       do not download the BM SKYBOXES: Rework skies (42 MB)
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
resrced=
build=1 assets=1 textures=1 bmskies=1 shortcuts=1 launcher=1 deps=1
build_args=()

while (($#)); do
	case "$1" in
		--root) root=$2; shift 2 ;;
		--steam) steam=$2; shift 2 ;;
		--half-life) half_life=$2; shift 2 ;;
		--bin-dir) bin_dir=$2; shift 2 ;;
		--work) work=$2; shift 2 ;;
		--apk) apk=$2; shift 2 ;;
		--resrced) resrced=$2; shift 2 ;;
		--no-build) build=0; shift ;;
		--no-assets) assets=0; shift ;;
		--no-textures) textures=0; shift ;;
		--no-bm-skies) bmskies=0; shift ;;
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
		log "system packages: all there"
	else
		for tool in git gcc g++ cmake make python3 pkg-config rsync curl unzip sha256sum; do
			command -v "$tool" >/dev/null || die "missing command: $tool"
		done
		warn "not Arch: only the build commands were checked; install the 32-bit (i386) development libraries listed in docs/linux-steamvr.md first"
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
declare -A game_names=([valve]="Half-Life" [bshift]="Blue Shift" [gearbox]="Opposing Force")
game_list=$(for game in "${games[@]}"; do printf '%s, ' "${game_names[$game]}"; done)
game_list=${game_list%, }
log "found $game_list in $half_life"

# --- Half-Life: ReSrced (--resrced): find its "STEP 4" folder (named after a step of ReSrced's own install guide;
# it holds the game folders). Accepts the unpack folder, the "Half-Life ReSrced download (v1)" folder or STEP 4 itself.
step4=
if [[ -n $resrced ]]; then
	for candidate in "$resrced" "$resrced/STEP 4" "$resrced"/*/"STEP 4"; do
		[[ -d $candidate/valve/materials/common ]] && { step4=$(realpath "$candidate"); break; }
	done
	[[ -n $step4 ]] || die "--resrced: $resrced does not look like the unpacked Half-Life: ReSrced download"
	log "Half-Life: ReSrced: $step4"
fi

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

# --- Detail textures from Half-Life: ReSrced (optional, --resrced) ------------------------------------------
# Fine grain tiled over the world textures, visible up close. The engine loads them per map from
# maps/<map>_detail.txt (images in valve/gfx/detail, which the expansions inherit) and only when r_detailtextures
# is 1 at map load; the video config saves 0 by default, so it is switched on in each game's opengl.cfg.
if [[ -n $resrced ]]; then
	mkdir -p "$root/valve/gfx/detail"
	cp "$step4"/valve/gfx/detail/*.tga "$root/valve/gfx/detail/"
	for pair in valve:valve bshift:blueshift_unlocked gearbox:gearbox; do
		dir=${pair%%:*} src=$step4/${pair#*:}/maps
		[[ -d $root/$dir/maps && -d $src ]] || continue
		cp "$src"/*_detail.txt "$root/$dir/maps/"
		cfg=$root/$dir/opengl.cfg
		if [[ -f $cfg ]] && grep -q '^r_detailtextures ' "$cfg"; then
			sed -i 's/^r_detailtextures .*/r_detailtextures "1"/' "$cfg"
		else
			echo 'r_detailtextures "1"' >>"$cfg"
		fi
		log "ReSrced detail textures: $dir"
	done
fi

# --- HD textures: the curated mix of textures/picks.tsv --------------------------------------------------------
# World textures from the free Half-Life: VR mod (Steam app 1908720) and ReSrced (--resrced), model textures from
# ReSrced, skies from ReSrced and BM SKYBOXES: Rework (downloaded here). Each pick falls back to another pack when
# its own is missing; see scripts/install-textures.py.
if ((textures)); then
	tex_args=(--root "$root")
	if hlvr=$(find_app_dir "Half-Life VR Mod") && [[ -d $hlvr/valve/textures/game ]]; then
		tex_args+=(--hlvr "$hlvr/valve/textures/game")
	else
		warn "Half-Life: VR mod not installed - fewer HD world textures (optional: install it in Steam, free, then re-run)"
	fi
	[[ -n $step4 ]] && tex_args+=(--resrced "$step4")
	if ((bmskies)); then
		bm_zip=$work/downloads/bm_skyboxes.zip bm_dir=$work/bm-skyboxes
		bm_sha256=b517574abe9c5ee0d8192b97e2e31de56899f2613d5ff6e193fee706f9c2d8ad
		if [[ ! -d "$bm_dir/BM Skyboxes" ]]; then
			log "downloading the BM SKYBOXES: Rework skies (42 MB, SHA-256 checked)"
			mkdir -p "$work/downloads"
			if curl -fL --retry 3 --progress-bar -o "$bm_zip.part" https://gamebanana.com/dl/1419394 &&
				[[ $(sha256sum "$bm_zip.part" | cut -d' ' -f1) == "$bm_sha256" ]]; then
				mv -f "$bm_zip.part" "$bm_zip"
				rm -rf "$bm_dir.new" && mkdir -p "$bm_dir.new" && unzip -q "$bm_zip" -d "$bm_dir.new" &&
					rm -rf "$bm_dir" && mv "$bm_dir.new" "$bm_dir"
			else
				rm -f "$bm_zip.part"
				warn "BM skies download failed or changed (checksum) - skipped; re-run later or use --no-bm-skies"
			fi
		fi
		[[ -d "$bm_dir/BM Skyboxes" ]] && tex_args+=(--bmskies "$bm_dir/BM Skyboxes")
	fi
	log "HD textures"
	python3 "$here/install-textures.py" "${tex_args[@]}"
fi

# --- launcher -------------------------------------------------------------------------------------------------
if ((launcher)); then
	mkdir -p "$bin_dir"
	sed "s|^root=\${LAMBDA1VR_ROOT:-\$HOME/Games/lambda1vr-pc}|root=\${LAMBDA1VR_ROOT:-$root}|" "$here/lambda1vr-pc" >"$bin_dir/lambda1vr-pc.new"
	chmod 755 "$bin_dir/lambda1vr-pc.new"
	mv -f "$bin_dir/lambda1vr-pc.new" "$bin_dir/lambda1vr-pc"
	sed "s|^root=\${LAMBDA1VR_ROOT:-\$HOME/Games/lambda1vr-pc}|root=\${LAMBDA1VR_ROOT:-$root}|" "$here/lambda1vr-relaunch" >"$bin_dir/lambda1vr-relaunch.new"
	chmod 755 "$bin_dir/lambda1vr-relaunch.new"
	mv -f "$bin_dir/lambda1vr-relaunch.new" "$bin_dir/lambda1vr-relaunch"
	log "launcher: $bin_dir/lambda1vr-pc (+ lambda1vr-relaunch)"
	[[ :$PATH: == *":$bin_dir:"* ]] || warn "$bin_dir is not on your PATH"
fi

# --- Steam library shortcuts ---------------------------------------------------------------------------------
shortcuts_added=0
if ((shortcuts && launcher)); then
	shortcut_cmd=("$here/steam-shortcuts.py" --root "$root" --launcher "$bin_dir/lambda1vr-pc" --steam "$steam")
	if pgrep -x steam >/dev/null; then
		warn "Steam is running, so the library shortcuts were not added. Close Steam completely, then run:"
		printf '    %q' "${shortcut_cmd[@]}" >&2; printf '\n' >&2
	else
		log "adding Steam library shortcuts"
		"${shortcut_cmd[@]}"
		shortcuts_added=1
	fi
fi

# --- summary ----------------------------------------------------------------------------------------------------
log "done"
printf '  game folder: %s\n' "$root"
printf '  games:       %s\n' "$game_list"
((launcher)) && printf '  launcher:    %s\n' "$bin_dir/lambda1vr-pc"
printf '\nTo play: switch the headset on, start SteamVR, then '
if ((shortcuts_added)); then
	printf 'start "Half-Life VR" in the Steam library\n(or run lambda1vr-pc; -game bshift / -game gearbox for the expansions).\n'
elif ((launcher)); then
	printf 'run lambda1vr-pc\n(-game bshift / -game gearbox for the expansions).\n'
else
	printf 'run %s/xash3d from %s.\n' "$root" "$root"
fi
printf 'Set the SteamVR per-application resolution for the game to about 300%%. Guide: docs/linux-steamvr.md\n'

