#!/bin/bash

#作者：康林
#参数:
#    $1:编译目标(android、windows_msvc、windows_mingw、unix)
#    $2:源码的位置

#运行本脚本前,先运行 build_$1_envsetup.sh 进行环境变量设置,需要先设置下面变量:
#   RABBIT_BUILD_TARGERT   编译目标（android、windows_msvc、windows_mingw、unix)
#   RABBIT_BUILD_PREFIX=`pwd`/../${RABBIT_BUILD_TARGERT}  #修改这里为安装前缀
#   RABBIT_BUILD_SOURCE_CODE    #源码目录
#   RABBIT_BUILD_CROSS_PREFIX   #交叉编译前缀
#   RABBIT_BUILD_CROSS_SYSROOT  #交叉编译平台的 sysroot

set -e
HELP_STRING="Usage $0 PLATFORM(android|windows_msvc|windows_mingw|unix) [SOURCE_CODE_ROOT_DIRECTORY]"

case $1 in
    android|windows_msvc|windows_mingw|unix)
    RABBIT_BUILD_TARGERT=$1
    ;;
    *)
    echo "${HELP_STRING}"
    exit 1
    ;;
esac

RABBIT_BUILD_SOURCE_CODE=$2
echo ". `pwd`/build_envsetup_${RABBIT_BUILD_TARGERT}.sh"
. `pwd`/build_envsetup_${RABBIT_BUILD_TARGERT}.sh

if [ -z "$RABBIT_BUILD_SOURCE_CODE" ]; then
    RABBIT_BUILD_SOURCE_CODE=${RABBIT_BUILD_PREFIX}/../src/geos
fi

CUR_DIR=`pwd`

#下载源码:
if [ ! -d ${RABBIT_BUILD_SOURCE_CODE} ]; then
    VERSION=3.7.1
    if [ "TRUE" = "${RABBIT_USE_REPOSITORIES}" ]; then
        echo "git clone -q https://github.com/OSGeo/geos.git ${RABBIT_BUILD_SOURCE_CODE}"
        git clone -q https://github.com/OSGeo/geos.git ${RABBIT_BUILD_SOURCE_CODE}
        cd ${RABBIT_BUILD_SOURCE_CODE}
        if [ "$VERSION" != "master" ]; then
            git checkout -b $VERSION $VERSION
        fi
    else
        echo "wget -q -c -nv https://github.com/OSGeo/geos/archive/$VERSION.tar.gz"
        mkdir -p ${RABBIT_BUILD_SOURCE_CODE}
        cd ${RABBIT_BUILD_SOURCE_CODE}
        wget -q -c -nv https://github.com/OSGeo/geos/archive/$VERSION.tar.gz
        tar xf $VERSION.tar.gz
        mv geos-$VERSION ..
        cd ..
        rm -fr ${RABBIT_BUILD_SOURCE_CODE}
        mv geos-$VERSION ${RABBIT_BUILD_SOURCE_CODE}
    fi
fi

cd ${RABBIT_BUILD_SOURCE_CODE}

mkdir -p build_${RABBIT_BUILD_TARGERT}
cd build_${RABBIT_BUILD_TARGERT}
if [ "$RABBIT_CLEAN" = "TRUE" ]; then
    rm -fr *
fi

echo ""
echo "RABBIT_BUILD_TARGERT:${RABBIT_BUILD_TARGERT}"
echo "RABBIT_BUILD_SOURCE_CODE:$RABBIT_BUILD_SOURCE_CODE"
echo "CUR_DIR:`pwd`"
echo "RABBIT_BUILD_PREFIX:$RABBIT_BUILD_PREFIX"
echo "RABBIT_BUILD_HOST:$RABBIT_BUILD_HOST"
echo "RABBIT_BUILD_CROSS_HOST:$RABBIT_BUILD_CROSS_HOST"
echo "RABBIT_BUILD_CROSS_PREFIX:$RABBIT_BUILD_CROSS_PREFIX"
echo "RABBIT_BUILD_CROSS_SYSROOT:$RABBIT_BUILD_CROSS_SYSROOT"
echo "RABBIT_BUILD_STATIC:$RABBIT_BUILD_STATIC"
echo ""

echo "configure ..."
if [ "$RABBIT_BUILD_STATIC" = "static" ]; then
    CMAKE_PARA="-DGEOS_BUILD_STATIC=ON -DGEOS_BUILD_SHARED=OFF" 
