#!/system/bin/sh
# 示例 2：打开任意 App。
#
# 用法：改下面 APP_ACTIVITY 两行，放到脚本目录，闹钟名称填 open-app.sh
#   查包名：      pm list packages | grep 关键词
#   查入口活动：  cmd package resolve-activity --brief -a android.intent.action.MAIN \
#                     -c android.intent.category.LAUNCHER <包名>

PKG=com.sankuai.meituan
ACT="$PKG/com.meituan.android.pt.homepage.activity.MainActivity"

am start -n "$ACT"
