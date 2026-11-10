# Turns the current Windows release build into PaperPlay-Setup.exe with Inno Setup.
# Build first: flutter build windows --release
param([string]$OutputDir = (Join-Path $env:USERPROFILE 'Downloads'))
$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot
$release = Join-Path $root 'build\windows\x64\runner\Release'
if (-not (Test-Path "$release\teleplayer.exe")) { throw 'No release build. Run: flutter build windows --release' }

# Where Inno Setup lands per user (winget), per machine, or from a CI image (choco).
$compiler = @(
  (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
  (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
  (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe')
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $compiler) { throw 'Inno Setup not found. Run: winget install --id JRSoftware.InnoSetup --exact --scope user' }

# The C++ runtime from whichever Visual Studio is installed, here or on a CI image.
$redistRoots = @(
  'D:\VS2022BuildTools\VC\Redist\MSVC',
  (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\2022\*\VC\Redist\MSVC'),
  (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\2022\*\VC\Redist\MSVC')
)
$redist = $redistRoots | ForEach-Object { Get-ChildItem (Join-Path $_ '*\x64\Microsoft.VC143.CRT') -Directory -ErrorAction SilentlyContinue } | Select-Object -Last 1
if (-not $redist) { throw 'C++ runtime files not found under Visual Studio.' }
New-Item -ItemType Directory -Force $OutputDir | Out-Null

# pubspec's 0.1.0+1 is version 0.1.0, build 1.
$version = ((Select-String -Path "$root\pubspec.yaml" -Pattern '^version:\s*([^+\s]+)').Matches[0].Groups[1].Value)

& $compiler /Qp "/DMyVersion=$version" "/DMyRelease=$release" "/DMyRedist=$($redist.FullName)" "/DMyOutputDir=$OutputDir" "$root\windows\packaging\teleplayer.iss"
if ($LASTEXITCODE -ne 0) { throw "Inno Setup failed with exit code $LASTEXITCODE." }
Write-Output "$OutputDir\PaperPlay-Setup.exe ($([math]::Round((Get-Item "$OutputDir\PaperPlay-Setup.exe").Length / 1MB)) MB, version $version)"
