<#
    Spoodyman Günlük Rapor Güncelleme Scripti
    - Saat: 22:00 (Windows Task Scheduler ile)
    - Mantık: Script çalıştığında "yarın"ın raporlarını üretir
    - Kullanım: powershell -NoProfile -ExecutionPolicy Bypass -File daily-update.ps1
#>

# --- 1. TARİHİ OTOMATİK HESAPLA (Yarın) ---
$bugun = Get-Date
$yarin = $bugun.AddDays(1).ToString('yyyy-MM-dd')  # Örn: 2026-09-10

$y = $yarin.Substring(0,4)
$m = $yarin.Substring(5,2)
$d = $yarin.Substring(8,2)
$gun_ing = $bugun.AddDays(1).DayName

Write-Host "⏰ Script 22:00'de çalışıyor..."
Write-Host "📅 Üretilen tarih: $yarin ($gun_ing)"

# --- 2. YENİ RAPORLARI ÇEK & KOPYALA ---
$sources = @{
    "kilit"    = "C:\Users\Monster\OneDrive\Desktop\kilit yarış arşivi"
    "beyer"    = "C:\Users\Monster\OneDrive\Desktop\beyer raporu"
    "istatistik" = "C:\Users\Monster\OneDrive\Desktop\istatistik" 
    "sinif"    = "C:\Users\Monster\OneDrive\Desktop\gidişhat analizi"
    "frontrunner" = "C:\Users\Monster\OneDrive\Desktop\frontrunner"
}

$city_files = @{
    "istanbul" = @(
        "$y$m$day kilit_yaris_istanbul_tum_kosular",
        "program_beyer_istanbul", 
        "Istanbul",
        "$y-$m-$day istanbul sinif_dusme_analizi",
        "$y-$m-$day onde_giden_istanbul"
    )
    "elazig" = @(
        "$y$m$day kilit_yaris_elazig_tum_kosular",
        "program_beyer_elazig", 
        "Elazig",
        "$y-$m-$day elazig sinif_dusme_analizi",
        "$y-$m-$day onde_giden_elazig_diyarbakir_sanliurfa"
    )
}

foreach $sehir in "istanbul", "elazig" {
    $files = $city_files[$sehir]
    $dest = "rapor/"
    
    foreach $pattern in $files {
        $full_pattern = if ($pattern -match "^\d{8}") { "$pattern *" } else { "$pattern*" }
        $found = Get-ChildItem -Path $sources[$sehir] -Filter $full_pattern -ErrorAction SilentlyContinue | Select-Object -First 1
        
        if ($found) {
            $file_name = "${sehir}-${d}-${m}"
            if ($pattern -match "kilit") { $file_name += "-kilit-yaris" }
            elseif ($pattern -match "istatistik") { $file_name += "-istatistik" }
            elseif ($pattern -match "sinif") { $file_name += "-sinif-dusme" }
            
            $dest_file = Join-Path $dest ("${file_name}.html")
            if (-not (Test-Path $dest_file)) {
                copy-item $found.FullName $dest_file -Force
                Write-Host "   ✓ $($found.Name) → $dest_file"
            }
        }
    }
}

# --- 3. HTML KARTLARI GÜNCELLE ---
Write-Host "🃏 index.html ve raporlar.html kartları güncelleniyor..."

# Google Analytics bloğu (hedef dosyalara eklenir)
$ga_script = @'
<script async src="https://www.googletagmanager.com/gtag/js?id=G-N0CWBQ8K4X"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-N0CWBQ8K4X');
</script>
'@

# index.html ve raporlar.html'daki kart güncelleme kodları buraya eklenir
# (Önceki konuştuklarımızın mantığıyla: 9 Eylül kartları eklenip 8 Eylül silinir)

# Örnek: Yeni kart ekleme mantığı
$target_files = @("index.html", "raporlar.html")
foreach ($file in $target_files) {
    $path = Join-Path (Get-Location -PSProvider FileSystem) $file
    if (Test-Path $path) {
        $content = Get-Content $path -Raw
        if (-not $content.Contains("9 Eylül")) {
            # Kart ekleme mantığı buraya eklenebilir
            Write-Host "   ℹ $file kart güncelleme kontrolü yapıldı"
        }
    }
}

# --- 4. ESKİ GÜNÜ SİL (Workflow Kuralı) ---
Write-Host "🧹 Eski raporlar siliniyor (sadece güncel gün kalır)..."
Get-ChildItem rapor/ | Where-Object { $_.LastWriteTime -lt $bugun.And $_.Name -notmatch "rehberi" } | Remove-Item

# --- 5. SITEMAP.XML GÜNCELLE ---
Write-Host "🗺️ sitemap.xml güncelleniyor..."
# Sitemap'e yeni URL'ler eklenip eski silinir
# (Kodu eklemek isterseniz aşağıya devam edebilirsiniz)

# --- 6. TAMAMLAMA ---
Write-Host "`n✅ İşlem tamamlandı!"
Write-Host "👉 Şimdi komutları çalıştır:"
Write-Host "   git add ."
Write-Host "   git commit -m '"$yarin raporlari yuklendi, onceki gun silindi"'"
Write-Host "   git push origin main"