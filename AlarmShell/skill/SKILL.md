---
name: alarmshell
description: 用系统闹钟做定时任务（AlarmShell）。用户说「每天中午提醒我打开某 App」「定时帮我做某件事」「闹钟响了自动执行」「配个定时任务」时使用。含装 APK、部署 root 守护、写脚本、建闹钟、排错全流程。
---

# AlarmShell：闹钟触发 shell 脚本

用户想「到点自动做某件事」时用这个。可靠性来自系统闹钟——后台被杀、重启都照样响。

**当前设备已部署好**（模块已装、LSPosed 已启用、root 守护在跑）。
多数情况只需要：**写一个脚本 → 放进脚本目录 → 建一个同名闹钟**。

---

## 一、先确认环境

```sh
# 1. 模块是否装了
su -c "pm path top.weixiansen574.alarmshell"

# 2. root 守护在不在
su -c "tail -5 /data/user/0/com.coloros.alarmclock/files/trigger/daemon.log"
# 期望有 daemon started；没有就拉起：
su -c "sh /data/adb/alarmshell/ensure-daemon.sh"

# 3. 目录是否存在
su -c "ls -ld /data/user/0/com.coloros.alarmclock/files/shell /data/user/0/com.coloros.alarmclock/files/trigger"
```

缺东西按第六节「安装部署」补齐。

---

## 二、写脚本（最容易踩坑）

### 硬规则

1. **必须写绝对路径**：守护进程环境变量极简，没有 PATH。

   ```sh
   BB=/data/adb/ksu/bin/busybox
   $BB date '+%H:%M:%S'
   ```

2. **系统命令不要加 `$BB` 前缀**：`am`、`input`、`cmd`、`dumpsys`、`screencap`
   要直接调用，busybox 里没有这些 applet（加了会报 applet not found）。

3. **不要在脚本里 `su`**：本机 KernelSU 对所有应用 uid 隐藏 `/system/bin/su`。
   脚本本身已由 root 守护执行，不需要再 su。

4. **不要用 `input swipe` 关闹钟**：闹钟响着就是要提醒用户，替它关等于吞掉提醒；
   滑动还会打在用户正在用的界面上，把刚启动的 App 划走。

5. **锁屏时不要尝试解锁**：不碰用户密码。正确做法是发通知 + 轮询等到真正进桌面。

### 判断「已进入桌面」

解锁不等于进桌面（可能还停在锁屏动画或密码页）：

```sh
is_home() {
    TOP=$(dumpsys activity activities 2>/dev/null | $BB grep -m1 "topResumedActivity")
    case "$TOP" in
        *com.android.launcher*|*com.oplus.launcher*|*com.coloros.launcher*) return 0 ;;
        *) return 1 ;;
    esac
}
```

### 判断锁屏 / 熄屏

```sh
is_locked() {
    DUMP=$(dumpsys window policy 2>/dev/null | $BB grep -m1 -A6 "KeyguardServiceDelegate")
    S=$(echo "$DUMP" | $BB grep -m1 "showing=" | $BB cut -d= -f2 | $BB tr -d " ")
    D=$(echo "$DUMP" | $BB grep -m1 "dreaming=" | $BB cut -d= -f2 | $BB tr -d " ")
    [ "$S" = "true" ] || [ "$D" = "true" ]
}
```

### 发通知

```sh
cmd notification post -S bigtext -t "标题" 唯一tag "正文" >/dev/null 2>&1
```

### 模板 A：立刻执行（亮屏场景）

```sh
#!/system/bin/sh
am start -n <包名>/<活动名>
```

### 模板 B：锁屏时等进桌面再执行（最推荐）

