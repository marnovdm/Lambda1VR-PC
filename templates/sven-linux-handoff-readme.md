# Lambda1VR PC — Sven Co-op Linux test handoff

This private test bundle contains a Linux OpenXR build and game data supplied
by its owner. Do not redistribute the archive or its `valve`/`sevenkewp`
content.

Requirements: an x86_64 Linux host with 32-bit OpenGL/SDL support, a working
32-bit OpenXR runtime, and a headset supported by that runtime. The provided
portable build targets Ubuntu 22.04 or newer compatible userspace and bundles
the Khronos OpenXR loader; the headset runtime itself comes from your machine.
Quest controllers and Valve Index controllers have explicit bindings in this
build.

Default right-handed controls: left stick moves; right stick left/right turns;
right trigger fires; a quick right-grip squeeze reloads, while holding grip plus
trigger uses secondary fire. Point the right controller at menu/dialog buttons
and click with its trigger. Touch's left menu button opens/backs out of menus;
on Index, click both thumbsticks together (the system button may be reserved by
the runtime). This includes Sven's welcome/MOTD dialog. Menu selection does not
also fire the weapon. Menu/dialog selection, pistol firing and snap turning were
exercised through Monado's simulated Index and Touch profiles; physical tracking
and haptics still need headset testing. Reload and secondary fire are control
instructions here, not additional claims of hardware validation.

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
