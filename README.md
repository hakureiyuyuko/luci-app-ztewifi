# luci-app-ztewifi

给 OpenWrt / ImmortalWrt 用的 LuCI 插件：把 **ZTE 随身 WiFi**（RedCap Mobile Hotspot，实测机型 `MU3650` / 市场名 `F40`）的信号、网络、设备信息接进路由器管理界面。

- **首页面板**：在 `状态 → 概览` 的「端口状态」下面、「网络」上面自动多出一块 `ZTE 随身WiFi`，
  排版完全照搬 LuCI 自带「无线」区块（`ifacebox`：蓝底标题条 + `标签: 值` 列表 + 宽体信号徽章），
  信号用 OpenWrt 原生图标（RSRP 换算成质量百分比选图），网络制式/频段/信道各自单独一行。
- **状态页**：`服务 → ZTE 随身WiFi → 状态`，信息更全（信号 / 网络 / 设备三块），按配置的间隔自动刷新。
- **设置页**：`服务 → ZTE 随身WiFi → 设置`，配置随身 WiFi 的 **IP** 与 **登录密码**，内置「保存并测试连接」。
  页底部还有一块「**设备控制**」，可以一键开关随身 WiFi 自身的无线热点（会就地刷新状态，不需要“保存并应用”）。
- 后端是一个**零依赖的 Go 二进制** `ztewifi`（状态类信息纯读取，只有「设备 WiFi 开关」会向设备下发指令）。
  它已拆成**独立的 ``ztewifi`` 包**（前面挂到 packages feed 的 ``net/ztewifi``），本插件只通过 ``LUCI_DEPENDS:=+ztewifi`` 依赖它，
  不再自带 Go 源码。

已在 **ImmortalWrt 25.12 / aarch64 (mediatek/filogic)** 上实测通过。

---

## 目录结构

```
luci-app-ztewifi/                 ← 提交到 immortalwrt/luci 的内容
├── Makefile                     OpenWrt 包定义（基于 luci.mk，依赖 +ztewifi）
├── htdocs/                      LuCI 前端（luci.mk 会装到 /www）
│   └── luci-static/resources/view/
│       ├── status/include/29z_ztewifi.js  ← 首页面板（命名见下方说明）
│       └── ztewifi/{common,status,settings}.js
├── po/                          翻译
│   ├── templates/ztewifi.pot
│   └── zh_Hans/ztewifi.po       → 安装为 ztewifi.zh-cn.lmo
└── root/                        安装到路由器的文件树
    ├── etc/config/ztewifi
    ├── usr/share/luci/menu.d/luci-app-ztewifi.json
    └── usr/share/rpcd/acl.d/luci-app-ztewifi.json
```