```sh
#!/system/bin/sh
BB=/data/adb/ksu/bin/busybox
LOG=/data/user/0/com.coloros.alarmclock/files/trigger/daemon.log
WAIT_SECONDS=3

log_msg() { echo "$($BB date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"; }

is_locked() {
    DUMP=$(dumpsys window policy 2>/dev/null | $BB grep -m1 -A6 "KeyguardServiceDelegate")
    S=$(echo "$DUMP" | $BB grep -m1 "showing=" | $BB cut -d= -f2 | $BB tr -d " ")
    D=$(echo "$DUMP" | $BB grep -m1 "dreaming=" | $BB cut -d= -f2 | $BB tr -d " ")
    [ "$S" = "true" ] || [ "$D" = "true" ]
}

is_home() {
    TOP=$(dumpsys activity activities 2>/dev/null | $BB grep -m1 "topResumedActivity")
    case "$TOP" in
        *com.android.launcher*|*com.oplus.launcher*|*com.coloros.launcher*) return 0 ;;
        *) return 1 ;;
    esac
}

do_action() {
    log_msg "执行动作"
    am start -n <包名>/<活动名>
}

if is_locked; then
    log_msg "锁屏，等待解锁进桌面"
    cmd notification post -S bigtext -t "提醒" alarm_action "解锁回到桌面后 ${WAIT_SECONDS} 秒自动执行" >/dev/null 2>&1
    W=0
    while [ $W -lt 300 ]; do
        sleep 2; W=$((W+2))
        if is_home; then
            log_msg "已进桌面，等 ${W} 秒"
            sleep $WAIT_SECONDS
            do_action
            exit 0
        fi
    done
    log_msg "超时放弃"
    exit 0
fi

log_msg "屏幕已解锁，${WAIT_SECONDS} 秒后执行"
sleep $WAIT_SECONDS
do_action
```

---

## 三、安装脚本

```sh
su -c "mkdir -p /data/user/0/com.coloros.alarmclock/files/shell"
su -c "chmod 755 /data/user/0/com.coloros.alarmclock/files/shell/<脚本名>.sh"
```

**脚本目录**：`/data/user/0/com.coloros.alarmclock/files/shell/`
**文件名 = 之后要填的闹钟名称**，必须完全一致（含 `.sh`）。

---

## 四、建闹钟

在系统时钟里建闹钟，**「闹钟名称」**（不是备注）填脚本文件名。

位置：新建闹钟 → 时间选择器下方 → 铃声那一行正上方，是个输入框。
它下面的「响一次 / 工作日 / 自定义」是**重复周期**，别填错。

> 让用户手动建更稳，能确认重复规则。

---

## 五、验证与排错

### 先验证脚本本身（不必等闹钟）

```sh
su -c "sh /data/user/0/com.coloros.alarmclock/files/shell/<脚本名>.sh"
```

### 看守护日志

```sh
su -c "tail -30 /data/user/0/com.coloros.alarmclock/files/trigger/daemon.log"
```

| 日志行 | 含义 |
|---|---|
| `daemon started` | 守护启动 |
| `trigger: [xxx.sh]` | 收到触发，内容是脚本名 |
| `run: /...xxx.sh` | 开始执行 |
| `done:` | 执行结束 |
| `empty trigger, skip` | 触发文件为空（罕见，多为重复触发） |

### 模块侧日志（LSPosed）

```sh
su -c "grep -a 'AlarmShell' /data/adb/lspd/log/modules_*.log | tail -20"
```

期望看到：`模块已注入`、`响铃入口被调用`、`解析出的闹钟名称 = [xxx.sh]`、`已投递触发`。

### 常见故障对照

| 现象 | 原因 | 处理 |
|---|---|---|
| 闹钟响了但日志无 trigger | 模块未注入或 hook 未命中 | 查 LSPosed 日志；`am force-stop com.coloros.alarmclock` 后重开时钟 |
| `解析出的闹钟名称 = [null]` | 闹钟名称没填 | 让用户填「闹钟名称」 |
| `没有找到同名脚本` | 名称不匹配 | 用 `ls` 核对文件名，注意大小写与 `.sh` |
| 脚本执行了但没效果 | 缺绝对路径 / 命令不存在 | 手动 `sh` 跑一次看输出 |
| `applet not found` | 给系统命令加了 `$BB` 前缀 | 去掉前缀 |
| `Cannot run program "su"` | 旧版模块或脚本自己调 su | 脚本里不要 su |
| 写入 `EACCES` | 触发目录路径错 | 必须在 `files/trigger`，不能 `/data/local/tmp` |
| 一次响铃执行两次 | 旧版模块无去重 | 装新版 APK（同闹钟 60 秒内只触发一次） |

