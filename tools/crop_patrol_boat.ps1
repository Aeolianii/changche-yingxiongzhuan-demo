Add-Type -AssemblyName System.Drawing

$sourcePath = Join-Path $PSScriptRoot "..\assets\ui\merchant_shop\ships\source\art_team_ship_1_alpha.png"
$outputPath = Join-Path $PSScriptRoot "..\assets\ui\merchant_shop\ships\source\patrol_boat_crop_alpha.png"
$source = [System.Drawing.Bitmap]::new($sourcePath)
$cropRect = [System.Drawing.Rectangle]::new(105, 320, 240, 300)
$crop = $source.Clone($cropRect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$crop.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
$crop.Dispose()
$source.Dispose()
