$ErrorActionPreference = 'Stop'
$mobileRoot = Split-Path -Parent $PSScriptRoot
$masterIcon = Join-Path $mobileRoot 'assets\images\app_icon.png'

Add-Type -AssemblyName System.Drawing

function Add-RoundedRectPath {
    param(
        [System.Drawing.Drawing2D.GraphicsPath]$Path,
        [System.Drawing.RectangleF]$Rect,
        [single]$Radius
    )
    $d = $Radius * 2
    $Path.AddArc($Rect.X, $Rect.Y, $d, $d, 180, 90)
    $Path.AddArc($Rect.Right - $d, $Rect.Y, $d, $d, 270, 90)
    $Path.AddArc($Rect.Right - $d, $Rect.Bottom - $d, $d, $d, 0, 90)
    $Path.AddArc($Rect.X, $Rect.Bottom - $d, $d, $d, 90, 90)
    $Path.CloseFigure()
}

function New-ScaledPoints {
    param([single[][]]$Points, [single]$Scale)
    $result = New-Object 'System.Drawing.PointF[]' $Points.Count
    for ($i = 0; $i -lt $Points.Count; $i++) {
        $result[$i] = New-Object System.Drawing.PointF(($Points[$i][0] * $Scale), ($Points[$i][1] * $Scale))
    }
    return ,$result
}

function New-MaIcon {
    param([int]$Size)

    $bitmap = New-Object System.Drawing.Bitmap($Size, $Size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

    $s = [single]$Size
    $scale = $s / 256.0

    $bgRect = New-Object System.Drawing.RectangleF(0, 0, $s, $s)
    $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $bgRect,
        [System.Drawing.Color]::FromArgb(255, 4, 91, 87),
        [System.Drawing.Color]::FromArgb(255, 10, 143, 136),
        135.0
    )
    $colorBlend = New-Object System.Drawing.Drawing2D.ColorBlend(3)
    $colorBlend.Colors = @(
        [System.Drawing.Color]::FromArgb(255, 4, 91, 87),
        [System.Drawing.Color]::FromArgb(255, 8, 122, 117),
        [System.Drawing.Color]::FromArgb(255, 10, 143, 136)
    )
    $colorBlend.Positions = @([single]0.0, [single]0.55, [single]1.0)
    $bgBrush.InterpolationColors = $colorBlend

    $bgPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    Add-RoundedRectPath -Path $bgPath -Rect $bgRect -Radius ($s * 0.22)
    $graphics.FillPath($bgBrush, $bgPath)

    $softBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(22, 255, 255, 255))
    $softPad = $s * 0.117
    $graphics.FillEllipse($softBrush, $softPad, $softPad, ($s - 2 * $softPad), ($s - 2 * $softPad))

    $ringPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(51, 255, 255, 255), [Math]::Max(1.5, $s * 0.01))
    $ringInset = $s * 0.1875
    $graphics.DrawEllipse($ringPen, $ringInset, $ringInset, ($s - 2 * $ringInset), ($s - 2 * $ringInset))

    $sheenBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.PointF(($s * 0.5), 0)),
        (New-Object System.Drawing.PointF(($s * 0.5), ($s * 0.55))),
        [System.Drawing.Color]::FromArgb(40, 255, 255, 255),
        [System.Drawing.Color]::FromArgb(0, 255, 255, 255)
    )
    $graphics.FillPath($sheenBrush, $bgPath)

    $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)

    # M: 54,172 → 146,88
    $mPts = New-ScaledPoints -Scale $scale -Points @(
        @(54, 172), @(54, 88), @(76, 88), @(100, 140), @(124, 88), @(146, 88),
        @(146, 172), @(126, 172), @(126, 122), @(108, 164), @(96, 164),
        @(78, 122), @(78, 172)
    )
    $m = New-Object System.Drawing.Drawing2D.GraphicsPath
    $m.AddPolygon($mPts)

    # A outer
    $aOuterPts = New-ScaledPoints -Scale $scale -Points @(
        @(156, 172), @(180, 88), @(204, 88), @(228, 172), @(206, 172),
        @(201.5, 156), @(174.5, 156), @(178, 172)
    )
    # Fix A bottom-left: should be 178,172 for left stem - wait path was L178 172 h-22 = 156
    # Correct outer:
    $aOuterPts = New-ScaledPoints -Scale $scale -Points @(
        @(156, 172), @(180, 88), @(204, 88), @(228, 172), @(206, 172),
        @(201.5, 156), @(174.5, 156), @(170, 172)
    )
    $aOuter = New-Object System.Drawing.Drawing2D.GraphicsPath
    $aOuter.AddPolygon($aOuterPts)

    $aHolePts = New-ScaledPoints -Scale $scale -Points @(
        @(183, 138), @(201, 138), @(192, 106)
    )
    $aHole = New-Object System.Drawing.Drawing2D.GraphicsPath
    $aHole.AddPolygon($aHolePts)

    $graphics.FillPath($white, $m)
    $aRegion = New-Object System.Drawing.Region($aOuter)
    $aRegion.Exclude($aHole)
    $graphics.FillRegion($white, $aRegion)

    $gold = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 185, 135, 22))
    $accentW = $s * (60.0 / 256.0)
    $accentH = [Math]::Max(2.0, $s * (5.0 / 256.0))
    $accentX = ($s - $accentW) / 2
    $accentY = $s * (190.0 / 256.0)
    $accentPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    Add-RoundedRectPath -Path $accentPath -Rect ([System.Drawing.RectangleF]::new($accentX, $accentY, $accentW, $accentH)) -Radius ($accentH / 2)
    $graphics.FillPath($gold, $accentPath)

    foreach ($obj in @($bgBrush, $softBrush, $ringPen, $sheenBrush, $white, $gold, $m, $aOuter, $aHole, $aRegion, $accentPath, $bgPath)) {
        $obj.Dispose()
    }
    $graphics.Dispose()
    return $bitmap
}

