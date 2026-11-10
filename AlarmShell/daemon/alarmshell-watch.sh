#!/system/bin/sh
# AlarmShell root daemon: poll trigger dir and run matching script.
BB=/data/adb/ksu/bin/busybox
TRIGGER_DIR=/data/user/0/com.coloros.alarmclock/files/trigger
SHELL_DIR=/data/user/0/com.coloros.alarmclock/files/shell
LOG=/data/user/0/com.coloros.alarmclock/files/trigger/daemon.log

log_msg() {
    TS=$($BB date "+%Y-%m-%d %H:%M:%S")
    echo "$TS $*" >> $LOG
}

mkdir -p $TRIGGER_DIR
chmod 777 $TRIGGER_DIR
log_msg "daemon started pid=$$"

while true; do
    for f in $TRIGGER_DIR/*.req; do
        [ -e "$f" ] || continue
        NAME=$($BB cat "$f")
        $BB rm -f "$f"
        NAME=$(echo "$NAME" | $BB tr -d "\r\n")
        log_msg "trigger: [$NAME]"
        if [ -z "$NAME" ]; then
            log_msg "empty trigger, skip"
            continue
        fi
        SCRIPT="$SHELL_DIR/$NAME"
        if [ ! -f "$SCRIPT" ]; then
            log_msg "no script: $SCRIPT"
            continue
        fi
        log_msg "run: $SCRIPT"
        $BB sh "$SCRIPT" >> $LOG 2>&1
        log_msg "done: $SCRIPT"
    done
    $BB sleep 1
done
