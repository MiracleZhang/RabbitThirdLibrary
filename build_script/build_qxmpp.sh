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
    RABBIT_BUILD_SOURCE_CODE=${RABBIT_BUILD_PREFIX}/../src/qxmpp
fi

CUR_DIR=`pwd`
#下载源码:
if [ ! -d ${RABBIT_BUILD_SOURCE_CODE} ]; then
    VERSION=0.9.3
    if [ "TRUE" = "${RABBIT_USE_REPOSITORIES}" ]; then
        echo "git clone -q https://github.com/qxmpp-project/qxmpp.git ${RABBIT_BUILD_SOURCE_CODE}"
        git clone -q -b v${VERSION} https://github.com/qxmpp-project/qxmpp.git ${RABBIT_BUILD_SOURCE_CODE}
        #git clone -q https://github.com/KangLin/qxmpp.git ${RABBIT_BUILD_SOURCE_CODE}
    else
        mkdir -p ${RABBIT_BUILD_SOURCE_CODE}
        cd ${RABBIT_BUILD_SOURCE_CODE}
        #wget -q -c -nv https://github.com/KangLin/qxmpp/archive/master.zip
        wget -q -c -nv https://github.com/qxmpp-project/qxmpp/archive/v${VERSION}.tar.gz
        tar xvf v${VERSION}.tar.gz
        mv qxmpp-${VERSION} ..
        rm -fr *
        cd ..
        rm -fr ${RABBIT_BUILD_SOURCE_CODE}
        mv -f qxmpp-${VERSION} ${RABBIT_BUILD_SOURCE_CODE}
    fi
fi

cd ${RABBIT_BUILD_SOURCE_CODE}

if [ ! -d build_${RABBIT_BUILD_TARGERT} ]; then
    mkdir -p build_${RABBIT_BUILD_TARGERT}
fi
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

case $RABBIT_BUILD_TARGERT in
    android)
        PARA="-r -spec android-g++"
        case $TARGET_OS in
            MINGW* | CYGWIN* | MSYS*)
                MAKE="$ANDROID_NDK/prebuilt/${RABBIT_BUILD_HOST}/bin/make ${RABBIT_MAKE_JOB_PARA} VERBOSE=1" #在windows下编译
                ;;
            *)
            ;;
         esac
         ;;
    unix)
        ;;
    windows_msvc)
        RABBIT_MAKE_JOB_PARA=""
        ;;
    windows_mingw)
        #PARA="-r -spec win32-g++" # CROSS_COMPILE=${RABBIT_BUILD_CROSS_PREFIX}"
        ;;
    *)
        echo "Usage $0 PLATFORM(android/windows_msvc/windows_mingw/unix) SOURCE_CODE_ROOT"
        cd $CUR_DIR
        exit 2
        ;;
esac

if [ "$RABBIT_BUILD_STATIC" = "static" ]; then
    PARA="${PARA} QXMPP_LIBRARY_TYPE=staticlib" #静态库
    PARA="${PARA} CONFIG*=static"
fi

PARA="${PARA} -o Makefile INCLUDEPATH+=${RABBIT_BUILD_PREFIX}/include"
if [ "$RABBIT_BUILD_TARGERT" != "android" -a "$RABBIT_ARCH" != "x86" ]; then
    PARA="${PARA} LIBS+=-L${RABBIT_BUILD_PREFIX}/lib QXMPP_USE_VPX=1"
fi
PARA="${PARA} QXMPP_NO_TESTS=1 QXMPP_NO_EXAMPLES=1"

PARA="${PARA} PREFIX=${RABBIT_BUILD_PREFIX}"

if [ "${RABBIT_CONFIG}" = "Debug" -o "${RABBIT_CONFIG}" = "debug" ]; then
    RELEASE_PARA="${PARA} CONFIG-=release CONFIG+=debug"
else
    RELEASE_PARA="${PARA} CONFIG-=debug CONFIG+=release"
fi

echo "$QMAKE ${RELEASE_PARA}"
$QMAKE ${RELEASE_PARA} ../qxmpp.pro
${MAKE} -f Makefile install ${RABBIT_MAKE_JOB_PARA}

if [ "$RABBIT_BUILD_TARGERT" = "windows_mingw" ]; then
    cp src/pkgconfig/qxmpp.pc ${RABBIT_BUILD_PREFIX}/lib/pkgconfig/.
fi
cd $CUR_DIR
