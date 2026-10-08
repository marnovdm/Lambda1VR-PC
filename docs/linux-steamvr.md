# Half-Life in VR on Linux with SteamVR

Play Half-Life, Blue Shift and Opposing Force in VR on Linux, natively (no Proton), with SteamVR as the OpenXR
runtime. This is the Lambda1VR-PC port (Xash3D FWGS + OpenXR, game code from Team Beef's Lambda1VR) with fixes and
tuning from playing all three games through on a PlayStation VR2 with Sense controllers.

- Engine: [`xash3d-fwgs`, branch `steamvr-linux`](https://git.marno.org/marnom/xash3d-fwgs/src/branch/steamvr-linux)
- Game code: [`hlsdk-portable`, branches `steamvr-linux`, `steamvr-linux-bshift`, `steamvr-linux-opfor`](https://git.marno.org/marnom/hlsdk-portable)
- What changed compared to ObeseCatLord's branches: the commit message on each branch, and [Changes](#changes-from-the-upstream-port) below.

Tested on Arch Linux, AMD GPU (Mesa/RADV), SteamVR 2.18 (beta), PS VR2 through Sony's PC adapter. Other headsets
and controllers that SteamVR supports should work, but they have not been tried.

## Requirements

- x86_64 Linux, Steam and SteamVR, and a working VR headset.
- **Half-Life** on Steam (app 70). Blue Shift and Opposing Force are picked up automatically when they are installed;
  they live in the same `Half-Life` folder.
- Optional: the free **Half-Life: VR** mod on Steam (app 1908720). Only its HD world textures are used; the mod
  itself does not have to run.
- Build tools and 32-bit libraries. The game is a 32-bit x86 build, because SteamVR's Linux OpenXR runtime for 32-bit
  clients is what the Half-Life game code needs. On Arch (enable the `multilib` repository):

  ```sh
  sudo pacman -S --needed git gcc cmake make python pkgconf rsync curl unzip python-pillow \
      lib32-gcc-libs lib32-glibc lib32-sdl2-compat lib32-libglvnd lib32-mesa lib32-freetype2 \
      lib32-fontconfig lib32-libvorbis lib32-libogg lib32-opus lib32-bzip2 lib32-libx11 lib32-libxcb
  ```

  On other distributions, install the equivalent i386 development packages of SDL2, OpenGL (libglvnd/Mesa),
  FreeType, fontconfig, Vorbis, Ogg, Opus, bzip2, X11 and XCB, plus a GCC that can build with `-m32`.

## Install

```sh
git clone https://git.marno.org/marnom/Lambda1VR-PC.git
cd Lambda1VR-PC
./scripts/install-linux-steamvr.sh
```

What it does (all steps can be skipped, see `--help`):

1. Checks the packages above (Arch only; elsewhere it only checks the commands).
2. Builds a 32-bit OpenXR loader, the engine and the three game libraries in `~/.cache/lambda1vr-pc`
   (`scripts/build-linux-steamvr.sh`, a few minutes the first time).
3. Creates the game folder `~/Games/lambda1vr-pc` from a **copy** of your Steam `Half-Life` game data (about 1 GB
   for all three games). Your Steam installation is not changed, and Steam's own Half-Life keeps working.
4. Installs the Lambda1VR VR weapon models, hands, sprites and sounds: it downloads the official Lambda1VR v1.6.2 APK
   from Team Beef's GitHub release and checks its SHA-256 (`scripts/install-lambda-assets.sh`). These assets are
   for private, non-commercial use; their readme is copied next to them.
   The flashlight model's orange logo and button are then painted over with the handle's black
   (`scripts/patch-torch-model.py`, keeps `v_torch.mdl.orig`; runs on every install).
5. Links the Half-Life: VR mod's HD world textures, if that mod is installed.
6. Installs the launcher `~/.local/bin/lambda1vr-pc`.
7. Adds **Half-Life VR**, **Blue Shift VR** and **Opposing Force VR** to the Steam library, with artwork made from
   each game's own art and a VR tag. Steam has to be closed for this step; when it is running, the installer prints
   the command to run later (`scripts/steam-shortcuts.py`).

**Update:** pull this repository and run the installer again. It fetches and rebuilds the engine and game code and
never overwrites your settings, saves or installed assets (apart from the flashlight paint-over above).

**Uninstall:** delete `~/Games/lambda1vr-pc`, `~/.cache/lambda1vr-pc` and `~/.local/bin/lambda1vr-pc`, and remove the
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
| Stick left / right | Snap turn 45° |
| Stick up / down, **held 0.15 s** | Open the weapon menu; then each push steps: up = previous weapon, down = next (`vr_weapon_stick_up_next 1` reverses it). Trigger selects |
| Cross (A) | Jump. Double-tap: crouch-jump |
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
| Physically crouch | Crouch (see `vr_enable_crouching` to turn this off) |
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
| `vr_weapon_stick_hold` | `0.15` | Seconds the right stick must be held up/down before the weapon menu opens (so brushing the stick while turning does not open it). Steps inside the open menu are immediate |
| `vr_weapon_stick_up_next` | `0` | Weapon menu direction: `0` stick up = previous weapon, down = next (Lambda1VR order); `1` up = next |
| `vr_weapon_stick_threshold` | `0.85` | How far (0–1) the stick must be pushed for the weapon menu; the push must also be mostly vertical |
| `vr_laser_doubleclick` | `0.35` | Maximum seconds between the two left stick clicks that cycle the laser sight |
| `vr_lasersight` | `1` | Laser sight: `1` beam + dot, `2` dot only, `0` off |
| `vr_laser_width` / `vr_laser_dot_scale` | `0.3` / `0.12` | Laser beam width and dot size |
| `vr_swap_jumpduck` | `1` | `1`: Cross/A jumps, Circle/B crouches (Half-Life 2 VR layout). `0`: the original Lambda1VR layout (A crouches, B jumps) |
| `vr_smoothturn` | `0` | `1` = smooth turning instead of snap turning |
| `vr_turn_angle` | `45` | Snap-turn angle (degrees), or the smooth-turn speed basis |
| `vr_walkdirection` | `1` | Stick movement follows `1` your head, `0` the left controller |
| `vr_enable_crouching` | `0.85` | Physical crouch: you crouch in game when your head is below this fraction of your standing height. `0` turns physical crouching off (button only) |
| `vr_height_adjust` | `0.1` | Extra eye height in metres (raise it if the world feels too tall) |
| `vr_recenter` | (command) | Make your current position and heading the centre (stand where you want to be first) |
| `vr_ladder_aim` | `0` | Ladder climb direction: `0` look up/down, `1` point the left controller (Lambda1VR) |
| `vr_quick_crouchjump` | `1` | Double-tap jump to crouch-jump |
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
| `vr_ui_distance` | `1.5` | Panel distance in metres |
| `vr_ui_offset_x` / `vr_ui_offset_y` | `-0.1` / `0` | Move the panel right/up in metres (negative = left/down), limited to ±1 |
| `vr_ui_glow_curve` | `1.6` | Hides faint lines around glowing HUD text; `1` = the original look |
| `vr_hud_hands` | `1` | Health, suit and the flashlight icon (battery; bright = on) side by side on the flashlight handle (with the drowning/freezing/poison/... icons to their right while they flash), ammo behind the gun hand, instead of on the head-locked HUD. `0` = classic HUD |
| `vr_hud_hand_scale` | `0.0005` | Hand panel size in metres per HUD pixel (digits about 1.2 cm tall) |
| `vr_hud_hand_tilt` | `-20` | Hand panel tilt in degrees (more negative = facing more upwards) |
| `vr_hud_hand_yaw` | `90` | Hand panels turned inwards in degrees, mirrored per hand (90 = facing your body, like a watch; 0 = facing back along the controller) |
| `vr_hud_right_flip` | `0` | `1` turns the right-hand panel 180° in its plane (text along the arm towards the fingers instead of the elbow) |
| `vr_hud_status_offset` | `0.025 0.035 -0.02` | Health/suit panel position from the left hand as you see it in game (the flashlight), metres: right, up, back (along where the controller points) (quote it: `vr_hud_status_offset "0 0.08 0"`) |
| `vr_hud_ammo_offset` | `0 0.025 0.08` | Ammo panel position from the gun-hand palm, metres: right, up, back |
| `vr_weapon_pointer_offset` | `0 0.035 -0.15` | Weapon grid centre from the left hand in game, metres: right, up, back (`-0.15` = out past the flashlight) |
| `vr_weapon_pointer_scale` | `0.0005` | Weapon grid size in metres per HUD pixel (the Half-Life grid is about 44 cm long) |
| `vr_weapon_pointer_yaw` | `60` | Weapon grid turn in degrees, like `vr_hud_hand_yaw` (lower = far end turned more towards you) |
| `vr_notify` | `0` | `1` = show console messages (top left) over the HUD |

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

### Debugging

`vr_poseinfo` (head/body angles), `vr_weaponinfo` (weapon model and pose), `vr_testhaptic [amplitude] [Hz]`
(pulses both controllers).

## Changes from the upstream port

ObeseCatLord's port was smoke-tested against a simulated Monado headset. Playing it on real hardware through
SteamVR needed, among others:

- **Runs on SteamVR**: OpenXR 1.0 instead of 1.1 (SteamVR rejects 1.1), full-resolution eye rendering straight into
  the swapchains, correct culling at the outer edge of each eye, menu visible without a map loaded.
- **Hand-mounted HUD**: health, suit and the flashlight battery on the flashlight handle (plus the damage-type icons), ammo on the gun hand
  (`vr_hud_hands`); the flashlight model's orange logo and button are painted black by the installer so the panel
  sits on a plain handle.
- **Weapon selection by pointing**: hold Triangle/Y for a weapon grid on the left arm, point with the gun hand,
  release to switch (`vr_weapon_pointer`).
- **Menus and HUD**: world-locked menu/console panel with a pointer ray and cursor, which also stays put while a map
  loads; HUD panel size/position settings; no faint lines around HUD text; screen fades (death, damage) cover the
  whole view instead of a box on the HUD; console messages hidden.
- **Aiming and weapons**: correct weapon/hand/flashlight orientation, shots that go where the gun points (also
  two-handed), stable aim when pointing steeply up, laser sight without lag, no stray muzzle flash when switching
  weapons, sensible crowbar damage and throw strength.
- **Movement**: no slowly building world tilt, head-relative analog movement with a walk modifier, ladders that
  climb where you look, physical crouch relative to the recentre height.
- **Controls**: weapon menu with a hold delay and dead zone, configurable up/down direction; off-hand
  use on L3 with the laser sight on a double-click; jump/crouch on Cross/Circle; a menu chord that never toggles
  the laser.
- **Use**: using things with the left hand works (it was always dropped), and a hand pressed against a button can
  use it.
- **Desktop/window**: full speed and sound when the desktop window does not have focus; the SDL gamepad view of the
  VR controllers no longer interferes.
- **Sound**: effects slightly quieter than speech.
- **Wall chargers** stop "charging" once you are full (`chargerfix`, set by the launcher).
- Fixed crashes (laser sight, `impulse 101`) and missing hands/flashlight models.

## Known issues

- The **reach gesture** (stretch your arm out to use something) does not trigger; use the stick clicks.
- The controller **menu button** (Sense Options/Create) may need a SteamVR binding change; both stick clicks always
  open the menu.
- Haptics in gameplay are unconfirmed (`vr_testhaptic` works).
- Blue Shift and Opposing Force were played less than Half-Life.
- They Hunger and Sven Co-op are not covered by this installer (see the main README for the upstream Sven tools).

## Troubleshooting

- **Logs:** `~/Games/lambda1vr-pc/lambda1vr-pc.log` (launcher + game output), `~/Games/lambda1vr-pc/engine.log`,
  SteamVR's OpenXR client log `~/.local/share/Steam/logs/xrclient_xash3d.txt`.
- **Game only shows on the desktop:** SteamVR was not running or the headset was off when the game started.
  Start SteamVR with the headset on and in the room first.
- **Crash or hang:** `LAMBDA1VR_GDB=1 lambda1vr-pc` runs it under gdb and writes a backtrace to the log.
- **Build failed:** the installer prints the end of the failing log; all build logs are in
  `~/.cache/lambda1vr-pc/logs/`. Usually a missing 32-bit package.
- **Steam shortcuts missing:** close Steam completely and run `./scripts/steam-shortcuts.py`.
