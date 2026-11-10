#!/bin/sh
# AlarmShell 离线构建脚本，aarch64 容器内构建，不需要 Android SDK / AGP
# 依赖：.tmp_alarmshell/tools/r8.jar、.tmp_alarmshell/platforms/android-11/android.jar、
#       /root/sdktools 下的 aapt2 / zipalign / apksigner
set -e
ROOT=/root/workspace/AlarmShell
TMP=/root/workspace/.tmp_alarmshell
SDK=/root/sdktools/usr/lib/android-sdk/build-tools/debian
AJAR=$TMP/platforms/android-11/android.jar
export LD_LIBRARY_PATH=/root/sdktools/usr/lib/aarch64-linux-gnu:/root/sdktools/usr/lib/aarch64-linux-gnu/android:/root/sdktools/usr/lib:/root/sdktools/usr/lib/7zip
cd $ROOT
mkdir -p build/gen build/classes build/dex build/empty

# 1. 资源。aapt2 要求 manifest 带 package 属性，AGP8 工程里没有，这里临时补一份
sed 's@<manifest @<manifest package="top.weixiansen574.alarmshell" @' app/src/main/AndroidManifest.xml > build/AndroidManifest.xml
sed -i '/dataExtractionRules/d' build/AndroidManifest.xml
$SDK/aapt2 compile --dir app/src/main/res -o build/res.zip
$SDK/aapt2 link -o build/base.apk -I $AJAR --manifest build/AndroidManifest.xml build/res.zip -A app/src/main/assets --java build/gen --min-sdk-version 21 --target-sdk-version 33 --version-code 1 --version-name 1.0

# 2. Java 源码编译成 class
find app/src/main/java build/gen -name "*.java" > build/sources.txt
javac -source 1.8 -target 1.8 -encoding UTF-8 -sourcepath build/empty -implicit:none -bootclasspath $AJAR -cp app/libs/XposedBridgeApi-54.jar -d build/classes @build/sources.txt

# 3. class 转 dex 并塞进 APK
cd build/classes
zip -q -r ../classes.jar .
cd $ROOT
java -cp $TMP/tools/r8.jar com.android.tools.r8.D8 --min-api 21 --lib $AJAR --output build/dex build/classes.jar
cd build/dex
zip -q -0 ../base.apk classes.dex
cd $ROOT

# 4. 对齐并签名
$SDK/zipalign -f 4 build/base.apk build/aligned.apk
java -jar /root/sdktools/usr/share/java/apksigner.jar sign --ks build/mykey.jks --ks-pass pass:alarmshell123 --key-pass pass:alarmshell123 --out AlarmShell-coloros.apk build/aligned.apk
echo "构建完成: $ROOT/AlarmShell-coloros.apk"
