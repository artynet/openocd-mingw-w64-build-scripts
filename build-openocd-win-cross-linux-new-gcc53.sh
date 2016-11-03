#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Script to cross build the 32/64-bit Windows version of OpenOCD with
# MinGW-w64 on GNU/Linux.
# Developed on Ubuntu 14.04 LTS.
# Also tested on Manjaro 0.8.11 and Fedora 21.
# Does not work properly on Debian 7 (incomplete MinGW-w64, missing
# 32-bit libwinpthread-1.dll).

# Prerequisites:
#
# sudo apt-get install git libtool autoconf automake autotools-dev pkg-config
# sudo apt-get install doxygen texinfo texlive dos2unix
# sudo apt-get install mingw-w64 mingw-w64-tools mingw-w64-dev

# ----- Parse actions and command line options -----

ACTION_CLEAN=""
ACTION_GIT=""
TARGET_BITS="32"

while [ $# -gt 0 ]
do
  if [ "$1" == "clean" ]
  then
    ACTION_CLEAN="$1"
  elif [ "$1" == "pull" ]
  then
    ACTION_GIT="$1"
elif [ "$1" == "checkout-primo" ]
  then
    ACTION_GIT="$1"
elif [ "$1" == "checkout-nrf52" ]
  then
    ACTION_GIT="$1"
elif [ "$1" == "clone" ]
  then
    ACTION_GIT="$1"
elif [ "$1" == "checkout-master" ]
  then
    ACTION_GIT="$1"
  elif [ "$1" == "-32" -o "$1" == "-m32" -o "$1" == "-w32" ]
  then
    TARGET_BITS="32"
  elif [ "$1" == "-64" -o "$1" == "-m64" -o "$1" == "-w64" ]
  then
    TARGET_BITS="64"
  else
    echo "Unknown action/option $1"
    exit 1
  fi

  shift
done

OPENOCD_WORK_FOLDER=$PWD/work

OPENOCD_WORKING_FOLDER=$PWD

MAKE_JOBS=${MAKE_JOBS:-"-j4"}

# ----- Local variables -----

# For updates, please check the corresponding pages.

# http://www.intra2net.com/en/developer/libftdi/download.php
LIBFTDI="libftdi1-1.2"

# https://sourceforge.net/projects/libusb-win32/files/libusb-win32-releases/
LIBUSB_W32_PREFIX="libusb-win32"
LIBUSB_W32_VERSION="1.2.6.0"
LIBUSB_W32="${LIBUSB_W32_PREFIX}-${LIBUSB_W32_VERSION}"
LIBUSB_W32_FOLDER="${LIBUSB_W32_PREFIX}-src-${LIBUSB_W32_VERSION}"
LIBUSB_W32_ARCHIVE="${LIBUSB_W32_FOLDER}.zip"

# https://sourceforge.net/projects/libusb/files/libusb-1.0/
LIBUSB1="libusb-1.0.19"

# https://github.com/signal11/hidapi/downloads
HIDAPI="hidapi-0.7.0"

HIDAPI_TARGET="windows"
HIDAPI_OBJECT="hid.o"

# OpenOCD build defs
OPENOCD_TARGET="win${TARGET_BITS}"

OPENOCD_GIT_FOLDER="${OPENOCD_WORK_FOLDER}/openocd-arduino"
OPENOCD_DOWNLOAD_FOLDER="${OPENOCD_WORK_FOLDER}/download"
OPENOCD_BUILD_FOLDER="${OPENOCD_WORK_FOLDER}/build/${OPENOCD_TARGET}"
OPENOCD_INSTALL_FOLDER="${OPENOCD_WORKING_FOLDER}/objdir"
OPENOCD_OUTPUT_FOLDER="${OPENOCD_WORK_FOLDER}/output"

WGET="wget"
WGET_OUT="-O"

# Decide which toolchain to use.
if [ ${TARGET_BITS} == "32" ]
then
  CROSS_COMPILE_PREFIX="i686-w64-mingw32"
else
  CROSS_COMPILE_PREFIX="x86_64-w64-mingw32"
fi

# ----- Test if some tools are present -----

echo
echo "Test tools..."
echo
${CROSS_COMPILE_PREFIX}-gcc --version
unix2dos --version >/dev/null 2>/dev/null
git --version >/dev/null
automake --version >/dev/null
# makensis -VERSION >/dev/null

# Process actions.

if [ "${ACTION_CLEAN}" == "clean" ]
then
  # Remove most build and temporary folders.
  echo
  echo "Remove most build folders..."

  rm -rf "${OPENOCD_BUILD_FOLDER}"
  rm -rf "${OPENOCD_INSTALL_FOLDER}"
  rm -rf "${OPENOCD_WORK_FOLDER}/${LIBFTDI}"
  rm -rf "${OPENOCD_WORK_FOLDER}/${LIBUSB_W32_FOLDER}"
  rm -rf "${OPENOCD_WORK_FOLDER}/${LIBUSB1}"
  rm -rf "${OPENOCD_WORK_FOLDER}/${HIDAPI}"
  rm -rf "${OPENOCD_WORKING_FOLDER}"/*.tar.bz2

  echo
  echo "Clean completed. Proceed with a regular build."
  exit 0
fi

if [ "${ACTION_GIT}" == "pull" ]
then
  if [ -d "${OPENOCD_GIT_FOLDER}" ]
  then
    echo
    if [ "${USER}" == "ilg" ]
    then
      echo "Enter SourceForge password for git pull"
    fi
    cd "${OPENOCD_GIT_FOLDER}"
    git pull
    git submodule update

    rm -rf "${OPENOCD_BUILD_FOLDER}/openocd"

    # Prepare autotools.
    echo
    echo "bootstrap..."

    cd "${OPENOCD_GIT_FOLDER}"
    ./bootstrap

    echo
    echo "Pull completed. Proceed with a regular build."
    exit 0
  else
	echo "No git folder."
    exit 1
  fi
fi

if [ "${ACTION_GIT}" == "checkout-master" ]
then
  if [ -d "${OPENOCD_GIT_FOLDER}" ]
  then

    cd "${OPENOCD_GIT_FOLDER}"
    git pull
    git checkout master
    git reset --hard HEAD
    git submodule update

    rm -rf "${OPENOCD_BUILD_FOLDER}/openocd"

    # Prepare autotools.
    echo
    echo "bootstrap..."

    cd "${OPENOCD_GIT_FOLDER}"
    ./bootstrap

    echo
    echo "Pull completed. Proceed with a regular build."
    exit 0
  else
	echo "No git folder."
    exit 1
  fi
fi

if [ "${ACTION_GIT}" == "checkout-primo" ]
then
  if [ -d "${OPENOCD_GIT_FOLDER}" ]
  then

    cd "${OPENOCD_GIT_FOLDER}"
    git pull
    git checkout primo
    git reset --hard HEAD
    git submodule update

    rm -rf "${OPENOCD_BUILD_FOLDER}/openocd"

    # Prepare autotools.
    echo
    echo "bootstrap..."

    cd "${OPENOCD_GIT_FOLDER}"
    ./bootstrap

    echo
    echo "Pull completed. Proceed with a regular build."
    exit 0
  else
	echo "No git folder."
    exit 1
  fi
fi

if [ "${ACTION_GIT}" == "checkout-nrf52" ]
then
  if [ -d "${OPENOCD_GIT_FOLDER}" ]
  then

    cd "${OPENOCD_GIT_FOLDER}"
    git pull
    git checkout nrf52-test
    git reset --hard HEAD
    git submodule update

    rm -rf "${OPENOCD_BUILD_FOLDER}/openocd"

    # Prepare autotools.
    echo
    echo "bootstrap..."

    cd "${OPENOCD_GIT_FOLDER}"
    ./bootstrap

    echo
    echo "Pull completed. Proceed with a regular build."
    exit 0
  else
	echo "No git folder."
    exit 1
  fi
fi

if [ "${ACTION_GIT}" == "clone" ]
then
    if [ ! -d "${OPENOCD_GIT_FOLDER}" ]
    then
        mkdir -p "${OPENOCD_WORK_FOLDER}"
        cd "${OPENOCD_WORK_FOLDER}"

        # For regular read/only access, use the git url.
        git clone https://github.com/arduino-org/openocd-official-mirror.git openocd-arduino

        # Change to the gnuarmeclipse branch. On subsequent runs use "git pull".
        cd "${OPENOCD_GIT_FOLDER}"
        # git checkout gnuarmeclipse
        git submodule update

        # Prepare autotools.
        echo
        echo "bootstrap..."

        cd "${OPENOCD_GIT_FOLDER}"
        ./bootstrap

        echo
        echo "Clone completed. Proceed with a regular build."
        exit 0
    else
        echo "No git folder."
        exit 1
    fi
fi

# ----- Begin of common part ---------------------------------------------------

# Create the work folders.
mkdir -p "${OPENOCD_WORK_FOLDER}"

# Get the GNU ARM Eclipse OpenOCD git repository.

# The custom OpenOCD branch is available from the dedicated Git repository
# which is part of the GNU ARM Eclipse project hosted on SourceForge.
# Generally this branch follows the official OpenOCD master branch,
# with updates after every OpenOCD public release.

if [ ! -d "${OPENOCD_GIT_FOLDER}" ]
then
  cd "${OPENOCD_WORK_FOLDER}"

  # For regular read/only access, use the git url.
  git clone https://github.com/arduino-org/openocd-official-mirror.git -b nrf52-test openocd-arduino

  # Change to the gnuarmeclipse branch. On subsequent runs use "git pull".
  cd "${OPENOCD_GIT_FOLDER}"
  # git checkout gnuarmeclipse
  git submodule update

  # Prepare autotools.
  echo
  echo "bootstrap..."

  cd "${OPENOCD_GIT_FOLDER}"
  ./bootstrap
fi

# Get the current Git branch name, to know if we are building the stable or
# the development release.
cd "${OPENOCD_GIT_FOLDER}"
stag=`git rev-parse --short HEAD`
OPENOCD_GIT_HEAD=$(git symbolic-ref -q --short HEAD)

# ----- Build the USB libraries -----

# Both USB libraries are available from a single project LIBUSB
# 	http://www.libusb.info
# with source files ready to download from SourceForge
# 	https://sourceforge.net/projects/libusb/files

# Download the new USB library.
LIBUSB1_ARCHIVE="${LIBUSB1}.tar.bz2"
if [ ! -f "${OPENOCD_DOWNLOAD_FOLDER}/${LIBUSB1_ARCHIVE}" ]
then
  mkdir -p "${OPENOCD_DOWNLOAD_FOLDER}"

  cd "${OPENOCD_DOWNLOAD_FOLDER}"
  "${WGET}" "http://sourceforge.net/projects/libusb/files/libusb-1.0/${LIBUSB1}/${LIBUSB1_ARCHIVE}" \
  "${WGET_OUT}" "${LIBUSB1_ARCHIVE}"
fi

# Unpack the new USB library.
if [ ! -d "${OPENOCD_WORK_FOLDER}/${LIBUSB1}" ]
then
  cd "${OPENOCD_WORK_FOLDER}"
  tar -xjvf "${OPENOCD_DOWNLOAD_FOLDER}/${LIBUSB1_ARCHIVE}"
fi

# Build and install the new USB library.
if [ ! \( -d "${OPENOCD_BUILD_FOLDER}/${LIBUSB1}" \) -o \
     ! \( -f "${OPENOCD_INSTALL_FOLDER}/lib/libusb-1.0.a" -o \
          -f "${OPENOCD_INSTALL_FOLDER}/lib64/libusb-1.0.a" \) ]
then
  rm -rfv "${OPENOCD_BUILD_FOLDER}/${LIBUSB1}"
  mkdir -p "${OPENOCD_BUILD_FOLDER}/${LIBUSB1}"

  mkdir -p "${OPENOCD_INSTALL_FOLDER}"

  cd "${OPENOCD_BUILD_FOLDER}/${LIBUSB1}"
  # Configure
  CFLAGS="-Wno-non-literal-null-conversion -m${TARGET_BITS}" \
  PKG_CONFIG="${OPENOCD_WORKING_FOLDER}/scripts/cross-pkg-config" \
  "${OPENOCD_WORK_FOLDER}/${LIBUSB1}/configure" \
  --host="${CROSS_COMPILE_PREFIX}" \
  --prefix="${OPENOCD_INSTALL_FOLDER}"

  # Build
  make ${MAKE_JOBS} clean install

  # Remove DLLs to force static link for final executable.
  rm -f "${OPENOCD_INSTALL_FOLDER}/bin/libusb-1.0.dll"
  rm -f "${OPENOCD_INSTALL_FOLDER}/lib/libusb-1.0.dll.a"
  rm -f "${OPENOCD_INSTALL_FOLDER}/lib/libusb-1.0.la"
fi

# http://sourceforge.net/projects/libusb-win32

# Download the old Win32 USB library.
if [ ! -f "${OPENOCD_DOWNLOAD_FOLDER}/${LIBUSB_W32_ARCHIVE}" ]
then
  mkdir -p "${OPENOCD_DOWNLOAD_FOLDER}"

  cd "${OPENOCD_DOWNLOAD_FOLDER}"
  "${WGET}" "http://sourceforge.net/projects/libusb-win32/files/libusb-win32-releases/${LIBUSB_W32_VERSION}/${LIBUSB_W32_ARCHIVE}" \
  "${WGET_OUT}" "${LIBUSB_W32_ARCHIVE}"
fi

# Unpack the old Win32 USB library.
if [ ! -d "${OPENOCD_WORK_FOLDER}/${LIBUSB_W32_FOLDER}" ]
then
  cd "${OPENOCD_WORK_FOLDER}"
  unzip "${OPENOCD_DOWNLOAD_FOLDER}/${LIBUSB_W32_ARCHIVE}"
fi

# Build and install the old Win32 USB library.
if [ ! \( -d "${OPENOCD_BUILD_FOLDER}/${LIBUSB_W32}" \) -o \
     ! \( -f "${OPENOCD_INSTALL_FOLDER}/lib/libusb.a" -o \
           -f "${OPENOCD_INSTALL_FOLDER}/lib64/libusb.a" \)  ]
then
  mkdir -p "${OPENOCD_BUILD_FOLDER}/${LIBUSB_W32}"

  cd "${OPENOCD_BUILD_FOLDER}/${LIBUSB_W32}"
  cp -r "${OPENOCD_WORK_FOLDER}/${LIBUSB_W32_FOLDER}/"* \
    "${OPENOCD_BUILD_FOLDER}/${LIBUSB_W32}"

  echo
  echo "make libusb-win32..."

  cd "${OPENOCD_BUILD_FOLDER}/${LIBUSB_W32}"
  # Patch from:
  # https://gitorious.org/jtag-tools/openocd-mingw-build-scripts
  patch -p1 < "${OPENOCD_WORKING_FOLDER}/patches/${LIBUSB_W32}-mingw-w64.patch"

  # Build
  CFLAGS="-m${TARGET_BITS}" \
  make host_prefix=${CROSS_COMPILE_PREFIX} host_prefix_x86=i686-w64-mingw32 dll

  mkdir -p "${OPENOCD_INSTALL_FOLDER}/bin"
  cp -v "${OPENOCD_BUILD_FOLDER}/${LIBUSB_W32}/libusb0.dll" \
     "${OPENOCD_INSTALL_FOLDER}/bin"

  mkdir -p "${OPENOCD_INSTALL_FOLDER}/lib"
  cp -v "${OPENOCD_BUILD_FOLDER}/${LIBUSB_W32}/libusb.a" \
     "${OPENOCD_INSTALL_FOLDER}/lib"

  mkdir -p "${OPENOCD_INSTALL_FOLDER}/lib/pkgconfig"
  sed -e "s|XXX|${OPENOCD_INSTALL_FOLDER}|" \
    "${OPENOCD_WORKING_FOLDER}/pkgconfig/${LIBUSB_W32}.pc" \
    > "${OPENOCD_INSTALL_FOLDER}/lib/pkgconfig/libusb.pc"

  mkdir -p "${OPENOCD_INSTALL_FOLDER}/include/libusb"
  cp -v "${OPENOCD_BUILD_FOLDER}/${LIBUSB_W32}/src/lusb0_usb.h" \
     "${OPENOCD_INSTALL_FOLDER}/include/libusb/usb.h"

fi

# ----- Build the FTDI library -----

# There are two versions of the FDDI library; we recommend using the
# open source one, available from intra2net.
#	http://www.intra2net.com/en/developer/libftdi/

# Download the FTDI library.
LIBFTDI_ARCHIVE="${LIBFTDI}.tar.bz2"
if [ ! -f "${OPENOCD_DOWNLOAD_FOLDER}/${LIBFTDI_ARCHIVE}" ]
then
  mkdir -p "${OPENOCD_DOWNLOAD_FOLDER}"

  cd "${OPENOCD_DOWNLOAD_FOLDER}"
  "${WGET}" "http://www.intra2net.com/en/developer/libftdi/download/${LIBFTDI_ARCHIVE}" \
  "${WGET_OUT}" "${LIBFTDI_ARCHIVE}"
fi

# Unpack the FTDI library.
if [ ! -d "${OPENOCD_WORK_FOLDER}/${LIBFTDI}" ]
then
  cd "${OPENOCD_WORK_FOLDER}"
  tar -xjvf "${OPENOCD_DOWNLOAD_FOLDER}/${LIBFTDI_ARCHIVE}"

  cd "${OPENOCD_WORK_FOLDER}/${LIBFTDI}"
  # Patch to prevent the use of system libraries and force the use of local ones.
  patch -p0 < "${OPENOCD_WORKING_FOLDER}/patches/${LIBFTDI}-cmake-FindUSB1.patch"
fi

# Build and install the FTDI library.
if [ ! \( -d "${OPENOCD_BUILD_FOLDER}/${LIBFTDI}" \) -o \
     ! \( -f "${OPENOCD_INSTALL_FOLDER}/lib/libftdi1.a" -o \
           -f "${OPENOCD_INSTALL_FOLDER}/lib64/libftdi1.a" \)  ]
then
  rm -rfv "${OPENOCD_BUILD_FOLDER}/${LIBFTDI}"
  mkdir -p "${OPENOCD_BUILD_FOLDER}/${LIBFTDI}"

  mkdir -p "${OPENOCD_INSTALL_FOLDER}"

  echo
  echo "cmake libftdi..."

  cd "${OPENOCD_BUILD_FOLDER}/${LIBFTDI}"
  # Configure
  CFLAGS="-m${TARGET_BITS}" \
  \
  PKG_CONFIG_LIBDIR=\
"${OPENOCD_INSTALL_FOLDER}/lib/pkgconfig":\
"${OPENOCD_INSTALL_FOLDER}/lib64/pkgconfig" \
  \
  cmake \
  -DPKG_CONFIG_EXECUTABLE="${OPENOCD_WORKING_FOLDER}/scripts/cross-pkg-config" \
  -DCMAKE_TOOLCHAIN_FILE="${OPENOCD_WORK_FOLDER}/${LIBFTDI}/cmake/Toolchain-${CROSS_COMPILE_PREFIX}.cmake" \
  -DCMAKE_INSTALL_PREFIX="${OPENOCD_INSTALL_FOLDER}" \
  -DLIBUSB_INCLUDE_DIR="${OPENOCD_INSTALL_FOLDER}/include/libusb-1.0" \
  -DLIBUSB_LIBRARIES="${OPENOCD_INSTALL_FOLDER}/lib/libusb-1.0.a" \
  -DBUILD_TESTS:BOOL=off \
  -DFTDIPP:BOOL=off \
  -DPYTHON_BINDINGS:BOOL=off \
  -DEXAMPLES:BOOL=off \
  -DDOCUMENTATION:BOOL=off \
  -DFTDI_EEPROM:BOOL=off \
  "${OPENOCD_WORK_FOLDER}/${LIBFTDI}"

  # Build
  make ${MAKE_JOBS} clean install

  # Remove DLLs to force static link for final executable.
  rm -f "${OPENOCD_INSTALL_FOLDER}/bin/libftdi1.dll"
  rm -f "${OPENOCD_INSTALL_FOLDER}/bin/libftdi1-config"
  rm -f "${OPENOCD_INSTALL_FOLDER}/lib/libftdi1.dll.a"
  rm -f "${OPENOCD_INSTALL_FOLDER}/lib/pkgconfig/libftdipp1.pc"
fi

# exit 0

# ----- Build the HDI library -----

# This is just a simple wrapper over libusb.
# http://www.signal11.us/oss/hidapi/

# Download the HDI library.
HIDAPI_ARCHIVE="${HIDAPI}.zip"
if [ ! -f "${OPENOCD_DOWNLOAD_FOLDER}/${HIDAPI_ARCHIVE}" ]
then
  mkdir -p "${OPENOCD_DOWNLOAD_FOLDER}"

  cd "${OPENOCD_DOWNLOAD_FOLDER}"
  "${WGET}" "https://github.com/downloads/signal11/hidapi/${HIDAPI_ARCHIVE}" \
  "${WGET_OUT}" "${HIDAPI_ARCHIVE}"
fi

# Unpack the HDI library.
if [ ! -d "${OPENOCD_WORK_FOLDER}/${HIDAPI}" ]
then
  cd "${OPENOCD_WORK_FOLDER}"
  unzip "${OPENOCD_DOWNLOAD_FOLDER}/${HIDAPI_ARCHIVE}"
fi

# Build the new HDI library.
if [ ! -f "${OPENOCD_INSTALL_FOLDER}/lib/libhid.a" ]
then
  rm -rfv "${OPENOCD_BUILD_FOLDER}/${HIDAPI}"
  mkdir -p "${OPENOCD_BUILD_FOLDER}/${HIDAPI}"

  cp -r "${OPENOCD_WORK_FOLDER}/${HIDAPI}/"* \
    "${OPENOCD_BUILD_FOLDER}/${HIDAPI}"

  echo
  echo "make libhid..."

  cd "${OPENOCD_BUILD_FOLDER}/${HIDAPI}/${HIDAPI_TARGET}"
  CFLAGS="-m${TARGET_BITS}" \
  \
  PKG_CONFIG_=\
"${OPENOCD_INSTALL_FOLDER}/lib/pkgconfig":\
"${OPENOCD_INSTALL_FOLDER}/lib64/pkgconfig" \
  \
  make -f Makefile.mingw \
  CC=${CROSS_COMPILE_PREFIX}-gcc \
  "${HIDAPI_OBJECT}"

  # Make just compiles the file. Create the archive and convert it to library.
  # No dynamic/shared libs involved.
  ar -r  libhid.a "${HIDAPI_OBJECT}"
  ${CROSS_COMPILE_PREFIX}-ranlib libhid.a

  mkdir -p "${OPENOCD_INSTALL_FOLDER}/lib"
  cp -v libhid.a \
     "${OPENOCD_INSTALL_FOLDER}/lib"

  mkdir -p "${OPENOCD_INSTALL_FOLDER}/lib/pkgconfig"
  sed -e "s|XXX|${OPENOCD_INSTALL_FOLDER}|" \
    "${OPENOCD_WORKING_FOLDER}/pkgconfig/${HIDAPI}-${HIDAPI_TARGET}.pc" \
    > "${OPENOCD_INSTALL_FOLDER}/lib/pkgconfig/hidapi.pc"

  mkdir -p "${OPENOCD_INSTALL_FOLDER}/include/hidapi"
  cp -v "${OPENOCD_WORK_FOLDER}/${HIDAPI}/hidapi/hidapi.h" \
     "${OPENOCD_INSTALL_FOLDER}/include/hidapi"
fi

# On first run, create the build folder.
mkdir -p "${OPENOCD_BUILD_FOLDER}/openocd"

# ----- End of common part ----------------------------------------------------

# Configure OpenOCD. Use the same options as Freddie Chopin.

if [ ! \( -d "${OPENOCD_BUILD_FOLDER}/openocd" \) -o \
     ! \( -f "${OPENOCD_BUILD_FOLDER}/openocd/config.h" \) ]
then

  echo
  echo "configure..."

  cd "${OPENOCD_BUILD_FOLDER}/openocd"
  # All variables below are passed on the command line before 'configure'.
  # Be sure all these lines end in '\' to ensure lines are concatenated.
  OUTPUT_DIR="${OPENOCD_BUILD_FOLDER}" \
  \
  CPPFLAGS="-m${TARGET_BITS}" \
  PKG_CONFIG="${OPENOCD_WORKING_FOLDER}/scripts/cross-pkg-config" \
  PKG_CONFIG_LIBDIR="${OPENOCD_INSTALL_FOLDER}/lib/pkgconfig" \
  PKG_CONFIG_PREFIX="${OPENOCD_INSTALL_FOLDER}" \
  \
  "${OPENOCD_GIT_FOLDER}/configure" \
  --build="$(uname -m)-linux-gnu" \
  --host="${CROSS_COMPILE_PREFIX}" \
  --prefix="${OPENOCD_INSTALL_FOLDER}"  \
  --enable-aice \
  --enable-amtjtagaccel \
  --enable-armjtagew \
  --enable-cmsis-dap \
  --enable-ftdi \
  --enable-gw16012 \
  --enable-jlink \
  --enable-jtag_vpi \
  --enable-opendous \
  --enable-openjtag_ftdi \
  --enable-osbdm \
  --enable-legacy-ft2232_libftdi \
  --enable-parport \
  --disable-parport-ppdev \
  --enable-parport-giveio \
  --enable-presto_libftdi \
  --enable-remote-bitbang \
  --enable-rlink \
  --enable-stlink \
  --enable-ti-icdi \
  --enable-ulink \
  --enable-usb-blaster-2 \
  --enable-usb_blaster_libftdi \
  --enable-usbprog \
  --enable-vsllink

fi

# --datarootdir="${OPENOCD_INSTALL_FOLDER}" \
# --infodir="${OPENOCD_INSTALL_FOLDER}/info"  \
# --localedir="${OPENOCD_INSTALL_FOLDER}/locale"  \
# --mandir="${OPENOCD_INSTALL_FOLDER}/man"  \
# --docdir="${OPENOCD_INSTALL_FOLDER}/doc"  \

# ----- Full build, with documentation -----

# The bindir and pkgdatadir are required to configure bin and scripts folders
# at the same level in the hierarchy.
cd "${OPENOCD_BUILD_FOLDER}/openocd"
# make ${MAKE_JOBS} bindir="bin" pkgdatadir="" all pdf html
make ${MAKE_JOBS}
make install
make distclean

echo
echo "copy dynamic libs..."

if [ "${TARGET_BITS}" == "32" ]
then
	# libgcc_s_seh-1.dll
  CROSS_GCC_VERSION=$(${CROSS_COMPILE_PREFIX}-gcc --version | grep 'gcc' | sed -e 's/.*\s\([0-9]*\)[.]\([0-9]*\)[.]\([0-9]*\).*/\1.\2.\3/')
  #CROSS_GCC_VERSION=5.3-win32
  CROSS_GCC_VERSION_SHORT=$(echo $CROSS_GCC_VERSION | sed -e 's/\([0-9]*\)[.]\([0-9]*\)[.]\([0-9]*\).*/\1.\2/')
  if [ -f "/usr/lib/gcc/${CROSS_COMPILE_PREFIX}/${CROSS_GCC_VERSION}/libgcc_s_sjlj-1.dll" ]
  then
    cp -v "/usr/lib/gcc/${CROSS_COMPILE_PREFIX}/${CROSS_GCC_VERSION}/libgcc_s_sjlj-1.dll" \
      "${OPENOCD_INSTALL_FOLDER}/bin"
  elif [ -f "/usr/lib/gcc/${CROSS_COMPILE_PREFIX}/5.3-win32/libgcc_s_sjlj-1.dll" ]
  then
    cp -v "/usr/lib/gcc/${CROSS_COMPILE_PREFIX}/5.3-win32/libgcc_s_sjlj-1.dll" \
      "${OPENOCD_INSTALL_FOLDER}/bin"
  elif [ -f "/usr/lib/gcc/${CROSS_COMPILE_PREFIX}/${CROSS_GCC_VERSION_SHORT}/libgcc_s_sjlj-1.dll" ]
  then
    cp -v "/usr/lib/gcc/${CROSS_COMPILE_PREFIX}/${CROSS_GCC_VERSION_SHORT}/libgcc_s_sjlj-1.dll" \
      "${OPENOCD_INSTALL_FOLDER}/bin"
  else
    echo "Searching /usr for libgcc_s_sjlj-1.dll..."
    SJLJ_PATH=$(find /usr \! -readable -prune -o -name 'libgcc_s_sjlj-1.dll' -print | grep ${CROSS_COMPILE_PREFIX})
    cp -v ${SJLJ_PATH} "${OPENOCD_INSTALL_FOLDER}/bin"
  fi

  if [ -f "/usr/${CROSS_COMPILE_PREFIX}/lib/libwinpthread-1.dll" ]
  then
    cp "/usr/${CROSS_COMPILE_PREFIX}/lib/libwinpthread-1.dll" \
      "${OPENOCD_INSTALL_FOLDER}/bin"
  else
    echo "Searching /usr for libwinpthread-1.dll..."
    PTHREAD_PATH=$(find /usr \! -readable -prune -o -name 'libwinpthread-1.dll' -print | grep ${CROSS_COMPILE_PREFIX})
    cp -v "${PTHREAD_PATH}" "${OPENOCD_INSTALL_FOLDER}/bin"
  fi

fi

# Copy possible DLLs. Currently only libusb0.dll is dynamic, all other
# are also compiled as static.
# cp -v "${OPENOCD_INSTALL_FOLDER}/bin/"*.dll "${OPENOCD_INSTALL_FOLDER}/openocd/bin"

# ----- Copy the license files -----

echo
echo "copy license files..."

mkdir -p "${OPENOCD_INSTALL_FOLDER}/openocd/license/openocd"
/usr/bin/install -v -c -m 644 "${OPENOCD_GIT_FOLDER}/AUTHORS" \
  "${OPENOCD_INSTALL_FOLDER}/openocd/license/openocd"
/usr/bin/install -v -c -m 644 "${OPENOCD_GIT_FOLDER}/COPYING" \
  "${OPENOCD_INSTALL_FOLDER}/openocd/license/openocd"
/usr/bin/install -v -c -m 644 "${OPENOCD_GIT_FOLDER}/"NEWS* \
  "${OPENOCD_INSTALL_FOLDER}/openocd/license/openocd"
/usr/bin/install -v -c -m 644 "${OPENOCD_GIT_FOLDER}/"README* \
  "${OPENOCD_INSTALL_FOLDER}/openocd/license/openocd"

mkdir -p "${OPENOCD_INSTALL_FOLDER}/openocd/license/${HIDAPI}"
/usr/bin/install -v -c -m 644 "${OPENOCD_WORK_FOLDER}/${HIDAPI}/"AUTHORS* \
  "${OPENOCD_INSTALL_FOLDER}/openocd/license/${HIDAPI}"
/usr/bin/install -v -c -m 644 "${OPENOCD_WORK_FOLDER}/${HIDAPI}/"LICENSE* \
  "${OPENOCD_INSTALL_FOLDER}/openocd/license/${HIDAPI}"
/usr/bin/install -v -c -m 644 "${OPENOCD_WORK_FOLDER}/${HIDAPI}/"README* \
  "${OPENOCD_INSTALL_FOLDER}/openocd/license/${HIDAPI}"

mkdir -p "${OPENOCD_INSTALL_FOLDER}/openocd/license/${LIBFTDI}"
/usr/bin/install -v -c -m 644 "${OPENOCD_WORK_FOLDER}/${LIBFTDI}/"AUTHORS* \
  "${OPENOCD_INSTALL_FOLDER}/openocd/license/${LIBFTDI}"
/usr/bin/install -v -c -m 644 "${OPENOCD_WORK_FOLDER}/${LIBFTDI}/"COPYING* \
  "${OPENOCD_INSTALL_FOLDER}/openocd/license/${LIBFTDI}"
/usr/bin/install -v -c -m 644 "${OPENOCD_WORK_FOLDER}/${LIBFTDI}/"LICENSE* \
  "${OPENOCD_INSTALL_FOLDER}/openocd/license/${LIBFTDI}"
/usr/bin/install -v -c -m 644 "${OPENOCD_WORK_FOLDER}/${LIBFTDI}/"README* \
  "${OPENOCD_INSTALL_FOLDER}/openocd/license/${LIBFTDI}"

mkdir -p "${OPENOCD_INSTALL_FOLDER}/openocd/license/${LIBUSB1}"
/usr/bin/install -v -c -m 644 "${OPENOCD_WORK_FOLDER}/${LIBUSB1}/"AUTHORS* \
  "${OPENOCD_INSTALL_FOLDER}/openocd/license/${LIBUSB1}"
/usr/bin/install -v -c -m 644 "${OPENOCD_WORK_FOLDER}/${LIBUSB1}/"COPYING* \
  "${OPENOCD_INSTALL_FOLDER}/openocd/license/${LIBUSB1}"
/usr/bin/install -v -c -m 644 "${OPENOCD_WORK_FOLDER}/${LIBUSB1}/"NEWS* \
  "${OPENOCD_INSTALL_FOLDER}/openocd/license/${LIBUSB1}"
/usr/bin/install -v -c -m 644 "${OPENOCD_WORK_FOLDER}/${LIBUSB1}/"README* \
  "${OPENOCD_INSTALL_FOLDER}/openocd/license/${LIBUSB1}"

mkdir -p "${OPENOCD_INSTALL_FOLDER}/openocd/license/${LIBUSB_W32}"
/usr/bin/install -v -c -m 644 "${OPENOCD_WORK_FOLDER}/${LIBUSB_W32_FOLDER}/"AUTHORS* \
  "${OPENOCD_INSTALL_FOLDER}/openocd/license/${LIBUSB_W32}"
/usr/bin/install -v -c -m 644 "${OPENOCD_WORK_FOLDER}/${LIBUSB_W32_FOLDER}/"COPYING* \
  "${OPENOCD_INSTALL_FOLDER}/openocd/license/${LIBUSB_W32}"
/usr/bin/install -v -c -m 644 "${OPENOCD_WORK_FOLDER}/${LIBUSB_W32_FOLDER}/"README.txt \
  "${OPENOCD_INSTALL_FOLDER}/openocd/license/${LIBUSB_W32}"

find "${OPENOCD_INSTALL_FOLDER}/openocd/license" -type f \
  -exec unix2dos {} \;

RESULT="$?"

# Removing licenses
rm -rf ${OPENOCD_INSTALL_FOLDER}/openocd

# Display some information about the created application.
echo
echo "DLLs:"
${CROSS_COMPILE_PREFIX}-objdump -x "${OPENOCD_INSTALL_FOLDER}/bin/openocd.exe" | grep -i 'DLL Name'

# renaming folder
mv ${OPENOCD_INSTALL_FOLDER} ${OPENOCD_WORKING_FOLDER}/OpenOCD-0.9.0-arduino

cd ${OPENOCD_WORKING_FOLDER}

tar cfvj OpenOCD-0.9.0-arduino.org-win${TARGET_BITS}-${stag}-nrf52.tar.bz2 OpenOCD-0.9.0-arduino/

# Removing build folder
rm -rf ${OPENOCD_WORKING_FOLDER}/OpenOCD-0.9.0-arduino

echo ""
echo "Finished !"
echo ""

echo
if [ "${RESULT}" == "0" ]
then
  echo "Build completed."
  # echo "File ${OPENOCD_SETUP} created."
else
  echo "Build failed."
fi

exit 0
