#!/bin/bash

##################################################################
# Created by Christian Haitian for use to easily update          #
# various standalone emulators, libretro cores, and other        #
# various programs for the RK3326 platform for various Linux     #
# based distributions.                                           #
# See the LICENSE.md file at the top-level directory of this     #
# repository.                                                    #
##################################################################

cur_wd="$PWD"
bitness="$(getconf LONG_BIT)"
TAG="v2.6"

	# flycastsa build
	if [[ "$var" == "flycastsa" || "$var" == "all" ]] && [[ "$bitness" == "64" ]]; then
	 cd $cur_wd
	  if [ ! -d "flycast/" ]; then
		git clone --depth 1 --branch ${TAG} https://github.com/flyinghead/flycast.git
		if [[ $? != "0" ]]; then
		  echo " "
		  echo "There was an error while cloning the flycast standalone git.  Is Internet active or did the git location change?  Stopping here."
		  exit 1
		 fi
		cp patches/flycastsa-patch* flycast/.
		cp mali/shims/gbm_shim.c flycast/.
		cp mali/shims/wayland_egl_shim.c flycast/.
	  fi

	 cd flycast/
	 git checkout ${TAG}
	 git submodule update --init --depth 1
	 sed -i 's/\-O[23]/-Ofast/' CMakeLists.txt
	 
	 flycastsa_patches=$(find *.patch)
	 
	 if [[ ! -z "$flycastsa_patches" ]]; then
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
	 fi

      if [[ "$0" != *"builds-alt"* ]]; then
        update-alternatives --set gcc "/usr/local/bin/aarch64-linux-gnu-gcc-13"
        update-alternatives --set g++ "/usr/local/bin/aarch64-linux-gnu-g++-13"
        export CPLUS_INCLUDE_PATH=/usr/include/c++/13:/usr/include/c++/13/backward:/usr/local/include/c++/13/aarch64-linux-gnu
      fi

	  for sdlmode in unrot rot
	  do
	    cd $cur_wd/flycast
	    rm -rf ../flycast-build
	    mkdir ../flycast-build
	    cd ../flycast-build

	    export CXXFLAGS="${CXXFLAGS} -Wno-error=array-bounds"

	    if [[ "$sdlmode" == "rot" ]]; then
	      hostsdlflag="-DUSE_HOST_SDL=ON"
	      shimflag="-DFLYCAST_LINK_MALI_SHIMS=ON"
	    else
	      hostsdlflag="-DUSE_HOST_SDL=OFF"
	      shimflag="-DFLYCAST_LINK_MALI_SHIMS=OFF"
	    fi

	    cmake -S ../flycast \
	      -DCMAKE_RULE_MESSAGES=OFF \
	      -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
	      -DCMAKE_BUILD_TYPE="Release" \
	      -DCMAKE_C_FLAGS_RELEASE="-DNDEBUG" \
	      -DCMAKE_CXX_FLAGS_RELEASE="-DNDEBUG" \
	      -DCMAKE_C_COMPILER_LAUNCHER=ccache \
	      -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
	      -DWITH_SYSTEM_ZLIB=ON \
	      -DUSE_PULSEAUDIO=OFF \
	      -DUSE_OPENMP=ON \
	      -DUSE_VULKAN=OFF \
	      -DUSE_GLES=ON ${hostsdlflag} ${shimflag} -B .

	    make -j$(nproc)

	    if [[ $? != "0" ]]; then
	      if [[ "$0" != *"builds-alt"* ]]; then
		    update-alternatives --set gcc "/usr/bin/gcc-8"
		    update-alternatives --set g++ "/usr/bin/g++-8"
		    unset CPLUS_INCLUDE_PATH
		  fi
		  echo " "
		  echo "There was an error while building the $sdlmode flycast standalone emulator.  Stopping here."
		  exit 1
	    fi

	    strip flycast

	    if [ ! -d "../flycastsa-$(getconf LONG_BIT)/" ]; then
		  mkdir -v ../flycastsa-$(getconf LONG_BIT)
	    fi

	    cp flycast ../flycastsa-$(getconf LONG_BIT)/flycast-rk3326.${sdlmode}

	    echo " "
	    echo "Flycast standalone ($sdlmode) has been created and has been placed in the rk3326_core_builds/flycastsa-$(getconf LONG_BIT) subfolder"
	  done

	  if [[ "$0" != *"builds-alt"* ]]; then
	    update-alternatives --set gcc "/usr/bin/gcc-8"
	    update-alternatives --set g++ "/usr/bin/g++-8"
	    unset CPLUS_INCLUDE_PATH
	  fi
	fi
