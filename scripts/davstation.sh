#!/bin/bash

##################################################################
# DavStation (SDL3) native build for RK3326 / aarch64.           #
# Runs inside a debian:trixie arm64 container.                   #
# Standalone script: NOT run through builds.sh.                  #
##################################################################

set -e

cur_wd="$PWD"
DAV_REPO="https://github.com/djparentx/DavStation.git"
DAV_REF="${DAV_REF:-main}"
SDL3_BRANCH="release-3.4.16"
CLANG_VER="19"
SRC="$cur_wd/davstation-src"
DEPS="$cur_wd/davstation-deps"
DEPS_BUILD="$cur_wd/davstation-deps-build"
OUT="$cur_wd/davstation-64"

if [ -d "$OUT" ]; then
  echo "davstation-64 already exists. Remove it and rerun."
  exit 1
fi
mkdir -p "$OUT"

# DavStation source (the workflow clones it first so the deps cache key can use the deps script)
if [ ! -d "$SRC/.git" ]; then
  git clone "$DAV_REPO" "$SRC"
fi
cd "$SRC"
git fetch -q origin "$DAV_REF"
git checkout -q FETCH_HEAD
DAV_COMMIT=$(git rev-parse HEAD)
echo "DavStation commit: $DAV_COMMIT"

# Dependencies (skipped when restored from cache)
if [ ! -f "$DEPS/.complete" ]; then
  rm -rf "$DEPS" "$DEPS_BUILD"
  mkdir -p "$DEPS" "$DEPS_BUILD"
  cd "$DEPS_BUILD"

  "$SRC/scripts/deps/build-dependencies-linux.sh" \
    -system-freetype -system-harfbuzz -system-libjpeg -system-libpng -system-libwebp -system-zstd -system-qt \
    "$DEPS" || { echo "build-dependencies-linux.sh failed. Stopping here."; exit 1; }

  # SDL3 for headers and linking only. The device uses its own patched SDL3 at runtime.
  git clone --depth 1 -b "$SDL3_BRANCH" https://github.com/libsdl-org/SDL.git SDL3
  cmake -S SDL3 -B SDL3/build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$DEPS" \
    -DSDL_SHARED=ON \
    -DSDL_STATIC=OFF \
    -DSDL_TESTS=OFF \
    -DSDL_EXAMPLES=OFF \
    -DSDL_UNIX_CONSOLE_BUILD=ON \
    -DSDL_X11=OFF \
    -DSDL_WAYLAND=OFF \
    -DSDL_KMSDRM=ON \
    -DSDL_VULKAN=ON \
    -DSDL_OPENGL=OFF \
    -DSDL_OPENGLES=ON \
    -DSDL_ALSA=ON \
    -DSDL_PULSEAUDIO=OFF \
    -DSDL_PIPEWIRE=OFF \
    -DSDL_JACK=OFF \
    -DSDL_SNDIO=OFF
  cmake --build SDL3/build --parallel
  cmake --install SDL3/build

  touch "$DEPS/.complete"
  cd "$cur_wd"
  rm -rf "$DEPS_BUILD"
fi

# Configure and build
cd "$SRC"
TUNE_FLAGS="-mcpu=cortex-a35+nocrypto"
cmake -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=clang-$CLANG_VER \
  -DCMAKE_CXX_COMPILER=clang++-$CLANG_VER \
  -DCMAKE_AR=/usr/bin/llvm-ar-$CLANG_VER \
  -DCMAKE_RANLIB=/usr/bin/llvm-ranlib-$CLANG_VER \
  -DCMAKE_C_FLAGS="$TUNE_FLAGS" \
  -DCMAKE_CXX_FLAGS="$TUNE_FLAGS" \
  -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld" \
  -DCMAKE_SHARED_LINKER_FLAGS="-fuse-ld=lld" \
  -DCMAKE_MODULE_LINKER_FLAGS="-fuse-ld=lld" \
  -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
  -DCMAKE_PREFIX_PATH="$DEPS" \
  -DBUILD_DAVSTATION_FRONTEND=ON \
  -DBUILD_QT_FRONTEND=OFF \
  -DENABLE_X11=OFF \
  -DENABLE_WAYLAND=OFF \
  -DENABLE_VULKAN=ON \
  -DENABLE_OPENGL=ON \
  -DHOST_PAGE_SIZE=4096 \
  -DHOST_CACHE_LINE_SIZE=64

cmake --build build --parallel --target davstation

# Collect output: davstation, resources/, lib/
mkdir -p "$OUT/bin/lib"
cp -a build/bin/davstation "$OUT/bin/"
cp -a build/bin/resources "$OUT/bin/"
cp "$cur_wd/openbios/openbios.bin" "$cur_wd/openbios/LICENSE.openbios" "$OUT/bin/resources/"
llvm-strip-$CLANG_VER "$OUT/bin/davstation"

# Bundle shared libs from the deps folder that the binary needs (SDL3 excluded: the device uses the patched system one)
DEPLIB="$DEPS/lib"
queue=("$OUT/bin/davstation")
seen=" "
while [ ${#queue[@]} -gt 0 ]; do
  cur="${queue[0]}"
  queue=("${queue[@]:1}")
  for need in $(readelf -d "$cur" | grep NEEDED | sed 's/.*\[\(.*\)\]/\1/'); do
    case "$seen" in *" $need "*) continue ;; esac
    seen="$seen$need "
    case "$need" in libSDL3.so*) continue ;; esac
    if [ -e "$DEPLIB/$need" ]; then
      cp -L "$DEPLIB/$need" "$OUT/bin/lib/$need"
      queue+=("$OUT/bin/lib/$need")
    fi
  done
done

# Loaded with dlopen at runtime, not in NEEDED
for dyn in libshaderc_shared.so libspirv-cross-c-shared.so.0; do
  cp -L "$DEPLIB/$dyn" "$OUT/bin/lib/$dyn" || { echo "$dyn missing from $DEPLIB. Stopping here."; exit 1; }
done

patchelf --set-rpath '$ORIGIN/lib' "$OUT/bin/davstation"
for lib in "$OUT"/bin/lib/*; do
  patchelf --set-rpath '$ORIGIN' "$lib"
done
ls -l "$OUT/bin/lib"

# Build info
{
  echo "DavStation commit: $DAV_COMMIT"
  echo "SDL3 headers: $SDL3_BRANCH"
  echo "Compiler: clang-$CLANG_VER ($TUNE_FLAGS)"
  echo "--- binary dynamic section ---"
  readelf -d "$OUT/bin/davstation" | grep -E 'NEEDED|RPATH|RUNPATH' || true
  echo "--- bundled libs ---"
  ls -1 "$OUT/bin/lib"
  echo "--- max GLIBC required ---"
  readelf -W --dyn-syms "$OUT/bin/davstation" | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -1 || true
} > "$OUT/build-info.txt"
cat "$OUT/build-info.txt"

tar -zcf "$OUT/davstation_pkg.tar.gz" -C "$OUT/bin" .

echo " "
echo "DavStation has been created and placed in the davstation-64 subfolder"
