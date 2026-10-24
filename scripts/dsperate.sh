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

	# DSperate Standalone build
	if [[ "$var" == "dsperate" ]]  && [[ "$bitness" == "64" ]]; then
	 cd $cur_wd

	  # Now we'll start the clone and build of dsperate
	  if [ ! -d "DSperate/" ]; then
		git clone --recursive https://github.com/beebono/DSperate.git

		if [[ $? != "0" ]]; then
		  echo " "
		  echo "There was an error while cloning the dsperate standalone git.  Is Internet active or did the git location change?  Stopping here."
		  exit 1
		fi
		if compgen -G "patches/dsperate-patch*" > /dev/null; then
		  cp patches/dsperate-patch* DSperate/.
		fi
	  else
		echo " "
		echo "A DSperate subfolder already exists.  Stopping here to not impact anything in the folder that may be needed.  If not needed, please remove the DSperate folder and rerun this script."
		echo " "
		exit 1
	  fi

	 cd DSperate

	 if compgen -G "dsperate-patch*" > /dev/null; then
	  for patching in dsperate-patch*
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

	 ccache_args=""
	 if command -v ccache > /dev/null; then
	   ccache_args="-DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache"
	 fi

           cmake -DDSPERATE_TESTS=OFF \
                 -DDSPERATE_HEADLESS=OFF \
                 -DDSPERATE_WAYLAND=OFF \
                 -DDSPERATE_PGO=OFF \
                 -DDSPERATE_TUNE=-mtune=cortex-a35 \
                 -DCMAKE_EXE_LINKER_FLAGS=-Wl,--allow-shlib-undefined \
                 $ccache_args \
                 --preset host

           if [[ $? != "0" ]]; then
		     echo " "
		     echo "There was an error while configuring the dsperate standalone.  Stopping here."
              exit 1
           fi

           cmake --build --preset host -j$(nproc)

           if [[ $? != "0" ]]; then
		     echo " "
		     echo "There was an error that occured while making the dsperate standalone.  Stopping here."
              exit 1
           fi

           strip build/host/src/frontend/sdl/dsperate

           if [ ! -d "../dsperate-$bitness/" ]; then
	         mkdir -v ../dsperate-$bitness
           fi

	   cp build/host/src/frontend/sdl/dsperate ../dsperate-$bitness/.
	   cp configs/default.ini ../dsperate-$bitness/.
	   git rev-parse HEAD > ../dsperate-$bitness/dsperate.commit

	   echo " "
	   echo "The dsperate executable has been created and has been placed in the rk3326_core_builds/dsperate-$bitness subfolder"

	fi