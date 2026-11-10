#!/system/bin/sh
# 示例 4：锁屏时先提醒，等你解锁进桌面后再执行动作。
# 这是最推荐的写法——不碰密码、不替你关闹钟，只在你真正开始用手机时才动作。
#
# 用法：闹钟名称填 wait-unlock.sh，改 ACTION 部分为你想要的动作。

BB=/data/adb/ksu/bin/busybox
LOG=/data/user/0/com.coloros.alarmclock/files/trigger/daemon.log
WAIT_SECONDS=3

log_msg() {
    echo "$($BB date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"
}

# 锁屏/熄屏判断
is_locked() {
    DUMP=$(dumpsys window policy 2>/dev/null | $BB grep -m1 -A6 "^    KeyguardServiceDelegate")
    SHOWING=$(echo "$DUMP" | $BB grep -m1 "showing=" | $BB cut -d= -f2 | $BB tr -d " ")
    DREAMING=$(echo "$DUMP" | $BB grep -m1 "dreaming=" | $BB cut -d= -f2 | $BB tr -d " ")
    if [ "$SHOWING" = "true" ] || [ "$DREAMING" = "true" ]; then
        return 0
    fi
    return 1
}

# 是否已经真的进到桌面（解锁了但还停在锁屏页不算）
is_home() {
    TOP=$(dumpsys activity activities 2>/dev/null | $BB grep -m1 "topResumedActivity")
    case "$TOP" in
        *com.android.launcher*|*com.oplus.launcher*|*com.coloros.launcher*)
            return 0 ;;
        *) return 1 ;;
    esac
}

do_action() {
    log_msg "执行动作"
    # ↓↓↓ 改这里：你想做的事 ↓↓↓
    am start -n com.sankuai.meituan/com.meituan.android.pt.homepage.activity.MainActivity
    # ↑↑↑ 改这里 ↑↑↑
}

if is_locked; then
    log_msg "锁屏中，等待解锁进桌面"
    cmd notification post -S bigtext -t "提醒" alarm_action "解锁回到桌面后 ${WAIT_SECONDS} 秒自动执行" >/dev/null 2>&1
    WAITED=0
    while [ $WAITED -lt 300 ]; do
        sleep 2
        WAITED=$((WAITED+2))
        if is_home; then
            log_msg "已进入桌面（等了 ${WAITED} 秒）"
            sleep $WAIT_SECONDS
            do_action
            exit 0
        fi
    done
    log_msg "等待解锁超时，放弃"
    exit 0
fi

log_msg "屏幕已解锁，${WAIT_SECONDS} 秒后执行"
sleep $WAIT_SECONDS
do_action
