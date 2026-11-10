#!/system/bin/sh
# 闹钟响铃后打开美团拼好饭。
# 亮屏：先发通知提示，几秒后自动打开。
# 锁屏：发通知提示解锁，不尝试解锁、不碰密码；解锁后自动打开。
BB=/data/adb/ksu/bin/busybox
PKG=com.sankuai.meituan
PINHAOFAN_URI='imeituan://www.meituan.com/mmp?shareEnv=release&appId=a8720b841a3d4b1d&targetPath=%2Fpages%2Findex%2Findex%3FshareType%3Dpinhaofan%26channel_id%3D14'
LOG=/data/user/0/com.coloros.alarmclock/files/trigger/daemon.log
WAIT_SECONDS=8

log_msg() {
    echo "$($BB date "+%Y-%m-%d %H:%M:%S") $*" >> $LOG
}

# 用 uiautomator 的方式不可靠，这里用 window policy 的 showing 字段
is_locked() {
    KEYGUARD=$(dumpsys window policy 2>/dev/null | $BB grep -m1 -A3 "^    KeyguardServiceDelegate" | $BB grep -m1 "showing=")
    case "$KEYGUARD" in
        *"showing=true"*) return 0 ;;
        *) return 1 ;;
    esac
}

notify() {
    TITLE="$1"
    BODY="$2"
    cmd notification post -S bigtext -t "$TITLE" alarmshell_eat "$BODY" >/dev/null 2>&1
}

open_meituan() {
    log_msg "打开美团拼好饭"
    am start -a android.intent.action.VIEW -d "$PINHAOFAN_URI" "$PKG" >> $LOG 2>&1
}

# 关掉闹钟响铃界面（全屏与悬浮窗各滑一次，滑不到也无所谓）
input swipe 540 1800 540 600 300
sleep 1
input swipe 540 1800 540 600 300
sleep 1

if is_locked; then
    log_msg "检测到锁屏，等待用户解锁（不解锁则不打开）"
    notify "该吃饭了" "手机已锁屏。解锁后会自动打开美团拼好饭。"
    WAITED=0
    while [ $WAITED -lt 300 ]; do
        sleep 2
        WAITED=$((WAITED+2))
        if ! is_locked; then
            log_msg "已解锁（等待 ${WAITED} 秒）"
            sleep 2
            open_meituan
            exit 0
        fi
    done
    log_msg "等待解锁超时（300 秒），放弃打开美团"
    notify "该吃饭了" "等待解锁超时，请手动打开美团拼好饭。"
    exit 0
fi

log_msg "屏幕已解锁，${WAIT_SECONDS} 秒后打开美团拼好饭"
notify "该吃饭了" "手机已解锁，${WAIT_SECONDS} 秒后打开美团拼好饭。"
sleep $WAIT_SECONDS
open_meituan