function Export-Bitmap {
    param(
        [System.Drawing.Bitmap]$Source,
        [string]$Target,
        [int]$Size
    )

    $dir = Split-Path -Parent $Target
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }

    $scaled = New-Object System.Drawing.Bitmap($Size, $Size)
    $g = [System.Drawing.Graphics]::FromImage($scaled)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::FromArgb(255, 8, 122, 117))
    $g.DrawImage($Source, 0, 0, $Size, $Size)
    $g.Dispose()

    if (Test-Path -LiteralPath $Target) {
        Remove-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue
    }
    $scaled.Save($Target, [System.Drawing.Imaging.ImageFormat]::Png)
    $scaled.Dispose()
}

$master = New-MaIcon -Size 1024
try {
    if (Test-Path -LiteralPath $masterIcon) {
        Remove-Item -LiteralPath $masterIcon -Force -ErrorAction SilentlyContinue
    }
    $master.Save($masterIcon, [System.Drawing.Imaging.ImageFormat]::Png)

    $androidSizes = [ordered]@{
        'mipmap-mdpi\ic_launcher.png' = 48
        'mipmap-hdpi\ic_launcher.png' = 72
        'mipmap-xhdpi\ic_launcher.png' = 96
        'mipmap-xxhdpi\ic_launcher.png' = 144
        'mipmap-xxxhdpi\ic_launcher.png' = 192
    }

    foreach ($entry in $androidSizes.GetEnumerator()) {
        $target = Join-Path $mobileRoot "android\app\src\main\res\$($entry.Key)"
        Export-Bitmap -Source $master -Target $target -Size $entry.Value
    }

    $iosIconRoot = Join-Path $mobileRoot 'ios\Runner\Assets.xcassets\AppIcon.appiconset'
    $iosContents = Get-Content -LiteralPath (Join-Path $iosIconRoot 'Contents.json') -Raw | ConvertFrom-Json
    foreach ($item in $iosContents.images) {
        if (-not $item.filename) { continue }
        $points = [double]($item.size -split 'x')[0]
        $scale = [int]($item.scale.TrimEnd('x'))
        $size = [int][Math]::Round($points * $scale)
        Export-Bitmap -Source $master -Target (Join-Path $iosIconRoot $item.filename) -Size $size
    }
}
finally {
    $master.Dispose()
}

Write-Output "Đã tạo logo MA chuyên nghiệp: $masterIcon"
