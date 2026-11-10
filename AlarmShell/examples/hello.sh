#!/system/bin/sh
# 示例 1：最简单——只往文件里记一笔，用来验证链路是否通。
#
# 用法：放到脚本目录，闹钟名称填 hello.sh
#   脚本目录：/data/user/0/com.coloros.alarmclock/files/shell/

BB=/data/adb/ksu/bin/busybox
OUT=/sdcard/Download/alarmshell_hello.log

echo "$($BB date '+%Y-%m-%d %H:%M:%S') hello.sh 被执行" >> "$OUT"
