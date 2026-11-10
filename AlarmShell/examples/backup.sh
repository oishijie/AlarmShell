#!/system/bin/sh
# 示例 5：定时备份 / 清理类任务（不需要屏幕交互的场景）。
#
# 用法：闹钟名称填 backup.sh。这类脚本适合设在凌晨，手机不用动。

BB=/data/adb/ksu/bin/busybox
DATE=$($BB date '+%Y%m%d_%H%M%S')
DEST=/sdcard/Download/alarmshell_backup
SRC=/sdcard/DCIM/Camera

mkdir -p "$DEST"

# 把今天新增的照片打个包（示例，按需改路径）
$BB tar -czf "$DEST/photos_$DATE.tar.gz" -C "$SRC" . 2>/dev/null

# 只保留最近 5 个备份
ls -1t "$DEST"/photos_*.tar.gz 2>/dev/null | $BB tail -n +6 | while read -r f; do
    rm -f "$f"
done

echo "$($BB date '+%Y-%m-%d %H:%M:%S') backup done: photos_$DATE.tar.gz" \
    >> /sdcard/Download/alarmshell_backup.log
