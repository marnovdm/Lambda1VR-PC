#!/usr/bin/env bash
set -euo pipefail

package_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fixture=$(mktemp -d /tmp/lambda1vr-connect-test.XXXXXX)
cleanup() {
	case "$fixture" in
		/tmp/lambda1vr-connect-test.*) find -P "$fixture" -xdev -depth -delete ;;
	esac
}
trap cleanup EXIT

install -m 755 "$package_root/scripts/connect-sven-linux.sh" "$fixture/connect-vr.sh"
cat > "$fixture/run-sven-linux.sh" <<'FAKE_RUN'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$CAPTURE_ARGS"
FAKE_RUN
chmod +x "$fixture/run-sven-linux.sh"
printf '%s\n' 'foundry.example.test:27015' > "$fixture/server.conf"

CAPTURE_ARGS="$fixture/args" "$fixture/connect-vr.sh" --display 1 -- --test-flag
expected=(--root "$fixture" --display 1 -- +connect foundry.example.test:27015 --test-flag)
mapfile -t actual < "$fixture/args"
[[ "${actual[*]}" == "${expected[*]}" ]]

if "$fixture/connect-vr.sh" --server 'bad;quit:27015'; then
	printf '%s\n' 'FAIL: unsafe server value accepted' >&2
	exit 1
fi

printf '%s\n' 'PASS: Sven OpenXR connection wrapper arguments'
