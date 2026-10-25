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

	 # dArkOSen: portrait panel that SDL presents as landscape -> use DSperate's own kms scanout + NEON rotation
	 sed -i 's|      if (m.hdisplay == w \&\& m.vdisplay == h) { mode = m; found = true; break; }|      if ((m.hdisplay == w \&\& m.vdisplay == h) \|\| (m.hdisplay == h \&\& m.vdisplay == w)) { mode = m; w_ = m.hdisplay; h_ = m.vdisplay; found = true; break; }|' src/frontend/sdl/display_drm.cpp
	 sed -i 's|  if (!dr->open(win_, ow, oh, display_index_)) { scaled_ = false; rot_ = 0; return false; }|&\n  if (!rot_ \&\& ow != oh \&\& dr->width() == oh \&\& dr->height() == ow) rot_ = 270;|' src/frontend/sdl/display.cpp
	 sed -i 's|  if (out_) { SDL_GetWindowSize(win_, \&w, \&h); if (rotated()) std::swap(w, h); return w > 0 \&\& h > 0; }|  if (out_) { SDL_GetWindowSize(win_, \&w, \&h); if (w == out_->height() \&\& h == out_->width()) { w = out_->width(); h = out_->height(); } if (rotated()) std::swap(w, h); return w > 0 \&\& h > 0; }|' src/frontend/sdl/display.cpp
	 sed -i 's|    if (w != out_->width() \|\| h != out_->height()) {|    if ((w != out_->width() \|\| h != out_->height()) \&\& !(w == out_->height() \&\& h == out_->width())) {|' src/frontend/sdl/display.cpp

	 # dArkOSen defaults: no realtime, adaptive frameskip, select = hotkey modifier
	 sed -i 's|^# realtime = rr |realtime = off |' configs/default.ini
	 sed -i 's|^# frameskip = 0 |frameskip = 2 |' configs/default.ini
	 sed -i 's|^# modifier = guide$|modifier = back|' configs/default.ini
	 sed -i 's|^# quit = mod+start+back$|quit = mod+start|' configs/default.ini
	 sed -i 's|^# pause = mod+start$|pause = mod+x|' configs/default.ini
	 sed -i 's|^# fast_forward = mod++righttrigger$|fast_forward = mod+dpup|' configs/default.ini
	 sed -i 's|^# save_state = mod+rightshoulder$|save_state = mod++righttrigger|' configs/default.ini
	 sed -i 's|^# load_state = mod+leftshoulder$|load_state = mod++lefttrigger|' configs/default.ini
	 sed -i 's|^# layout_next = mod+back$|layout_next = mod+b|' configs/default.ini
	 sed -i 's|^# layout_prev = mod+x$|layout_prev = mod+a|' configs/default.ini
	 sed -i 's|^# screen_swap = mod+y$|screen_swap = mod+y|' configs/default.ini

	 ccache_args=""
	 if command -v ccache > /dev/null; then
	   ccache_args="-DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache"
	 fi

           cmake -DCMAKE_C_COMPILER=gcc-12 \
                 -DCMAKE_CXX_COMPILER=g++-12 \
                 -DDSPERATE_TESTS=OFF \
                 -DDSPERATE_HEADLESS=OFF \
                 -DDSPERATE_WAYLAND=OFF \
                 -DDSPERATE_PGO=use \
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