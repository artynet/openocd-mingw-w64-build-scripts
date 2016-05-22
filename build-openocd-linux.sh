#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Script to build the GNU/Linux version of OpenOCD.
# Developed on Debian 7.
# Also tested on: 
#	Ubuntu 14.04 LTS
#	Manjaro 0.8.11
#	Fedora 21.
#
# Prerequisites:
#
# sudo apt-get install git libtool autoconf automake autotools-dev pkg-config
# sudo apt-get install texinfo texlive doxygen
# sudo apt-get install cmake libudev-dev 
# sudo apt-get install libconfuse-dev g++ libboost1.49-dev

# ----- Determine distribution name and word size -----

set +e
DISTRO_NAME=$(lsb_release -si | tr "[:upper:]" "[:lower:]")
set -e

if [ ! -z "${DISTRO_NAME}" ]
then
  echo $(lsb_release -i)
else
  echo "Please install the lsb core package and rerun."
  DISTRO_NAME="linux"
fi

if [ "$(uname -m)" == "x86_64" ]
then
  DISTRO_BITS="64"
  DISTRO_MACHINE="x86_64"
elif [ "$(uname -m)" == "i686" ]
then
  DISTRO_BITS="32"
  DISTRO_MACHINE="i386"
else
  echo "Unknown uname -m $(uname -m)"
  exit 1
fi

# ----- Parse actions and command line options -----

ACTION_CLEAN=""
ACTION_GIT=""
ACTION_INSTALL=""
TARGET_BITS="${DISTRO_BITS}"

while [ $# -gt 0 ]
do
  if [ "$1" == "clean" ]
  then
    ACTION_CLEAN="$1"
  elif [ "$1" == "pull" ]
  then
    ACTION_GIT="$1"
  elif [ "$1" == "install" ]
  then
    ACTION_INSTALL="$1"
  elif [ "$1" == "checkout-dev" ]
  then
    ACTION_GIT="$1"
  elif [ "$1" == "checkout-stable" ]
  then
    ACTION_GIT="$1"
  else
    echo "Unknown action/option $1"
    exit 1
  fi

  shift
done

# ----- Externally configurable variables -----

# The folder where the entire build procedure will run.
# If you prefer to build in a separate folder, define it before invoking
# the script.
if [ -d /root/Host/Work ]
then
  OPENOCD_WORK_FOLDER=${OPENOCD_WORK_FOLDER:-"/root/Host/Work/openocd"}
elif [ -d /media/psf/Home/Work ]
then
  OPENOCD_WORK_FOLDER=${OPENOCD_WORK_FOLDER:-"/media/psf/Home/Work/openocd"}
elif [ -d /media/${USER}/Work ]
then
  OPENOCD_WORK_FOLDER=${OPENOCD_WORK_FOLDER:-"/media/${USER}/Work/openocd"}
elif [ -d /media/Work ]
then
  OPENOCD_WORK_FOLDER=${OPENOCD_WORK_FOLDER:-"/media/Work/openocd"}
else
  OPENOCD_WORK_FOLDER=${OPENOCD_WORK_FOLDER:-${HOME}/Work/openocd}
fi

# The folder where OpenOCD is installed.
# If you prefer to install in different location, like in your home folder,
# define it before invoking the script.
SYSTEM_INSTALL_FOLDER=${SYSTEM_INSTALL_FOLDER:-"/opt/gnuarmeclipse"}

# PKG_CONFIG_PATH=${PKG_CONFIG_PATH:-""}
PKG_CONFIG_LIBDIR=${PKG_CONFIG_LIBDIR:-""}
LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-""}

MAKE_JOBS=${MAKE_JOBS:-"-j4"}

# ----- Local variables -----

# For updates, please check the corresponding pages.

# http://www.intra2net.com/en/developer/libftdi/download.php
LIBFTDI="libftdi1-1.2"

# https://sourceforge.net/projects/libusb/files/libusb-compat-0.1/
LIBUSB0="libusb-compat-0.1.5"

# https://sourceforge.net/projects/libusb/files/libusb-1.0/
LIBUSB1="libusb-1.0.19"

