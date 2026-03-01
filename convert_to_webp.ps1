# ============================================================
# SCI-Bot PNG -> WebP Batch Converter
# Converts all PNG assets and updates all references
# ============================================================

$cwebpPath  = "D:\Downloads\libwebp-1.6.0-windows-x64\libwebp-1.6.0-windows-x64\bin\cwebp.exe"
$assetsPath = "d:\Program Projects\Flutter\SciBot\sci_bot\assets"
$projectPath= "d:\Program Projects\Flutter\SciBot\sci_bot"
$quality    = 80

# Verify cwebp exists
if (-not (Test-Path $cwebpPath)) {
    Write-Host "[ERROR] cwebp.exe not found at: $cwebpPath" -ForegroundColor Red
    Write-Host "Check the path and try again." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  SCI-Bot PNG -> WebP Converter (q=$quality%)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ── Step 1: Convert all PNGs ─────────────────────────────────
Write-Host "STEP 1: Converting PNG files..." -ForegroundColor Yellow
Write-Host ""

$pngs      = Get-ChildItem -Path $assetsPath -Filter "*.png" -Recurse
$total     = $pngs.Count
$converted = 0
$failed    = 0
$savedKB   = 0

Write-Host "Found $total PNG files." -ForegroundColor White
Write-Host ""

foreach ($png in $pngs) {
    $webpPath = [System.IO.Path]::ChangeExtension($png.FullName, ".webp")
    $origSize = $png.Length

    & "$cwebpPath" -q $quality "$($png.FullName)" -o "$webpPath" 2>&1 | Out-Null

    if ($LASTEXITCODE -eq 0 -and (Test-Path $webpPath)) {
        $newSize  = (Get-Item $webpPath).Length
        $saved    = [math]::Round(($origSize - $newSize) / 1KB, 0)
        $origKB   = [math]::Round($origSize / 1KB, 0)
        $newKB    = [math]::Round($newSize  / 1KB, 0)
        $savedKB += $saved

        Write-Host "  [OK] $($png.Name)" -ForegroundColor Green -NoNewline
        Write-Host "   ${origKB}KB -> ${newKB}KB  (saved ${saved}KB)" -ForegroundColor DarkGray

        Remove-Item $png.FullName -Force
        $converted++
    } else {
        Write-Host "  [FAIL] $($png.Name)" -ForegroundColor Red
        $failed++
    }
}

$savedMB = [math]::Round($savedKB / 1024, 1)
Write-Host ""
Write-Host "Converted : $converted / $total" -ForegroundColor Cyan
Write-Host "Failed    : $failed"              -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
Write-Host "Saved     : ~${savedMB} MB"       -ForegroundColor Cyan

# ── Step 2: Update .png -> .webp in Dart + JSON files ────────
Write-Host ""
Write-Host "STEP 2: Updating .png references in source files..." -ForegroundColor Yellow
Write-Host ""

$sourceFiles  = @()
$sourceFiles += Get-ChildItem -Path "$projectPath\lib"          -Filter "*.dart" -Recurse
$sourceFiles += Get-ChildItem -Path "$projectPath\assets\data"  -Filter "*.json" -Recurse

$updatedCount = 0
foreach ($file in $sourceFiles) {
    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    if ($content.Contains('.png')) {
        $newContent = $content -replace '\.png', '.webp'
        [System.IO.File]::WriteAllText($file.FullName, $newContent, [System.Text.Encoding]::UTF8)
        Write-Host "  Updated: $($file.Name)" -ForegroundColor Green
        $updatedCount++
    }
}

Write-Host ""
Write-Host "Updated $updatedCount source files." -ForegroundColor Cyan

# ── Done ─────────────────────────────────────────────────────
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  All done!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. cd to your project folder"
Write-Host "  2. flutter pub get"
Write-Host "  3. flutter build apk --release"
Write-Host ""
