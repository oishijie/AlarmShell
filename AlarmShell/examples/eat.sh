#!/system/bin/sh
# 闹钟响铃后打开美团拼好饭。
# 亮屏：先发通知提示，几秒后自动打开。
# 锁屏：发通知提示解锁，不尝试解锁、不碰密码；解锁后自动打开。
BB=/data/adb/ksu/bin/busybox
PKG=com.sankuai.meituan
PINHAOFAN_URI='imeituan://www.meituan.com/mmp?shareEnv=release&appId=a8720b841a3d4b1d&targetPath=%2Fpages%2Findex%2Findex%3FshareType%3Dpinhaofan%26channel_id%3D14'
LOG=/data/user/0/com.coloros.alarmclock/files/trigger/daemon.log
WAIT_SECONDS=3

log_msg() {
    echo "$($BB date "+%Y-%m-%d %H:%M:%S") $*" >> $LOG
}

# 用 uiautomator 的方式不可靠，这里用 window policy 的 showing 字段
is_locked() {
    DUMP=$(dumpsys window policy 2>/dev/null | $BB grep -m1 -A6 "^    KeyguardServiceDelegate")
    SHOWING=$(echo "$DUMP" | $BB grep -m1 "showing=" | $BB cut -d= -f2 | $BB tr -d " ")
    DREAMING=$(echo "$DUMP" | $BB grep -m1 "dreaming=" | $BB cut -d= -f2 | $BB tr -d " ")
    log_msg "  锁屏检测: showing=$SHOWING dreaming=$DREAMING"
    if [ "$SHOWING" = "true" ] || [ "$DREAMING" = "true" ]; then
        return 0
    fi
    return 1
}

notify() {
    TITLE="$1"
    BODY="$2"
    cmd notification post -S bigtext -t "$TITLE" alarmshell_eat "$BODY" >/dev/null 2>&1
}

# 美团是否真的在前台
is_front() {
    TOP=$(dumpsys activity activities 2>/dev/null | $BB grep -m1 "topResumedActivity")
    case "$TOP" in
        *sankuai.meituan*) return 0 ;;
        *) log_msg "  当前前台: $TOP" ; return 1 ;;
    esac
}

# 用户是否已经真的进到桌面（解锁了但还停在锁屏/亮屏动画上都不算）
is_home() {
    TOP=$(dumpsys activity activities 2>/dev/null | $BB grep -m1 "topResumedActivity")
    case "$TOP" in
        *com.android.launcher*|*com.oplus.launcher*|*com.coloros.launcher*)
            return 0 ;;
        *) return 1 ;;
    esac
}

open_meituan() {
    log_msg "打开美团拼好饭"
    am start -a android.intent.action.VIEW -d "$PINHAOFAN_URI" "$PKG" >> $LOG 2>&1
}

# 先判断锁屏状态，再决定是等解锁还是直接打开。
LOCKED=0
if is_locked; then
    LOCKED=1
fi

if [ "$LOCKED" = "1" ]; then
    log_msg "检测到锁屏，等待用户解锁（不解锁则不打开）"
    notify "该吃饭了" "手机已锁屏。解锁回到桌面后 ${WAIT_SECONDS} 秒自动打开美团拼好饭。"
    WAITED=0
    while [ $WAITED -lt 300 ]; do
        sleep 2
        WAITED=$((WAITED+2))
        if is_home; then
            log_msg "已进入桌面（等待 ${WAITED} 秒），${WAIT_SECONDS} 秒后打开美团"
            sleep $WAIT_SECONDS
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
