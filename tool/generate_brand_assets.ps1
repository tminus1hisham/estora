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

# The mark: a navy arcade on a warm stone tile, brass on the centre pier.
# Geometry is normalised to a 512 artboard and shared with
# assets/branding/tenant_portal_mark.svg and lib/components/app_brand_mark.dart.
$navy = [System.Drawing.Color]::FromArgb(255, 10, 26, 48)
$brass = [System.Drawing.Color]::FromArgb(255, 185, 132, 46)
$stone0 = [System.Drawing.Color]::FromArgb(255, 255, 254, 251)
$stone50 = [System.Drawing.Color]::FromArgb(255, 250, 248, 243)
$stone100 = [System.Drawing.Color]::FromArgb(255, 243, 240, 233)

$cornerRatio = 0.21875   # 112 / 512

function New-RoundedRectPath {
    param(
        [Parameter(Mandatory = $true)][double] $X,
        [Parameter(Mandatory = $true)][double] $Y,
        [Parameter(Mandatory = $true)][double] $W,
        [Parameter(Mandatory = $true)][double] $H,
        [Parameter(Mandatory = $true)][double] $R
    )

    $d = $R * 2
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc([single] $X, [single] $Y, [single] $d, [single] $d, 180, 90)
    $path.AddArc([single] ($X + $W - $d), [single] $Y, [single] $d, [single] $d, 270, 90)
    $path.AddArc(
        [single] ($X + $W - $d),
        [single] ($Y + $H - $d),
        [single] $d,
        [single] $d,
        0,
        90
    )
    $path.AddArc([single] $X, [single] ($Y + $H - $d), [single] $d, [single] $d, 90, 90)
    $path.CloseFigure()
    return $path
}

function New-ArcadePath {
    # Outer piers of 48, a centre pier of 64 and two bays of 84, cut as one
    # outline so the arches are true negative space. Arc sweeps are negative
    # because GDI+ measures positive angles clockwise on a y-down canvas, and
    # each arch climbs from its right springing point over the crown to its
    # left one.
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.StartFigure()
    $path.AddLine(92, 118, 420, 118)
    $path.AddLine(420, 118, 420, 394)
    $path.AddLine(420, 394, 372, 394)
    $path.AddLine(372, 394, 372, 220)
    $path.AddArc(288, 178, 84, 84, 0, -180)
    $path.AddLine(288, 220, 288, 394)
    $path.AddLine(288, 394, 224, 394)
    $path.AddLine(224, 394, 224, 220)
    $path.AddArc(140, 178, 84, 84, 0, -180)
    $path.AddLine(140, 220, 140, 394)
    $path.AddLine(140, 394, 92, 394)
    $path.CloseFigure()
    return $path
}

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
        $graphics.Clear([System.Drawing.Color]::Transparent)

        # Launcher PNGs stay square and full-bleed — every platform applies its
        # own mask, and a pre-rounded corner shows up as a seam inside it. The
        # transparent variant is the standalone launch mark, so that one carries
        # the rounded tile itself.
        $clipPath = $null
        if ($Transparent) {
            $clipPath = New-RoundedRectPath -X 0 -Y 0 -W $Size -H $Size -R ($Size * $cornerRatio)
            $graphics.SetClip($clipPath)
        }

        $tileRect = New-Object System.Drawing.RectangleF(0, 0, [single] $Size, [single] $Size)
        $tileBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            $tileRect, $stone0, $stone100, [single] 45.0
        )
        try {
            $blend = New-Object System.Drawing.Drawing2D.ColorBlend(3)
            $blend.Colors = @($stone0, $stone50, $stone100)
            $blend.Positions = @([single] 0.0, [single] 0.55, [single] 1.0)
            $tileBrush.InterpolationColors = $blend
            $graphics.FillRectangle($tileBrush, $tileRect)
        }
        finally {
            $tileBrush.Dispose()
        }

        $edgeInset = $Size * (1.0 - $MarkScale) / 2.0
        $graphics.TranslateTransform([single] $edgeInset, [single] $edgeInset)
        $scale = $Size * $MarkScale / 512.0
        $graphics.ScaleTransform([single] $scale, [single] $scale)

        $navyBrush = New-Object System.Drawing.SolidBrush($navy)
        try {
            $arcade = New-ArcadePath
            try { $graphics.FillPath($navyBrush, $arcade) } finally { $arcade.Dispose() }
        }
        finally {
            $navyBrush.Dispose()
        }

        # The load-bearing centre pier.
        $brassBrush = New-Object System.Drawing.SolidBrush($brass)
        try {
            $graphics.FillRectangle($brassBrush, 224, 118, 64, 276)
        }
        finally {
            $brassBrush.Dispose()
        }

        if ($null -ne $clipPath) {
            $graphics.ResetClip()
            $clipPath.Dispose()
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

Write-Output "Generated $($appIconTargets.Count + 5) PNG assets and the Windows ICO from the Tenant Portal arcade mark."
