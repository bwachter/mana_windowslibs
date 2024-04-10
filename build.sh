#!/bin/bash

set -e

if [ `uname` = "Darwin" ]; then
    NPROC=`sysctl -n hw.ncpu`
else
    NPROC=`nproc`
fi

CROSS=${CROSS:-x86_64-w64-mingw32}
PREFIX=${PREFIX:-/opt/mana_libpack}
BDIR=${BDIR:-`pwd`/build}
SRCDIR=`pwd`
mkdir -p $BDIR

BUILD_LIBS=${BUILD_LIBS:-"SDL2 SDL2_image SDL2_mixer SDL2_ttf SDL2_net physfs"}

autoconf_bi(){
    ./configure --host=${CROSS} --prefix=${PREFIX} && make -j${NPROC} && make -j${NPROC} install
}

cmake_bi(){
    sed -e "s,LIBPACK_PREFIX,${PREFIX},g" ${SRCDIR}/toolchain.cmake > toolchain.cmake && \
        mkdir -p build && cd build && cmake --toolchain ../toolchain.cmake -DCMAKE_INSTALL_PREFIX=${PREFIX} .. && make install
}

export SDL2_CONFIG=${PREFIX}/bin/sdl2-config

for lib in $BUILD_LIBS; do
    . ${lib}/config
    if [ -z "$URL" ] || [ -z "$TYPE" ] || [ -z "$VERSION" ]; then
        echo "Incomplete build information for ${lib}"
        exit 1
    fi
    if [ -z "$ARCHIVE_NAME" ]; then
        ARCHIVE_NAME=${lib}
    fi
    ARCHIVE_TYPE=${ARCHIVE_TYPE:-tar.gz}
    NAME=${ARCHIVE_NAME}-${VERSION}
    if ! [ -f ${BDIR}/${NAME}.${ARCHIVE_TYPE} ]; then
        wget -O ${BDIR}/${NAME}.${ARCHIVE_TYPE} -nc ${URL}
    fi
    tar xf ${BDIR}/${NAME}.${ARCHIVE_TYPE} -C ${BDIR} && (
        cd ${BDIR}/${NAME} &&
            if [ "$TYPE" = "autoconf" ]; then
                autoconf_bi
            elif [ "$TYPE" = "cmake" ]; then
                cmake_bi
            else
                echo "Unsupported build type"
            fi )
    unset URL
    unset TYPE
    unset ARCHIVE_NAME
    unset VERSION
done
