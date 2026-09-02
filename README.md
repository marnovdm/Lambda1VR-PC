# Lambda1VR PC packaging tools

This repository contains desktop packaging glue for the Linux/Windows OpenXR
port. It intentionally does not redistribute Half-Life data or Lambda1VR's
third-party model files.

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
  -- +map c1a0
```

## Linux OpenXR smoke testing

`scripts/linux-openxr-smoke.sh` starts one map or a complete game-directory
map set under a selected OpenXR runtime. A passing map must start its game
server, connect the local client, and submit both stereo and head-relative UI
layers without a fatal engine or malformed-protocol error. Raw logs are kept
only when `--keep-logs` is explicitly supplied.

Example using Monado and a staged Sven installation:

```sh
./scripts/linux-openxr-smoke.sh \
  --root /path/to/xash-stage \
  --game sevenkewp \
  --map c1a0 \
  --runtime /usr/share/openxr/1/openxr_monado.json \
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