else
    CMAKE_PARA="-DGEOS_BUILD_STATIC=OFF -DGEOS_BUILD_SHARED=ON"
fi
MAKE_PARA="-- ${RABBIT_MAKE_JOB_PARA} VERBOSE=1"
case ${RABBIT_BUILD_TARGERT} in
    android)
        if [ -n "$RABBIT_CMAKE_MAKE_PROGRAM" ]; then
            CMAKE_PARA="${CMAKE_PARA} -DCMAKE_MAKE_PROGRAM=$RABBIT_CMAKE_MAKE_PROGRAM" 
        fi
        CMAKE_PARA="${CMAKE_PARA} -DCMAKE_TOOLCHAIN_FILE=$RABBIT_BUILD_PREFIX/../build_script/cmake/platforms/toolchain-android.cmake"
        CMAKE_PARA="${CMAKE_PARA} -DANDROID_NATIVE_API_LEVEL=${ANDROID_NATIVE_API_LEVEL}"
        #CMAKE_PARA="${CMAKE_PARA} -DANDROID_ABI=${ANDROID_ABI}"  
        ;;
    unix)
        CONFIG_PARA="${CONFIG_PARA} --with-gnu-ld --enable-sse "
        ;;
    windows_msvc)
        MAKE_PARA=""
        ;;
    windows_mingw)
        #CMAKE_PARA="${CMAKE_PARA} -DCMAKE_TOOLCHAIN_FILE=$RABBIT_BUILD_PREFIX/../build_script/cmake/platforms/toolchain-mingw.cmake"
        cd ${RABBIT_BUILD_SOURCE_CODE}
        if [ ! -f configure ]; then
            ./autogen.sh
        fi
        cd build_${RABBIT_BUILD_TARGERT}
        CONFIG_PARA="${CONFIG_PARA} --host=$RABBIT_BUILD_CROSS_HOST"
        #CONFIG_PARA="${CONFIG_PARA} --with-sysroot=${RABBIT_BUILD_CROSS_SYSROOT}"
        CFLAGS="${RABBIT_CFLAGS}"
        CPPFLAGS="${RABBIT_CPPFLAGS} -std=c++11"
        LDFLAGS="$LDFLAGS ${RABBIT_LDFLAGS}" # -lsupc++"
        export LIBS="-lstdc++" #-lsupc++
        CONFIG_PARA="${CONFIG_PARA} --prefix=$RABBIT_BUILD_PREFIX"
        echo "../configure ${CONFIG_PARA} CFLAGS=\"${CFLAGS=}\" CPPFLAGS=\"${CPPFLAGS}\" CXXFLAGS=\"${CPPFLAGS}\" LDFLAGS=\"${LDFLAGS}\""
        ../configure ${CONFIG_PARA} \
            CFLAGS="${CFLAGS}" CPPFLAGS="${CPPFLAGS}" CXXFLAGS="${CPPFLAGS}" \
            LDFLAGS="${LDFLAGS}"
        
        ${MAKE} V=1 ${RABBIT_MAKE_JOB_PARA}
        echo "make install ....................................."
        ${MAKE} install
        
        cd $CUR_DIR
        exit 0
        ;;
    *)
    echo "${HELP_STRING}"
    cd $CUR_DIR
    exit 3
    ;;
esac

CMAKE_PARA="${CMAKE_PARA} -DCMAKE_BUILD_TYPE=${RABBIT_CONFIG}"
CMAKE_PARA="${CMAKE_PARA} -DGEOS_ENABLE_TESTS=OFF"
echo "cmake .. ${CMAKE_PARA} -DCMAKE_INSTALL_PREFIX=$RABBIT_BUILD_PREFIX -DCMAKE_BUILD_TYPE=Release -G\"${RABBITIM_GENERATORS}\" ${CMAKE_PARA}"
cmake .. \
    -DCMAKE_INSTALL_PREFIX="$RABBIT_BUILD_PREFIX" \
    -G"${RABBITIM_GENERATORS}" ${CMAKE_PARA} -DCMAKE_VERBOSE_MAKEFILE=TRUE

cmake --build . --target install --config ${RABBIT_CONFIG} ${MAKE_PARA}

cd $CUR_DIR
