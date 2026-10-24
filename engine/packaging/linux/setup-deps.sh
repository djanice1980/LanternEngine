#!/usr/bin/env bash
# The engine's Linux build libraries, built from source into one prefix without root: the same
# libraries at the same versions as packaging/linux/setup-ubuntu.sh builds into /opt/deps (static
# and position independent, linked into libbbgpu.so), for any distribution whose own packages
# differ (Arch and CachyOS, Fedora, NixOS without the shell). The compilers, CMake, Ninja, Git,
# curl, Python 3, pkg-config and the Vulkan loader, X11, Wayland and OpenSSL development files
# come from the system; SDL3 is taken from the system when pkg-config knows it, else built here.
#
#   packaging/linux/setup-deps.sh [prefix]
#
# The prefix is the argument, else BB_DEPS_PREFIX, else engine/out/deps (/opt/deps as root;
# ~/.cache/lantern-engine/deps when the checkout's path holds a space, which pkg-config paths
# cannot). build.sh and packaging/linux/build.sh look in those places on their own. One stamp per library: a rerun skips what is installed. Build output goes to the
# log named at the end of each step; a failing step stops the script with its last lines.
set -euo pipefail
engine=$(cd -- "$(dirname -- "$0")/../.." && pwd)
prefix=${1:-${BB_DEPS_PREFIX:-}}
if [[ -z $prefix ]]; then
    if [[ $(id -u) == 0 ]]; then prefix=/opt/deps
    # pkg-config paths cannot hold a space (CMake splits them): a checkout under one keeps the
    # libraries in the user's cache folder instead.
    elif [[ $engine == *" "* ]]; then prefix=${XDG_CACHE_HOME:-$HOME/.cache}/lantern-engine/deps
    else prefix=$engine/out/deps; fi
fi
[[ $prefix != *" "* ]] || { echo "setup-deps: the prefix cannot hold a space: $prefix" >&2; exit 1; }
mkdir -p "$prefix"
prefix=$(cd -- "$prefix" && pwd)
jobs=${BB_JOBS:-$(nproc)}
for tool in clang clang++ cmake ninja git curl tar python3 pkg-config make; do
    command -v "$tool" >/dev/null || { echo "setup-deps: $tool is needed (install it with your package manager)" >&2; exit 1; }
done
export CC=${CC:-clang} CXX=${CXX:-clang++}
export PATH=$prefix/bin:$PATH
export PKG_CONFIG_PATH=$prefix/lib/pkgconfig:$prefix/share/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}
export CMAKE_PREFIX_PATH=$prefix${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}
deps=(-G Ninja -DCMAKE_BUILD_TYPE=Release "-DCMAKE_INSTALL_PREFIX=$prefix"
      -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DBUILD_SHARED_LIBS=OFF -DCMAKE_POLICY_VERSION_MINIMUM=3.5)
work=${BB_DEPS_WORK:-$prefix-work}
mkdir -p "$work"
cd "$work"
echo "deps: into $prefix (work in $work, $jobs jobs)"

built() { [[ -f $prefix/.stamp-$1 ]]; }
stamp() { touch "$prefix/.stamp-$1"; }
step() { # name command...: runs it with its output in a log, shown on failure
    local name=$1
    shift
    if ! "$@" > "$work/$name.log" 2>&1; then
        tail -40 "$work/$name.log" >&2
        echo "deps: $name failed (log: $work/$name.log)" >&2
        exit 1
    fi
}
fetch() { # name tag url [--recursive]
    rm -rf "$1"
    git clone -q --depth 1 -b "$2" ${4:-} "$3" "$1"
}
cmake_dep() { # name tag url [cmake args...]
    local name=$1 tag=$2 url=$3
    shift 3
    built "$name" && return
    echo "deps: $name $tag"
    fetch "$name" "$tag" "$url" --recursive
    step "$name" bash -c 'cmake -S "$0" -B "$0/b" "$@" && cmake --build "$0/b" -j "'"$jobs"'" && cmake --install "$0/b"' "$name" "${deps[@]}" "$@"
    rm -rf "$name"
    stamp "$name"
}