# https://github.com/signal11/hidapi/downloads
HIDAPI="hidapi-0.7.0"

HIDAPI_TARGET="linux"
HIDAPI_OBJECT="hid-libusb.o"

# OpenOCD build defs
OPENOCD_TARGET="${DISTRO_NAME}${TARGET_BITS}"

OPENOCD_GIT_FOLDER="${OPENOCD_WORK_FOLDER}/gnuarmeclipse-openocd.git"
OPENOCD_DOWNLOAD_FOLDER="${OPENOCD_WORK_FOLDER}/download"
OPENOCD_BUILD_FOLDER="${OPENOCD_WORK_FOLDER}/build/${OPENOCD_TARGET}"
OPENOCD_INSTALL_FOLDER="${OPENOCD_WORK_FOLDER}/install/${OPENOCD_TARGET}"
OPENOCD_OUTPUT="${OPENOCD_WORK_FOLDER}/output"

WGET="wget"
WGET_OUT="-O"

# ----- Test if some tools are present -----

gcc --version
git --version >/dev/null
automake --version >/dev/null
cmake --version >/dev/null
readelf --version >/dev/null

# Process actions.

if [ "${ACTION_CLEAN}" == "clean" ]
then
  # Remove most build and temporary folders
  echo
  echo "Remove most build folders..."

  rm -rf "${OPENOCD_BUILD_FOLDER}"
  rm -rf "${OPENOCD_INSTALL_FOLDER}"
  rm -rf "${OPENOCD_WORK_FOLDER}/${LIBFTDI}"
  rm -rf "${OPENOCD_WORK_FOLDER}/${LIBUSB0}"
  rm -rf "${OPENOCD_WORK_FOLDER}/${LIBUSB1}"
  rm -rf "${OPENOCD_WORK_FOLDER}/${HIDAPI}"

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

if [ "${ACTION_INSTALL}" == "install" ]
then

  # Always clear the destination folder, to have a consistent package.
  rm -rfv "${SYSTEM_INSTALL_FOLDER}/openocd"
  mkdir -p "${SYSTEM_INSTALL_FOLDER}"

  # Transfer the install folder to the final destination. 
  # Use tar to preserve rights.
  cd "${OPENOCD_INSTALL_FOLDER}"
  tar c -z --owner root --group root -f - openocd | tar x -z -f - -C "${SYSTEM_INSTALL_FOLDER}"

  # Display some information about the created application.
  echo
  echo "Libraries:"
  readelf -d "${OPENOCD_INSTALL_FOLDER}/openocd/bin/openocd" | grep -i 'library'

  # Check if the application starts (if all dynamic libraries are available).
  echo
  "${SYSTEM_INSTALL_FOLDER}/openocd/bin/openocd" --version
  RESULT="$?"

  echo
  if [ "${RESULT}" == "0" ]
  then
    echo "Installed. (Configure openocd_path to ${SYSTEM_INSTALL_FOLDER}/openocd/bin)."
  else
    echo "Install failed."
  fi

  exit 0
fi

if [ "${ACTION_GIT}" == "checkout-dev" ]
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
    git checkout gnuarmeclipse-dev
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

if [ "${ACTION_GIT}" == "checkout-stable" ]
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
    git checkout gnuarmeclipse
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

# ----- Begin of common part --------------------------------------------------

# Create the work folder.
mkdir -p "${OPENOCD_WORK_FOLDER}"

# ----- Get the GNU ARM Eclipse OpenOCD git repository -----

# The custom OpenOCD branch is available from the dedicated Git repository
# which is part of the GNU ARM Eclipse project hosted on SourceForge.
# Generally this branch follows the official OpenOCD master branch, 
# with updates after every OpenOCD public release.

