#!/system/bin/sh
# 确保 AlarmShell 守护在运行（可反复执行）
BB=/data/adb/ksu/bin/busybox
DAEMON=/data/adb/alarmshell/alarmshell-watch.sh
[ -f "$DAEMON" ] || exit 0
if $BB ps -A 2>/dev/null | $BB grep -q "[a]larmshell-watch.sh"; then
    exit 0
fi
nohup $BB setsid /system/bin/sh "$DAEMON" >/dev/null 2>&1 < /dev/null &
exit 0
