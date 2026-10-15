# luci-app-ztewifi

给 OpenWrt / ImmortalWrt 用的 LuCI 插件：把 **ZTE 随身 WiFi**（RedCap Mobile Hotspot，实测机型 `MU3650` / 市场名 `F40`）的信号、网络、设备信息接进路由器管理界面。

- **首页面板**：在 `状态 → 概览` 的「端口状态」下面、「网络」上面自动多出一块 `ZTE 随身WiFi`，
  排版完全照搬 LuCI 自带「无线」区块（`ifacebox`：蓝底标题条 + `标签: 值` 列表 + 宽体信号徽章），
  信号用 OpenWrt 原生图标（RSRP 换算成质量百分比选图），网络制式/频段/信道各自单独一行。
- **状态页**：`服务 → ZTE 随身WiFi → 状态`，信息更全（信号 / 网络 / 设备三块），按配置的间隔自动刷新。
- **设置页**：`服务 → ZTE 随身WiFi → 设置`，配置随身 WiFi 的 **IP** 与 **登录密码**，内置「保存并测试连接」。
- 后端是一个**零依赖的 Go 二进制**（`/usr/bin/ztewifi`），通过设备自带网页接口取数；纯读取，不修改随身 WiFi 的任何设置。

已在 **ImmortalWrt 25.12 / aarch64 (mediatek/filogic)** 上实测通过。

---

## 目录结构

```
luci-app-ztewifi/
├── Makefile                     OpenWrt buildroot 包定义
├── build.ps1                    Windows 下交叉编译（也可直接 go build）
├── package.ps1                  生成可分发的 tar.gz
├── deploy.ps1                   构建 + 一键部署到测试路由器
├── install.sh                   在路由器本机安装（tar 包内）
├── src/                         Go 源码（标准库，无第三方依赖）
│   ├── go.mod
│   ├── main.go                  CLI 入口 / 输出
│   ├── status.go                状态聚合、会话缓存、UCI 读写
│   ├── zte.go                   gofrom 接口客户端（登录 / 读命令）
│   ├── config.go                UCI 配置解析
│   └── tz.go                    OpenWrt /etc/TZ 解析（否则时间会显示成 UTC）
└── root/                        安装到路由器的文件树
    ├── etc/config/ztewifi
    ├── usr/share/luci/menu.d/luci-app-ztewifi.json
    ├── usr/share/rpcd/acl.d/luci-app-ztewifi.json
    └── www/luci-static/resources/view/
        ├── status/include/29z_ztewifi.js  ← 首页面板（命名见下方说明）
        └── ztewifi/{common,status,settings}.js
```

---

## 安装

### 方式 A：分发包（推荐）

```sh
# 把 luci-app-ztewifi-1.0.0.tar.gz 传到路由器后
cd /tmp && tar xzf luci-app-ztewifi-1.0.0.tar.gz
cd luci-app-ztewifi-1.0.0 && sh install.sh
```

默认配置文件中密码为空，安装后到 LuCI 设置页填写即可：

```
uci set ztewifi.main.password='你的随身WiFi后台密码'
uci commit ztewifi
```

### 方式 B：从 Windows 一键部署（开发用）

```powershell
.\deploy.ps1 -DevicePassword '你的密码'
```

需要本机有 Go 工具链（`build.ps1` 会找 `$env:GO_ROOT`、`.build\go` 或 PATH 里的 `go`）。

### 方式 C：buildroot 编译成 ipk/apk

把整个目录放进 feed（如 `package/luci-app-ztewifi`），然后：

```sh
make menuconfig      # LuCI -> Applications -> luci-app-ztewifi
make package/luci-app-ztewifi/compile V=s
```

> 注：`Makefile` 使用 OpenWrt 标准的 `golang-package.mk` 约定，未在本机构建验证；
> 免 buildroot 的安装请用方式 A / B。

---

## 使用

LuCI 菜单：`服务 → ZTE 随身WiFi`

| 页面 | 说明 |
|---|---|
| 状态 | 信号 / 网络 / 设备三块信息，按「状态页刷新间隔」自动刷新，可点「立即刷新」 |
| 设置 | 启用开关、设备 IP、登录密码、刷新间隔、请求超时、「保存并测试连接」 |

首页 `状态 → 概览` 的 `ZTE 随身WiFi` 面板跟随 LuCI 的全局轮询（约 5 秒）刷新。

### 命令行

```sh
ztewifi status --human        # 人类可读
ztewifi status                # JSON
ztewifi test                  # 测连通性，输出 {ok, message}
ztewifi config                # 当前生效配置（密码打码）
ztewifi set --ip 192.168.0.1 --password xxx --interval 5 --enabled 1
```

### 配置文件

`/etc/config/ztewifi`（安装后权限 600）：

```
config ztewifi 'main'
	option enabled '1'
	option ip '192.168.0.1'
	option password '...'
	option interval '5'
	option timeout '8'
```

优先级：命令行参数 > 环境变量（`ZTEWIFI_IP` / `ZTEWIFI_PASSWORD`）> UCI > 默认值。

---

## 它对接的是什么接口

随身 WiFi 内置网页（`http://192.168.0.1`）用的是 ZTE 一脉相承的 `goform` 接口，逆向要点：