if [ ! -d "${OPENOCD_GIT_FOLDER}" ]
then
  cd "${OPENOCD_WORK_FOLDER}"

  if [ "${USER}" == "ilg" ]
  then
    # Shortcut for ilg, who has full access to the repo.
    echo
    echo "Enter SourceForge password for git clone"
    git clone ssh://ilg-ul@git.code.sf.net/p/gnuarmeclipse/openocd gnuarmeclipse-openocd.git
  else
    # For regular read/only access, use the git url.
    git clone http://git.code.sf.net/p/gnuarmeclipse/openocd gnuarmeclipse-openocd.git
  fi

  # Change to the gnuarmeclipse branch. On subsequent runs use "git pull".
  cd "${OPENOCD_GIT_FOLDER}"
  git checkout gnuarmeclipse
  git submodule update

  # ---- Prepare autotools -----
  echo
  echo "bootstrap..."

  cd "${OPENOCD_GIT_FOLDER}"
  ./bootstrap
fi

# Get the current Git branch name, to know if we are building the stable or
# the development release.
cd "${OPENOCD_GIT_FOLDER}"
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
  rm -rf "${OPENOCD_BUILD_FOLDER}/${LIBUSB1}"
  mkdir -p "${OPENOCD_BUILD_FOLDER}/${LIBUSB1}"

  mkdir -p "${OPENOCD_INSTALL_FOLDER}"

  cd "${OPENOCD_BUILD_FOLDER}/${LIBUSB1}"
  # Configure
  CFLAGS="-Wno-non-literal-null-conversion -m${TARGET_BITS}" \
  "${OPENOCD_WORK_FOLDER}/${LIBUSB1}/configure" \
  --prefix="${OPENOCD_INSTALL_FOLDER}"

  # Build
  make ${MAKE_JOBS} clean install
fi

# http://www.libusb.org

# Download the old USB library.
LIBUSB0_ARCHIVE="${LIBUSB0}.tar.bz2"
if [ ! -f "${OPENOCD_DOWNLOAD_FOLDER}/${LIBUSB0_ARCHIVE}" ]
then
  mkdir -p "${OPENOCD_DOWNLOAD_FOLDER}"

  cd "${OPENOCD_DOWNLOAD_FOLDER}"
  "${WGET}" "http://sourceforge.net/projects/libusb/files/libusb-compat-0.1/${LIBUSB0}/${LIBUSB0_ARCHIVE}" \
  "${WGET_OUT}" "${LIBUSB0_ARCHIVE}"
fi

# Unpack the old USB library.
if [ ! -d "${OPENOCD_WORK_FOLDER}/${LIBUSB0}" ]
then
  cd "${OPENOCD_WORK_FOLDER}"
  tar -xjvf "${OPENOCD_DOWNLOAD_FOLDER}/${LIBUSB0_ARCHIVE}"
fi

# Build and install the old USB library.
if [ ! \( -d "${OPENOCD_BUILD_FOLDER}/${LIBUSB0}" \) -o \
     ! \( -f "${OPENOCD_INSTALL_FOLDER}/lib/libusb.a" -o \
          -f "${OPENOCD_INSTALL_FOLDER}/lib64/libusb.a" \) ]
then
  rm -rf "${OPENOCD_BUILD_FOLDER}/${LIBUSB0}"
  mkdir -p "${OPENOCD_BUILD_FOLDER}/${LIBUSB0}"

  mkdir -p "${OPENOCD_INSTALL_FOLDER}"

  cd "${OPENOCD_BUILD_FOLDER}/${LIBUSB0}"
  # Configure
  CFLAGS="-m${TARGET_BITS}" \
  \
  PKG_CONFIG_LIBDIR=\
"${OPENOCD_INSTALL_FOLDER}/lib/pkgconfig":\
"${OPENOCD_INSTALL_FOLDER}/lib64/pkgconfig" \
  \
  "${OPENOCD_WORK_FOLDER}/${LIBUSB0}/configure" \
  --prefix="${OPENOCD_INSTALL_FOLDER}"

  # Build
  make ${MAKE_JOBS} clean install
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
  patch -p0 < "${OPENOCD_GIT_FOLDER}/gnuarmeclipse/patches/${LIBFTDI}-cmake-FindUSB1.patch"
fi

# Build and install the FTDI library.
if [ ! \( -d "${OPENOCD_BUILD_FOLDER}/${LIBFTDI}" \) -o \
     ! \( -f "${OPENOCD_INSTALL_FOLDER}/lib/libftdi1.a" -o \
           -f "${OPENOCD_INSTALL_FOLDER}/lib64/libftdi1.a" \)  ]
