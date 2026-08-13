Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class TenantPortalNativeIcon
{
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern bool DestroyIcon(IntPtr handle);
}
'@

$projectRoot = Split-Path -Parent $PSScriptRoot
$ink = [System.Drawing.Color]::FromArgb(255, 13, 33, 29)
$porcelain = [System.Drawing.Color]::FromArgb(255, 250, 248, 243)
$brass = [System.Drawing.Color]::FromArgb(255, 214, 180, 119)
$emerald = [System.Drawing.Color]::FromArgb(255, 21, 151, 117)

function New-BrandBitmap {
    param(
        [Parameter(Mandatory = $true)]
        [int] $Size,
        [bool] $Transparent = $false,
        [double] $MarkScale = 1.0
    )

    $pixelFormat = if ($Transparent) {
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    }
    else {
        [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
    }
    $bitmap = New-Object System.Drawing.Bitmap($Size, $Size, $pixelFormat)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    try {
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.Clear($(if ($Transparent) { [System.Drawing.Color]::Transparent } else { $ink }))

        $edgeInset = $Size * (1.0 - $MarkScale) / 2.0
        $graphics.TranslateTransform([single] $edgeInset, [single] $edgeInset)
        $scale = $Size * $MarkScale / 512.0
        $graphics.ScaleTransform([single] $scale, [single] $scale)

        $arch = New-Object System.Drawing.Drawing2D.GraphicsPath
        try {
            $arch.StartFigure()
            $arch.AddLine(112, 400, 112, 222)
            $arch.AddBezier(112, 222, 112, 129, 176, 72, 256, 72)
            $arch.AddBezier(256, 72, 336, 72, 400, 129, 400, 222)
            $arch.AddLine(400, 222, 400, 400)
            $arch.AddLine(400, 400, 326, 400)
            $arch.AddLine(326, 400, 326, 224)
            $arch.AddBezier(326, 224, 326, 178, 297, 148, 256, 148)
            $arch.AddBezier(256, 148, 215, 148, 186, 178, 186, 224)
            $arch.AddLine(186, 224, 186, 400)
            $arch.CloseFigure()
            $brush = New-Object System.Drawing.SolidBrush($porcelain)
            try { $graphics.FillPath($brush, $arch) } finally { $brush.Dispose() }
        }
        finally {
            $arch.Dispose()
        }

        $keystone = New-Object System.Drawing.Drawing2D.GraphicsPath
        try {
            $keystone.StartFigure()
            $keystone.AddLine(232, 104, 280, 104)
            $keystone.AddLine(280, 104, 269, 153)
            $keystone.AddBezier(269, 153, 260, 149, 252, 149, 243, 153)
            $keystone.CloseFigure()
            $brush = New-Object System.Drawing.SolidBrush($brass)
            try { $graphics.FillPath($brush, $keystone) } finally { $brush.Dispose() }
        }
        finally {
            $keystone.Dispose()
        }

        $door = New-Object System.Drawing.Drawing2D.GraphicsPath
        try {
            $door.StartFigure()
            $door.AddLine(216, 246, 263, 255)
            $door.AddBezier(263, 255, 284, 259, 296, 274, 296, 294)
            $door.AddLine(296, 294, 296, 370)
            $door.AddLine(296, 370, 216, 398)
            $door.CloseFigure()
            $brush = New-Object System.Drawing.SolidBrush($brass)
            try { $graphics.FillPath($brush, $door) } finally { $brush.Dispose() }
        }
        finally {
            $door.Dispose()
        }

        $thresholdBrush = New-Object System.Drawing.SolidBrush($emerald)
        try {
            $graphics.FillRectangle($thresholdBrush, 176, 384, 160, 24)
            $graphics.FillEllipse($thresholdBrush, 164, 384, 24, 24)
            $graphics.FillEllipse($thresholdBrush, 324, 384, 24, 24)
        }
        finally {
            $thresholdBrush.Dispose()
        }
    }
    finally {
        $graphics.Dispose()
    }

    return $bitmap
}

function Save-BrandPng {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RelativePath,
        [Parameter(Mandatory = $true)]
        [int] $Size,
        [bool] $Transparent = $false,
        [double] $MarkScale = 1.0
    )

    $target = Join-Path $projectRoot $RelativePath
    $targetDirectory = Split-Path -Parent $target
    [System.IO.Directory]::CreateDirectory($targetDirectory) | Out-Null
    $bitmap = New-BrandBitmap -Size $Size -Transparent $Transparent -MarkScale $MarkScale
    try {
        $bitmap.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $bitmap.Dispose()
    }
}

