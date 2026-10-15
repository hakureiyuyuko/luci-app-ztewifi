# 打包 luci-app-ztewifi 为可分发的 tar.gz（含 arm64 二进制 + LuCI 文件 + install.sh）
param(
  [string]$Arch = 'arm64',
  [string]$Version = '1.0.0'
)

$ErrorActionPreference = 'Stop'
$proj = $PSScriptRoot
$root = Split-Path $proj -Parent
$name = "luci-app-ztewifi-$Version"
$dist = "$root\dist\$name"

# 1) 编译
$bin = "$root\.build\ztewifi-linux-$Arch"
& "$proj\build.ps1" -Target "linux/$Arch" -Out $bin

# 2) 组装
if (Test-Path "$root\dist") { Remove-Item "$root\dist" -Recurse -Force }
New-Item -ItemType Directory -Force -Path $dist | Out-Null
Copy-Item $bin "$dist\ztewifi"
Copy-Item "$proj\install.sh" "$dist\install.sh"
Copy-Item "$proj\root" "$dist\root" -Recurse

# 3) 强制 LF（脚本在 Linux 上执行）
foreach ($f in @("$dist\install.sh", "$dist\etc\config\ztewifi")) {
  if (Test-Path $f) {
    $t = [System.IO.File]::ReadAllText($f) -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($f, $t, (New-Object System.Text.UTF8Encoding($false)))
  }
}
Get-ChildItem "$dist\root" -Recurse -File | ForEach-Object {
  $t = [System.IO.File]::ReadAllText($_.FullName) -replace "`r`n", "`n"
  [System.IO.File]::WriteAllText($_.FullName, $t, (New-Object System.Text.UTF8Encoding($false)))
}

# 4) 打包
$tar = "$root\dist\$name.tar.gz"
tar -czf $tar -C "$root\dist" $name
Write-Host ("包已生成: {0} ({1:N1} KB)" -f $tar, ((Get-Item $tar).Length / 1KB))