then
  rm -rf "${OPENOCD_BUILD_FOLDER}/${LIBFTDI}"
  mkdir -p "${OPENOCD_BUILD_FOLDER}/${LIBFTDI}"

  mkdir -p "${OPENOCD_INSTALL_FOLDER}"

  echo
  echo "cmake libftdi..."

  cd "${OPENOCD_BUILD_FOLDER}/${LIBFTDI}"
  # cmake
  CFLAGS="-m${TARGET_BITS}" \
  \
  PKG_CONFIG_LIBDIR=\
"${OPENOCD_INSTALL_FOLDER}/lib/pkgconfig":\
"${OPENOCD_INSTALL_FOLDER}/lib64/pkgconfig" \
  \
  cmake \
  -DCMAKE_INSTALL_PREFIX="${OPENOCD_INSTALL_FOLDER}" \
  -DBUILD_TESTS:BOOL=off \
  -DFTDIPP:BOOL=off \
  -DPYTHON_BINDINGS:BOOL=off \
  -DEXAMPLES:BOOL=off \
  -DDOCUMENTATION:BOOL=off \
  -DFTDI_EEPROM:BOOL=off \
  "${OPENOCD_WORK_FOLDER}/${LIBFTDI}"

  # Build
  make ${MAKE_JOBS} clean install
fi

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

if [ ! \( -d "${OPENOCD_BUILD_FOLDER}/${HIDAPI}" \) -o \
     ! \( -f "${OPENOCD_INSTALL_FOLDER}/lib/libhid.a" \) ]
then
  rm -rf "${OPENOCD_BUILD_FOLDER}/${HIDAPI}"
  mkdir -p "${OPENOCD_BUILD_FOLDER}/${HIDAPI}"

  cp -r "${OPENOCD_WORK_FOLDER}/${HIDAPI}/"* \
    "${OPENOCD_BUILD_FOLDER}/${HIDAPI}"

  echo
  echo "make libhid..."

  cd "${OPENOCD_BUILD_FOLDER}/${HIDAPI}/${HIDAPI_TARGET}"
  CFLAGS="-m${TARGET_BITS}" \
  \
  PKG_CONFIG_LIBDIR=\
"${OPENOCD_INSTALL_FOLDER}/lib/pkgconfig":\
"${OPENOCD_INSTALL_FOLDER}/lib64/pkgconfig" \
  \
  make clean "${HIDAPI_OBJECT}"

  # Make just compiles the file. Create the archive.
  # No dynamic/shared libs involved.
  ar -r libhid.a ${HIDAPI_OBJECT}
  ranlib libhid.a

  mkdir -p "${OPENOCD_INSTALL_FOLDER}/lib"
  cp -v libhid.a \
     "${OPENOCD_INSTALL_FOLDER}/lib"

  mkdir -p "${OPENOCD_INSTALL_FOLDER}/lib/pkgconfig"
  sed -e "s|XXX|${OPENOCD_INSTALL_FOLDER}|" \
    "${OPENOCD_GIT_FOLDER}/gnuarmeclipse/pkgconfig/${HIDAPI}-${HIDAPI_TARGET}.pc" \
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
  # On some machines libftdi ends in lib64, so we refer both lib & lib64
  CPPFLAGS="-m${TARGET_BITS}" \
  LDFLAGS='-Wl,-rpath=\$$ORIGIN -lpthread' \
  \
  PKG_CONFIG_LIBDIR=\
"${OPENOCD_INSTALL_FOLDER}/lib/pkgconfig":\
"${OPENOCD_INSTALL_FOLDER}/lib64/pkgconfig" \
  \
  LD_LIBRARY_PATH=\
