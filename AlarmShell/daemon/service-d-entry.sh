#!/system/bin/sh
# KernelSU service.d 入口：后台拉起 AlarmShell 守护
DAEMON=/data/adb/alarmshell/alarmshell-watch.sh
[ -f "$DAEMON" ] || exit 0
nohup /system/bin/sh "$DAEMON" >/dev/null 2>&1 &
exit 0
