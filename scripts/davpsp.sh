#!/bin/bash

##################################################################
# DavPSP standalone build (CI use).                              #
# Same cmake options and clang flags as ppsspp.sh, DavPSP repo.  #
# Run it through: ./builds.sh davpsp                             #
##################################################################

cur_wd="$PWD"
bitness="$(getconf LONG_BIT)"
BRANCH="${DAVPSP_BRANCH:-main}"
BASE_VERSION="v1.20.4"

	# DavPSP standalone build
	if [[ "$var" == "davpsp" ]] && [[ "$bitness" == "64" ]]; then
	 cd $cur_wd

	  echo "Building davpsp $BRANCH"

	  if [ ! -d "davpsp-src/" ]; then
		git clone --recursive --depth 1 --shallow-submodules --branch ${BRANCH} "https://${DAVPSP_TOKEN:+x-access-token:${DAVPSP_TOKEN}@}github.com/djparentx/DavPSP.git" davpsp-src
		if [[ $? != "0" ]]; then
		  echo " "
		  echo "There was an error while cloning the davpsp git.  Stopping here."
		  exit 1
		fi
	  else
		echo " "
		echo "A davpsp-src subfolder already exists.  Stopping here to not impact anything in the folder that may be needed.  If not needed, please remove the davpsp-src folder and rerun this script."
		echo " "
		exit 1
	  fi

	  cd davpsp-src
	  davpsp_hash=$(git rev-parse HEAD | cut -c -7)

	  mkdir build
	  cd build

	  # The shallow clone has no tags, so git describe would give a bare hash.
	  # Pin a parseable version (savestate/version checks parse it); NO_UPDATE stops cmake overwriting it.
	  printf '%s\n' '// This is a generated file.' '' "const char *PPSSPP_GIT_VERSION = \"${BASE_VERSION}-davpsp-${davpsp_hash}\";" '' '#define PPSSPP_GIT_VERSION_NO_UPDATE 1' > git-version.cpp

	  cmake -DUSING_EGL=OFF \
		-DCMAKE_BUILD_TYPE=Release \
		-DUSING_GLES2=ON \
		-DUSE_FFMPEG=YES \
		-DUSE_SYSTEM_FFMPEG=NO \
		-DUSE_SYSTEM_LIBPNG=OFF \
		-DVULKAN=ON \
		-DSDL2_LIBRARY="/usr/lib/aarch64-linux-gnu/libSDL2.so" \
		-DSDL2_INCLUDE_DIR="/usr/include/SDL2" \
		-DUSE_VULKAN_DISPLAY_KHR=ON \
		-DUSING_X11_VULKAN=OFF \
		-DUSE_WAYLAND_WSI=OFF \
		-DUSING_FBDEV=ON \
		-DCMAKE_C_COMPILER=/usr/bin/clang \
		-DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
		-DCMAKE_C_COMPILER_LAUNCHER=ccache \
		-DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
		-DCMAKE_C_FLAGS="-Ofast -D_NDEBUG -march=armv8-a+crc -mtune=cortex-a35 -ftree-vectorize -funsafe-math-optimizations" \
		-DCMAKE_CXX_FLAGS="-Ofast -D_NDEBUG -march=armv8-a+crc -mtune=cortex-a35 -ftree-vectorize -funsafe-math-optimizations -fpermissive" \
		-DUSE_MINIUPNPC=OFF \
		-DUSING_QT_UI=OFF \
		-DUSE_DISCORD=OFF \
		-DCMAKE_EXE_LINKER_FLAGS="-Wl,--allow-shlib-undefined" \
		../.
	  make -j$(nproc) 2>&1 | tee make.log

	  if [[ ${PIPESTATUS[0]} != "0" ]]; then
		echo " "
		echo "=== FIRST ERRORS ==="
		grep -n -m10 -B3 -A8 "error:\|undefined\|\*\*\*" make.log
		echo "There was an error while building davpsp.  Stopping here."
		exit 1
	  fi

	  strip davpsp

	  if [ ! -d "../../davpsp$bitness/" ]; then
		mkdir -v ../../davpsp$bitness
	  fi

	  cp davpsp ../../davpsp$bitness/.
	  tar -zchvf ../../davpsp$bitness/davpsp_pkg_${davpsp_hash}.tar.gz assets/ davpsp

	  echo " "
	  echo "davpsp executable and davpsp_pkg_${davpsp_hash}.tar.gz package have been created and placed in the davpsp$bitness subfolder"

	fi
