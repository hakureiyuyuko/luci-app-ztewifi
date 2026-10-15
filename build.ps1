param(
  [string]$Target = 'linux/arm64',
  [string]$Out = "$PSScriptRoot\..\.build\ztewifi"
)

$ErrorActionPreference = 'Stop'

# Go 工具链位置：优先环境变量 GO_ROOT，其次 .build\go，其次 PATH 里的 go
$root = Split-Path $PSScriptRoot -Parent
$goRoot = $env:GO_ROOT
if (-not $goRoot -or -not (Test-Path "$goRoot\bin\go.exe")) {
  if (Test-Path "$root\.build\go\bin\go.exe") { $goRoot = "$root\.build\go" }
}
if ($goRoot) {
  $env:GOROOT = $goRoot
  $env:PATH = "$goRoot\bin;$env:PATH"
  $goExe = "$goRoot\bin\go.exe"
} else {
  $goExe = (Get-Command go).Source
}

$env:GOCACHE = "$root\.build\gocache"
$env:CGO_ENABLED = '0'

$parts = $Target.Split('/')
$env:GOOS = $parts[0]
$env:GOARCH = $parts[1]

Write-Host "building $Target -> $Out"
Push-Location "$PSScriptRoot\src"
try {
  & $goExe build -trimpath -ldflags '-s -w' -o $Out .
  if ($LASTEXITCODE -ne 0) { throw "go build failed" }
} finally {
  Pop-Location
}

$f = Get-Item $Out
Write-Host ("ok: {0} ({1:N1} KB)" -f $f.Name, ($f.Length / 1KB))
