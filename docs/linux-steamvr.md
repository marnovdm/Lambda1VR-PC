# Half-Life in VR on Linux with SteamVR

Play Half-Life, Blue Shift and Opposing Force in VR on Linux, natively (no Proton), with SteamVR as the OpenXR
runtime. This is the Lambda1VR-PC port (Xash3D FWGS + OpenXR, game code from Team Beef's Lambda1VR) with fixes and
tuning from playing all three games through on Linux with a PlayStation VR2 and Sense controllers.

- Engine: [`xash3d-fwgs`, branch `steamvr-linux`](https://github.com/marnovdm/xash3d-fwgs/tree/steamvr-linux)
  (menu: [`mainui_cpp`, branch `steamvr-linux`](https://github.com/marnovdm/mainui_cpp/tree/steamvr-linux))
- Game code: [`hlsdk-portable`, branches `steamvr-linux`, `steamvr-linux-bshift`, `steamvr-linux-opfor`](https://github.com/marnovdm/hlsdk-portable/tree/steamvr-linux)
- What changed compared to ObeseCatLord's branches: the commit message on each branch, and [Changes](#changes-from-the-upstream-port) below.

Tested on Arch Linux, AMD GPU (Mesa/RADV), SteamVR 2.18 (beta), PS VR2 through Sony's PC adapter. Other headsets
and controllers that SteamVR supports should work, but they have not been tried.

## Requirements

- x86_64 Linux, Steam and SteamVR, and a working VR headset.
- **Half-Life** on Steam (app 70). Blue Shift and Opposing Force are picked up automatically when they are installed;
  they live in the same `Half-Life` folder.
- Optional, for HD textures: the free **Half-Life: VR** mod on Steam (app 1908720; only its textures are used, the
  mod itself does not have to run) and the **Half-Life: ReSrced** download. See the README.
- Build tools and 32-bit libraries. The game is a 32-bit x86 build, because SteamVR's Linux OpenXR runtime for 32-bit
  clients is what the Half-Life game code needs. On Arch (enable the `multilib` repository):

  ```sh
  sudo pacman -S --needed git gcc cmake make python pkgconf rsync curl unzip python-pillow \
      lib32-gcc-libs lib32-glibc lib32-sdl2-compat lib32-libglvnd lib32-mesa lib32-freetype2 \
      lib32-fontconfig lib32-libvorbis lib32-libogg lib32-opus lib32-bzip2 lib32-libx11 lib32-libxcb
  ```

  Debian / Ubuntu (untested; package names from the Xash3D FWGS build notes):

  ```sh
  sudo dpkg --add-architecture i386 && sudo apt update
  sudo apt install --no-install-recommends git build-essential gcc-multilib g++-multilib cmake python3 \
      python3-pil pkg-config rsync curl unzip libsdl2-dev:i386 libgl-dev:i386 libfreetype-dev:i386 \
      libfontconfig-dev:i386 libvorbis-dev:i386 libogg-dev:i386 libopus-dev:i386 libopusfile-dev:i386 \
      libbz2-dev:i386 libx11-dev:i386 libxcb1-dev:i386
  ```

  Fedora (untested):

  ```sh
  sudo dnf install git gcc gcc-c++ glibc-devel.i686 libstdc++-devel.i686 cmake make python3 python3-pillow \
      pkgconf rsync curl unzip sdl2-compat-devel.i686 mesa-libGL-devel.i686 freetype-devel.i686 \
      fontconfig-devel.i686 libvorbis-devel.i686 libogg-devel.i686 opus-devel.i686 opusfile-devel.i686 \
      bzip2-devel.i686 libX11-devel.i686 libxcb-devel.i686
  ```

  Other distributions: the i386 development packages of SDL2, OpenGL, FreeType, fontconfig, Vorbis, Ogg, Opus,
  bzip2, X11 and XCB, plus a GCC that can build with `-m32`. If the build fails on your distribution, please open
  an issue with the log the installer points to.

## Install

```sh
git clone https://github.com/marnovdm/Lambda1VR-PC.git
cd Lambda1VR-PC
./scripts/install-linux-steamvr.sh
```

What it does (all steps can be skipped, see `--help`):

1. Checks the packages above (Arch only; elsewhere it only checks the build commands).
2. Builds a 32-bit OpenXR loader, the engine and the three game libraries in `~/.cache/lambda1vr-pc`
   (`scripts/build-linux-steamvr.sh`, a few minutes the first time).
3. Creates the game folder `~/Games/lambda1vr-pc` from a **copy** of your Steam `Half-Life` game data (about 1 GB
   for all three games). Your Steam installation is not changed, and Steam's own Half-Life keeps working.
4. Installs the Lambda1VR VR weapon models, hands, sprites and sounds: it downloads the official Lambda1VR v1.6.2 APK
   from Team Beef's GitHub release and checks its SHA-256 (`scripts/install-lambda-assets.sh`). These assets are
   for private, non-commercial use; their readme is copied next to them.
   The flashlight model's orange logo and button are then painted over with the handle's black
   (`scripts/patch-torch-model.py`, keeps `v_torch.mdl.orig`; runs on every install). Some weapon models are fixed
   too (`scripts/patch-weapon-models.py`, keeps `*.mdl.orig`): the revolver's reload sound and the Opposing Force
   Desert Eagle, sniper rifle and M249 reload sounds (the models asked for sound files that never shipped), and a
   loose shell that hung below the shotgun's grip between reloads.
5. Installs the **HD texture mix** from [`textures/picks.tsv`](../textures/picks.tsv) (`scripts/install-textures.py`):
   world textures from the Half-Life: VR mod (if installed in Steam) and Half-Life: ReSrced (with `--resrced DIR`),
   ReSrced's model textures, and skies from ReSrced and BM SKYBOXES: Rework (downloaded, SHA-256 checked). See
   [HD textures](../README.md#hd-textures-optional-recommended) for where to get the packs. The world and model
   textures are links into the packs, in `<game>/materials/common` and `<game>/materials/models`; a folder you made
   yourself there is left alone. With `--resrced DIR` (where you unpacked the
   [Half-Life: ReSrced](https://www.moddb.com/mods/half-life-resrced-hd-graphics-mod) download) it also installs ReSrced's detail textures for all three games and sets `r_detailtextures "1"` in
   each game's `opengl.cfg` (they only load when it is on at map load; the video settings save it as 0).
6. Installs the launcher `~/.local/bin/lambda1vr-pc` and `~/.local/bin/lambda1vr-relaunch` (see Debugging).
7. Adds **Half-Life VR**, **Blue Shift VR** and **Opposing Force VR** to the Steam library, with artwork made from
   each game's own art and a VR tag. Steam has to be closed for this step; when it is running, the installer prints
   the command to run later (`scripts/steam-shortcuts.py`).

**Update:** pull this repository and run the installer again. It fetches and rebuilds the engine and game code and
never overwrites your settings, saves or installed assets (apart from the model fixes above).

**Uninstall:** delete `~/Games/lambda1vr-pc`, `~/.cache/lambda1vr-pc`, `~/.local/bin/lambda1vr-pc` and
`~/.local/bin/lambda1vr-relaunch`, and remove the
shortcuts in Steam.

## Play

1. Switch the headset on (in the room, not in its box), then start the game: **Half-Life VR** in the Steam library
   (also listed under VR in SteamVR), or `lambda1vr-pc` in a terminal. The launcher starts SteamVR when it is not
   running yet.
2. Blue Shift: `lambda1vr-pc -game bshift`; Opposing Force: `lambda1vr-pc -game gearbox`.
3. Skip the menu: `lambda1vr-pc +map c0a0` (the tram ride), or continue the quicksave with
   `lambda1vr-pc +load quick`.

**Resolution:** set the per-application resolution in SteamVR (Settings → Video → Per-application video settings)
to around **300%** of the headset default. Much higher values (600%) need about 1 GB of VRAM per eye-image set and
can hang the game when the headset wakes from standby.

Saves and settings live in the game folders (`~/Games/lambda1vr-pc/valve/SAVE`, `…/valve/config.cfg`). Settings are
written when you quit through the menu; a crash loses changes made in that session.

## Controls

Right-handed defaults. PlayStation VR2 Sense button names first, Oculus Touch / Index names in brackets
(SteamVR presents the Sense controllers to the game as Touch controllers).

### Right hand (weapon hand)

| Input | Action |
|---|---|
| Trigger | Fire |
| Grip held + trigger | Secondary fire (alt mode, zoom, …) |
| Grip, short tap (≤ 0.2 s) | Reload |
| Stick left / right | Turn (smooth; `vr_smoothturn 0` = snap turns of 45°) |
| Stick up / down, **held 0.15 s** | Only with `vr_weapon_stick_menu 1` (off by default; Triangle's weapon grid replaces it): open the weapon menu; then each push steps: up = previous weapon, down = next (`vr_weapon_stick_up_next 1` reverses it). Trigger selects |
| Cross (A) | Jump (with `vr_quick_crouchjump 1` a double-tap crouch-jumps) |
| Circle (B) | Crouch (hold) |
| Stick click (R3) | Use, with the right hand |
| Hand behind your head/shoulder + grip | Crowbar while held; let go to switch back |

### Left hand (off hand)

| Input | Action |
|---|---|
| Stick | Move, in the direction you look (analog) |
| Trigger | Walk (slow, quiet) |
| Square (X) | Flashlight on/off |
| Triangle (Y), hold | **Weapon grid** on the left arm: point at a weapon with the gun hand (its laser shows where), let go of Triangle to switch to it; let go while pointing at nothing to cancel |
| Stick click (L3) | Use, with the left hand: doors, buttons, chargers (hold) |
| Stick double-click | Cycle the laser sight: beam + dot → dot → off. While scoped: toggle scope smoothing |
| Hand behind your shoulder + Square (X) | **Quicksave** (the controller pulses) |
| Hand behind your shoulder + Triangle (Y) | **Quickload** |
| Grip held, hand near the gun | Two-handed aim (the gun follows the line between your hands) |

### Both hands / body

| Input | Action |
|---|---|
| Both stick clicks together | Menu (pause). The menu panel stays fixed in the room; point with the right hand, trigger clicks |
| Physically crouch | Off by default; `vr_enable_crouching 0.85` crouches you when your head goes below 85% of your height |
| Walk around | Room-scale movement |
| Ladders | Push forward and look up or down to climb that way; push back or step off at the bottom to get off |
| Throw grenades / satchels | Throw with your arm; strength follows the hand speed |
| Crowbar | Swing it; damage depends on swing speed (capped at 2× a normal hit) |
| Swimming | Look where you want to go and push forward; jump/crouch move straight up/down |

The keyboard and mouse still work on the desktop window; the `` ` `` key opens the console (shown in the headset).

## Settings

**Options → VR in the game menu** has almost all of them, on four pages: *Comfort and movement*, *Weapons*,
*Hand HUD* and *HUD and cinema*, plus *Recenter*. Point with the laser and click with the trigger; hold the trigger on
an arrow to run through the values. Positions are in cm, angles in degrees, sizes in % of the default. A change applies
at once, so close the menu to check it (e.g. look at your arm for the hand panels) and reopen; *Reset page* puts a page
back to the defaults. World scale and the debug settings are console only.

The tables below are the reference for the console. Change them in the console (`` ` `` on the keyboard, e.g. `vr_weapon_stick_hold 0.25`). They are saved when you quit
through the menu. To force one at every start, add `+set name value` to the Steam shortcut's launch options or the
`lambda1vr-pc` command line.

### Controls and comfort

| Setting | Default | Meaning |
|---|---|---|
| `vr_weapon_pointer` | `1` | Triangle (Y) shows the weapon grid while held (point and release to switch). `0` = Triangle switches to the previous weapon |
| `vr_weapon_stick_menu` | `0` | `1` = pushing the right stick up/down opens the HUD weapon menu (the original Lambda1VR way) |
| `vr_weapon_stick_hold` | `0.15` | Seconds the right stick must be held up/down before the weapon menu opens (so brushing the stick while turning does not open it). Steps inside the open menu are immediate |
| `vr_weapon_stick_up_next` | `0` | Weapon menu direction: `0` stick up = previous weapon, down = next (Lambda1VR order); `1` up = next |
| `vr_weapon_stick_threshold` | `0.85` | How far (0–1) the stick must be pushed for the weapon menu; the push must also be mostly vertical |
| `vr_laser_doubleclick` | `0.35` | Maximum seconds between the two left stick clicks that cycle the laser sight |
| `vr_lasersight` | `1` | Laser sight: `1` beam + dot, `2` dot only, `0` off |
| `vr_laser_width` / `vr_laser_dot_scale` | `0.3` / `0.08` | Laser beam width and dot size |
| `vr_swap_jumpduck` | `1` | `1`: Cross/A jumps, Circle/B crouches (Half-Life 2 VR layout). `0`: the original Lambda1VR layout (A crouches, B jumps) |
| `vr_smoothturn` | `1` | Smooth turning; `0` = snap turning |
| `vr_turn_angle` | `45` | Snap-turn angle (degrees), or the smooth-turn speed basis |
| `vr_walkdirection` | `1` | Stick movement follows `1` your head, `0` the left controller |
| `vr_enable_crouching` | `0` | Physical crouch, off by default (button only). E.g. `0.85`: you crouch in game when your head is below that fraction of your standing height |
| `vr_height_adjust` | `0.1` | Extra eye height in metres (raise it if the world feels too tall) |
| `vr_recenter` | (command) | Make your current position and heading the centre (stand where you want to be first) |
| `vr_ladder_aim` | `0` | Ladder climb direction: `0` look up/down, `1` point the left controller (Lambda1VR) |
| `vr_quick_crouchjump` | `0` | `1` = double-tap jump to crouch-jump |
| `vr_reloadtimeoutms` | `200` | Longest right-grip tap (ms) that counts as reload |
| `vr_control_scheme` | `0` | Lambda1VR control schemes `0`–`3`; add 10 for left-handed (e.g. `10`) |
| `vr_headtorch` | `0` | `1` = flashlight beam follows your head instead of the left hand |
| `vr_backpack_weapon` | `weapon_crowbar` | Weapon you get from behind your shoulder |
| `vr_throw_scale` | `3.75` | Grenade/satchel throw strength (multiplier on hand speed) |

### HUD and menus

| Setting | Default | Meaning |
|---|---|---|
| `vr_ui_width` | `2.6` | HUD/menu panel width in metres |
| `vr_ui_height` | `0` | Panel height in metres (`0` = from the width, 16:9) |
| `vr_ui_distance` | `2.2` | Panel distance in metres |
| `vr_ui_offset_x` / `vr_ui_offset_y` | `-0.1` / `0` | Move the panel right/up in metres (negative = left/down), limited to ±1 |
| `vr_ui_glow_curve` | `1.6` | Hides faint lines around glowing HUD text; `1` = the original look |
| `vr_hud_hands` | `1` | Health, suit and the flashlight icon (battery; bright = on) side by side on the flashlight handle (with the drowning/freezing/poison/... icons to their right while they flash), ammo behind the gun hand, instead of on the head-locked HUD. `0` = classic HUD |
| `vr_hud_hand_scale` | `0.0005` | Health panel size in metres per HUD pixel (digits about 1.2 cm tall) |
| `vr_hud_hand_tilt` | `-20` | Health panel (and weapon grid) tilt in degrees (more negative = facing more upwards) |
| `vr_hud_hand_yaw` | `90` | Health panel turned inwards in degrees, mirrored per hand (90 = facing your body, like a watch; 0 = facing back along the controller) |
| `vr_hud_ammo_scale`, `vr_hud_ammo_tilt`, `vr_hud_ammo_yaw` | `0.0005`, `0`, `20` | The same for the ammo panel. Holding the gun with both hands, the health panel moves under the ammo panel and takes these settings |
| `vr_hud_right_flip` | `0` | `1` turns the right-hand panel 180° in its plane (text along the arm towards the fingers instead of the elbow) |
| `vr_hud_status_offset` | `0.025 0.035 -0.02` | Health/suit panel position from the left hand as you see it in game (the flashlight), metres: right, up, back (along where the controller points) (quote it: `vr_hud_status_offset "0 0.08 0"`) |
| `vr_hud_ammo_offset` | `-0.01 0.02 -0.05` | Ammo panel position from the gun-hand palm, metres: right, up, back |
| `vr_weapon_pointer_offset` | `0 0.035 -0.35` | Weapon grid centre from the left hand in game, metres: right, up, back (`-0.35` = out past the flashlight) |
| `vr_weapon_pointer_scale` | `0.00065` | Weapon grid size in metres per HUD pixel (the Half-Life grid is about 57 cm long) |
| `vr_weapon_pointer_yaw` | `40` | Weapon grid turn in degrees, like `vr_hud_hand_yaw` (lower = far end turned more towards you) |
| `vr_notify` | `0` | `1` = show console messages (top left) over the HUD |
| `vr_cinema` | `1` | Scripted camera views (`trigger_camera`) are shown on a flat screen in the room instead of moving your whole view; `0` = original behaviour |
| `vr_cinema_fade` | `0.2` | Seconds the cinema screen and the world take to fade in and out |

### Graphics and sound

| Setting | Default | Meaning |
|---|---|---|
| `vr_supersampling` | `1.0` | Eye resolution scale on top of SteamVR's resolution (prefer the SteamVR per-app setting) |
| `vr_mirror_eye` | `0` | Eye shown in the desktop window (`0` left, `1` right) |
| `width` / `height` | `1280` / `720` | Desktop window size. The HUD is drawn at this size into the 1280×720 VR HUD image, so 1280×720 is the sharpest; smaller windows blur and stretch the HUD |
| `snd_effects_scale` | `0.75` | Volume of everything except speech, so voices stand out; `1` = original mix |
| `room_off` | `0` | `1` = no room echo (the original game's reverb in large rooms; also mutes the underwater effect) |
| `host_allow_materials` | `1` when HD textures are installed | `0` = original textures (set by the launcher; remove the `valve/materials` link to turn it off permanently) |

### Gameplay

| Setting | Default | Meaning |
|---|---|---|
| `chargerfix` | `1` (set by the launcher) | Health/HEV chargers give the "denied" sound once you are full instead of charging on while you hold use. `0` = original behaviour. Not saved by the game, so the launcher sets it at every start |
| `vr_tank_grab` | `1` | Mounted guns (machine guns, mortars, the tank's gun): use it with your hand on its handles, then aim by swinging the handles around the gun's pivot. `0` = the gun points where your controller points. Walk away to get off |

### Debugging

`vr_poseinfo` (head/body angles), `vr_weaponinfo` (weapon model and pose), `vr_testhaptic [amplitude] [Hz]`
(pulses both controllers).

**Console commands from outside:** the launcher connects the game's console input to
`~/Games/lambda1vr-pc/console.fifo`, so a terminal can send commands while you are in the headset, one per line:
`echo 'map c2a3d' > ~/Games/lambda1vr-pc/console.fifo`. `lambda1vr-relaunch` uses it to restart the game where you
are: quicksave, quit, start again with `+load quick` (`stop` / `start` do the halves, e.g. to install a rebuilt
engine in between). It refuses to quit when the save did not land.

## Changes from the upstream port

See [What this fork adds](../README.md#what-this-fork-adds) in the README.

## Known issues

- The **reach gesture** (stretch your arm out to use something) does not trigger, and touching a button with your
  hand does not press it; use the stick clicks.
- The controller **menu button** (Sense Options) does not open the menu: SteamVR's generated Touch binding and
  Sony's Touch emulation use different paths for it. Both stick clicks together always open the menu.
- Haptics in gameplay are unconfirmed (`vr_testhaptic` works).
- Blue Shift and Opposing Force were played less than Half-Life.
- They Hunger and Sven Co-op are not covered by this installer (see the main README for the upstream Sven tools).
- The engine also has an experimental Counter-Strike VR mode (`-game cstrike`, for a matching client DLL). It is
  not part of this release and not supported yet.

## Troubleshooting

- **Logs:** `~/Games/lambda1vr-pc/lambda1vr-pc.log` (launcher + game output), `~/Games/lambda1vr-pc/engine.log`,
  SteamVR's OpenXR client log `~/.local/share/Steam/logs/xrclient_xash3d.txt`.
- **Game only shows on the desktop:** SteamVR was not running or the headset was off when the game started.
  Start SteamVR with the headset on and in the room first.
- **Crash or hang:** `LAMBDA1VR_GDB=1 lambda1vr-pc` runs it under gdb and writes a backtrace to the log.
- **Build failed:** the installer prints the end of the failing log; all build logs are in
  `~/.cache/lambda1vr-pc/logs/`. Usually a missing 32-bit package.
- **Steam shortcuts missing:** close Steam completely and run `./scripts/steam-shortcuts.py`.

## Credits and licences

- [Team Beef](https://github.com/Team-Beef-Studios/Lambda1VR): Lambda1VR, the Quest port this is based on, and its
  VR models (downloaded from their release; non-commercial use, readme kept next to them).
- [ObeseCatLord](https://github.com/ObeseCatLord/Lambda1VR-PC): the PC OpenXR port of Lambda1VR this fork builds on.
- HD textures: the [Half-Life: VR](https://store.steampowered.com/app/1908720/) mod team, Leaufai
  ([Half-Life: ReSrced](https://www.moddb.com/mods/half-life-resrced-hd-graphics-mod)) and Gondon Kefirman
  ([BM SKYBOXES: Rework](https://gamebanana.com/mods/587803), after Crowbar Collective's Black Mesa). Their files are
  downloaded or linked from your own copies, never redistributed here.
- [Xash3D FWGS](https://github.com/FWGS/xash3d-fwgs) and [hlsdk-portable](https://github.com/FWGS/hlsdk-portable).
- The engine and game code keep their upstream licences (Xash3D FWGS; the Half-Life SDK licence from Valve for the
  game code). This repository's scripts and docs: MIT. Half-Life itself and its content are not included: you need your own copy on Steam.
