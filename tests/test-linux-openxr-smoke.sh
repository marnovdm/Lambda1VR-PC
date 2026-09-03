#!/usr/bin/env bash
set -euo pipefail

package_root=$(cd "$(dirname "$0")/.." && pwd)
fixture=$(mktemp -d /tmp/lambda1vr-smoke-harness-test.XXXXXX)
cleanup() {
	case "$fixture" in
		/tmp/lambda1vr-smoke-harness-test.*) find -P "$fixture" -xdev -depth -delete ;;
	esac
}
trap cleanup EXIT

mkdir -p "$fixture/root/testgame/maps" "$fixture/root/testgame/cl_dlls" \
	"$fixture/root/testgame/dlls" "$fixture/evidence"
: > "$fixture/root/testgame/maps/testmap.bsp"
: > "$fixture/runtime.json"
for artifact in libxash.so libref_gl.so filesystem_stdio.so \
	testgame/cl_dlls/client.so testgame/dlls/server.so; do
	printf 'fixture artifact: %s\n' "$artifact" > "$fixture/root/$artifact"
done

cat > "$fixture/root/fake-xash" <<'FAKE_XASH'
#!/usr/bin/env bash
printf 'fixture root: %s\n' "$PWD"
printf 'runtime: %s\n' "$XR_RUNTIME_JSON"
printf '%s\n' \
	'OpenXR: initialized Linux/GLX stereo session' \
	'Game started' \
	'client connected' \
	'VR client API v2 initialized' \
	'OpenXR: first tracked controller frame received' \
	'SV: vr_usercmd_sidecar_consumer_ready'
if [[ ${FAKE_SKIP_POSE_MARKER:-0} != 1 ]]; then
	printf '%s\n' 'SV: vr_usercmd_sidecar_pose_delivered'
fi
printf '%s\n' \
	'OpenXR: first stereo frame submitted' \
	'OpenXR: first head-relative UI layer submitted'
if [[ ${FAKE_RESOURCE_WARNING:-0} == 1 ]]; then
	printf '%s\n' 'File not found: deliberate-test-resource'
fi
FAKE_XASH
chmod +x "$fixture/root/fake-xash"

"$package_root/scripts/linux-openxr-smoke.sh" \
	--root "$fixture/root" \
	--xash "$fixture/root/fake-xash" \
	--game testgame \
	--map testmap \
	--runtime "$fixture/runtime.json" \
	--display 1 \
	--seconds 1 \
	--keep-logs "$fixture/evidence"

grep -Fq $'format\tlambda1vr-openxr-smoke-v2' "$fixture/evidence/manifest.tsv"
grep -Fq $'testmap\tPASS\t0\t0' "$fixture/evidence/manifest.tsv"
for key in xash_sha256 libxash.so_sha256 libref_gl.so_sha256 \
	filesystem_stdio.so_sha256 testgame_cl_dlls_client.so_sha256 \
	testgame_dlls_server.so_sha256; do
	grep -Eq "^${key}"$'\t''[0-9a-f]{64}$' "$fixture/evidence/manifest.tsv"
done
grep -Fq '<ROOT>' "$fixture/evidence/testmap.log"
grep -Fq '<OPENXR_RUNTIME>' "$fixture/evidence/testmap.log"
if grep -Fq "$fixture/root" "$fixture/evidence/testmap.log"; then
	printf '%s\n' 'FAIL: retained log contains unsanitized root' >&2
	exit 1
fi

cp "$fixture/root/fake-xash" "$fixture/external-xash"
if "$package_root/scripts/linux-openxr-smoke.sh" \
	--root "$fixture/root" \
	--xash "$fixture/external-xash" \
	--game testgame \
	--map testmap \
	--runtime "$fixture/runtime.json" \
	--seconds 1; then
	printf '%s\n' 'FAIL: launcher outside staged root passed' >&2
	exit 1
fi

mv "$fixture/root/libref_gl.so" "$fixture/missing-libref_gl.so"
if "$package_root/scripts/linux-openxr-smoke.sh" \
	--root "$fixture/root" \
	--xash "$fixture/root/fake-xash" \
	--game testgame \
	--map testmap \
	--runtime "$fixture/runtime.json" \
	--seconds 1; then
	printf '%s\n' 'FAIL: missing staged artifact passed' >&2
	exit 1
fi
mv "$fixture/missing-libref_gl.so" "$fixture/root/libref_gl.so"

if FAKE_SKIP_POSE_MARKER=1 "$package_root/scripts/linux-openxr-smoke.sh" \
	--root "$fixture/root" \
	--xash "$fixture/root/fake-xash" \
	--game testgame \
	--map testmap \
	--runtime "$fixture/runtime.json" \
	--seconds 1; then
	printf '%s\n' 'FAIL: missing pose-delivery marker passed' >&2
	exit 1
fi

if FAKE_RESOURCE_WARNING=1 "$package_root/scripts/linux-openxr-smoke.sh" \
	--root "$fixture/root" \
	--xash "$fixture/root/fake-xash" \
	--game testgame \
	--map testmap \
	--runtime "$fixture/runtime.json" \
	--seconds 1; then
	printf '%s\n' 'FAIL: resource warning passed without override' >&2
	exit 1
fi

FAKE_RESOURCE_WARNING=1 "$package_root/scripts/linux-openxr-smoke.sh" \
	--root "$fixture/root" \
	--xash "$fixture/root/fake-xash" \
	--game testgame \
	--map testmap \
	--runtime "$fixture/runtime.json" \
	--seconds 1 \
	--allow-resource-warnings

printf '%s\n' 'PASS: strict smoke markers, evidence sanitization, and resource policy'
