# AlarmShell (ColorOS / realme UI 适配版)

用系统闹钟做定时任务。闹钟响铃时，按**闹钟名称**找到同名脚本并以 **root** 执行。
可靠性来自系统闹钟本身——后台被杀、甚至重启后闹钟照样会响。

本仓库是 [weixiansen574/AlarmShell](https://github.com/weixiansen574/AlarmShell) 的适配分支，
原版仅支持 MIUI（`com.android.deskclock`），这里适配到 **ColorOS / realme UI**
（`com.coloros.alarmclock`），并重构了执行链路以便在 KernelSU 环境下工作。

---

## 一、原理

```
闹钟响铃
  └─ LSPosed 模块（运行在时钟进程内，不需要 root）
        hook AlarmService.O(Context, b2)  ← 全屏响铃与悬浮窗两条路径的公共入口
        读取闹钟名称（b2.j() → r0.m() → r0 字段 j）
        写触发文件  files/trigger/<时间戳>.req （内容 = 脚本名）
  └─ root 守护 alarmshell-watch.sh（每秒轮询）
        读 req → 执行 files/shell/<脚本名>
        日志追加到 files/trigger/daemon.log
```

**为什么应用不直接 `su`**：本机 KernelSU 对所有应用 uid 都隐藏了 `/system/bin/su`
（实测 `su 10312 -c "ls /system/bin/su"` → No such file or directory，`su 0` 则正常可见）。
所以原版 `Runtime.exec("su")` 必然失败。改成「模块只写文件、root 侧执行」后，
应用进程完全不碰 su，也就不用动 `kernel_umount` 这类隐藏 root 的安全设置。

---

## 二、环境要求

| 项 | 要求 |
|---|---|
| 系统 | ColorOS / realme UI（Android 14+ 实测，realme RMX3841 / Android 16） |
| Root | KernelSU（Magisk 应也可，脚本路径需相应调整） |
| 框架 | LSPosed |
| 作用域 | `com.coloros.alarmclock`（系统「时钟」） |

---

## 三、编译

### 方式 A：Android Studio（推荐，通用）

直接打开 `AlarmShell/` 目录构建即可。

### 方式 B：命令行离线构建（aarch64 Linux 容器内，无需 SDK）

```sh
sh AlarmShell/build-offline.sh
# 产物：AlarmShell/AlarmShell-coloros.apk
```

脚本依赖以下工具，路径写在脚本头部，按需修改：

- `aapt2`、`zipalign`、`apksigner` —— Ubuntu 包 `aapt` / `zipalign` / `apksigner` 解包后可用
- `r8.jar`（含 D8）—— 从 Google Maven 取 `com.android.tools.r8`
- `android.jar` —— 用 **API 30** 的版本（更高版本的 resources.arsc 编码新版 aapt2 读不了）

---

## 四、部署（手机侧）

### 1. 安装模块并启用

```sh
adb install -r AlarmShell-coloros.apk
```

然后在 LSPosed 管理器里：
1. 启用 **AlarmShell** 模块
2. 作用域勾选 **时钟**
3. 强制停止一次时钟应用，让 hook 生效：
   ```sh
   adb shell am force-stop com.coloros.alarmclock
   ```

### 2. 部署 root 守护（关键，否则脚本不会执行）

```sh
adb shell
su
mkdir -p /data/adb/alarmshell
cp /sdcard/AlarmShell/daemon/alarmshell-watch.sh /data/adb/alarmshell/
cp /sdcard/AlarmShell/daemon/ensure-daemon.sh    /data/adb/alarmshell/
chmod 755 /data/adb/alarmshell/*.sh

# 开机自启入口
cp /data/adb/alarmshell/ensure-daemon.sh /data/adb/service.d/alarmshell-watch.sh
chmod 755 /data/adb/service.d/alarmshell-watch.sh

# 立即拉起（不用等重启）
/data/adb/ksud services
```

> `ensure-daemon.sh` 里用 `grep "[a]larmshell-watch.sh"` 的自匹配写法，
> 否则会把执行检查的脚本自身也匹配上，导致判断为「已在运行」而不再拉起。

### 3. 建目录

```sh
su
mkdir -p /data/user/0/com.coloros.alarmclock/files/shell
mkdir -p /data/user/0/com.coloros.alarmclock/files/trigger
chmod 777 /data/user/0/com.coloros.alarmclock/files/shell
chmod 777 /data/user/0/com.coloros.alarmclock/files/trigger
```

> 触发目录必须放在**应用私有目录**（`app_data_file`），不能放 `/data/local/tmp`
> （那是 `shell_data_file`，应用写入会 `EACCES`）。

### 4. 放脚本

把脚本放进 `/data/user/0/com.coloros.alarmclock/files/shell/`，
文件名就是之后要填的闹钟名称。

---

## 五、使用

时钟 → 闹钟 → 点 **+** 新建闹钟，在 **「闹钟名称」** 输入框里填脚本文件名
（一字不差，含 `.sh` 后缀），保存即可。

> ColorOS 里这一项叫 **「闹钟名称」**，不是「备注/标签」。
> 它位于时间选择器下方、「铃声」那一行的正上方。
> 名字下方的「响一次 / 工作日 / 自定义」是**重复周期**，别填错地方。

闹钟名称对不上的闹钟，模块完全不碰，正常响铃。

---

## 六、自带的 eat.sh（打开美团拼好饭）

`daemon/eat.sh` 是给「定时提醒吃饭」场景写的示例：

- **亮屏时**：关闹钟 → 通知「8 秒后打开美团拼好饭」→ 8 秒后打开
- **锁屏时**：关闹钟 → 通知「解锁后会自动打开美团拼好饭」→ **不尝试解锁、不接触密码**
  → 每 2 秒检查一次解锁状态 → 解锁后 2 秒打开
  → 5 分钟未解锁则放弃并提醒手动打开

拼好饭 URI（从美团 APK 内提取，非猜测）：

```
imeituan://www.meituan.com/mmp?shareEnv=release&appId=a8720b841a3d4b1d&targetPath=%2Fpages%2Findex%2Findex%3FshareType%3Dpinhaofan%26channel_id%3D14
```

可调参数（脚本顶部）：`WAIT_SECONDS=8`（亮屏等待秒数）、锁屏等待上限 300 秒。

---

## 七、排错

| 现象 | 排查 |
|---|---|
| 脚本不执行 | ① 看 LSPosed 日志有无「模块已注入」；② 看 `files/trigger/daemon.log` 有无 `trigger:` 记录；③ 确认守护在跑 |
| 守护没跑 | `su -c "/data/adb/alarmshell/ensure-daemon.sh"`，再看 `daemon.log` 是否有 `daemon started` |
| 提示 `Cannot run program "su"` | 说明还在用旧版（应用内 su）。本版已不依赖 su，重装 APK |
| 写入触发文件 `EACCES` | 触发目录路径错，必须在 `files/trigger` 下 |
| 一次响铃执行两次 | 确认模块是含去重逻辑的版本（同一闹钟 60 秒内只触发一次） |
| 闹钟名称读不到 | ColorOS 字段是混淆名，日志会打印 `b2.j()` / `r0.m()` 的实际值，按日志调整 `getAlarmLabel` |

查看日志：

```sh
su -c "tail -f /data/user/0/com.coloros.alarmclock/files/trigger/daemon.log"
```

---

## 八、与 MIUI 原版的差异

| 项 | 原版（MIUI） | 本版（ColorOS） |
|---|---|---|
| 目标包 | `com.android.deskclock` | `com.coloros.alarmclock` |
| hook 点 | `AlarmAlertFullScreenActivity.onCreate` | `AlarmService.O(Context, b2)` |
| 脚本目录 | `/data/user/0/com.android.deskclock/files/shell/` | `/data/user/0/com.coloros.alarmclock/files/shell/` |
| 取名称 | 反射字段 `label` | `b2.j()` → `r0.m()` → `r0.j`（带多路回退） |
| 执行方式 | 应用内 `Runtime.exec("su")` | 写触发文件，root 守护执行 |

> hook 点换到 `AlarmService.O` 的原因：ColorOS 在**熄屏→亮屏**瞬间响铃时走的是
> **悬浮窗**（`AlarmService startFloatingView`），不会创建 `AlarmAlertFullScreen`，
> 原 hook 点在这种情况下永远不触发。