function Get-BrandIcoImageBytes {
    param([Parameter(Mandatory = $true)][int] $Size)

    $bitmap = New-BrandBitmap -Size $Size
    $iconHandle = $bitmap.GetHicon()
    $icon = [System.Drawing.Icon]::FromHandle($iconHandle)
    $stream = New-Object System.IO.MemoryStream
    try {
        $icon.Save($stream)
        $singleIcon = $stream.ToArray()
        $imageLength = [System.BitConverter]::ToUInt32($singleIcon, 14)
        $imageOffset = [System.BitConverter]::ToUInt32($singleIcon, 18)
        $imageBytes = New-Object byte[] $imageLength
        [System.Array]::Copy(
            $singleIcon,
            [long] $imageOffset,
            $imageBytes,
            0,
            [long] $imageLength
        )
        $planes = [System.BitConverter]::ToUInt16($imageBytes, 12)
        $bitCount = [System.BitConverter]::ToUInt16($imageBytes, 14)
        return [PSCustomObject]@{
            Bytes = $imageBytes
            Planes = $planes
            BitCount = $bitCount
            ColorCount = $(if ($bitCount -lt 8) { [Math]::Pow(2, $bitCount) } else { 0 })
        }
    }
    finally {
        $stream.Dispose()
        $icon.Dispose()
        [TenantPortalNativeIcon]::DestroyIcon($iconHandle) | Out-Null
        $bitmap.Dispose()
    }
}

$appIconTargets = @(
    @{ Path = 'android/app/src/main/res/mipmap-mdpi/ic_launcher.png'; Size = 48 },
    @{ Path = 'android/app/src/main/res/mipmap-hdpi/ic_launcher.png'; Size = 72 },
    @{ Path = 'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png'; Size = 96 },
    @{ Path = 'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png'; Size = 144 },
    @{ Path = 'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png'; Size = 192 },
    @{ Path = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png'; Size = 1024 },
    @{ Path = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png'; Size = 20 },
    @{ Path = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png'; Size = 40 },
    @{ Path = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png'; Size = 60 },
    @{ Path = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png'; Size = 29 },
    @{ Path = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png'; Size = 58 },
    @{ Path = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png'; Size = 87 },
    @{ Path = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png'; Size = 40 },
    @{ Path = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png'; Size = 80 },
    @{ Path = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png'; Size = 120 },
    @{ Path = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png'; Size = 120 },
    @{ Path = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png'; Size = 180 },
    @{ Path = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png'; Size = 76 },
    @{ Path = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png'; Size = 152 },
    @{ Path = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png'; Size = 167 },
    @{ Path = 'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png'; Size = 16 },
    @{ Path = 'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png'; Size = 32 },
    @{ Path = 'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png'; Size = 64 },
    @{ Path = 'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png'; Size = 128 },
    @{ Path = 'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png'; Size = 256 },
    @{ Path = 'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png'; Size = 512 },
    @{ Path = 'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png'; Size = 1024 },
    @{ Path = 'web/favicon.png'; Size = 32 },
    @{ Path = 'web/icons/Icon-192.png'; Size = 192 },
    @{ Path = 'web/icons/Icon-512.png'; Size = 512 },
    @{ Path = 'web/icons/apple-touch-icon.png'; Size = 180 }
)

foreach ($target in $appIconTargets) {
    Save-BrandPng -RelativePath $target.Path -Size $target.Size
}

Save-BrandPng -RelativePath 'web/icons/Icon-maskable-192.png' -Size 192 -MarkScale 0.8
Save-BrandPng -RelativePath 'web/icons/Icon-maskable-512.png' -Size 512 -MarkScale 0.8

Save-BrandPng -RelativePath 'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png' -Size 120 -Transparent $true
Save-BrandPng -RelativePath 'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png' -Size 240 -Transparent $true
Save-BrandPng -RelativePath 'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png' -Size 360 -Transparent $true

$icoSizes = @(16, 24, 32, 48, 64, 128, 256)
$icoImages = @()
foreach ($size in $icoSizes) {
    $icoImages += Get-BrandIcoImageBytes -Size $size
}

$icoPath = Join-Path $projectRoot 'windows/runner/resources/app_icon.ico'
$icoStream = New-Object System.IO.MemoryStream
$writer = New-Object System.IO.BinaryWriter($icoStream)
try {
    $writer.Write([UInt16] 0)
    $writer.Write([UInt16] 1)
    $writer.Write([UInt16] $icoImages.Count)
    $imageOffset = 6 + (16 * $icoImages.Count)

    for ($index = 0; $index -lt $icoImages.Count; $index++) {
        $size = $icoSizes[$index]
        $image = $icoImages[$index]
        $bytes = $image.Bytes
        $writer.Write([byte] $(if ($size -eq 256) { 0 } else { $size }))
        $writer.Write([byte] $(if ($size -eq 256) { 0 } else { $size }))
        $writer.Write([byte] $image.ColorCount)
        $writer.Write([byte] 0)
        $writer.Write([UInt16] $image.Planes)
        $writer.Write([UInt16] $image.BitCount)
        $writer.Write([UInt32] $bytes.Length)
        $writer.Write([UInt32] $imageOffset)
        $imageOffset += $bytes.Length
    }

    foreach ($image in $icoImages) {
        $writer.Write($image.Bytes)
    }

    [System.IO.File]::WriteAllBytes($icoPath, $icoStream.ToArray())
}
finally {
    $writer.Dispose()
    $icoStream.Dispose()
}

Write-Output "Generated $($appIconTargets.Count + 5) PNG assets and the Windows ICO from the Tenant Portal master mark."
