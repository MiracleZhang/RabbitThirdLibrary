#!/bin/bash 
#下载工具  

set -e

SOURCE_DIR="`pwd`"
echo $SOURCE_DIR
TOOLS_DIR=${SOURCE_DIR}/Tools
if [ -d "${SOURCE_DIR}/ThirdLibrary" ]; then
    TOOLS_DIR=${SOURCE_DIR}/ThirdLibrary/Tools
fi
PKG_DIR=${SOURCE_DIR}/Packages
if [ -d "${SOURCE_DIR}/ThirdLibrary" ]; then
    PKG_DIR=${SOURCE_DIR}/ThirdLibrary/Packages
fi
echo ${TOOLS_DIR}
SCRIPT_DIR=${SOURCE_DIR}/build_script
if [ -d ${SOURCE_DIR}/ThirdLibrary/build_script ]; then
    SCRIPT_DIR=${SOURCE_DIR}/ThirdLibrary/build_script
fi
if [ "$BUILD_TARGERT" = "android" ]; then
    export ANDROID_SDK_ROOT=${TOOLS_DIR}/android-sdk
    export ANDROID_NDK_ROOT=${TOOLS_DIR}/android-ndk
    export JAVA_HOME="/C/Program Files (x86)/Java/jdk1.8.0"
    export PATH=/usr/bin:${TOOLS_DIR}/apache-ant/bin:$JAVA_HOME:$PATH
else
    exit 0
fi

if [ ! -d "${TOOLS_DIR}" ]; then
    mkdir ${TOOLS_DIR}
fi
if [ ! -d "${PKG_DIR}" ];then
    mkdir ${PKG_DIR}
fi

cd ${TOOLS_DIR}

#下载ANT
#wget -c -nv http://apache.fayea.com/ant/binaries/apache-ant-1.10.1-bin.tar.gz
if [ ! -d "${TOOLS_DIR}/apache-ant" ]; then
    ANT_VERSION=1.10.5
    if [ ! -f ${PKG_DIR}/apache-ant-${ANT_VERSION}-bin.tar.gz ]; then
        cd ${PKG_DIR}
        wget -c -nv https://www.apache.org/dist/ant/binaries/apache-ant-${ANT_VERSION}-bin.tar.gz
        cd ${TOOLS_DIR}
    fi
    tar xzf ${PKG_DIR}/apache-ant-${ANT_VERSION}-bin.tar.gz
    mv apache-ant-${ANT_VERSION} apache-ant
fi

#Download android sdk  
if [ ! -d "${TOOLS_DIR}/android-sdk" ]; then
    if [ ! -f ${PKG_DIR}/android-sdk_r24.4.1-windows.zip ]; then
        cd ${PKG_DIR}
        wget -c -nv https://dl.google.com/android/android-sdk_r24.4.1-windows.zip
        cd ${TOOLS_DIR}
    fi
    unzip -q ${PKG_DIR}/android-sdk_r24.4.1-windows.zip
    mv android-sdk-windows android-sdk
    #https://developer.android.google.cn/studio/command-line/sdkmanager
    (sleep 5 ; while true ; do sleep 1 ; printf 'y\r\n' ; done ) \
    | android-sdk/tools/android.bat update sdk -u -t tool,android-18,android-24,extra,platform-tools,build-tools #platforms
fi

#下载android ndk  
if [ ! -d "${TOOLS_DIR}/android-ndk" ]; then
    NDK_VERSOIN=r17b
    if [ ! -f ${PKG_DIR}/android-ndk-${NDK_VERSOIN}-windows-x86_64.zip ]; then
        cd ${PKG_DIR}
        wget -c -nv https://dl.google.com/android/repository/android-ndk-${NDK_VERSOIN}-windows-x86_64.zip
        cd ${TOOLS_DIR}
    fi
    unzip -q ${PKG_DIR}/android-ndk-${NDK_VERSOIN}-windows-x86_64.zip
    mv android-ndk-${NDK_VERSOIN} android-ndk
    #使用WINDOWS下的PYTHON
    cd android-ndk/build/tools
    if [ -z "${ANDROID_NATIVE_API_LEVEL}" ]; then
        ./make_standalone_toolchain.py \
            --arch ${RABBIT_ARCH} \
            --install-dir ${TOOLS_DIR}/android-ndk/android-toolchain-${RABBIT_ARCH}
    else
        ./make_standalone_toolchain.py \
            --arch ${RABBIT_ARCH} \
            --api ${ANDROID_NATIVE_API_LEVEL} \
            --install-dir ${TOOLS_DIR}/android-ndk/android-toolchain-${RABBIT_ARCH}
    fi
fi

# Qt qt安装参见：https://github.com/benlau/qtci  
if [ "NO" != "${QT_VERSION}" ]; then
    QT_DIR=C:/projects/rabbitthirdlibrary/Tools/Qt/Qt${QT_VERSION}
    if [ -d "C:/projects/rabbitim/ThirdLibrary/Tools" ]; then
        QT_DIR=C:/projects/rabbitim/ThirdLibrary/Tools/Qt/Qt${QT_VERSION}
    fi
    QT_INSTALL_FILE_NAME=qt-opensource-windows-x86-${QT_VERSION}.exe
    if [ ! -d "${QT_DIR}" ]; then
        if [ ! -f ${PKG_DIR}/$QT_INSTALL_FILE_NAME ]; then
            cd ${PKG_DIR}
            wget -c --no-check-certificate -nv http://download.qt.io/official_releases/qt/${QT_VERSION_DIR}/${QT_VERSION}/${QT_INSTALL_FILE_NAME}
            cd ${TOOLS_DIR}
        fi
        echo "bash ${SCRIPT_DIR}/ci/qt-installer.sh ${PKG_DIR}/${QT_INSTALL_FILE_NAME} ${QT_DIR}"
        bash ${SCRIPT_DIR}/ci/qt-installer.sh ${PKG_DIR}/${QT_INSTALL_FILE_NAME} ${QT_DIR}
    fi
fi

cd ${SOURCE_DIR}
