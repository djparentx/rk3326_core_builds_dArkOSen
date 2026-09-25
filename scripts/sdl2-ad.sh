#!/bin/bash

##################################################################
# Build SDL2 at the advanced_drastic-compatible commit (3000.10) #
# with dArkOSen rotation patches applied.                        #
# 64-bit (aarch64) only.                                         #
##################################################################

cur_wd="$PWD"
commit="9c821dc21ccbd69b2bda421fdb35cb4ae2da8f5e" # SDL 2.0.30.10 (AD-compatible)
extension="3000.10"

if [ ! -d "SDL-ad/" ]; then
    git clone https://github.com/libsdl-org/SDL SDL-ad
    if [[ $? != "0" ]]; then
        echo "Error cloning SDL. Stopping."
        exit 1
    fi
    cp patches/sdl2-patch* SDL-ad/.
else
    echo "SDL-ad subfolder already exists. Remove it and rerun. Stopping."
    exit 1
fi

cd SDL-ad
git checkout $commit

for patching in sdl2-patch*; do
    patch -Np1 < "$patching"
    if [[ $? != "0" ]]; then
        echo "Error applying $patching. Stopping."
        exit 1
    fi
    rm "$patching"
done

git checkout 528b71284f491bcb6ecfd4ab7e00d37b296bd621 -- src/joystick/SDL_gamecontroller.c
git revert -n e5024fae3decb724e397d3c9dbcb744d8c79aac1

mkdir build && cd build

cmake -DCMAKE_INSTALL_PREFIX=/usr/lib/aarch64-linux-gnu \
      -DCMAKE_INSTALL_LIBDIR="/usr/lib/aarch64-linux-gnu" \
      -DSDL_STATIC=OFF \
      -DSDL_LIBC=ON \
      -DSDL_GCC_ATOMICS=ON \
      -DSDL_ALTIVEC=OFF \
      -DSDL_OSS=OFF \
      -DSDL_ALSA=ON \
      -DSDL_ALSA_SHARED=ON \
      -DSDL_JACK=OFF \
      -DSDL_JACK_SHARED=OFF \
      -DSDL_ESD=OFF \
      -DSDL_ESD_SHARED=OFF \
      -DSDL_ARTS=OFF \
      -DSDL_ARTS_SHARED=OFF \
      -DSDL_NAS=OFF \
      -DSDL_NAS_SHARED=OFF \
      -DSDL_LIBSAMPLERATE=ON \
      -DSDL_LIBSAMPLERATE_SHARED=OFF \
      -DSDL_SNDIO=OFF \
      -DSDL_DISKAUDIO=OFF \
      -DSDL_DUMMYAUDIO=OFF \
      -DSDL_WAYLAND=OFF \
      -DSDL_WAYLAND_QT_TOUCH=OFF \
      -DSDL_WAYLAND_SHARED=OFF \
      -DSDL_COCOA=OFF \
      -DSDL_DIRECTFB=OFF \
      -DSDL_VIVANTE=OFF \
      -DSDL_DIRECTFB_SHARED=OFF \
      -DSDL_FUSIONSOUND=OFF \
      -DSDL_FUSIONSOUND_SHARED=OFF \
      -DSDL_DUMMYVIDEO=OFF \
      -DSDL_PTHREADS=ON \
      -DSDL_PTHREADS_SEM=ON \
      -DSDL_DIRECTX=OFF \
      -DSDL_CLOCK_GETTIME=OFF \
      -DSDL_RPATH=OFF \
      -DSDL_RENDER_D3D=OFF \
      -DSDL_X11=OFF \
      -DSDL_OPENGLES=ON \
      -DSDL_VULKAN=OFF \
      -DSDL_KMSDRM=ON \
      -DSDL_PULSEAUDIO=ON ..

export LDFLAGS="${LDFLAGS} -lrga"

make -j$(nproc)
if [[ $? != "0" ]]; then
    echo "Build failed. Stopping."
    exit 1
fi

strip libSDL2-2.0.so.0.$extension

mkdir -p $cur_wd/sdl2-ad-64
cp libSDL2-2.0.so.0.$extension $cur_wd/sdl2-ad-64/.

echo ""
echo "Built libSDL2-2.0.so.0.$extension -> sdl2-ad-64/"