# Boost: headers only (the renderer uses boost::container, icl and a few others). The release's
# CMake archive installs the headers of the named libraries and what they include.
if ! built boost; then
    echo 'deps: boost 1.86.0 (headers)'
    rm -rf boost
    curl -fsSL --retry 3 -o boost.tar.xz \
        https://github.com/boostorg/boost/releases/download/boost-1.86.0/boost-1.86.0-cmake.tar.xz
    mkdir boost && tar -xJf boost.tar.xz -C boost --strip-components=1 && rm boost.tar.xz
    step boost bash -c 'cmake -S boost -B boost/b "$@" -DBOOST_INSTALL_LAYOUT=system -DBOOST_ENABLE_CMAKE=ON \
        -DBOOST_INCLUDE_LIBRARIES="container;icl;algorithm;asio;functional;graph;intrusive;move;range;static_string;unordered;variant;asio;beast;process;iostreams" \
        -DBOOST_EXCLUDE_LIBRARIES="python;mpi;graph_parallel" && cmake --build boost/b -j "'"$jobs"'" && cmake --install boost/b' "${deps[@]}"
    rm -rf boost
    stamp boost
fi

cmake_dep vulkan-headers v1.4.363 https://github.com/KhronosGroup/Vulkan-Headers.git
cmake_dep vma v3.3.0 https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator.git
cmake_dep fmt 12.0.0 https://github.com/fmtlib/fmt.git -DFMT_TEST=OFF -DFMT_DOC=OFF
cmake_dep magic_enum v0.9.7 https://github.com/Neargye/magic_enum.git \
    -DMAGIC_ENUM_OPT_BUILD_EXAMPLES=OFF -DMAGIC_ENUM_OPT_BUILD_TESTS=OFF
cmake_dep robin-map v1.4.0 https://github.com/Tessil/robin-map.git
cmake_dep miniz 3.1.0 https://github.com/richgel999/miniz.git \
    -DBUILD_EXAMPLES=OFF -DBUILD_TESTS=OFF -DBUILD_FUZZERS=OFF
cmake_dep nlohmann_json v3.11.3 https://github.com/nlohmann/json.git -DJSON_BuildTests=OFF
# xxHash's CMake project is a subfolder.
if ! built xxhash; then
    echo 'deps: xxHash v0.8.3'
    fetch xxhash v0.8.3 https://github.com/Cyan4973/xxHash.git
    step xxhash bash -c 'cmake -S xxhash/cmake_unofficial -B xxhash/b "$@" -DXXHASH_BUILD_XXHSUM=OFF &&
        cmake --build xxhash/b -j "'"$jobs"'" && cmake --install xxhash/b' "${deps[@]}"
    rm -rf xxhash
    stamp xxhash
fi
# Zydis with its Zycore installed beside it (zydis-config.cmake looks for Zycore's own config,
# which the bundled copy does not install; Zydis itself builds with the bundled copy).
if ! built zydis-zycore; then
    echo 'deps: zydis v4.1.1 + zycore'
    fetch zydis v4.1.1 https://github.com/zyantific/zydis.git --recursive
    step zydis bash -c 'cmake -S zydis/dependencies/zycore -B zydis/zb "$@" -DZYCORE_BUILD_TESTS=OFF -DZYCORE_BUILD_EXAMPLES=OFF &&
        cmake --build zydis/zb -j "'"$jobs"'" && cmake --install zydis/zb &&
        cmake -S zydis -B zydis/b "$@" -DZYDIS_BUILD_TOOLS=OFF -DZYDIS_BUILD_EXAMPLES=OFF -DZYDIS_BUILD_DOXYGEN=OFF &&
        cmake --build zydis/b -j "'"$jobs"'" && cmake --install zydis/b' "${deps[@]}"
    rm -rf zydis
    stamp zydis-zycore
fi
# miniupnpc (bbnet's port mapping), static as on Windows: its CMake project is a subfolder.
if ! built miniupnpc; then
    echo 'deps: miniupnpc 2.2.8'
    fetch miniupnp miniupnpc_2_2_8 https://github.com/miniupnp/miniupnp.git
    step miniupnpc bash -c 'cmake -S miniupnp/miniupnpc -B miniupnp/b "$@" -DUPNPC_BUILD_STATIC=ON \
        -DUPNPC_BUILD_SHARED=OFF -DUPNPC_BUILD_TESTS=OFF -DUPNPC_BUILD_SAMPLE=OFF &&
        cmake --build miniupnp/b -j "'"$jobs"'" && cmake --install miniupnp/b' "${deps[@]}"
    rm -rf miniupnp
    stamp miniupnpc
