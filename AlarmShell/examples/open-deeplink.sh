#!/system/bin/sh
# 示例 3：打开 Deep Link / URL Scheme 指定的页面（如某个 App 的具体功能页）。
#
# 用法：把 URI 换成目标页的 deep link，闹钟名称填 open-deeplink.sh
# 下面这条是美团「拼好饭」页面（从美团 APK 内提取）。

PKG=com.sankuai.meituan
URI='imeituan://www.meituan.com/mmp?shareEnv=release&appId=a8720b841a3d4b1d&targetPath=%2Fpages%2Findex%2Findex%3FshareType%3Dpinhaofan%26channel_id%3D14'

am start -a android.intent.action.VIEW -d "$URI" "$PKG"
