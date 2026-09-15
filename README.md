# Lambda1VR PC packaging tools

This repository contains desktop packaging glue for the Linux/Windows OpenXR
port. It intentionally does not redistribute Half-Life data or Lambda1VR's
third-party model files.

The corresponding public engine and game-code forks, exact branches, retained
Team Beef behavioral references, and license boundaries are listed in
[`SOURCES.md`](SOURCES.md). The port keeps Xash as the desktop OpenXR owner and
reuses Team Beef gameplay through narrow client/server adapters.

`scripts/install-lambda-assets.sh` downloads (or accepts a local copy of) the
official Lambda1VR v1.6.2 APK, verifies its SHA-256 digest, and installs the
VR-adjusted models, presentation sprites, and weapon sounds into selected game
directories.
The official artifact includes distinct model overrides for Blue Shift,
Opposing Force, and They Hunger. Sven/SevenKewp uses the base Half-Life VR
model set.

Example:

```sh
./scripts/install-lambda-assets.sh \
  --root /path/to/xash3d \
  --base valve \
  --bshift bshift \
  --opfor gearbox \
  --hunger Hunger \
  --sven sevenkewp
```

Pass `--apk /path/to/lambda1vr-v1.6.2.apk` to avoid downloading the artifact.
Each destination is relative to `--root`; absolute destinations and parent
directory traversal are rejected.

You must supply a legally owned Half-Life installation and expansion/mod
content separately. The model pack's original readme is copied with the base
models. It limits the content to non-commercial/private use and requires its
credits and terms to remain attached. The extractor keeps the upstream
artifact as the source of truth instead of vendoring those files here.

For development checkouts, `tests/test-vr-interface-parity.sh` verifies that
the versioned client API and usercmd-sidecar headers have not drifted between
the engine, campaign game libraries, and SevenKewp. Pass an alternate workspace
root as its first argument when the repositories are not siblings.

Upstream artifact:

- <https://github.com/Team-Beef-Studios/Lambda1VR/releases/tag/v1.6.2>
- APK SHA-256: `73ad8d81b36acfd92992039cbbc3da0386fe93450b1182f7b52f39e2e701d5ad`

## Sven 3 Linux staging

`scripts/stage-sven-linux.sh` builds a self-contained Linux launch tree from
the Sven 3 archive, current Xash and SevenKewp build outputs/content, and a
legally owned Half-Life `valve` directory. It deliberately excludes the archive's
legacy Half-Life PAK and links the supplied legal installation as the fallback
game instead. The destination must not already exist; construction is performed
in a temporary tree and moved into place only after every install step passes.
The source-controlled SevenKewp content overlay
supplies the matching custom HUD, command menu, sprites, and weapon metadata.

```sh
./scripts/stage-sven-linux.sh \
  --root /tmp/lambda1vr-sven \
  --archive /path/to/SvenCoop3.0.zip \
  --valve /path/to/Half-Life/valve \
  --xash-build /path/to/xash3d-fwgs/build-linux-openxr \
  --seven-build /path/to/SevenKewp/build-xash-audit/output \
  --seven-content /path/to/SevenKewp/sevenkewp \
  --vgui /path/to/SevenKewp/linux/vgui.so \
  --apk /path/to/lambda1vr-v1.6.2.apk
```

Launch the resulting tree with the companion wrapper. It always enables the
required GoldSrc static-sound translation and the Sven BSP compatibility
setting; arguments after `--` are passed to Xash without shell evaluation.

```sh
./scripts/run-sven-linux.sh \
  --root /tmp/lambda1vr-sven \
  --runtime /usr/share/openxr/1/openxr_monado.json \
  --display 1 \
  -- +map c1a0
```

If a locally built Monado service and its installed 32-bit client library have
only a harmless minor IPC version mismatch, add `--ipc-ignore-version`.

## Linux OpenXR smoke testing

`scripts/linux-openxr-smoke.sh` starts one map or a complete game-directory
map set under a selected OpenXR runtime. A passing map must start its game
server, connect the local client, initialize the game-DLL VR API, receive valid
tracked-controller poses, deliver a valid sidecar pose to a ready server game
DLL, and submit both stereo and head-relative UI layers without a fatal engine,
malformed-protocol, or resource error. Raw logs are kept only when
`--keep-logs` is explicitly supplied.

Example using Monado and a staged Sven installation:

```sh
./scripts/linux-openxr-smoke.sh \
  --root /path/to/xash-stage \
  --game sevenkewp \
  --map c1a0 \
  --runtime /usr/share/openxr/1/openxr_monado.json \
  --display 1 \
  --bugcomp gsmrf \
  --set sv_precache_bspmodels=0
```

SevenKewp restarts ambient sounds for newly joined players with GoldSrc's
legacy static-sound message. `--bugcomp gsmrf` enables Xash's narrowly scoped
conversion of that message to the current protocol; Sven launchers must carry
the same engine option.

