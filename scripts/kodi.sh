#!/bin/bash

##################################################################
# Kodi 21.3-Omega build script for RK3326/R50H — builds two      #
# variants: kodi-gbm.unrot (normal RK3326 devices) and           #
# kodi-gbm.rot (R50H, RGA 270° rotation patch applied)            #
##################################################################

cur_wd="$PWD"
commit="a3a448d26b8d560a65655dab2cd122994dc4e146" # 21.3-Omega

if [ ! -d "xbmc/" ]; then
  git clone https://github.com/djparentx/xbmc
  if [[ $? != "0" ]]; then
    echo " "
    echo "There was an error while cloning the xbmc git. Is Internet active or did the git location change? Stopping here."
    exit 1
  fi
  cp patches/kodi-patch* xbmc/.
else
  echo " "
  echo "An xbmc subfolder already exists. Stopping here to not impact anything in the folder that may be needed. If not needed, please remove the xbmc folder and rerun this script."
  exit 1
fi

cd xbmc
git checkout $commit

kodi_patches=$(find *.patch 2>/dev/null)

if [[ ! -z "$kodi_patches" ]]; then
  for patching in kodi-patch*
  do
    if [[ $patching == *"r50h"* ]]; then
      echo " "
      echo "Skipping the $patching for now and making a note to apply that later"
      sleep 3
      kodi_rotationpatch="yes"
    else
      patch -Np1 < "$patching"
      if [[ $? != "0" ]]; then
        echo " "
        echo "There was an error while applying $patching. Stopping here."
        exit 1
      fi
      rm "$patching"
    fi
  done
fi

mkdir -p build-unrot
cd build-unrot

cmake -DCMAKE_INSTALL_PREFIX=/usr \
      -DCORE_PLATFORM_NAME=gbm \
      -DAPP_RENDER_SYSTEM=gles \
      -DENABLE_X11=OFF \
      -DENABLE_WAYLAND=OFF \
      -DENABLE_VAAPI=OFF \
      -DENABLE_VDPAU=OFF \
      -DENABLE_INTERNAL_FFMPEG=ON \
      ..

if [[ $? != "0" ]]; then
  echo " "
  echo "There was an error while configuring the unrotated Kodi build. Stopping here."
  exit 1
fi

make -j$(nproc)

if [[ $? != "0" ]]; then
  echo " "
  echo "There was an error while building unrotated Kodi at commit $commit. Stopping here."
  exit 1
fi

strip tools/depends/target/kodi-gbm/kodi-gbm 2>/dev/null || strip kodi-gbm

if [ ! -d "$cur_wd/kodi-64/" ]; then
  mkdir -v $cur_wd/kodi-64
fi

cp kodi-gbm $cur_wd/kodi-64/kodi-gbm.unrot

echo " "
echo "Kodi (unrotated) has been built and placed in $cur_wd/kodi-64/kodi-gbm.unrot"

cd ..

if [[ $kodi_rotationpatch == "yes" ]]; then
  for patching in kodi-patch*
  do
    patch -Np1 < "$patching"
    if [[ $? != "0" ]]; then
      echo " "
      echo "There was an error while applying $patching. Stopping here."
      exit 1
    fi
    rm "$patching"
  done
fi

mkdir -p build-rot
cd build-rot

cmake -DCMAKE_INSTALL_PREFIX=/usr \
      -DCORE_PLATFORM_NAME=gbm \
      -DAPP_RENDER_SYSTEM=gles \
      -DENABLE_X11=OFF \
      -DENABLE_WAYLAND=OFF \
      -DENABLE_VAAPI=OFF \
      -DENABLE_VDPAU=OFF \
      -DENABLE_INTERNAL_FFMPEG=ON \
      ..

if [[ $? != "0" ]]; then
  echo " "
  echo "There was an error while configuring the rotated Kodi build. Stopping here."
  exit 1
fi

make -j$(nproc)

if [[ $? != "0" ]]; then
  echo " "
  echo "There was an error while building rotated Kodi at commit $commit with the R50H rotation patch applied. Stopping here."
  exit 1
fi

strip tools/depends/target/kodi-gbm/kodi-gbm 2>/dev/null || strip kodi-gbm

cp kodi-gbm $cur_wd/kodi-64/kodi-gbm.rot

echo " "
echo "Kodi (rotated for R50H) has been built and placed in $cur_wd/kodi-64/kodi-gbm.rot"
