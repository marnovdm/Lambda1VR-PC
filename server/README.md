# Linux dedicated Half-Life campaign

Use the Xash and SevenKewp branches in `../SOURCES.md`, with matching native
architectures for the engine, filesystem module and server game library.
The portable VR client remains x86 Linux; a dedicated server can use ARM64.
On ARM64, Xash loads `sevenkewp/dlls/server_arm64.so`, not `server.so`.

Stage the supplied Valve/Sven content privately, then run:

```sh
./server/prepare-hl-campaign.sh /path/to/server-root
docker build -t lambda1vr-sven-runtime -f server/Dockerfile.runtime .
docker run -di --name lambda1vr-sven-hl-campaign --restart unless-stopped \
  --log-opt max-size=10m --log-opt max-file=3 \
  --network host --user "$(id -u):$(id -g)" \
  -v /path/to/server-root:/server lambda1vr-sven-runtime \
  -dedicated -bugcomp gsmrf -game sevenkewp -port 26099 \
  +maxplayers 8 +exec server.cfg +map c1a0
```

Choose an available UDP port permitted by the host and upstream firewall and
use that same port in the client's `server.conf`. Host networking avoids Docker
bridge forwarding; it is intended for Linux dedicated hosts. `gsmrf` is required
on the **server** too, because SevenKewp emits GoldSrc static sound messages.

Preparation installs the campaign config and changes `mp_timelimit` to zero in
the listed maps' CFGs. It leaves their spawn equipment, scripts and changelevel
triggers intact. SevenKewp treats one mapcycle line as one campaign series;
splitting this campaign across lines causes campaign state to reset.

For a portable client directory containing the extracted `lambda1vr-sven-linux`
folder, copy `scripts/launch-sven-vr.sh` and `server.conf` beside the folder.
Run `./launch-sven-vr.sh`; it reads the adjacent address. The lower-level
`connect-vr.sh` and `run-sven-linux.sh` accept `--root` for other layouts.

The portable client bundles the Khronos **32-bit loader**. It still needs a
working **32-bit headset runtime**, SDL2 and OpenGL driver on the destination
x86_64 Linux machine. Use `--runtime PATH` and `--display N` when needed.
Simulation checks do not establish physical controller or Windows parity.

## Portable client build

Build against Ubuntu 22.04 userspace, rather than the host distribution's libc:

```sh
docker build -t lambda1vr-client-builder:ubuntu22 -f server/Dockerfile.client-builder .
docker run --rm --user "$(id -u):$(id -g)" \
  -v /path/to/checkouts:/workspace -v /path/to/build-output:/build \
  -v /path/to/owned/vgui.so:/vgui.so:ro lambda1vr-client-builder:ubuntu22 \
  bash /workspace/lambda1vr-pc-package/scripts/build-portable-sven-linux.sh
```

The workspace needs `xash3d-fwgs`, `SevenKewp`, `OpenXR-SDK` and this package
checkout. Stage `/build/xash` and `/build/seven/output` with the existing stage
script, and copy `/build/prefix/lib/libopenxr_loader.so.1` plus the SDK `LICENSE`
into the staged root. The launcher adds that root to its own library search path.
The handoff includes a `BINARY-SHA256SUMS` manifest and source revisions.

Check every shipped ELF's required symbol versions and resolve its dependencies
inside this older userspace before testing the extracted archive against a real
OpenXR service. The tested build requires no glibc symbol newer than 2.34.
