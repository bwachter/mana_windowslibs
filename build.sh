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

# openssl also is an option for curl, but seems to be more problematic
BUILD_LIBS=${BUILD_LIBS:-"SDL2 SDL2_mixer SDL2_ttf SDL2_net SDL2_image physfs curl libxml2 libpng gettext"}

autoconf_bi(){
    if [ -n "$PATCH" ]; then
        eval "$PATCH"
    fi
    ./configure --host=${CROSS} --prefix=${PREFIX} ${CONFIGURE_ARGS} && make -j${NPROC} && make -j${NPROC} install && touch .done
}

cmake_bi(){
    sed -e "s,LIBPACK_PREFIX,${PREFIX},g" ${SRCDIR}/toolchain.cmake > toolchain.cmake && \
        mkdir -p build && cd build && cmake --toolchain ../toolchain.cmake -DCMAKE_INSTALL_PREFIX=${PREFIX} ${CMAKE_ARGS} .. && make install && touch ../.done
}

openssl_bi(){
    ./Configure mingw64 --cross-compile-prefix=${CROSS}- --prefix=${PREFIX} --libdir=lib enable-quic && make -j${NPROC} && make -j ${NPROC} install && touch .done
}

build_package(){
    echo "Building $1..."
    unset URL
    unset TYPE
    unset ARCHIVE_NAME
    unset VERSION
    unset CONFIGURE_ARGS
    unset DEPENDENCIES

    . $1/config

    if [ -n "$DEPENDENCIES" ]; then
        echo "$1 requires $DEPENDENCIES"
        for dep in $DEPENDENCIES; do
            (build_package $dep)
        done
    fi

    if [ -z "$URL" ] || [ -z "$TYPE" ] || [ -z "$VERSION" ]; then
        echo "Incomplete build information for ${lib}"
        exit 1
    fi
    if [ -z "$ARCHIVE_NAME" ]; then
        ARCHIVE_NAME=$1
    fi
    ARCHIVE_TYPE=${ARCHIVE_TYPE:-tar.gz}
    NAME=${ARCHIVE_NAME}-${VERSION}
    if ! [ -f ${BDIR}/${NAME}.${ARCHIVE_TYPE} ]; then
        wget -O ${BDIR}/${NAME}.${ARCHIVE_TYPE} -nc ${URL}
    fi
    tar xf ${BDIR}/${NAME}.${ARCHIVE_TYPE} -C ${BDIR} && test -f ${BDIR}/${NAME}/.done || (
        cd ${BDIR}/${NAME} &&
            if [ "$TYPE" = "autoconf" ]; then
                autoconf_bi
            elif [ "$TYPE" = "cmake" ]; then
                cmake_bi
            elif [ "$TYPE" = "openssl" ]; then
                openssl_bi
            else
                echo "Unsupported build type"
            fi )

}

export SDL2_CONFIG=${PREFIX}/bin/sdl2-config
export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig:${PREFIX}/share/pkgconfig

for lib in $BUILD_LIBS; do
    build_package ${lib}
done

PREFIX_DIR=`dirname $PREFIX`
PREFIX_LIBPACK=`basename $PREFIX`
# required for some legacy includes which don't properly use pkgconfig
(cd ${PREFIX}/include && ln -s SDL2 SDL)
tar -C ${PREFIX_DIR} -czf ${BDIR}/mana_libpack.tar.gz ${PREFIX_LIBPACK}
