#!/bin/sh
# luci-app-ztewifi 安装脚本（在路由器本机以 root 运行）
#
# 目录布局:
#   ztewifi            -> /usr/bin/ztewifi
#   root/              -> 直接铺到 /  (etc/, usr/，含 usr/lib/lua/luci/i18n/*.lmo)
#   htdocs/            -> /www/
#   root/etc/config/ztewifi 仅在不存在时安装
#
# 用法:  sh install.sh

set -e

DIR="$(cd "$(dirname "$0")" && pwd)"

if [ "$(id -u)" != "0" ]; then
	echo "错误: 请以 root 身份运行（OpenWrt 上直接 sh install.sh）" >&2
	exit 1
fi

if [ ! -f "$DIR/ztewifi" ]; then
	echo "错误: 找不到 $DIR/ztewifi（请使用与本机架构匹配的二进制）" >&2
	exit 1
fi

echo "==> 安装 /usr/bin/ztewifi"
cp -f "$DIR/ztewifi" /usr/bin/ztewifi
chmod 0755 /usr/bin/ztewifi

echo "==> 安装 LuCI 文件"
mkdir -p /usr/share/luci/menu.d /usr/share/rpcd/acl.d \
         /usr/lib/lua/luci/i18n \
         /www/luci-static/resources/view/ztewifi \
         /www/luci-static/resources/view/status/include
cp -a "$DIR/root/usr/." /usr/
cp -a "$DIR/htdocs/." /www/
# 清理旧版本文件名（早期版本叫 75_ztewifi.js）
rm -f /www/luci-static/resources/view/status/include/75_ztewifi.js
chmod 0644 /usr/share/luci/menu.d/luci-app-ztewifi.json \
           /usr/share/rpcd/acl.d/luci-app-ztewifi.json \
           /www/luci-static/resources/view/ztewifi/*.js \
           /www/luci-static/resources/view/status/include/29z_ztewifi.js
chmod 0644 /usr/lib/lua/luci/i18n/*.lmo 2>/dev/null || true

echo "==> 初始化 /etc/config/ztewifi"
[ -f /etc/config/ztewifi ] || cp "$DIR/root/etc/config/ztewifi" /etc/config/ztewifi
uci -q get ztewifi.main >/dev/null 2>&1 || uci set ztewifi.main=ztewifi
uci -q get ztewifi.main.enabled  >/dev/null 2>&1 || uci set ztewifi.main.enabled='1'
uci -q get ztewifi.main.ip       >/dev/null 2>&1 || uci set ztewifi.main.ip='192.168.0.1'
uci -q get ztewifi.main.interval >/dev/null 2>&1 || uci set ztewifi.main.interval='5'
uci -q get ztewifi.main.timeout  >/dev/null 2>&1 || uci set ztewifi.main.timeout='8'
uci commit ztewifi
chmod 600 /etc/config/ztewifi

echo "==> 重载 rpcd"
/etc/init.d/rpcd restart >/dev/null 2>&1 || true
rm -f /tmp/luci-indexcache* 2>/dev/null || true

echo "==> 安装完成: $(/usr/bin/ztewifi version)"
echo "    请在 LuCI 重新登录后进入『服务 -> ZTE 随身WiFi -> 设置』填写设备登录密码。"
