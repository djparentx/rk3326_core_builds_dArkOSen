#!/bin/bash

##################################################################
# Flycast standalone v2.7 test build (CI use).                   #
# Same patches and gcc-tune flags as flycastsatest, tag v2.7.    #
# Run it through: ./builds.sh flycastsa27                        #
##################################################################

cur_wd="$PWD"
bitness="$(getconf LONG_BIT)"
TAG="v2.7"

	# flycastsa27 build
	if [[ "$var" == "flycastsa27" ]] && [[ "$bitness" == "64" ]]; then
	  FLY_CC="gcc"; FLY_CXX="g++"
	  FLY_FLAGS="-Ofast -march=armv8-a+crc -mtune=cortex-a35 -ftree-vectorize -funsafe-math-optimizations -DNDEBUG -g1"
	  FLY_LINK=""
	  FLY_AR="/usr/bin/ar"; FLY_RANLIB="/usr/bin/ranlib"; FLY_BREAKPAD="ON"; FLY_OPENMP="ON"

	  echo "Building flycast $TAG ($FLY_CC, $FLY_FLAGS)"

	  cd $cur_wd
	  if [ ! -d "flycast/" ]; then
		git clone --depth 1 --branch ${TAG} https://github.com/flyinghead/flycast.git
		if [[ $? != "0" ]]; then
		  echo " "
		  echo "There was an error while cloning the flycast standalone git.  Stopping here."
		  exit 1
		fi
		cp patches/flycastsa-patch* patches/flycastsa27-patch* flycast/.
		cp mali/shims/gbm_shim.c flycast/.
		cp mali/shims/wayland_egl_shim.c flycast/.
	  fi

	  cd flycast/
	  git checkout ${TAG}
	  git submodule update --init --recursive --depth 1

	  rm -f flycastsa-patch-004-link-mali-shims.patch
	  
	  for patching in flycastsa-patch* flycastsa27-patch*
	  do
		patch -Np1 < "$patching"
		if [[ $? != "0" ]]; then
		  echo " "
		  echo "There was an error while applying $patching.  Stopping here."
		  exit 1
		fi
		rm "$patching"
	  done

	  printf '%s\n' '' 'if(FLYCAST_LINK_MALI_SHIMS)' '  target_sources(${PROJECT_NAME} PRIVATE gbm_shim.c wayland_egl_shim.c)' '  target_link_libraries(${PROJECT_NAME} PRIVATE gbm)' 'endif()' >> CMakeLists.txt
	  sed -i 's/LINK_FLAGS_RELEASE -s)/LINK_FLAGS_RELEASE "")/' CMakeLists.txt
	  
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
	    -DUSE_OPENMP="$FLY_OPENMP" \
	    -DUSE_VULKAN=OFF \
	    -DUSE_GLES=ON -DUSE_HOST_SDL=ON -DUSE_ALSA=ON -DFLYCAST_LINK_MALI_SHIMS=ON -B .

	  make -j$(nproc) 2>&1 | tee make.log
	  if [[ ${PIPESTATUS[0]} != "0" ]]; then
		echo " "
		echo "=== FIRST ERRORS ==="
		grep -n -m10 -B3 -A8 "error:\|undefined\|\*\*\*" make.log
		echo "There was an error while building the flycast standalone emulator.  Stopping here."
		exit 1
	  fi

	  if [ ! -d "../flycastsa-64/" ]; then
		mkdir -v ../flycastsa-64
	  fi

	  cp flycast ../flycastsa-64/flycast-$TAG
	  readelf -p .comment flycast | head -5

	  echo " "
	  echo "flycast-$TAG has been created and placed in the flycastsa-64 subfolder"
	fi