package top.weixiansen574.alarmshell.xposed;

import java.io.File;
import java.io.FileOutputStream;
import java.text.SimpleDateFormat;
import java.util.Locale;

import de.robv.android.xposed.XposedBridge;

// 不依赖应用内 root：只把要执行的脚本名写进触发目录，
// 由 root 侧的 alarmshell-watch.sh 监听并执行。
public class ShellExecThread extends Thread {
    private static final String TAG = "AlarmShell ";
    private static final String TRIGGER_DIR = "/data/user/0/com.coloros.alarmclock/files/trigger";

    private final String scriptName;

    public ShellExecThread(String scriptName) {
        this.scriptName = scriptName;
    }

    @Override
    public void run() {
        try {
            File dir = new File(TRIGGER_DIR);
            if (!dir.exists() && !dir.mkdirs()) {
                XposedBridge.log(TAG + "无法创建触发目录: " + TRIGGER_DIR);
                return;
            }
            String stamp = new SimpleDateFormat("yyyyMMdd_HHmmss_SSS", Locale.US).format(System.currentTimeMillis());
            File req = new File(dir, stamp + ".req");
            FileOutputStream fos = new FileOutputStream(req);
            fos.write(scriptName.getBytes("UTF-8"));
            fos.close();
            req.setReadable(true, false);
            XposedBridge.log(TAG + "已投递触发: " + req.getAbsolutePath() + " -> " + scriptName);
        } catch (Exception e) {
            XposedBridge.log(TAG + "投递触发失败: " + e);
        }
    }
}
