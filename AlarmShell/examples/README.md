# 示例脚本

装好 APK 只是第一步，**通知里说的「脚本」要你自己放**。这里是一组可以直接抄的例子。

## 放哪里

所有脚本都放到**时钟应用的私有目录**：

```
/data/user/0/com.coloros.alarmclock/files/shell/
```

建目录（如果还没有）：

```sh
su -c "mkdir -p /data/user/0/com.coloros.alarmclock/files/shell && chmod 777 /data/user/0/com.coloros.alarmclock/files/shell"
```

拷脚本进去并给执行权限：

```sh
su -c "cp /sdcard/Download/hello.sh /data/user/0/com.coloros.alarmclock/files/shell/"
su -c "chmod 755 /data/user/0/com.coloros.alarmclock/files/shell/hello.sh"
```

> 用 MT 管理器之类的 root 文件管理器直接拖进去也可以，记得给 755 权限。

## 怎么触发

时钟 → 闹钟 → 新建 → 在 **「闹钟名称」** 里填**脚本的文件名**（要带 `.sh`，一字不差）。

比如放了 `hello.sh`，闹钟名称就填 `hello.sh`。

## 脚本清单

| 脚本 | 用途 | 难度 |
|---|---|---|
| [hello.sh](hello.sh) | 往文件里写一行日志，**用来验证链路是否通** | ⭐ |
| [open-app.sh](open-app.sh) | 打开任意 App（改成你要的包名/活动名） | ⭐⭐ |
| [open-deeplink.sh](open-deeplink.sh) | 打开 App 里的某个具体页面（deep link） | ⭐⭐ |
| [wait-unlock.sh](wait-unlock.sh) | 锁屏时等你解锁进桌面后再动作，**最推荐** | ⭐⭐⭐ |
| [eat.sh](eat.sh) | 完整实战：闹钟响铃 → 解锁进桌面 → 打开美团拼好饭 | ⭐⭐⭐ |
| [backup.sh](backup.sh) | 定时备份 / 清理，不需要动屏幕 | ⭐⭐ |

## 建议先跑 hello.sh

第一次用别直接上复杂脚本。放 `hello.sh`、建个 2 分钟后的闹钟、名称填 `hello.sh`。
响铃后看 `/sdcard/Download/alarmshell_hello.log`：

- 有内容 → 链路通了，再换你真正想要的脚本
- 没内容 → 按仓库 README「八、排错」逐项查，或看
  `/data/user/0/com.coloros.alarmclock/files/trigger/daemon.log`

## 写脚本的几个坑

**1. 没有 `PATH`，命令要写全路径**

守护进程以 root 跑，但环境变量极简。`busybox` 里的工具写成绝对路径最稳：

```sh
BB=/data/adb/ksu/bin/busybox
$BB date '+%H:%M:%S'
```

系统命令（`am`、`input`、`cmd`、`dumpsys`）可以直接调，**不要**加 `$BB` 前缀——busybox 里没有这些 applet。

**2. 锁屏时不要硬来**

想「自动解锁」就得知道你的密码，本项目不碰这个。正确做法是
`wait-unlock.sh` 那样：发通知提醒，轮询到你真的进桌面后再执行。

**3. 判断「进桌面」别只看解锁**

解锁 ≠ 进桌面，可能还停在锁屏动画或密码页。要判断前台是不是 launcher：

```sh
TOP=$(dumpsys activity activities 2>/dev/null | $BB grep -m1 "topResumedActivity")
case "$TOP" in
    *com.android.launcher*|*com.oplus.launcher*|*com.coloros.launcher*) ;;
esac
```

**4. 不要用 `input swipe` 关闹钟**

闹钟响着本身就是要提醒你。脚本替它关掉，等于把提醒吞了；
而且滑动会打在你正在用的界面上（比如把刚打开的美团划走）。

**5. 日志很有用**

脚本里随手写日志，出问题才有据可查：

```sh
echo "$($BB date '+%Y-%m-%d %H:%M:%S') 做了什么" >> /sdcard/Download/myscript.log
```