Use `--maps-file FILE` for an ordered campaign manifest or `--all-maps` for a
startup sweep. The latter proves that maps initialize; it does not replace
physical play-through testing of transitions, scripted sequences, or weapons.
Use `--display N` to create the desktop mirror on a specific SDL display, so
automated VR mirrors can stay off the primary monitor.
`--ipc-ignore-version` opts into Monado's IPC compatibility override when a
locally built service and installed multilib client differ only in minor
version; it is deliberately not enabled by default.

Retained logs replace the staged game root and OpenXR runtime path with stable
placeholders. The same directory receives `manifest.tsv`, which records the
launcher, engine, renderer, filesystem, runtime, and client/server game-DLL
hashes; required acceptance markers; display index; and each map's result,
exit status, and resource-warning count. The launcher must be staged directly
in `--root`, and all five loadable artifacts are required before any map runs,
so a passing manifest cannot silently omit an executed binary. Resource
warnings fail acceptance by default; use `--allow-resource-warnings` only for
a reviewed, intentional content exception.

## Connect to a Sven test server in VR

`scripts/connect-sven-linux.sh` delegates to the existing Sven OpenXR launcher
and adds a validated remote `+connect` command. It therefore retains the same
VR enablement, Sven compatibility flags, OpenXR runtime selection, and SDL
display routing instead of maintaining a second launch path.

```sh
./scripts/connect-sven-linux.sh \
  --root /path/to/xash-stage \
  --server example.net:27015 \
  --display 1
```

For a private transfer between machines you own,
`scripts/create-sven-linux-handoff.sh` replaces the staged `valve` symlink with
a copy of your supplied Half-Life data and bundles the launch scripts. The
result contains copyrighted game data and must not be attached to a public
release or otherwise redistributed.

```sh
./scripts/create-sven-linux-handoff.sh \
  --root /path/to/xash-stage \
  --valve /path/to/Half-Life/valve \
  --server example.net:27015 \
  --output /path/to/lambda1vr-sven-linux.tar.zst
```

After extraction, `./connect-vr.sh` reads the bundled `server.conf` and starts
directly in OpenXR VR. Pass `--runtime FILE`, `--display N`, or `--server
HOST:PORT` only when an override is needed.

## Dedicated Sven campaign server

`server/Dockerfile.runtime` is a small architecture-neutral runtime image for
a natively built Xash dedicated executable and matching SevenKewp server DLL.
It contains no game data or project binaries. Mount a private server tree at
`/server`; that tree must provide `xash`, `filesystem_stdio.so`, `valve/`, and
`sevenkewp/`. The supplied `server.cfg` and `mapcycle.txt` configure the Sven 3
Half-Life campaign beginning at `c1a0`.

The server and game DLL must share one native ABI. In particular, an ARM64
host needs the LP64 Xash and SevenKewp branches listed in `SOURCES.md`; it
cannot load the 32-bit x86 client handoff DLL.

## They Hunger multiplayer overlay

`scripts/stage-they-hunger-mp-overlay.sh` overlays the user-supplied *They
Hunger Multiplayer Map Conversion* archive onto a **copy** of an already staged
Sven/SevenKewp Linux tree. It does not unpack into or otherwise modify either
the source stage or the archive. The new destination must not exist and cannot
be within the source tree; it is built in `/tmp` and moved into place only after
archive, layout, case-collision, and map-manifest validation succeeds.

The archive is additional game content: obtain and use it only where you are
authorized to do so. This package does not vendor or redistribute it. The base
stage still needs the legally owned Half-Life `valve` data, Sven/SevenKewp
content, Xash build artifacts, and Lambda1VR assets described above.

```sh
./scripts/stage-they-hunger-mp-overlay.sh \
  --source-root /tmp/lambda1vr-sven \
  --destination /tmp/lambda1vr-sven-they-hunger-mp \
  --archive '/home/obesecatlord/Backup/Downloads/They Hunger Multiplayer Map Conversion.zip'
```

`templates/they-hunger-mp-maps.txt` is the checked-in, exact 58-BSP inventory
for this archive. Staging refuses an archive with a different top-level map set
and installs that inventory in the overlay's `sevenkewp` directory for audit.
Use the dedicated wrapper for either a four-map startup sample (the default) or
the manifest-scoped all-map sweep. It retains SevenKewp's required `gsmrf`
compatibility flag and BSP-model setting.

```sh
./scripts/smoke-they-hunger-mp-linux.sh \
  --root /tmp/lambda1vr-sven-they-hunger-mp \
  --runtime /usr/share/openxr/1/openxr_monado.json \
  --display 1 \
  --representative

./scripts/smoke-they-hunger-mp-linux.sh \
  --root /tmp/lambda1vr-sven-they-hunger-mp \
  --runtime /usr/share/openxr/1/openxr_monado.json \
  --display 1 \
  --all-maps
```

Both modes are startup smoke tests only. A pass demonstrates OpenXR startup,
local connection, and first-frame/UI submission; it does not demonstrate a
complete campaign, transitions, scripted events, or multiplayer gameplay.
