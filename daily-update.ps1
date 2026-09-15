<#
    Spoodyman Günlük Rapor Güncelleme Scripti
    - Saat: 22:00 (Windows Task Scheduler ile)
    - Mantık: Script çalıştığında "yarın"ın tarihini hesaplar, asıl yükleme
      işini scripts\site-yukle-22-30.ps1'e devreder (kopyalama + gtag +
      Beyer temizliği + kartlar + sitemap + eski gün temizliği +
      değerlendirme + commit mesajı).
    - Kullanım: powershell -NoProfile -ExecutionPolicy Bypass -File daily-update.ps1 [-Tarih dd/MM/yyyy] [-WhatIf]
#>
param(
    [string]$Tarih = "",
    [switch]$WhatIf,
    [string[]]$SkipTur = @()
)

$ErrorActionPreference = 'Stop'
$RepoRoot = $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($Tarih)) {
    $yarin = (Get-Date).AddDays(1)
    $Tarih = $yarin.ToString('dd/MM/yyyy', [System.Globalization.CultureInfo]::InvariantCulture)
}

Write-Output "22:00 tetiklendi, hedef tarih: $Tarih"

$yukle = Join-Path $RepoRoot 'scripts\site-yukle-22-30.ps1'
$splat = @{ Tarih = $Tarih }
if ($WhatIf) { $splat['WhatIf'] = $true }
if ($SkipTur.Count -gt 0) { $splat['SkipTur'] = $SkipTur }
& $yukle @splat
exit $LASTEXITCODE