package top.weixiansen574.alarmshell.xposed;

import android.content.Context;

import java.io.File;
import java.text.SimpleDateFormat;
import java.util.Locale;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import de.robv.android.xposed.IXposedHookLoadPackage;
import de.robv.android.xposed.XC_MethodHook;
import de.robv.android.xposed.XposedBridge;
import de.robv.android.xposed.XposedHelpers;
import de.robv.android.xposed.callbacks.XC_LoadPackage;

public class XposedMain implements IXposedHookLoadPackage {

    private static final String TARGET_PACKAGE = "com.coloros.alarmclock";
    private static final String ALARM_SERVICE = "com.oplus.alarmclock.alert.AlarmService";
    private static final String ALARM_SCHEDULE = "com.oplus.alarmclock.alarmclock.b2";
    private static final String SHELL_DIR = "/data/user/0/com.coloros.alarmclock/files/shell/";
    private static final String TAG = "AlarmShell ";
    // 同一次响铃 AlarmService 入口会被调用多次（全屏与悬浮窗两条路径），
    // 这里按闹钟 id 做窗口去重，避免脚本重复执行。
    private static final long DEDUP_WINDOW_MS = 60_000L;
    private static final ConcurrentHashMap<String, Long> LAST_FIRED = new ConcurrentHashMap<>();

    @Override
    public void handleLoadPackage(XC_LoadPackage.LoadPackageParam loadPackageParam) throws Throwable {
        if (!TARGET_PACKAGE.equals(loadPackageParam.packageName)) {
            return;
        }
        ClassLoader classLoader = loadPackageParam.classLoader;
        try {
            Class<?> serviceClass = XposedHelpers.findClass(ALARM_SERVICE, classLoader);
            Class<?> scheduleClass = XposedHelpers.findClass(ALARM_SCHEDULE, classLoader);
            XposedBridge.log(TAG + "模块已注入: " + loadPackageParam.processName);

            XposedHelpers.findAndHookMethod(serviceClass, "O", Context.class, scheduleClass, new XC_MethodHook() {
                @Override
                protected void afterHookedMethod(MethodHookParam param) throws Throwable {
                    super.afterHookedMethod(param);
                    try {
                        Object schedule = param.args.length > 1 ? param.args[1] : null;
                        XposedBridge.log(TAG + "响铃入口被调用 schedule=" + schedule);
                        if (schedule == null) {
                            return;
                        }
                        String label = getAlarmLabel(schedule);
                        XposedBridge.log(TAG + "解析出的闹钟名称 = [" + label + "]");
                        if (label == null) {
                            return;
                        }
                        String alarmKey = label + "#" + getAlarmId(schedule);
                        long now = System.currentTimeMillis();
                        Long last = LAST_FIRED.get(alarmKey);
                        if (last != null && now - last < DEDUP_WINDOW_MS) {
                            XposedBridge.log(TAG + "重复触发已忽略: " + alarmKey
                                    + "（距上次 " + (now - last) + "ms）");
                            return;
                        }
                        LAST_FIRED.put(alarmKey, now);
                        runScript(label);
                    } catch (Throwable t) {
                        XposedBridge.log(TAG + "处理异常: " + t);
                    }
                }
            });
        } catch (Throwable t) {
            XposedBridge.log(TAG + "初始化失败: " + t);
        }
    }

    private static void runScript(String label) {
        File shellDir = new File(SHELL_DIR);
        if (!shellDir.exists()) {
            XposedBridge.log(TAG + "创建脚本目录 " + SHELL_DIR + " -> " + shellDir.mkdirs());
        }
        File[] shFiles = shellDir.listFiles();
        XposedBridge.log(TAG + "脚本目录文件数 = " + (shFiles == null ? -1 : shFiles.length));
        if (shFiles == null) {
            return;
        }
        for (File shFile : shFiles) {
            if (shFile.getName().equals(label)) {
                SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault());
                String shFilePath = shFile.getAbsolutePath();
                XposedBridge.log(sdf.format(System.currentTimeMillis()) + " 正在执行shell脚本:" + shFilePath);
                Thread execThread = new ShellExecThread(shFile.getName());
                execThread.setName("AlarmShellThread");
                execThread.start();
                return;
            }
        }
        XposedBridge.log(TAG + "没有找到同名脚本: " + label);
    }

    // b2 里闹钟 id 是 long 字段 c，取不到就退回 hashCode
    private static String getAlarmId(Object schedule) {
        try {
            Object v = XposedHelpers.getObjectField(schedule, "c");
            if (v != null) {
                return String.valueOf(v);
            }
        } catch (Throwable ignored) {
        }
        return String.valueOf(schedule.hashCode());
    }

    private static String getAlarmLabel(Object schedule) {
        try {
            Object v = XposedHelpers.callMethod(schedule, "j");
            XposedBridge.log(TAG + "  b2.j() = " + v);
            if (v instanceof String) {
                return (String) v;
            }
        } catch (Throwable t) {
            XposedBridge.log(TAG + "  b2.j() 调用失败: " + t);
        }
        try {
            Object inner = XposedHelpers.getObjectField(schedule, "p");
            if (inner != null) {
                Object v = XposedHelpers.callMethod(inner, "m");
                XposedBridge.log(TAG + "  r0.m() = " + v);
                if (v instanceof String) {
                    return (String) v;
                }
                v = XposedHelpers.getObjectField(inner, "j");
                if (v instanceof String) {
                    return (String) v;
                }
            }
        } catch (Throwable t) {
            XposedBridge.log(TAG + "  内层取备注失败: " + t);
        }
        return null;
    }
}
