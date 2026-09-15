#!/usr/bin/env bash
set -euo pipefail

# Run inside Dockerfile.client-builder with the checkout workspace mounted at
# /workspace, a writable build directory at /build, and owned VGUI at /vgui.so.
[[ -d /workspace/xash3d-fwgs && -d /workspace/SevenKewp && -f /vgui.so ]] || {
	printf '%s\n' 'Expected /workspace checkouts, /build output and /vgui.so.' >&2
	exit 1
}
jobs=${BUILD_JOBS:-4}

# Jammy does not ship an i386 OpenXR loader. Reuse the Khronos loader source.
cmake -S /workspace/OpenXR-SDK -B /build/openxr \
	-DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS=-m32 -DCMAKE_CXX_FLAGS=-m32 \
	-DCMAKE_INSTALL_PREFIX=/build/prefix -DCMAKE_INSTALL_LIBDIR=lib \
	-DBUILD_TESTS=OFF -DBUILD_CONFORMANCE_TESTS=OFF -DBUILD_API_LAYERS=OFF \
	-DBUILD_WITH_SYSTEM_JSONCPP=OFF
cmake --build /build/openxr -j "$jobs"
cmake --install /build/openxr
export PKG_CONFIG_PATH=/build/prefix/lib/pkgconfig
export LD_LIBRARY_PATH=/build/prefix/lib

cd /workspace/xash3d-fwgs
./waf configure -o /build/xash --enable-openxr --enable-tests
./waf build -o /build/xash -j "$jobs"

mkdir -p /build/linux/release
install -m 755 /vgui.so /build/linux/release/vgui.so
cmake -S /workspace/SevenKewp -B /build/seven \
	-DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_CLIENT=ON -DBUILD_SERVER=ON \
	-DBUILD_PLUGINS=OFF -DENABLE_CURL=OFF -DINCREASED_SERVER_LIMITS=OFF
cmake --build /build/seven -j "$jobs"