fi
# Protobuf (bbnet's shadNet messages), with its Abseil.
cmake_dep protobuf v29.5 https://github.com/protocolbuffers/protobuf.git \
    -Dprotobuf_BUILD_TESTS=OFF -Dprotobuf_ABSL_PROVIDER=module -DABSL_PROPAGATE_CXX_STD=ON \
    -Dprotobuf_INSTALL=ON -Dutf8_range_ENABLE_INSTALL=ON
# SDL3: shared (its video, audio and input backends are loaded at run time from the system). The
# system's own SDL3 serves when pkg-config knows it (Arch, Fedora 42, Ubuntu 25.04 and later).
if ! built sdl3; then
    if pkg-config --exists 'sdl3 >= 3.2'; then
        echo "deps: SDL3 $(pkg-config --modversion sdl3) from the system"
    else
        echo 'deps: SDL3 release-3.4.18'
        fetch sdl release-3.4.18 https://github.com/libsdl-org/SDL.git
        step sdl3 bash -c 'cmake -S sdl -B sdl/b -G Ninja -DCMAKE_BUILD_TYPE=Release "-DCMAKE_INSTALL_PREFIX='"$prefix"'" \
            -DSDL_SHARED=ON -DSDL_STATIC=OFF -DSDL_TESTS=OFF -DSDL_EXAMPLES=OFF &&
            cmake --build sdl/b -j "'"$jobs"'" && cmake --install sdl/b'
        rm -rf sdl
    fi
    stamp sdl3
fi
# nasm for FFmpeg's x86 assembly, built here when the system has neither nasm nor yasm.
if ! built nasm && ! command -v nasm >/dev/null && ! command -v yasm >/dev/null; then
    echo 'deps: nasm 2.16.03'
    rm -rf nasm
    curl -fsSL --retry 3 -o nasm.tar.xz https://www.nasm.us/pub/nasm/releasebuilds/2.16.03/nasm-2.16.03.tar.xz
    mkdir nasm && tar -xJf nasm.tar.xz -C nasm --strip-components=1 && rm nasm.tar.xz
    step nasm bash -c 'cd nasm && ./configure --prefix="'"$prefix"'" && make -j "'"$jobs"'" nasm && install -m755 nasm "'"$prefix"'/bin/nasm"'
    rm -rf nasm
    stamp nasm
fi
# FFmpeg: only what the game's movies need (H.264/HEVC video, AAC audio in MP4), no system
# libraries.
if ! built ffmpeg; then
    echo 'deps: FFmpeg n7.1.1'
    fetch ffmpeg n7.1.1 https://github.com/FFmpeg/FFmpeg.git
    step ffmpeg bash -c 'cd ffmpeg && ./configure --prefix="'"$prefix"'" --cc="$CC" --enable-pic --enable-static --disable-shared \
        --disable-autodetect --disable-programs --disable-doc --disable-network --disable-everything \
        --disable-avdevice --disable-avfilter --disable-postproc \
        --enable-decoder=h264,hevc,aac,aac_latm --enable-parser=h264,hevc,aac \
        --enable-demuxer=mov,mpegts,h264,hevc,aac --enable-protocol=file --enable-swscale \
        --enable-swresample && make -j "'"$jobs"'" && make install'
    rm -rf ffmpeg
    stamp ffmpeg
fi
# patchelf (the package's RUNPATHs) from PyPI when the system lacks it: the wheel carries the program.
if ! built patchelf && ! command -v patchelf >/dev/null; then
    echo 'deps: patchelf (PyPI wheel)'
    step patchelf bash -c 'python3 -m venv "'"$prefix"'/venv" && "'"$prefix"'/venv/bin/pip" -q install patchelf &&
        mkdir -p "'"$prefix"'/bin" && ln -sf ../venv/bin/patchelf "'"$prefix"'/bin/patchelf"'
    stamp patchelf
fi
echo "Linux build libraries ready in $prefix"
echo "Build with: BB_DEPS_PREFIX=$prefix bash build.sh"
