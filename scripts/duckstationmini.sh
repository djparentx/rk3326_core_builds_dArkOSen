#!/bin/bash

##################################################################
# DuckStation Mini (SDL3) cross-compile for RK3326 / aarch64.    #
# Runs inside ghcr.io/duckstation/cross-build-arm64 (clang-19).  #
# Standalone script: NOT run through builds.sh.                  #
##################################################################

set -e

cur_wd="$PWD"
DS_COMMIT="fedd294bdeada11505bef868bcb65bf89a05cf90"
SRC="$cur_wd/duckstationmini-src"
OUT="$cur_wd/duckstationmini-64"
TOOLCHAIN="$HOME/toolchain.cmake"

if [ -d "$SRC" ]; then
  echo "duckstationmini-src already exists. Remove it and rerun."
  exit 1
fi

mkdir -p "$OUT" "$SRC"
cd "$SRC"
git init -q
git remote add origin https://github.com/stenzek/duckstation.git
git fetch --depth 1 origin "$DS_COMMIT"
git checkout -q FETCH_HEAD

# Upstream bug: opengl_context.cpp uses OpenGLContextEGL but only gets its header via the X11/Wayland headers
sed -i 's|^#ifdef ENABLE_EGL$|#ifdef ENABLE_EGL\n#include "opengl_context_egl.h"|' src/util/opengl_context.cpp
grep -q '^#include "opengl_context_egl.h"$' src/util/opengl_context.cpp || { echo "opengl_context.cpp include fix did not apply. Stopping here."; exit 1; }

# Prebuilt dependency pack (version pinned by the DuckStation commit)
DEPS_VERSION=$(cat dep/PREBUILT-VERSION)
echo "Using dependency pack $DEPS_VERSION"
cd dep/prebuilt
for pack in deps-linux-x64 deps-linux-cross-arm64; do
  curl --retry 5 --retry-all-errors -fLO "https://github.com/duckstation/dependencies/releases/download/${DEPS_VERSION}/${pack}.tar.xz" || { echo "Failed to download ${pack}.tar.xz for ${DEPS_VERSION}. Stopping here."; exit 1; }
  tar -xf "${pack}.tar.xz"
  rm "${pack}.tar.xz"
done
cd "$SRC"

# Detect the clang version the container actually ships (image tag :latest drifts)
CLANG_VER=""
for v in 25 24 23 22 21 20 19 18; do
  if command -v clang-$v >/dev/null 2>&1 && command -v llvm-ar-$v >/dev/null 2>&1; then
    CLANG_VER=$v
    break
  fi
done
if [ -z "$CLANG_VER" ]; then
  echo "No usable clang-NN found in PATH. Compiler tools present:"
  ls /usr/bin /usr/local/bin 2>/dev/null | grep -i "clang\|llvm" || true
  exit 1
fi
echo "Using clang-$CLANG_VER"

# Toolchain file: pack's toolchain + clang/lld, same as upstream's cross workflow
cp dep/prebuilt/linux-cross-arm64/toolchain.cmake "$TOOLCHAIN"
cat >> "$TOOLCHAIN" <<EOF
set(CMAKE_FIND_ROOT_PATH "$PWD/dep/prebuilt/linux-cross-arm64;/arm64-chroot")
set(CMAKE_C_COMPILER clang-${CLANG_VER})
set(CMAKE_C_COMPILER_AR llvm-ar-${CLANG_VER})
set(CMAKE_C_COMPILER_RANLIB llvm-ranlib-${CLANG_VER})
set(CMAKE_CXX_COMPILER clang++-${CLANG_VER})
set(CMAKE_CXX_COMPILER_AR llvm-ar-${CLANG_VER})
set(CMAKE_CXX_COMPILER_RANLIB llvm-ranlib-${CLANG_VER})
set(CMAKE_EXE_LINKER_FLAGS_INIT "-fuse-ld=lld")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "-fuse-ld=lld")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "-fuse-ld=lld")
EOF

cmake -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
  -DBUILD_QT_FRONTEND=OFF \
  -DBUILD_MINI_FRONTEND=ON \
  -DENABLE_X11=OFF \
  -DENABLE_WAYLAND=OFF \
  -DENABLE_VULKAN=OFF \
  -DHOST_MIN_PAGE_SIZE=4096 \
  -DHOST_MAX_PAGE_SIZE=16384 \
  -DHOST_CACHE_LINE_SIZE=64

cmake --build build --parallel --target duckstation-mini

# Collect output
mkdir -p "$OUT/bin"
cp -a build/bin/. "$OUT/bin/"
llvm-strip-${CLANG_VER} "$OUT/bin/duckstation-mini"

# Diagnostics for the first run
{
  echo "DuckStation commit: $DS_COMMIT"
  echo "Dependency pack: $DEPS_VERSION"
  echo "--- pack SDL3 version ---"
  grep -h "PACKAGE_VERSION " dep/prebuilt/linux-cross-arm64/lib/cmake/SDL3/SDL3ConfigVersion.cmake || echo "not found"
  echo "--- pack SDL3 libs ---"
  ls -l dep/prebuilt/linux-cross-arm64/lib | grep -i sdl3 || echo "none in lib/"
  echo "--- binary dynamic section ---"
  readelf -d "$OUT/bin/duckstation-mini" | grep -E 'NEEDED|RPATH|RUNPATH|SONAME' || true
  echo "--- max GLIBC required ---"
  readelf -W --dyn-syms "$OUT/bin/duckstation-mini" | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -1 || true
} > "$OUT/build-info.txt"
cat "$OUT/build-info.txt"

tar -zcf "$OUT/duckstationmini_pkg.tar.gz" -C "$OUT/bin" .

echo " "
echo "DuckStation Mini has been created and placed in the duckstationmini-64 subfolder"