| 事项 | 结论 |
|---|---|
| 读接口 | `GET /goform/goform_get_cmd_process?isTest=false&multi_data=1&cmd=a,b,c` |
| 写接口 | `POST /goform/goform_set_cmd_process`，body `isTest=false&goformId=...` |
| 必需请求头 | `Referer: http://<ip>/` 和 `X-Requested-With: XMLHttpRequest`，**缺任一个返回空** |
| 登录 | `GET cmd=LD` 取挑战值 → `password = SHA256(SHA256(明文) + LD)`（全大写）→ `goformId=LOGIN`，`result` 为 `0`/`4` 即成功 |
| 会话 | 登录响应的 `Set-Cookie: zsidn=<64hex>`（**HttpOnly**，`document.cookie` 看不到），后续请求必须回传 |
| 连接 | 设备是 HTTP/1.0 语义，必须短连接（Go 里 `DisableKeepAlives`），否则第二个请求 ECONNRESET |

关键命令（实测值示例）：

```
network_type        NR5G-SA          network_signalbar   4
Z5g_rsrp / Z5g_rsrq / Z5g_SINR   -99 / -13 / 1.5     （SINR 是大写）
network_lte_rsrp    -93              network_rssi        -66
wan_active_band     NR BAND 28       wan_active_channel  154570
network_cell_id     xxxxxxx         network_provider_fullname  <运营商名>
ppp_status          ipv4_ipv6_connected
sim_iccid / sim_imsi / imei / model_name / device_market_name / wa_inner_version
flux_realtime_{tx,rx}_thrpt   battery_value   wifi_chip1_ssid1_ssid
```

> 注意：**未登录时几乎所有命令都返回空串**（只有 `imei`、`wa_inner_version` 等少数例外），
> 所以「读不到数据」基本等于「没登录成功 / 会话被顶掉」。

---

## 实现说明（LuCI 25.12 适配）

当前 LuCI（25.12，JS 客户端）与老的 Lua 版差异较大，几个必须踩对的点：

1. **首页挂载与排序**：`view/status/index.js` 会 `fs.list()` 出 `view/status/include/` 下的所有 `.js`，
   按 **文件名字符串序** 排序后逐个 `L.require`，每个渲染成一块面板。
   所以往那个目录塞文件就出现在首页，**不需要改任何 LuCI 自带文件**。
   本插件用 `29z_ztewifi.js` 这个名字，是为了让字符串序落在
   `29_ports`（端口状态）与 `30_network`（网络）之间。改名即可调整位置。
2. **抄原生排版**：首页模板 `/usr/share/ucode/luci/template/admin_status/index.ut` 会向页面注入三个全局：
   `renderBox(title, active, childs, ...pairs)`、`renderBadge(icon, title, ...pairs)`、`L.itemlist()`。
   直接复用它们就能做出和官方「无线」区块一模一样的 `ifacebox`。
   注意宽体徽章靠的是容器 `.network-status-table`：
   `.network-status-table .ifacebox-body .ifacebadge { display:flex; flex:1; min-width:220px }`。
3. **模块返回值**：LuCI 的 loader 会 `const instance = new _class()`，模块**必须返回 `baseclass.extend({...})`**；
   返回普通对象字面量会报 `factory yields invalid constructor`。
4. **路由是路径式**：`/cgi-bin/luci/admin/services/ztewifi/status`，不是老的 `#/...`。
5. **调用后端**：视图用 `fs.exec('/usr/bin/ztewifi', ['status'])`（走 rpcd 的 `file.exec`），
   因此 ACL 需要放开 `ubus.file.exec` 与对应 `file` 的 `exec` 权限。
6. **时区**：OpenWrt 把时区放在 `/etc/TZ`（POSIX 串如 `CST-8`），而 Go 只认 `$TZ` / `/etc/localtime`
   且不解析 POSIX 串 → 不处理的话时间会显示成 UTC。`src/tz.go` 里做了手动解析。

---

## 排错

| 现象 | 原因 / 处理 |
|---|---|
| 面板显示「读取失败」 | 一般是密码没填或填错；用 `ztewifi test` 看具体报错 |
| `PermissionError` / 403 | ACL 未生效：`/etc/init.d/rpcd restart`，然后**重新登录 LuCI**（会话 ACL 在登录时下发） |
| 菜单里没有「ZTE 随身WiFi」 | `/etc/config/ztewifi` 不存在（菜单依赖 `uci: ztewifi`），或 rpcd 未重载 |
| 状态页空白并报 `factory yields invalid constructor` | 模块没返回 `baseclass.extend(...)` |
| 时间显示成 UTC/偏移 | `/etc/TZ` 内容不是标准 POSIX 串 |
| 数据时有时无 | 设备只允许单个 web 会话；若有别人开着随身 WiFi 网页后台，会互相顶掉 |

---

## 安全提示

- 密码以明文保存在路由器 `/etc/config/ztewifi`（权限 600），与 LuCI 自身的做法一致。
- ACL 放开的是**执行本插件二进制**的权限，不会给用户 shell。
- 插件只读随身 WiFi 的状态，不写入。
