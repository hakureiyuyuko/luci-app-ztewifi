# 构建并部署 luci-app-ztewifi 到路由器
# 用法:  .\deploy.ps1 -Router 192.168.1.1 -DevicePassword 'xxx'   完整构建+部署
#        .\deploy.ps1 -NoBuild                                  跳过构建, 直接部署已有二进制
param(
  [switch]$NoBuild,
  [string]$Router = '192.168.1.1',
  [string]$DeviceIP = '192.168.0.1',
  [string]$DevicePassword = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$proj = $PSScriptRoot
$bin  = "$root\.build\ztewifi-linux-arm64"

$env:SSH_ASKPASS = "$root\_askpass.cmd"
$env:SSH_ASKPASS_REQUIRE = 'force'
$env:DISPLAY = 'localhost:0'

$sshFlags = @('-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=NUL', '-o', 'LogLevel=ERROR',
              '-o', 'PreferredAuthentications=password', '-o', 'PubkeyAuthentication=no')
$scpFlags = @('-O') + $sshFlags

function RSH([string]$cmd) {
  & ssh @sshFlags "root@$Router" $cmd
  if ($LASTEXITCODE -ne 0) { throw "remote command failed: $cmd" }
}
function RPUT([string]$src, [string]$dst) {
  & scp @scpFlags "$src" "root@${Router}:$dst"
  if ($LASTEXITCODE -ne 0) { throw "scp failed: $src -> $dst" }
}

# ---------- 1. 构建 ----------
if (-not $NoBuild) {
  & "$proj\build.ps1" -Target 'linux/arm64' -Out $bin
}
if (-not (Test-Path $bin)) { throw "找不到二进制 $bin，请先构建" }

# ---------- 2. 上传二进制 ----------
Write-Host "==> uploading binary"
RPUT $bin '/tmp/ztewifi.new'
RSH "mkdir -p /usr/bin && mv /tmp/ztewifi.new /usr/bin/ztewifi && chmod 755 /usr/bin/ztewifi && /usr/bin/ztewifi version"

# ---------- 3. 上传 LuCI 文件 ----------
Write-Host "==> uploading luci files"
RSH "mkdir -p /usr/share/luci/menu.d /usr/share/rpcd/acl.d /usr/lib/lua/luci/i18n /www/luci-static/resources/view/ztewifi /www/luci-static/resources/view/status/include"

RPUT "$proj\root\usr\share\luci\menu.d\luci-app-ztewifi.json"      '/usr/share/luci/menu.d/luci-app-ztewifi.json'
RPUT "$proj\root\usr\share\rpcd\acl.d\luci-app-ztewifi.json"       '/usr/share/rpcd/acl.d/luci-app-ztewifi.json'
RPUT "$proj\htdocs\luci-static\resources\view\ztewifi\common.js"   '/www/luci-static/resources/view/ztewifi/common.js'
RPUT "$proj\htdocs\luci-static\resources\view\ztewifi\status.js"   '/www/luci-static/resources/view/ztewifi/status.js'
RPUT "$proj\htdocs\luci-static\resources\view\ztewifi\settings.js" '/www/luci-static/resources/view/ztewifi/settings.js'
RPUT "$proj\htdocs\luci-static\resources\view\status\include\29z_ztewifi.js" '/www/luci-static/resources/view/status/include/29z_ztewifi.js'
# 清理旧版本文件名（早期版本叫 75_ztewifi.js）
RSH "rm -f /www/luci-static/resources/view/status/include/75_ztewifi.js"
RSH "chmod 644 /usr/share/luci/menu.d/luci-app-ztewifi.json /usr/share/rpcd/acl.d/luci-app-ztewifi.json /www/luci-static/resources/view/ztewifi/*.js /www/luci-static/resources/view/status/include/29z_ztewifi.js"

# 翻译目录（语言目录名 -> LuCI 语言代码，与 luci.mk 的 LUCI_LC_ALIAS 一致）
$langMap = @{ 'zh_Hans' = 'zh-cn'; 'zh_Hant' = 'zh-tw' }
Write-Host "==> uploading translations"
Get-ChildItem "$proj\po" -Directory | Where-Object { $_.Name -ne 'templates' } | ForEach-Object {
  $code = if ($langMap.ContainsKey($_.Name)) { $langMap[$_.Name] } else { $_.Name.ToLower().Replace('_','-') }
  Get-ChildItem $_.FullName -Filter *.po | ForEach-Object {
    $lmo = "$env:TEMP\$($_.BaseName).$code.lmo"
    & node "$root\.build\potool.mjs" $_.FullName $lmo | Out-Null
    RPUT $lmo "/usr/lib/lua/luci/i18n/$($_.BaseName).$code.lmo"
    RSH "chmod 644 /usr/lib/lua/luci/i18n/$($_.BaseName).$code.lmo"
  }
}

# ---------- 4. UCI 配置（仅在不存在时创建，避免覆盖已有设置） ----------
RSH "if [ ! -f /etc/config/ztewifi ]; then touch /etc/config/ztewifi; fi"
RSH "uci -q get ztewifi.main >/dev/null || uci set ztewifi.main=ztewifi"
RSH "uci -q get ztewifi.main.ip >/dev/null || uci set ztewifi.main.ip='$DeviceIP'"
RSH "uci -q get ztewifi.main.enabled >/dev/null || uci set ztewifi.main.enabled='1'"
RSH "uci -q get ztewifi.main.interval >/dev/null || uci set ztewifi.main.interval='5'"
RSH "uci -q get ztewifi.main.timeout >/dev/null || uci set ztewifi.main.timeout='8'"
if ($DevicePassword -ne '') {
  RSH "uci set ztewifi.main.password='$DevicePassword'"
}
RSH "uci commit ztewifi; chmod 600 /etc/config/ztewifi; cat /etc/config/ztewifi"

# ---------- 5. 重载 rpcd (ACL 变更需重新登录生效) ----------
Write-Host "==> reloading rpcd"
RSH "rm -f /tmp/luci-indexcache* /tmp/luci-modulecache/* 2>/dev/null; /etc/init.d/rpcd restart >/dev/null 2>&1; sleep 1; echo rpcd-restarted"

# ---------- 6. 自检 ----------
Write-Host "==> self test"
RSH "/usr/bin/ztewifi status --human"
