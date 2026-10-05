#!/bin/bash

##################################################################
# Flycast standalone compiler/flag test builds (CI use).         #
# The variant is chosen with the FLY_VARIANT environment         #
# variable: gcc-tune, gcc-notune, gcc-O3 or clang-lto.           #
# Run it through: ./builds.sh flycastsatest                      #
##################################################################

cur_wd="$PWD"
bitness="$(getconf LONG_BIT)"
TAG="v2.6"

	# flycastsatest build
	if [[ "$var" == "flycastsatest" ]] && [[ "$bitness" == "64" ]]; then
	  case "$FLY_VARIANT" in
	    gcc-tune)
	      FLY_CC="gcc"; FLY_CXX="g++"
	      FLY_FLAGS="-Ofast -march=armv8-a+crc -mtune=cortex-a35 -ftree-vectorize -funsafe-math-optimizations -DNDEBUG"
	      FLY_LINK=""
	      ;;
	    gcc-notune)
	      FLY_CC="gcc"; FLY_CXX="g++"
	      FLY_FLAGS="-Ofast -march=armv8-a+crc -ftree-vectorize -funsafe-math-optimizations -DNDEBUG"
	      FLY_LINK=""
	      ;;
	    gcc-O3)
	      FLY_CC="gcc"; FLY_CXX="g++"
	      FLY_FLAGS="-O3 -march=armv8-a+crc -DNDEBUG"
	      FLY_LINK=""
	      ;;
	    clang-lto)
	      FLY_CC="clang"; FLY_CXX="clang++"
	      FLY_FLAGS="-O3 -march=armv8-a+crc -flto=thin -DNDEBUG"
	      FLY_LINK="-fuse-ld=lld"
	      ;;
	    *)
	      echo "FLY_VARIANT must be one of: gcc-tune gcc-notune gcc-O3 clang-lto"
	      exit 1
	      ;;
	  esac
	  FLY_AR="/usr/bin/ar"; FLY_RANLIB="/usr/bin/ranlib"; FLY_BREAKPAD="ON"
	  if [[ "$FLY_VARIANT" == "clang-lto" ]]; then
	    FLY_AR="/usr/bin/llvm-ar"; FLY_RANLIB="/usr/bin/llvm-ranlib"; FLY_BREAKPAD="OFF"
	  fi

	  echo "Building flycast variant: $FLY_VARIANT ($FLY_CC, $FLY_FLAGS)"

	  cd $cur_wd
	  if [ ! -d "flycast/" ]; then
		git clone --depth 1 --branch ${TAG} https://github.com/flyinghead/flycast.git
		if [[ $? != "0" ]]; then
		  echo " "
		  echo "There was an error while cloning the flycast standalone git.  Stopping here."
		  exit 1
		fi
		cp patches/flycastsa-patch* flycast/.
		cp mali/shims/gbm_shim.c flycast/.
		cp mali/shims/wayland_egl_shim.c flycast/.
	  fi

	  cd flycast/
	  git checkout ${TAG}
	  git submodule update --init --depth 1

	  for patching in flycastsa-patch*
	  do
		patch -Np1 < "$patching"
		if [[ $? != "0" ]]; then
		  echo " "
		  echo "There was an error while applying $patching.  Stopping here."
		  exit 1
		fi
		rm "$patching"
	  done

	  cd $cur_wd
	  rm -rf flycast-build
	  mkdir flycast-build
	  cd flycast-build

	  export CXXFLAGS="${CXXFLAGS} -Wno-error=array-bounds"

	  cmake -S ../flycast \
	    -DCMAKE_RULE_MESSAGES=OFF \
	    -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
	    -DCMAKE_BUILD_TYPE="Release" \
	    -DCMAKE_C_COMPILER="$FLY_CC" \
	    -DCMAKE_CXX_COMPILER="$FLY_CXX" \
	    -DCMAKE_C_FLAGS="$FLY_FLAGS" \
	    -DCMAKE_CXX_FLAGS="$FLY_FLAGS" \
	    -DCMAKE_EXE_LINKER_FLAGS="$FLY_LINK" \
	    -DCMAKE_AR="$FLY_AR" \
	    -DCMAKE_RANLIB="$FLY_RANLIB" \
	    -DUSE_BREAKPAD="$FLY_BREAKPAD" \
	    -DCMAKE_C_COMPILER_LAUNCHER=ccache \
	    -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
	    -DWITH_SYSTEM_ZLIB=ON \
	    -DUSE_PULSEAUDIO=OFF \
	    -DUSE_OPENMP=ON \
	    -DUSE_VULKAN=OFF \
	    -DUSE_GLES=ON -DUSE_HOST_SDL=ON -DUSE_ALSA=OFF -DFLYCAST_LINK_MALI_SHIMS=ON -B .

	  make -j$(nproc) 2>&1 | tee make.log
	  if [[ ${PIPESTATUS[0]} != "0" ]]; then
		echo " "
		echo "=== FIRST ERRORS ==="
		grep -n -m10 -B3 -A8 "error:\|undefined\|\*\*\*" make.log
		echo "There was an error while building the flycast standalone emulator.  Stopping here."
		exit 1
	  fi

	  strip flycast

	  if [ ! -d "../flycastsa-64/" ]; then
		mkdir -v ../flycastsa-64
	  fi

	  cp flycast ../flycastsa-64/flycast-$FLY_VARIANT
	  readelf -p .comment flycast | head -5

	  echo " "
	  echo "flycast-$FLY_VARIANT has been created and placed in the flycastsa-64 subfolder"
	fi