---

## 六、安装部署（设备上还没有时）

### 1. 装模块

```sh
su -c "pm install -r /data/local/tmp/AlarmShell-coloros.apk"
```

LSPosed 里启用模块 → 作用域勾选「时钟」→ 强制停止时钟进程：

```sh
su -c "am force-stop com.coloros.alarmclock"
```

### 2. 部署 root 守护

```sh
su
mkdir -p /data/adb/alarmshell
cp .../daemon/alarmshell-watch.sh /data/adb/alarmshell/
cp .../daemon/ensure-daemon.sh    /data/adb/alarmshell/
chmod 755 /data/adb/alarmshell/*.sh
cp /data/adb/alarmshell/ensure-daemon.sh /data/adb/service.d/alarmshell-watch.sh
chmod 755 /data/adb/service.d/alarmshell-watch.sh
sh /data/adb/alarmshell/ensure-daemon.sh
```

### 3. 建目录

```sh
su
mkdir -p /data/user/0/com.coloros.alarmclock/files/shell
mkdir -p /data/user/0/com.coloros.alarmclock/files/trigger
chmod 777 /data/user/0/com.coloros.alarmclock/files/shell
chmod 777 /data/user/0/com.coloros.alarmclock/files/trigger
```

---

## 七、架构速查（排错时理解用）

```
闹钟响铃
  └─ LSPosed 模块（时钟进程内，不碰 root）
       hook com.oplus.alarmclock.alert.AlarmService.O(Context, b2)
         ← 全屏响铃与悬浮窗两条路径的公共入口
       读闹钟名称：b2.j() → r0.m() → r0 字段 j（混淆名，多路回退）
       写触发文件 files/trigger/<时间戳>.req（内容 = 脚本名）
       同一闹钟 60 秒内去重
  └─ root 守护 alarmshell-watch.sh（每秒轮询）
       读 req → 执行 files/shell/<脚本名>
       日志追加到 files/trigger/daemon.log
```

**为什么应用内不 su**：本机 KernelSU 对所有应用 uid 隐藏 `/system/bin/su`
（`su 10312 -c "ls /system/bin/su"` 不存在；`su 0` 正常）。
所以应用只写文件，执行交给 root 守护。好处是 `kernel_umount`（隐藏 root）可保持开启。

---

## 八、常用 App 的启动命令

```sh
# 美团外卖（主 App 首页）
am start -n com.sankuai.meituan/com.meituan.android.pt.homepage.activity.MainActivity

# 美团拼好饭（deep link）
am start -a android.intent.action.VIEW -d 'imeituan://www.meituan.com/mmp?shareEnv=release&appId=a8720b841a3d4b1d&targetPath=%2Fpages%2Findex%2Findex%3FshareType%3Dpinhaofan%26channel_id%3D14' com.sankuai.meituan
```

查任意 App 的入口：

```sh
pm list packages | grep 关键词
cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.LAUNCHER <包名>
```

---

## 九、可直接复用的示例

仓库 `AlarmShell/examples/` 下有现成的：

- `hello.sh` —— 写一行日志，验证链路是否通（建议第一个试）
- `open-app.sh` —— 打开任意 App
- `open-deeplink.sh` —— 打开 App 内具体页面
- `wait-unlock.sh` —— 锁屏时等解锁进桌面再动作（最推荐）
- `eat.sh` —— 实战：响铃 → 进桌面 → 打开美团拼好饭
- `backup.sh` —— 定时备份 / 清理

仓库地址：https://github.com/oishijie/AlarmShell