Go 后端在另一个仓库 [hakureiyuyuko/ztewifi](https://github.com/hakureiyuyuko/ztewifi)
（上游 feed 包：`net/ztewifi`），不在本目录内。

本工作区里还有本地调试用的一次性打包脚本（不属于上面两个包）：
`build.ps1` / `package.ps1` / `deploy.ps1` / `install.sh`，位于工作区根目录。

Go 后端（`ztewifi` 仓库）的文件构成：

```
ztewifi/
├── main.go        CLI 入口 / 输出
├── status.go      状态聚合、会话缓存、UCI 读写、WiFi 开关
├── zte.go         goform 接口客户端（登录 / 读命令 / AD 校验位）
├── config.go      UCI 配置解析
└── tz.go          OpenWrt /etc/TZ 解析（否则时间会显示成 UTC）
```

---

## 国际化（i18n）

按 OpenWrt / LuCI 的惯例组织：

- 源码里的可翻译字符串一律是**英文**，并用 `_()` 包起来（`menu.d` 的 `title` 也会被服务端 `translate()`）。
- 翻译目录放在 `po/<BCP-47>/<catalog>.po`，`luci.mk` 会用 `po2lmo` 把它们编译成
  `/usr/lib/lua/luci/i18n/<catalog>.<luci-lang>.lmo`（`po/zh_Hans/` → `ztewifi.zh-cn.lmo`），
  并自动生成 `luci-i18n-ztewifi-<lang>` 子包。
- catalog 名取 `LUCI_BASENAME`（即 `ztewifi`），与 `luci-app-ddns` → `ddns.po` 的约定一致。
- 后端（Go）不参与 LuCI i18n：它的 `message` / 错误文本用英文，信号强弱用
  `excellent|good|fair|weak|poor` **代码**输出，由前端用 `_()` 翻译。

目前提供 `zh_Hans`（简体中文）。新增语言只需在 `po/<lang>/ztewifi.po` 放一份翻译。

> 小坑：LuCI 会把目录下**所有** `.lmo` 合并成一张表，`luci-base` 的词条会覆盖同名的插件词条。
> 所以与 base 含义不同的词必须换一个源字符串（本项目就把 `Band` 改成了 `Radio band`,
> 否则会被 base 译成“带宽”）。

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

### 方式 C：buildroot 编译

把整个目录放进 feed（如 `package/luci-app-ztewifi`），然后：

```sh
make menuconfig      # LuCI -> Applications -> luci-app-ztewifi
make package/luci-app-ztewifi/compile V=s
```

`Makefile` 基于 `luci.mk`，会自动处理 `htdocs/`、`root/`、`po/`，并生成
`luci-i18n-ztewifi-<lang>` 翻译子包。Go 后端通过 `src/Makefile` 钩子交叉编译：
luci.mk 会执行 `make -C $(PKG_BUILD_DIR)/src clean compile` 与
`... DESTDIR=$(PKG_INSTALL_DIR) install`（`GOOS`/`GOARCH` 由顶层 Makefile 传入）。
因为存在 `src/Makefile`，本包会被构建成**架构相关**包（带 Go 二进制，这是预期的）。

> 注：本项目的测试环境没有 buildroot，方式 C 的构建未经实机验证；
> 免 buildroot 的安装请用方式 A / B。

---

## 使用

LuCI 菜单：`服务 → ZTE 随身WiFi`

| 页面 | 说明 |
|---|---|
| 状态 | 信号 / 网络 / 设备三块信息，按「状态页刷新间隔」自动刷新，可点「立即刷新」 |
| 设置 | 启用开关、设备 IP、登录密码、刷新间隔、请求超时、「保存并测试连接」 |
| 设置 → 设备控制 | 显示并切换随身 WiFi 自身的无线开关（开启 / 关闭） |

首页 `状态 → 概览` 的 `ZTE 随身WiFi` 面板跟随 LuCI 的全局轮询（约 5 秒）刷新。

### 命令行

> CLI 输出为英文（源码/日志统一英文），中文只出现在 LuCI 界面里（走 `po/` 翻译）。

```sh
ztewifi status --human        # 人类可读
ztewifi status                # JSON
ztewifi test                  # 测连通性，输出 {ok, message}
ztewifi config                # 当前生效配置（密码打码）
ztewifi set --ip 192.168.0.1 --password xxx --interval 5 --enabled 1
ztewifi wifi status           # 读取设备 WiFi 开关状态
ztewifi wifi on | off         # 开启 / 关闭设备 WiFi（会等设备生效后返回）
ztewifi raw cmd1,cmd2         # 调试：直接读任意 goform 命令，输出 JSON
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
| **写操作鉴权** | `ACCESSIBLE_ID_SUPPORT` 为 true 时（本机型如此），**除 `LOGIN` / `SET_WEB_LANGUAGE` 外所有写操作的 body 都要带 `AD`**，否则设备会返回 `{"result":"success"}` 但实际不生效。算法：`AD = SHA256(SHA256(wa_inner_version + cr_version) + RD)`，`RD` 由 `cmd=RD` 读取 |
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

### 设备 WiFi 开关

逆向自设备前端 `js/wifi/wifi_main.js` + `js/service.js`（都需带 `AD`）：

```
关闭: goformId=switchWiFiModule & SwitchOption=0
开启: goformId=switchWiFiChip   & ChipEnum=<chip1_2|chip1|chip2> & GuestEnable=0
```

`ChipEnum` 按当前各芯片的 AP 开关状态推导（同设备 `util.js` 的 `handleWifiChipStatus`）：

```
wifi_chip1_ssid1_switch_onoff / wifi_chip2_ssid1_switch_onoff
  1/1 -> chip1_2     1/0 -> chip1     0/1 -> chip2     其他 -> chip1_2
```

开关后靠轮询 `wifi_onoff_state` 判断是否生效（设备实际切换需要几秒）。

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