"${OPENOCD_INSTALL_FOLDER}/lib":\
"${OPENOCD_INSTALL_FOLDER}/lib64":\
"${LD_LIBRARY_PATH}" \
  \
  "${OPENOCD_GIT_FOLDER}/configure" \
  --prefix="${OPENOCD_INSTALL_FOLDER}/openocd"  \
  --datarootdir="${OPENOCD_INSTALL_FOLDER}" \
  --infodir="${OPENOCD_INSTALL_FOLDER}/openocd/info"  \
  --localedir="${OPENOCD_INSTALL_FOLDER}/openocd/locale"  \
  --mandir="${OPENOCD_INSTALL_FOLDER}/openocd/man"  \
  --docdir="${OPENOCD_INSTALL_FOLDER}/openocd/doc"  \
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

  # Note: a very important detail here is LDFLAGS='-Wl,-rpath=\$$ORIGIN which 
  # adds a special record to the ELF file asking the loader to search for the 
  # libraries first in the same folder where the executable is located. The 
  # task is complicated due to the multiple substitutions that are done on 
  # the way, and need to be escaped.

fi

# ----- Full build, with documentation -----

# The bindir and pkgdatadir are required to configure bin and scripts folders
# at the same level in the hierarchy.
cd "${OPENOCD_BUILD_FOLDER}/openocd"
make ${MAKE_JOBS} bindir="bin" pkgdatadir="" all pdf html

# Always clear the destination folder, to have a consistent package.
echo
echo "remove install..."

rm -rf "${OPENOCD_INSTALL_FOLDER}/openocd"

# ----- Full install, including documentation -----

echo
echo "make install..."

cd "${OPENOCD_BUILD_FOLDER}/openocd"
make install-strip install-pdf install-html install-man

# ----- Copy dynamic libraries to the install bin folder -----

echo
echo "copy shared libs..."

ILIB=$(find "${OPENOCD_INSTALL_FOLDER}/lib"* -type f -name 'libusb-1.0.so.*.*' -print)
if [ ! -z "${ILIB}" ]
then
  echo "Found ${ILIB}"
  ILIB_BASE="$(basename ${ILIB})"
  /usr/bin/install -v -c -m 644 "${ILIB}" \
  "${OPENOCD_INSTALL_FOLDER}/openocd/bin"
  ILIB_SHORT="$(echo $ILIB_BASE | sed -e 's/\([[:alnum:]]*\)[.]\([[:alnum:]]*\)[.]\([[:digit:]]*\)[.].*/\1.\2.\3/')"
  (cd "${OPENOCD_INSTALL_FOLDER}/openocd/bin"; ln -sv "${ILIB_BASE}" "${ILIB_SHORT}")
  ILIB_SHORT="$(echo $ILIB_BASE | sed -e 's/\([[:alnum:]]*\)[.]\([[:alnum:]]*\)[.]\([[:digit:]]*\)[.].*/\1.\2/')"
  (cd "${OPENOCD_INSTALL_FOLDER}/openocd/bin"; ln -sv "${ILIB_BASE}" "${ILIB_SHORT}")
fi

ILIB=$(find "${OPENOCD_INSTALL_FOLDER}/lib"* -type f -name 'libusb-0.1.so.*.*' -print)
if [ ! -z "${ILIB}" ]
then
  echo "Found ${ILIB}"
  ILIB_BASE="$(basename ${ILIB})"
  /usr/bin/install -v -c -m 644 "${ILIB}" \
  "${OPENOCD_INSTALL_FOLDER}/openocd/bin"
  ILIB_SHORT="$(echo $ILIB_BASE | sed -e 's/\([[:alnum:]]*\)[.]\([[:alnum:]]*\)[.]\([[:digit:]]*\)[.].*/\1.\2.\3/')"
  (cd "${OPENOCD_INSTALL_FOLDER}/openocd/bin"; ln -sv "${ILIB_BASE}" "${ILIB_SHORT}")
  ILIB_SHORT="$(echo $ILIB_BASE | sed -e 's/\([[:alnum:]]*\)[.]\([[:alnum:]]*\)[.]\([[:digit:]]*\)[.].*/\1.\2/')"
  (cd "${OPENOCD_INSTALL_FOLDER}/openocd/bin"; ln -sv "${ILIB_BASE}" "${ILIB_SHORT}")
fi

