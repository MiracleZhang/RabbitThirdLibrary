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
    RABBIT_BUILD_SOURCE_CODE=${RABBIT_BUILD_PREFIX}/../src/osgQt
fi

CUR_DIR=`pwd`

#下载源码:
if [ ! -d ${RABBIT_BUILD_SOURCE_CODE} ]; then
    OSG_VERSION=2ee974e4e85ddf349baee0a3a1e44eb25243bce0 #3.5.7
    if [ "TRUE" = "${RABBIT_USE_REPOSITORIES}" ]; then
        echo "git clone -q --branch=${OSG_VERSION} https://github.com/openscenegraph/osgQt.git ${RABBIT_BUILD_SOURCE_CODE}"
        git clone -q https://github.com/openscenegraph/osgQt.git ${RABBIT_BUILD_SOURCE_CODE}
        #git clone -q https://github.com/KangLin/osgQt.git ${RABBIT_BUILD_SOURCE_CODE}
        if [ "$OSG_VERSION" != "master" ]; then
            git checkout -b $OSG_VERSION $OSG_VERSION
        fi
    else
        echo "wget -q https://github.com/openscenegraph/osgQt/archive/${OSG_VERSION}.zip"
        mkdir -p ${RABBIT_BUILD_SOURCE_CODE}
        cd ${RABBIT_BUILD_SOURCE_CODE}
        wget -q https://github.com/openscenegraph/osgQt/archive/${OSG_VERSION}.zip
        #wget -q https://github.com/KangLin/osgQt/archive/${OSG_VERSION}.zip
        unzip -q ${OSG_VERSION}.zip
        mv osgQt-${OSG_VERSION} ..
        rm -fr *
        cd ..
        rm -fr ${RABBIT_BUILD_SOURCE_CODE}
        mv -f osgQt-${OSG_VERSION} ${RABBIT_BUILD_SOURCE_CODE}
    fi
fi

cd ${RABBIT_BUILD_SOURCE_CODE}

if [ ! -f CMakeModules/Find3rdPartyDependencies.cmake ]; then
    wget -O CMakeModules/Find3rdPartyDependencies.cmake https://raw.githubusercontent.com/openscenegraph/OpenSceneGraph/master/CMakeModules/Find3rdPartyDependencies.cmake
fi

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

#需要设置 CMAKE_MAKE_PROGRAM 为 make 程序路径。

if [ "$RABBIT_BUILD_STATIC" = "static" ]; then
    CMAKE_PARA="-DDYNAMIC_OPENSCENEGRAPH=OFF" 
else
    CMAKE_PARA="-DDYNAMIC_OPENSCENEGRAPH=ON"
