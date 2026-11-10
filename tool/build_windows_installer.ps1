# Turns the current Windows release build into PaperPlay-Setup.exe with Inno Setup.
# Build first: flutter build windows --release
param([string]$OutputDir = (Join-Path $env:USERPROFILE 'Downloads'))
$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot
$release = Join-Path $root 'build\windows\x64\runner\Release'
if (-not (Test-Path "$release\teleplayer.exe")) { throw 'No release build. Run: flutter build windows --release' }

$compiler = Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'
if (-not (Test-Path $compiler)) { throw 'Inno Setup not found. Run: winget install --id JRSoftware.InnoSetup --exact --scope user' }

$redist = Get-ChildItem 'D:\VS2022BuildTools\VC\Redist\MSVC\*\x64\Microsoft.VC143.CRT' -Directory | Select-Object -Last 1
if (-not $redist) { throw 'C++ runtime files not found under VS2022BuildTools.' }

# pubspec's 0.1.0+1 is version 0.1.0, build 1.
$version = ((Select-String -Path "$root\pubspec.yaml" -Pattern '^version:\s*([^+\s]+)').Matches[0].Groups[1].Value)

& $compiler /Qp "/DMyVersion=$version" "/DMyRelease=$release" "/DMyRedist=$($redist.FullName)" "/DMyOutputDir=$OutputDir" "$root\windows\packaging\teleplayer.iss"
if ($LASTEXITCODE -ne 0) { throw "Inno Setup failed with exit code $LASTEXITCODE." }
Write-Output "$OutputDir\PaperPlay-Setup.exe ($([math]::Round((Get-Item "$OutputDir\PaperPlay-Setup.exe").Length / 1MB)) MB, version $version)"
