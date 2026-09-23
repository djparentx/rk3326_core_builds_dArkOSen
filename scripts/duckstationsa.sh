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

	# Duckstation standalone package
	if [[ "$var" == "duckstationsa" ]] && [[ "$bitness" == "64" ]]; then
	 cd $cur_wd

	  # Now we'll start the clone and build of duckstation
	  if [ ! -d "duckstation/" ]; then
		git clone --recursive https://github.com/stenzek/duckstation.git

		if [[ $? != "0" ]]; then
		  echo " "
		  echo "There was an error while cloning the duckstation standalone git.  Is Internet active or did the git location change?  Stopping here."
		  exit 1
		fi
		cp patches/duckstationsa-patch* duckstation/.
	  else
		echo " "
		echo "A duckstation standalone subfolder already exists.  Stopping here to not impact anything in the folder that may be needed.  If not needed, please remove the duckstation folder and rerun this script."
		echo " "
		exit 1
	  fi

	 # Ensure dependencies are installed and available
     neededlibs=(  )
     updateapt="N"
     for libs in "${neededlibs[@]}"
     do
          dpkg -s "${libs}" &>/dev/null
          if [[ $? != "0" ]]; then
           if [[ "$updateapt" == "N" ]]; then
            apt-get -y update
            updateapt="Y"
           fi
           apt-get -y install "${libs}"
           if [[ $? != "0" ]]; then
            echo " "
            echo "Could not install needed library ${libs}.  Stopping here so this can be reviewed."
            exit 1
           fi
          fi
     done

	 cd duckstation
     git checkout 5ab5070d73f1acc51e064bd96be4ba6ce3c06f5c

	cp "$cur_wd/mali/shims/gbm_shim.c" src/duckstation-nogui/.
	cp "$cur_wd/mali/shims/wayland_egl_shim.c" src/duckstation-nogui/.
	 
	 duckstationsa_patches=$(find *.patch)
	 
	 if [[ ! -z "$duckstationsa_patches" ]]; then
	  for patching in duckstationsa-patch*
	  do
		 if [[ $patching == *"chirgb10"* ]]; then
		   echo " "
		   echo "Skipping the $patching for now and making a note to apply that later"
		   sleep 3
		   chikey_patch="yes"
		 else
		   patch -Np1 < "$patching"
		   if [[ $? != "0" ]]; then
			echo " "
			echo "There was an error while applying $patching.  Stopping here."
			exit 1
		   fi
		   rm "$patching"
		 fi
	  done
	  fi

	 if [ ! -d "build" ]; then
           mkdir -p build-a35
           cd build-a35
           rm -f CMakeCache.txt
           cmake -DANDROID=OFF \
	               -DENABLE_DISCORD_PRESENCE=OFF \
	               -DUSE_X11=OFF \
	               -DBUILD_QT_FRONTEND=OFF \
	               -DBUILD_NOGUI_FRONTEND=ON \
	               -DCMAKE_BUILD_TYPE=Release \
	               -DBUILD_SHARED_LIBS=OFF \
	               -DUSE_SDL2=ON \
	               -DENABLE_CHEEVOS=ON \
                   -DUSE_FBDEV=OFF \
                   -DUSE_EVDEV=ON \
                   -DUSE_EGL=ON \
                   -DUSE_DRMKMS=ON \
                   -DUSE_MALI=OFF \
                   -DCMAKE_C_FLAGS="-Ofast -march=armv8-a+crc -mtune=cortex-a35 -DNDEBUG" \
                   -DCMAKE_CXX_FLAGS="-Ofast -march=armv8-a+crc -mtune=cortex-a35 -DNDEBUG" \
                   ..
           if [[ $? != "0" ]]; then
			       echo " "
			       echo "There was an error that occured while configuring duckstation standalone (a35).  Stopping here."
               exit 1
           fi

           make -j$(nproc)
           if [[ $? != "0" ]]; then
			     echo " "
			     echo "There was an error that occured while making duckstation standalone (a35).  Stopping here."
             exit 1
           fi
           strip bin/duckstation-nogui

           if [ ! -d "../../duckstationsa-$bitness/" ]; then
			     mkdir -v ../../duckstationsa-$bitness
		       fi

	       cp bin/duckstation-nogui ../../duckstationsa-$bitness/duckstationsa-a35
	       if [[ $? != "0" ]]; then
			     echo " "
			     echo "There was an error copying the duckstationsa-a35 binary.  Stopping here."
		         exit 1
	       fi
           tar -zchvf ../../duckstationsa-$bitness/duckstationsa-a35_pkg_$(git rev-parse HEAD | cut -c -7).tar.gz bin/duckstation-nogui ../data/database/ ../data/resources/ ../data/shaders/
	       if [[ $? != "0" ]]; then
			     echo " "
			     echo "There was an error packaging the duckstationsa-a35 tarball.  Stopping here."
		         exit 1
	       fi

	       echo " "
	       echo "duckstationsa-a35 has been created and placed in the rk3326_core_builds/duckstationsa-$bitness subfolder"

           cd ..

           mkdir -p build-generic
           cd build-generic
           rm -f CMakeCache.txt
           cmake -DANDROID=OFF \
	               -DENABLE_DISCORD_PRESENCE=OFF \
	               -DUSE_X11=OFF \
	               -DBUILD_QT_FRONTEND=OFF \
	               -DBUILD_NOGUI_FRONTEND=ON \
	               -DCMAKE_BUILD_TYPE=Release \
	               -DBUILD_SHARED_LIBS=OFF \
	               -DUSE_SDL2=ON \
	               -DENABLE_CHEEVOS=ON \
                   -DUSE_FBDEV=OFF \
                   -DUSE_EVDEV=ON \
                   -DUSE_EGL=ON \
                   -DUSE_DRMKMS=ON \
                   -DUSE_MALI=OFF \
                   -DCMAKE_C_FLAGS="-Ofast -march=armv8-a+crc -DNDEBUG" \
                   -DCMAKE_CXX_FLAGS="-Ofast -march=armv8-a+crc -DNDEBUG" \
                   ..
           if [[ $? != "0" ]]; then
			       echo " "
			       echo "There was an error that occured while configuring duckstation standalone (generic).  Stopping here."
               exit 1
           fi

           make -j$(nproc)
           if [[ $? != "0" ]]; then
			     echo " "
			     echo "There was an error that occured while making duckstation standalone (generic).  Stopping here."
             exit 1
           fi
           strip bin/duckstation-nogui

           if [ ! -d "../../duckstationsa-$bitness/" ]; then
			     mkdir -v ../../duckstationsa-$bitness
		       fi

	       cp bin/duckstation-nogui ../../duckstationsa-$bitness/duckstationsa-generic
	       if [[ $? != "0" ]]; then
			     echo " "
			     echo "There was an error copying the duckstationsa-generic binary.  Stopping here."
		         exit 1
	       fi
           tar -zchvf ../../duckstationsa-$bitness/duckstationsa-generic_pkg_$(git rev-parse HEAD | cut -c -7).tar.gz bin/duckstation-nogui ../data/database/ ../data/resources/ ../data/shaders/
	       if [[ $? != "0" ]]; then
			     echo " "
			     echo "There was an error packaging the duckstationsa-generic tarball.  Stopping here."
		         exit 1
	       fi

	       echo " "
	       echo "duckstationsa-generic has been created and placed in the rk3326_core_builds/duckstationsa-$bitness subfolder"

            if [[ $chikey_patch == "yes" ]]; then
              cd ..
        	  for patching in duckstationsa-patch*
        	  do
                git checkout src/frontend-common/sdl_controller_interface.cpp
        	    patch -Np1 < "$patching"
        		if [[ $? != "0" ]]; then
        		  echo " "
        		  echo "There was an error while applying $patching.  Stopping here."
        		  exit 1
        		fi
        		rm "$patching"
        	  done
        	fi

           cd build
           make -j$(nproc)
           if [[ $? != "0" ]]; then
		     echo " "
		     echo "There was an error that occured while making the duckstation standalone.  Stopping here."
             exit 1
           fi
           bin/duckstation-nogui

           if [ ! -d "../../duckstationsa-$bitness/" ]; then
		     mkdir -v ../../duckstationsa-$bitness
	       fi

	       cp bin/duckstation-nogui ../../duckstationsa-$bitness/duckstation-nogui.chirgb10
	       
	       echo " "
	       echo "The duckstation standalone executable for the chi and rgb10 has been created and has been placed in the rk3326_core_builds/duckstationsa-$bitness subfolder"
	fi