ILIB=$(find "${OPENOCD_INSTALL_FOLDER}/lib"* -type f -name 'libftdi1.so.*.*' -print)
if [ ! -z "${ILIB}" ]
then
  echo "Found ${ILIB}"
  ILIB_BASE="$(basename ${ILIB})"
  /usr/bin/install -v -c -m 644 "${ILIB}" \
  "${OPENOCD_INSTALL_FOLDER}/openocd/bin"
  ILIB_SHORT="$(echo $ILIB_BASE | sed -e 's/\([[:alnum:]]*\)[.]\([[:alnum:]]*\)[.]\([[:digit:]]*\)[.].*/\1.\2.\3/')"
  (cd "${OPENOCD_INSTALL_FOLDER}/openocd/bin"; ln -sv "${ILIB_BASE}" "${ILIB_SHORT}")
  ILIB_SHORT="$(echo $ILIB_BASE | sed -e 's/\([[:alnum:]]*\)[.]\([[:alnum:]]*\)[.]\([[:digit:]]*\)[.].*/\1.\2/')"
  (cd "${OPENOCD_INSTALL_FOLDER}/openocd/bin"; ln -sv "${ILIB_BASE}" "${ILIB_SHORT}")
fi

# Add libudev.so locally.
ILIB=$(find /lib/${DISTRO_MACHINE}-linux-gnu /usr/lib/${DISTRO_MACHINE}-linux-gnu -type f -name 'libudev.so.*.*' -print)
if [ ! -z "${ILIB}" ]
then
  echo "Found ${ILIB}"
  ILIB_BASE="$(basename ${ILIB})"
  /usr/bin/install -v -c -m 644 "${ILIB}" \
  "${OPENOCD_INSTALL_FOLDER}/openocd/bin"
  ILIB_SHORT="$(echo $ILIB_BASE | sed -e 's/\([[:alnum:]]*\)[.]\([[:alnum:]]*\)[.]\([[:digit:]]*\)[.].*/\1.\2.\3/')"
  (cd "${OPENOCD_INSTALL_FOLDER}/openocd/bin"; ln -sv "${ILIB_BASE}" "${ILIB_SHORT}")
  ILIB_SHORT="$(echo $ILIB_BASE | sed -e 's/\([[:alnum:]]*\)[.]\([[:alnum:]]*\)[.]\([[:digit:]]*\)[.].*/\1.\2/')"
  (cd "${OPENOCD_INSTALL_FOLDER}/openocd/bin"; ln -sv "${ILIB_BASE}" "${ILIB_SHORT}")
else
  echo
  echo 'WARNING: libudev.so not copied locally!'
  if [ "${USER}" == "ilg" ]
  then
    exit 1
  fi
fi

# Add librt.so.1 locally, to be sure it is available always.
ILIB=$(find /lib/${DISTRO_MACHINE}-linux-gnu /usr/lib/${DISTRO_MACHINE}-linux-gnu -type f -name 'librt-*.so' -print | grep -v i686)
if [ ! -z "${ILIB}" ]
then
  echo "Found ${ILIB}"
  ILIB_BASE="$(basename ${ILIB})"
  /usr/bin/install -v -c -m 644 "${ILIB}" \
  "${OPENOCD_INSTALL_FOLDER}/openocd/bin"
  (cd "${OPENOCD_INSTALL_FOLDER}/openocd/bin"; ln -sv "${ILIB_BASE}" "librt.so.1")
  (cd "${OPENOCD_INSTALL_FOLDER}/openocd/bin"; ln -sv "${ILIB_BASE}" "librt.so")
else
  echo
  echo "WARNING: librt.so not copied locally!"
  if [ "${USER}" == "ilg" ]
  then
    exit 1
  fi
fi

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

mkdir -p "${OPENOCD_INSTALL_FOLDER}/openocd/license/${LIBUSB0}"
/usr/bin/install -v -c -m 644 "${OPENOCD_WORK_FOLDER}/${LIBUSB0}/"AUTHORS* \
  "${OPENOCD_INSTALL_FOLDER}/openocd/license/${LIBUSB0}"
/usr/bin/install -v -c -m 644 "${OPENOCD_WORK_FOLDER}/${LIBUSB0}/"COPYING* \
  "${OPENOCD_INSTALL_FOLDER}/openocd/license/${LIBUSB0}"
