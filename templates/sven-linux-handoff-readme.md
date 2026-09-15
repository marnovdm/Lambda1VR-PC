# Lambda1VR PC — Sven Co-op Linux test handoff

This private test bundle contains a Linux OpenXR build and game data supplied
by its owner. Do not redistribute the archive or its `valve`/`sevenkewp`
content.

Requirements: an x86_64 Linux host with 32-bit OpenGL/SDL/OpenXR loader
support, a running OpenXR runtime, and a headset supported by that runtime.
Quest controllers and Valve Index controllers have explicit bindings in this
build.

Extract and connect in VR:

```sh
tar --zstd -xf lambda1vr-sven-linux.tar.zst
cd lambda1vr-sven-linux
./connect-vr.sh
```

The server address is in `server.conf`. Override it with
`./connect-vr.sh --server HOST:PORT`. If the OpenXR loader does not select the
right runtime, pass `--runtime /path/to/runtime.json`. Use `--display N` to put
the desktop mirror on a non-primary SDL display.

This is a test build. Report the map, weapon, controller profile, dominant
hand, and exact reproduction steps for any locomotion, interaction, haptic, or
6DoF aiming issue.
