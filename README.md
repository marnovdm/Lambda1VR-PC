# Lambda1VR PC packaging tools

This repository contains desktop packaging glue for the Linux/Windows OpenXR
port. It intentionally does not redistribute Half-Life data or Lambda1VR's
third-party model files.

`scripts/install-lambda-assets.sh` downloads (or accepts a local copy of) the
official Lambda1VR v1.6.2 APK, verifies its SHA-256 digest, and installs the
VR-adjusted models and presentation sprites into selected game directories.
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
  --set sv_precache_bspmodels=0
```

Use `--maps-file FILE` for an ordered campaign manifest or `--all-maps` for a
startup sweep. The latter proves that maps initialize; it does not replace
physical play-through testing of transitions, scripted sequences, or weapons.
