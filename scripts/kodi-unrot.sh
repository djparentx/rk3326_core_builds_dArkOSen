#!/bin/bash

##################################################################
# Kodi 21.3-Omega build script for R36H Pro Max — vanilla build, #
# no RGA/rotation patch (landscape-native panel, no rotation     #
# needed)                                                         #
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
else
  echo " "
  echo "An xbmc subfolder already exists. Stopping here to not impact anything in the folder that may be needed. If not needed, please remove the xbmc folder and rerun this script."
  exit 1
fi

cd xbmc
git checkout $commit

mkdir -p build-unrot
cd build-unrot

cmake -DCMAKE_INSTALL_PREFIX=/opt/kodi \
      -DCORE_PLATFORM_NAME=gbm \
      -DAPP_RENDER_SYSTEM=gles \
      -DENABLE_VAAPI=OFF \
      -DENABLE_VDPAU=OFF \
      -DENABLE_INTERNAL_FFMPEG=ON \
      -DENABLE_INTERNAL_PCRE=ON \
      -DENABLE_TESTING=OFF \
      ..

if [[ $? != "0" ]]; then
  echo " "
  echo "There was an error while configuring the unrotated Kodi build. Stopping here."
  exit 1
fi

make -j$(nproc)

echo "=== Kodi runtime dependencies ==="
ldd kodi-gbm

if [[ $? != "0" ]]; then
  echo " "
  echo "There was an error while building unrotated Kodi at commit $commit. Stopping here."
  exit 1
fi

strip tools/depends/target/kodi-gbm/kodi-gbm 2>/dev/null || strip kodi-gbm

mkdir -p "$cur_wd/kodi-64/lib"

for lib in \
    libpython3.12.so.1.0 \
    libdisplay-info.so.1 \
    libmysqlclient.so.21 \
    libfmt.so.9 \
    libspdlog.so.1.12 \
    libtag.so.1 \
    libtinyxml2.so.10
do
    libpath=$(ldd kodi-gbm | awk -v lib="$lib" '$1 == lib {print $3; exit}')
    cp -L "$libpath" "$cur_wd/kodi-64/lib/"
done

cp kodi-gbm "$cur_wd/kodi-64/kodi-gbm.unrot"

echo " "
echo "Kodi (unrotated, for Pro Max) has been built and placed in $cur_wd/kodi-64/kodi-gbm.unrot"
