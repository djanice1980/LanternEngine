#!/usr/bin/env bash
# The Linux release built in the Ubuntu 24.04 container (Dockerfile), where it belongs: a build
# on the developer's own distribution ties the package to that distribution's glibc, and some
# toolchains stamp every program with an instruction-set level the CPU in a Steam Deck or an
# older PC does not have (CachyOS's binutils 2.47 marks x86-64-v4 whatever the code needs).
# The container has glibc 2.39, stock clang 20 and lld, and the libraries in /opt/deps.
#
#   packaging/linux/release-docker.sh <version> <package-template folder> <launcher folder>
#
# The launcher folder is the Avalonia launcher published on the host (dotnet publish ... -r
# linux-x64 --self-contained true): .NET's native libraries are built for glibc 2.17, so they
# are fine from any host. Writes engine/out/package/<name>-v<version>-linux-x64.tar.gz and the
# AppImage beside it (appimage.sh, run on the host with APPIMAGETOOL or appimagetool on PATH).
# BB_MARCH: the instruction-set level of the GPU library (empty: the compiler's default, plain
# x86-64, which runs everywhere). docker or podman, whichever is installed (BB_CONTAINER).
# BB_PGO: off (default; the profiles in engine/pgo come from Windows runs and are not used),
# generate (the training build: the game writes the GPU library's profile into the data folder,
# <data>/pgo/*.profraw, while it runs), use (engine/pgo/*.profraw from training runs, merged in
# the container with llvm-profdata, optimize the GPU library).
set -euo pipefail
engine=$(cd -- "$(dirname -- "$0")/../.." && pwd)
version=${1:?usage: packaging/linux/release-docker.sh <version> <package-template folder> <launcher folder>}
template=$(cd -- "${2:?package-template folder}" && pwd)
launcher=$(cd -- "${3:?launcher folder}" && pwd)
container=${BB_CONTAINER:-$(command -v docker || command -v podman || true)}
[[ -n $container ]] || { echo 'docker or podman is needed' >&2; exit 1; }
image=${BB_IMAGE:-paleblood-linux}
if ! "$container" image inspect "$image" >/dev/null 2>&1; then
    echo "Building the $image image (Ubuntu 24.04 with the engine's libraries; once, several minutes)"
    "$container" build -t "$image" "$engine/packaging/linux"
fi
# The checkout is mounted at /build (a path without spaces: pkg-config cannot take one). A build
# made on the host (out/gpu, the runtime objects) is removed first: its CMake cache names the
# host's compilers and paths. Files are written as the host user, not root.
rm -rf "$engine/out/gpu" "$engine/out/atrac9" "$engine/out/libatrac9.a" "$engine/out/bb-probe" \
       "$engine/out/bb-gpu-capabilities" "$engine/out/bb-shader-lab" "$engine/out/bb-engine-assets"
"$container" run --rm \
    --user "$(id -u):$(id -g)" -e HOME=/tmp/home \
    -v "$engine/..:/build" -v "$template:/template:ro" -v "$launcher:/launcher:ro" \
    -w /build/engine \
    -e BB_MARCH="${BB_MARCH:-}" -e BB_PGO="${BB_PGO:-off}" -e BB_PACKAGE_NAME="${BB_PACKAGE_NAME:-PalebloodEngine}" \
    "$image" \
    bash -c 'mkdir -p "$HOME" && git config --global --add safe.directory "*" && bash packaging/linux/build.sh "$0" /template /launcher' "$version"
name=${BB_PACKAGE_NAME:-PalebloodEngine}
package=$engine/out/package/$name
# What the package needs from the player's system: no instruction-set level above the default,
# and the container's glibc at most.
for file in "$package"/engine/out/bb-probe "$package"/engine/out/gpu/libbbgpu.so "$package"/engine/out/gpu/libSDL3.so.0; do
    isa=$(readelf -n "$file" 2>/dev/null | grep -o 'x86 ISA needed: .*' || true)
    glibc=$(objdump -T "$file" 2>/dev/null | grep -o 'GLIBC_[0-9.]*' | sort -Vu | tail -1)
    printf '%s: glibc %s%s\n' "${file#"$package"/}" "${glibc:-?}" "${isa:+, $isa}"
done
bash "$engine/packaging/linux/appimage.sh" "$package" "$version" "${APPIMAGETOOL:-}"
