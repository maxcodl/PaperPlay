# Writes windows/runner/resources/app_icon.ico from assets/icon/icon.png, at each size
# Windows asks for, so the taskbar and Start menu don't scale one large image down.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = Split-Path $PSScriptRoot
$sizes = 16, 20, 24, 32, 40, 48, 64, 128, 256
$source = [Drawing.Image]::FromFile("$root\assets\icon\icon.png")
$frames = foreach ($size in $sizes) {
  $bitmap = New-Object Drawing.Bitmap $size, $size
  $graphics = [Drawing.Graphics]::FromImage($bitmap)
  $graphics.InterpolationMode = 'HighQualityBicubic'
  $graphics.DrawImage($source, 0, 0, $size, $size)
  $graphics.Dispose()
  $png = New-Object IO.MemoryStream
  $bitmap.Save($png, [Drawing.Imaging.ImageFormat]::Png)
  $bitmap.Dispose()
  , $png.ToArray()
}
$source.Dispose()

$out = New-Object IO.MemoryStream
$writer = New-Object IO.BinaryWriter $out
$writer.Write([uint16]0)              # Reserved
$writer.Write([uint16]1)              # Type: icon
$writer.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
  $side = if ($sizes[$i] -eq 256) { 0 } else { $sizes[$i] }  # 0 means 256 in this format
  $writer.Write([byte]$side)
  $writer.Write([byte]$side)
  $writer.Write([byte]0)              # No palette
  $writer.Write([byte]0)              # Reserved
  $writer.Write([uint16]1)            # Colour planes
  $writer.Write([uint16]32)           # Bits per pixel
  $writer.Write([uint32]$frames[$i].Length)
  $writer.Write([uint32]$offset)
  $offset += $frames[$i].Length
}
foreach ($frame in $frames) { $writer.Write([byte[]]$frame) }
$writer.Flush()
[IO.File]::WriteAllBytes("$root\windows\runner\resources\app_icon.ico", $out.ToArray())