/usr/bin/install -v -c -m 644 "${OPENOCD_WORK_FOLDER}/${LIBUSB0}/"LICENSE* \
  "${OPENOCD_INSTALL_FOLDER}/openocd/license/${LIBUSB0}"
/usr/bin/install -v -c -m 644 "${OPENOCD_WORK_FOLDER}/${LIBUSB0}/"NEWS* \
  "${OPENOCD_INSTALL_FOLDER}/openocd/license/${LIBUSB0}"
/usr/bin/install -v -c -m 644 "${OPENOCD_WORK_FOLDER}/${LIBUSB0}/"README* \
  "${OPENOCD_INSTALL_FOLDER}/openocd/license/${LIBUSB0}"

# ----- Copy the GNU ARM Eclipse info files -----

echo
echo "copy info files..."

/usr/bin/install -v -c -m 644 "${OPENOCD_GIT_FOLDER}/gnuarmeclipse/info/INFO-linux.txt" \
  "${OPENOCD_INSTALL_FOLDER}/openocd/INFO.txt"
mkdir -p "${OPENOCD_INSTALL_FOLDER}/openocd/gnuarmeclipse"
/usr/bin/install -v -c -m 644 "${OPENOCD_GIT_FOLDER}/gnuarmeclipse/info/BUILD-linux.txt" \
  "${OPENOCD_INSTALL_FOLDER}/openocd/gnuarmeclipse/BUILD.txt"
/usr/bin/install -v -c -m 644 "${OPENOCD_GIT_FOLDER}/gnuarmeclipse/info/CHANGES.txt" \
  "${OPENOCD_INSTALL_FOLDER}/openocd/gnuarmeclipse/"
/usr/bin/install -v -c -m 644 "${OPENOCD_GIT_FOLDER}/gnuarmeclipse/scripts/$(basename $0)" \
  "${OPENOCD_INSTALL_FOLDER}/openocd/gnuarmeclipse/"

# ----- Create the distribution archive ----

mkdir -p "${OPENOCD_OUTPUT}"

# Increment the revision with each new release.
OUTFILE_VERSION=$(cat "${OPENOCD_GIT_FOLDER}/gnuarmeclipse/VERSION")
# The UTC date part in the name of the archive. 
OUTFILE_DATE=${OUTFILE_DATE:-$(date -u +%Y%m%d%H%M)}

if [ "${OPENOCD_GIT_HEAD}" == "gnuarmeclipse" ]
then
  OUTFILE_VERSION=$(cat "${OPENOCD_GIT_FOLDER}/gnuarmeclipse/VERSION")-${OUTFILE_DATE}
elif [ "${OPENOCD_GIT_HEAD}" == "gnuarmeclipse-dev" ]
then
  OUTFILE_VERSION=$(cat "${OPENOCD_GIT_FOLDER}/gnuarmeclipse/VERSION-dev")-${OUTFILE_DATE}-dev
fi

OPENOCD_ARCHIVE="${OPENOCD_OUTPUT}/gnuarmeclipse-openocd-\
${OPENOCD_TARGET}-${OUTFILE_VERSION}.tgz"

echo
echo "create tgz archive..."
echo

cd "${OPENOCD_INSTALL_FOLDER}"
mkdir ${OUTFILE_VERSION}
mv openocd/* ${OUTFILE_VERSION}
mv ${OUTFILE_VERSION} openocd
tar czf "${OPENOCD_ARCHIVE}" --owner root --group root openocd

# Display some information about the created application.
echo
echo "Libraries:"
readelf -d "${OPENOCD_INSTALL_FOLDER}/openocd/${OUTFILE_VERSION}/bin/openocd" | grep -i 'library'

echo
ls -l "${OPENOCD_INSTALL_FOLDER}/openocd/${OUTFILE_VERSION}/bin"

# Check if the application starts (if all dynamic libraries are available).
echo
"${OPENOCD_INSTALL_FOLDER}/openocd/${OUTFILE_VERSION}/bin/openocd" --version
RESULT="$?"

echo
if [ "${RESULT}" == "0" ]
then
  echo "Build completed."
  echo "File ${OPENOCD_ARCHIVE} created."
else
  echo "Build failed."
fi

exit 0

