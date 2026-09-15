#!/usr/bin/env bash
set -euo pipefail

package_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fixture=$(mktemp -d /tmp/lambda1vr-handoff-test.XXXXXX)
cleanup() {
	case "$fixture" in
		/tmp/lambda1vr-handoff-test.*) find -P "$fixture" -xdev -depth -delete ;;
	esac
}
trap cleanup EXIT

mkdir -p "$fixture/stage/sevenkewp/cl_dlls" "$fixture/stage/sevenkewp/dlls" \
	"$fixture/owned-valve/maps" "$fixture/output" "$fixture/extract" "$fixture/work"
for artifact in xash3d libxash.so libref_gl.so filesystem_stdio.so; do
	printf '%s\n' "$artifact" > "$fixture/stage/$artifact"
done
chmod +x "$fixture/stage/xash3d"
printf '%s\n' client > "$fixture/stage/sevenkewp/cl_dlls/client.so"
printf '%s\n' server > "$fixture/stage/sevenkewp/dlls/server.so"
printf '%s\n' crash > "$fixture/stage/sevenkewp/buffer.dat"
printf '%s\n' log > "$fixture/stage/sevenkewp/engine.log"
printf '%s\n' game > "$fixture/owned-valve/liblist.gam"
printf '%s\n' map > "$fixture/owned-valve/maps/c0a0.bsp"
ln -s "$fixture/owned-valve" "$fixture/stage/valve"

archive="$fixture/output/lambda1vr-sven-linux.tar.zst"
TMPDIR="$fixture/work" "$package_root/scripts/create-sven-linux-handoff.sh" \
	--root "$fixture/stage" --valve "$fixture/owned-valve" \
	--server foundry.example.test:27015 --output "$archive"

(cd "$fixture/output" && sha256sum -c "$(basename "$archive").sha256")
tar --zstd -xf "$archive" -C "$fixture/extract"
bundle="$fixture/extract/lambda1vr-sven-linux"
[[ -f "$bundle/valve/maps/c0a0.bsp" && ! -L "$bundle/valve" ]]
[[ -x "$bundle/connect-vr.sh" && -x "$bundle/run-sven-linux.sh" ]]
[[ -f "$bundle/SOURCES.md" && -f "$bundle/BINARY-SHA256SUMS" ]]
[[ ! -e "$bundle/sevenkewp/buffer.dat" && ! -e "$bundle/sevenkewp/engine.log" ]]
(cd "$bundle" && sha256sum -c BINARY-SHA256SUMS)
[[ -z "$(find "$bundle" -perm /022 -print -quit)" ]]
grep -Fxq 'foundry.example.test:27015' "$bundle/server.conf"
[[ -z "$(find "$fixture/work" -mindepth 1 -maxdepth 1 -print -quit)" ]]

printf '%s\n' 'PASS: portable Sven Linux VR handoff'