fi
MAKE_PARA="-- ${RABBIT_MAKE_JOB_PARA} VERBOSE=1"
case ${RABBIT_BUILD_TARGERT} in
    android)      
        CMAKE_PARA="-DBUILD_SHARED_LIBS=OFF -DDYNAMIC_OPENTHREADS=OFF"
        CMAKE_PARA="${CMAKE_PARA} -DDYNAMIC_OPENSCENEGRAPH=OFF"
        CMAKE_PARA="${CMAKE_PARA} -DCMAKE_TOOLCHAIN_FILE=$RABBIT_BUILD_PREFIX/../build_script/cmake/platforms/toolchain-android.cmake"
        CMAKE_PARA="${CMAKE_PARA} -DOSG_BUILD_PLATFORM_ANDROID=ON"
        CMAKE_PARA="${CMAKE_PARA} -DOSG_GL1_AVAILABLE=OFF -DOSG_GL2_AVAILABLE=OFF -DOSG_GL3_AVAILABLE=OFF -DOSG_GLES1_AVAILABLE=OFF"
        CMAKE_PARA="${CMAKE_PARA} -DOSG_GLES2_AVAILABLE=ON -DOSG_GL_LIBRARY_STATIC=OFF -DOSG_GL_DISPLAYLISTS_AVAILABLE=OFF"
        CMAKE_PARA="${CMAKE_PARA} -DOSG_GL_MATRICES_AVAILABLE=OFF -DOSG_GL_VERTEX_FUNCS_AVAILABLE=OFF -DOSG_GL_VERTEX_ARRAY_FUNCS_AVAILABLE=OFF -DOSG_GL_FIXED_FUNCTION_AVAILABLE=OFF"
        CMAKE_PARA="${CMAKE_PARA} -DBUILD_OSG_PACKAGES=OFF"
        if [ -n "$RABBIT_CMAKE_MAKE_PROGRAM" ]; then
            CMAKE_PARA="${CMAKE_PARA} -DCMAKE_MAKE_PROGRAM=$RABBIT_CMAKE_MAKE_PROGRAM" 
        fi
        CMAKE_PARA="${CMAKE_PARA} -DCMAKE_TOOLCHAIN_FILE=$RABBIT_BUILD_PREFIX/../build_script/cmake/platforms/toolchain-android.cmake"
        CMAKE_PARA="${CMAKE_PARA} -DANDROID_NATIVE_API_LEVEL=${ANDROID_NATIVE_API_LEVEL}"
        #CMAKE_PARA="${CMAKE_PARA} -DANDROID_ABI=${ANDROID_ABI}"  
        ;;
    unix)
        ;;
    windows_msvc)
        MAKE_PARA=""
        CMAKE_PARA="${CMAKE_PARA} -DWIN32_USE_MP=ON"
        ;;
    windows_mingw)
        CMAKE_PARA="${CMAKE_PARA} -DOPENTHREADS_ATOMIC_USE_MUTEX=ON -DCMAKE_TOOLCHAIN_FILE=$RABBIT_BUILD_PREFIX/../build_script/cmake/platforms/toolchain-mingw.cmake"
        ;;
    *)
    echo "${HELP_STRING}"
    cd $CUR_DIR
    exit 2
    ;;
esac

export OSG_3RDPARTY_DIR=$RABBIT_BUILD_PREFIX
#export OSGDIR=$RABBIT_BUILD_PREFIX
#CMAKE_PARA="${CMAKE_PARA} -DOpenSceneGraph_DEBUG=ON"
CMAKE_PARA="${CMAKE_PARA} -DBUILD_DOCUMENTATION=OFF -DBUILD_OSG_EXAMPLES=OFF" # -DBUILD_OSG_APPLICATIONS=OFF"
CMAKE_PARA="${CMAKE_PARA} -DQt5_DIR=${QT_ROOT}/lib/cmake/Qt5"
#CMAKE_PARA="${CMAKE_PARA} -DDESIRED_QT_VERSION=5 -DQt5Widgets_DIR=${QT_ROOT}/lib/cmake/Qt5Widgets"
#CMAKE_PARA="${CMAKE_PARA} -DQt5Gui_DIR=${QT_ROOT}/lib/cmake/Qt5Gui"
#CMAKE_PARA="${CMAKE_PARA} -DQt5Core_DIR=${QT_ROOT}/lib/cmake/Qt5Core"
#CMAKE_PARA="${CMAKE_PARA} -DQt5OpenGL_DIR=${QT_ROOT}/lib/cmake/Qt5OpenGL"
CMAKE_PARA="${CMAKE_PARA} -DCMAKE_VERBOSE_MAKEFILE=ON "
CMAKE_PARA="${CMAKE_PARA} -DCMAKE_MODULE_PATH=$RABBIT_BUILD_PREFIX/lib/cmake"
CMAKE_PARA="${CMAKE_PARA} -DCMAKE_BUILD_TYPE=${RABBIT_CONFIG}"
echo "cmake .. -DCMAKE_INSTALL_PREFIX=$RABBIT_BUILD_PREFIX -DCMAKE_BUILD_TYPE=$RABBIT_CONFIG -G\"${RABBITIM_GENERATORS}\" ${CMAKE_PARA}"
cmake .. \
    -DCMAKE_INSTALL_PREFIX="$RABBIT_BUILD_PREFIX" \
    -G"${RABBITIM_GENERATORS}" ${CMAKE_PARA}

cmake --build . --target install --config ${RABBIT_CONFIG} ${MAKE_PARA}

cd $CUR_DIR
