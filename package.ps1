# 打包 luci-app-ztewifi 为可分发的 tar.gz
#   - arm64 Go 二进制
#   - htdocs/ (LuCI 前端)   root/ (UCI/menu/ACL)   po/ 编译出的 .lmo
#   - install.sh
param(
  [string]$Arch = 'arm64',
  [string]$Version = '1.0.0'
)

$ErrorActionPreference = 'Stop'
$proj = $PSScriptRoot
$root = Split-Path $proj -Parent
$name = "luci-app-ztewifi-$Version"
$dist = "$root\dist\$name"

# po 语言目录名 -> LuCI 安装后的语言代码（与 luci.mk 的 LUCI_LC_ALIAS 对应）
$langMap = @{ 'zh_Hans' = 'zh-cn'; 'zh_Hant' = 'zh-tw'; 'pt_BR' = 'pt-br'; 'nb_NO' = 'nb-no' }

# ---------- 1. 编译 Go ----------
$bin = "$root\.build\ztewifi-linux-$Arch"
& "$proj\build.ps1" -Target "linux/$Arch" -Out $bin

# ---------- 2. 组装 ----------
if (Test-Path "$root\dist") { Remove-Item "$root\dist" -Recurse -Force }
New-Item -ItemType Directory -Force -Path $dist | Out-Null
Copy-Item $bin "$dist\ztewifi"
Copy-Item "$proj\install.sh" "$dist\install.sh"
Copy-Item "$proj\root" "$dist\root" -Recurse
Copy-Item "$proj\htdocs" "$dist\htdocs" -Recurse

# ---------- 3. po -> lmo ----------
# 正式构建由 luci.mk 调用 po2lmo 完成，这里用等价的本地实现，
# 顺便验证 .po 能被正确解析。
$i18n = "$dist\root\usr\lib\lua\luci\i18n"
New-Item -ItemType Directory -Force -Path $i18n | Out-Null
$poDir = "$proj\po"
Get-ChildItem $poDir -Directory | Where-Object { $_.Name -ne 'templates' } | ForEach-Object {
  $langDir = $_.Name
  $code = if ($langMap.ContainsKey($langDir)) { $langMap[$langDir] } else { $langDir.ToLower().Replace('_', '-') }
  Get-ChildItem $_.FullName -Filter *.po | ForEach-Object {
    $out = Join-Path $i18n ("{0}.{1}.lmo" -f $_.BaseName, $code)
    & node "$root\.build\potool.mjs" $_.FullName $out
  }
}

# ---------- 4. 统一换行符为 LF ----------
$utf8 = New-Object System.Text.UTF8Encoding($false)
Get-ChildItem $dist -Recurse -File | Where-Object { $_.Extension -ne '.lmo' -and $_.Extension -ne '' -and $_.Name -ne 'ztewifi' } | ForEach-Object {
  if ($_.Name -notmatch '\.(exe|bin)$' -and $_.FullName -notlike '*\ztewifi') {
    $t = [System.IO.File]::ReadAllText($_.FullName) -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($_.FullName, $t, $utf8)
  }
}

# ---------- 5. 打包 ----------
$tar = "$root\dist\$name.tar.gz"
tar -czf $tar -C "$root\dist" $name
Write-Host ("包已生成: {0} ({1:N1} KB)" -f $tar, ((Get-Item $tar).Length / 1KB))
