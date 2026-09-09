param(
    [string]$Tarih = "",
    [switch]$WhatIf
)

# 22:30 site yukleme otomasyonu:
# - Masaustundeki kaynak klasorlerden hedef gunun raporlarini bulur
# - rapor/ klasorune kopyalar (gtag + Beyer temizligi uygular)
# - raporlar.html ve index.html kartlarini + sitemap.xml'i gunceller
# - Onceki gunun rapor dosya/kart/URL'lerini siler
# Kullanim: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\site-yukle-22-30.ps1 [-Tarih 10/09/2026] [-WhatIf]

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path $PSScriptRoot -Parent
$RaporDir = Join-Path $RepoRoot 'rapor'
$NoBom = New-Object Text.UTF8Encoding($false)

$SrcKilit  = 'C:\Users\Monster\OneDrive\Desktop\kilit yarış arşivi'
$SrcBeyer  = 'C:\Users\Monster\OneDrive\Desktop\beyer raporu'
$SrcIstat  = 'C:\Users\Monster\OneDrive\Desktop\istatistik'
$SrcSinif  = 'C:\Users\Monster\OneDrive\Desktop\gidişhat analizi'
$SrcTempo  = 'C:\Users\Monster\OneDrive\Desktop\frontrunner'
$SrcDeger  = 'C:\Users\Monster\OneDrive\Desktop\günlük sonuç değerlendirme raporu'

$AyDosya = @{ '01'='ocak'; '02'='subat'; '03'='mart'; '04'='nisan'; '05'='mayis'; '06'='haziran';
              '07'='temmuz'; '08'='agustos'; '09'='eylul'; '10'='ekim'; '11'='kasim'; '12'='aralik' }
$AyAd = @{ '01'='Ocak'; '02'='Şubat'; '03'='Mart'; '04'='Nisan'; '05'='Mayıs'; '06'='Haziran';
           '07'='Temmuz'; '08'='Ağustos'; '09'='Eylül'; '10'='Ekim'; '11'='Kasım'; '12'='Aralık' }
$AyTers = @{ 'ocak'='01'; 'subat'='02'; 'mart'='03'; 'nisan'='04'; 'mayis'='05'; 'haziran'='06';
             'temmuz'='07'; 'agustos'='08'; 'eylul'='09'; 'ekim'='10'; 'kasim'='11'; 'aralik'='12' }
$SehirAd = @{ 'istanbul'='İstanbul'; 'elazig'='Elazığ'; 'ankara'='Ankara'; 'kocaeli'='Kocaeli';
              'izmir'='İzmir'; 'bursa'='Bursa'; 'adana'='Adana'; 'diyarbakir'='Diyarbakır'; 'sanliurfa'='Şanlıurfa' }

$Gtag = @'
<script async src="https://www.googletagmanager.com/gtag/js?id=G-N0CWBQ8K4X"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-N0CWBQ8K4X');
</script>
'@

function ToAsciiLower([string]$s) {
    $s = $s.ToLowerInvariant()
    $s = $s.Replace('İ','i').Replace('ı','i').Replace('ş','s').Replace('ğ','g').Replace('ü','u').Replace('ö','o').Replace('ç','c')
    return $s
}

function SehirGoster([string]$sehir) {
    if ($SehirAd.ContainsKey($sehir)) { return $SehirAd[$sehir] }
    return $sehir.Substring(0,1).ToUpper() + $sehir.Substring(1)
}

function YazDosya([string]$yol, [string]$icerik) {
    if ($WhatIf) { Write-Output "[WhatIf] yazilacak: $yol"; return }
    [System.IO.File]::WriteAllText($yol, $icerik, $NoBom)
}

function OkuDosya([string]$yol) {
    return [System.IO.File]::ReadAllText($yol)
}

# ---------- 1. Hedef tarihi belirle ----------
$HedefIso = ''
$sehirler = New-Object System.Collections.Generic.HashSet[string]
if ($Tarih -ne '') {
    $d = [datetime]::ParseExact($Tarih, 'dd/MM/yyyy', $null)
    $HedefIso = $d.ToString('yyyy-MM-dd')
}
if ($HedefIso -eq '') {
    $tarihler = New-Object System.Collections.Generic.List[string]
    if (Test-Path $SrcBeyer) {
        foreach ($f in Get-ChildItem $SrcBeyer -Filter '*.html') {
            $m = [regex]::Match($f.Name, '^program_beyer_(.+)_(\d{8})(_normal)?\.html$')
            if ($m.Success) { $tarihler.Add($m.Groups[2].Value); $sehirler.Add($m.Groups[1].Value.ToLower()) | Out-Null }
        }
    }
    if (Test-Path $SrcKilit) {
        foreach ($f in Get-ChildItem $SrcKilit -Filter '*.html') {
            $m = [regex]::Match($f.Name, '_(\d{8})\.html$')
            if ($m.Success) { $tarihler.Add($m.Groups[1].Value) }
        }
    }
    foreach ($dir in @($SrcSinif, $SrcTempo)) {
        if (Test-Path $dir) {
            foreach ($f in Get-ChildItem $dir -Filter '*.html') {
                $m = [regex]::Match($f.Name, '^(\d{4}-\d{2}-\d{2})_')
                if ($m.Success) { $tarihler.Add($m.Groups[1].Value.Replace('-','')) }
            }
        }
    }
    if ($tarihler.Count -eq 0) { Write-Output 'HATA: kaynak klasorlerde tarihli rapor bulunamadi.'; exit 1 }
    $enYeni = ($tarihler | Sort-Object -Descending | Select-Object -First 1)
    $HedefIso = $enYeni.Substring(0,4) + '-' + $enYeni.Substring(4,2) + '-' + $enYeni.Substring(6,2)
}
$Hedef = [datetime]::ParseExact($HedefIso, 'yyyy-MM-dd', $null)
$gun = $Hedef.Day.ToString()
$ayNo = $Hedef.ToString('MM')
$hedefAy = $AyDosya[$ayNo]
$TarihEtiket = "$gun $($AyAd[$ayNo]) $($Hedef.Year)"
$ddMMyyyy = $Hedef.ToString('dd/MM/yyyy')
$basic = $Hedef.ToString('yyyyMMdd')
Write-Output "Hedef tarih: $ddMMyyyy"

# Sehirleri dosya adlarindan topla (kilit + beyer)
foreach ($dir in @($SrcKilit, $SrcBeyer)) {
    if (!(Test-Path $dir)) { continue }
    foreach ($f in Get-ChildItem $dir -Filter '*.html') {
        $m = [regex]::Match($f.Name, '^(?:kilit_yaris|program_beyer)_(.+?)(?:_tum_kosular)?_\d{8}(_normal)?\.html$')
        if ($m.Success) { $sehirler.Add($m.Groups[1].Value.ToLower()) | Out-Null }
    }
}
if ($sehirler.Count -eq 0) { Write-Output 'HATA: kaynaklardan sehir tespit edilemedi.'; exit 1 }

# ---------- 2. Sehir siralamasi (ilk yaris saati) ----------
$sira = New-Object System.Collections.Generic.List[string]
try {
    $cikti = & (Join-Path $PSScriptRoot 'tjk-ilk-yaris-saati.ps1') -Tarih $ddMMyyyy 2>&1 | Out-String
    foreach ($satir in $cikti -split "`r?`n") {
        $m = [regex]::Match($satir.Trim(), '^(.+?)\s+-> ilk yaris (\d{2}:\d{2})$')
        if ($m.Success) {
            $ad = ToAsciiLower ($m.Groups[1].Value.Trim())
            foreach ($s in @($sehirler)) {
                if ((ToAsciiLower $s) -eq $ad -and -not $sira.Contains($s)) { $sira.Add($s) }
            }
        }
    }
    if ($sira.Count -eq 0) { throw 'parse edilemedi' }
    Write-Output "Siralama (TJK ilk yaris): $($sira -join ', ')"
} catch {
    Write-Output "UYARI: ilk yaris saati alinamadi ($($_.Exception.Message)) - mevcut site sirasi kullaniliyor."
    $sira = New-Object System.Collections.Generic.List[string]
    $mevcut = OkuDosya (Join-Path $RepoRoot 'raporlar.html')
    foreach ($m in [regex]::Matches($mevcut, 'href="rapor/([a-z]+)-\d{1,2}-(?:ocak|subat|mart|nisan|mayis|haziran|temmuz|agustos|eylul|ekim|kasim|aralik)(?:-[a-z-]+)?\.html"')) {
        $s = $m.Groups[1].Value
        if ($sehirler.Contains($s) -and -not $sira.Contains($s)) { $sira.Add($s) }
    }
    foreach ($s in ($sehirler | Sort-Object)) { if (-not $sira.Contains($s)) { $sira.Add($s) } }
}
foreach ($s in ($sehirler | Sort-Object)) { if (-not $sira.Contains($s)) { $sira.Add($s) } }

# ---------- 3. Rapor dosyalari ----------
function KopyalaRapor([string]$kaynak, [string]$hedefAd, [switch]$BeyerTemizle) {
    $hedef = Join-Path $RaporDir $hedefAd
    $t = OkuDosya $kaynak
    if ($t -notmatch 'googletagmanager') {
        $t = $t -replace '</head>', ($Gtag + '</head>')
    }
    if ($BeyerTemizle) {
        $parcalar = [regex]::Split($t, '(?s)(<div class="mesafe-fark-note">.*?</div>)')
        for ($i = 0; $i -lt $parcalar.Count; $i++) {
            if ($parcalar[$i] -notmatch '^<div class="mesafe-fark-note">') {
                $parcalar[$i] = $parcalar[$i] -replace 'Beyer\s+(\d+)', '$1'
                $parcalar[$i] = $parcalar[$i] -replace ' Beyer ', ' '
            }
        }
        $t = $parcalar -join ''
    }
    YazDosya $hedef $t
    return $hedef
}

$yeniDosyalar = New-Object System.Collections.Generic.List[string]
$kartVerisi = @()
foreach ($sehir in $sira) {
    $g = SehirGoster $sehir
    $taban = "$sehir-$gun-$hedefAy"
    $bulundu = @{}

    $beyer = Get-ChildItem $SrcBeyer -Filter "program_beyer_${sehir}_${basic}_normal.html" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $beyer) { $beyer = Get-ChildItem $SrcBeyer -Filter "program_beyer_${sehir}_${basic}.html" -ErrorAction SilentlyContinue | Select-Object -First 1 }
    $kilit = Get-ChildItem $SrcKilit -Filter "kilit_yaris_${sehir}_tum_kosular_${basic}.html" -ErrorAction SilentlyContinue | Select-Object -First 1
    $istat = Get-ChildItem $SrcIstat -Filter '*.html' -ErrorAction SilentlyContinue | Where-Object { (ToAsciiLower ([System.IO.Path]::GetFileNameWithoutExtension($_.Name))) -eq (ToAsciiLower $sehir) } | Select-Object -First 1
    $sinif = Get-ChildItem $SrcSinif -Filter "${HedefIso}_${sehir}_sinif_dusme_analizi.html" -ErrorAction SilentlyContinue | Select-Object -First 1
    $tempo = Get-ChildItem $SrcTempo -Filter '*.html' -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "^${HedefIso}_onde_giden_.*" -and $_.Name -match ("_" + [regex]::Escape($sehir) + "(_|\.)") } | Select-Object -First 1

    if ($beyer) {
        $t = OkuDosya $beyer.FullName
        $kosu = ([regex]::Matches($t, '<section')).Count
        KopyalaRapor $beyer.FullName "$taban.html" -BeyerTemizle | Out-Null
        $yeniDosyalar.Add("$taban.html") | Out-Null
        $bulundu['beyer'] = $kosu
        Write-Output "OK beyer: $($beyer.Name) -> $taban.html ($kosu kosu)"
    } else { Write-Output "UYARI: $g icin beyer kaynagi yok." }
    if ($kilit) {
        KopyalaRapor $kilit.FullName "$taban-kilit-yaris.html" | Out-Null
        $yeniDosyalar.Add("$taban-kilit-yaris.html") | Out-Null
        $bulundu['kilit'] = $true
        Write-Output "OK kilit: $($kilit.Name) -> $taban-kilit-yaris.html"
    } else { Write-Output "UYARI: $g icin kilit kaynagi yok." }
    if ($tempo) {
        KopyalaRapor $tempo.FullName "$taban-tempo.html" | Out-Null
        $yeniDosyalar.Add("$taban-tempo.html") | Out-Null
        $bulundu['tempo'] = $true
        Write-Output "OK tempo: $($tempo.Name) -> $taban-tempo.html"
    } else { Write-Output "UYARI: $g icin tempo kaynagi yok." }
    if ($istat) {
        KopyalaRapor $istat.FullName "$taban-istatistik.html" | Out-Null
        $yeniDosyalar.Add("$taban-istatistik.html") | Out-Null
        $bulundu['istat'] = $true
        Write-Output "OK istatistik: $($istat.Name) -> $taban-istatistik.html"
    } else { Write-Output "UYARI: $g icin istatistik kaynagi yok." }
    if ($sinif) {
        $t = OkuDosya $sinif.FullName
        $kosuS = ([regex]::Matches($t, '<section')).Count
        KopyalaRapor $sinif.FullName "$taban-sinif-dusme.html" | Out-Null
        $yeniDosyalar.Add("$taban-sinif-dusme.html") | Out-Null
        $bulundu['sinif'] = $kosuS
        Write-Output "OK sinif: $($sinif.Name) -> $taban-sinif-dusme.html ($kosuS kosu)"
    } else { Write-Output "UYARI: $g icin sinif-dusme kaynagi yok." }
    $kartVerisi += [pscustomobject]@{ Sehir = $sehir; Goster = $g; Taban = $taban; Rapor = $bulundu }
}

# ---------- 4. Degerlendirme (onceki gun) ----------
$Onceki = $Hedef.AddDays(-1)
$oncekiIso = $Onceki.ToString('yyyy-MM-dd')
$oncekiGun = $Onceki.Day.ToString()
$oncekiAyDosya = $AyDosya[$Onceki.ToString('MM')]
$OncekiEtiket = "$oncekiGun $($AyAd[$Onceki.ToString('MM')]) $($Onceki.Year)"
$degerKart = @()
if (Test-Path $SrcDeger) {
    foreach ($f in Get-ChildItem $SrcDeger -Filter "${oncekiIso}_*_evaluation.html") {
        $m = [regex]::Match($f.Name, "^${oncekiIso}_(.+)_evaluation\.html$")
        if (-not $m.Success) { continue }
        $dsehir = ToAsciiLower $m.Groups[1].Value
        if ($dsehir -eq 'general' -or $dsehir -like '*ayni_yuzey*') { continue }
        $g = SehirGoster $dsehir
        $hedefAd = "$dsehir-$oncekiGun-$oncekiAyDosya-degerlendirme.html"
        $t = OkuDosya $f.FullName
        $satir = ([regex]::Matches($t, '<tr><td>')).Count
        if ($t -notmatch 'googletagmanager') { $t = $t -replace '</head>', ($Gtag + '</head>') }
        YazDosya (Join-Path $RaporDir $hedefAd) $t
        $yeniDosyalar.Add($hedefAd) | Out-Null
        $degerKart += [pscustomobject]@{ Sehir = $dsehir; Goster = $g; Dosya = $hedefAd; Kosu = $satir }
        Write-Output "OK degerlendirme: $($f.Name) -> $hedefAd ($satir kosu)"
    }
}
if ($degerKart.Count -eq 0) { Write-Output "UYARI: $oncekiIso icin degerlendirme dosyasi yok - kart uretilmedi." }

# ---------- 5. Eski gun dosyalari ----------
# Ayni-yuzey degerlendirmeleri siteye yuklenmez; eski kalintilar temizlenir.
foreach ($f in Get-ChildItem $RaporDir -Filter '*ayni_yuzey*') {
    Write-Output "SIL (ayni-yuzey): rapor/$($f.Name)"
    if (-not $WhatIf) { Remove-Item $f.FullName -Force }
}
$ayDesen = $AyTers.Keys -join '|'
$silinenTarihler = New-Object System.Collections.Generic.HashSet[string]
foreach ($f in Get-ChildItem $RaporDir -Filter '*.html') {
    $m = [regex]::Match($f.Name, "^([a-z]+)-(\d{1,2})-($ayDesen)(-[a-z-]+)?\.html$")
    if (-not $m.Success) { continue }
    if ($m.Groups[2].Value -eq $gun -and $m.Groups[3].Value -eq $hedefAy) { continue }
    if ($m.Groups[2].Value -eq $oncekiGun -and $m.Groups[3].Value -eq $oncekiAyDosya -and $m.Groups[4].Value -eq '-degerlendirme') { continue }
    $silinenTarihler.Add("$($m.Groups[2].Value).$($AyTers[$m.Groups[3].Value]).$($Hedef.Year)") | Out-Null
    Write-Output "SIL: rapor/$($f.Name)"
    if (-not $WhatIf) { Remove-Item $f.FullName -Force }
}

# ---------- 6. Kartlar ----------
function KartBlok([string]$tag, [string]$tarihEtiket, [string]$href, [string]$baslik, [string]$desc) {
    return @"
<article class="card">
  <div class="meta">
    <span class="tag">$tag</span>
    <span>$tarihEtiket</span>
  </div>
  <h3><a href="$href">$baslik</a></h3>
  <p class="desc">$desc</p>
</article>
"@
}

$yeniKartlar = New-Object System.Collections.Generic.List[string]
foreach ($d in $degerKart) {
    $yeniKartlar.Add((KartBlok 'Önceki Günün Değerlendirmesi' $OncekiEtiket "rapor/$($d.Dosya)" "$($d.Goster) $OncekiEtiket Sonuç Değerlendirmesi" "$($d.Goster) $($d.Kosu) koşu için hız figürü metriklerinin sonuç doğruluk analizi (Erken/Kapanış/Son 3 Ort./Son Hız).")) | Out-Null
}
foreach ($k in $kartVerisi) {
    $r = $k.Rapor
    if ($r.ContainsKey('beyer')) {
        $yeniKartlar.Add((KartBlok 'Hız Figürleri' $TarihEtiket "rapor/$($k.Taban).html" "$($k.Goster) $TarihEtiket Hız Figürü Raporu" "$($k.Goster) $($r['beyer']) koşu için erken/kapanış hızı, son 3 ortalaması ve form analizi.")) | Out-Null
    }
    if ($r.ContainsKey('kilit')) {
        $yeniKartlar.Add((KartBlok 'Kilit Yarış Analizi' $TarihEtiket "rapor/$($k.Taban)-kilit-yaris.html" "$($k.Goster) $TarihEtiket Kilit Yarış Analizi" 'Sıcak form ve referans grup karşılaştırmalarıyle kilit yarış tespitleri.')) | Out-Null
    }
    if ($r.ContainsKey('tempo')) {
        $yeniKartlar.Add((KartBlok 'Tempo Analizi' $TarihEtiket "rapor/$($k.Taban)-tempo.html" "$($k.Goster) $TarihEtiket Tempo Analizi" "Önde giden figürleri, erken hız top-3'ü ve frontrunner güven seviyeleri.")) | Out-Null
    }
    if ($r.ContainsKey('istat')) {
        $yeniKartlar.Add((KartBlok 'İstatistik ve Galoplar' $TarihEtiket "rapor/$($k.Taban)-istatistik.html" "$($k.Goster) $TarihEtiket İstatistik ve Galoplar" 'Pist eğilimi, dikkat çekici galoplar, J/A kombo ve ara veren at istatistikleri.')) | Out-Null
    }
    if ($r.ContainsKey('sinif')) {
        $yeniKartlar.Add((KartBlok 'Sınıf Düşme/Yükselme Analizi' $TarihEtiket "rapor/$($k.Taban)-sinif-dusme.html" "$($k.Goster) $TarihEtiket Sınıf Düşme/Yükselme Analizi" "$($k.Goster) $($r['sinif']) koşu için sınıf düşen, yükselen ve nötr atların 1.lik ikramiyesi karşılaştırması.")) | Out-Null
    }
}

$tarihliHref = 'href="rapor/[a-z_]+-\d{1,2}-(?:' + ($AyTers.Keys -join '|') + ')(?:-[a-z-]+)?\.html"'
foreach ($sayfa in @((Join-Path $RepoRoot 'raporlar.html'), (Join-Path $RepoRoot 'index.html'))) {
    $html = OkuDosya $sayfa
    $bloklar = [regex]::Matches($html, '(?s)<article class="card">.*?</article>')
    foreach ($b in $bloklar) {
        if ($b.Value -match $tarihliHref) { $html = $html.Replace($b.Value, '') }
    }
    $ekle = ($yeniKartlar -join "`r`n") + "`r`n"
    $html = [regex]::Replace($html, '(?m)^([ \t]*)<div class="cards-grid">\s*\r?\n', "`$0" + $ekle, 1)
    YazDosya $sayfa $html
    Write-Output "OK kartlar: $([System.IO.Path]::GetFileName($sayfa)) ($($yeniKartlar.Count) kart eklendi)"
}

# ---------- 7. Sitemap ----------
$sitemapYol = Join-Path $RepoRoot 'sitemap.xml'
$sm = OkuDosya $sitemapYol
$tabanUrl = 'https://feriduntoprakk10-design.github.io/spoodymann'
$m0 = [regex]::Match($sm, '(https://[^<"]+/spoodymann)/rapor/')
if ($m0.Success) { $tabanUrl = $m0.Groups[1].Value }
$sm = [regex]::Replace($sm, '(?s)<url>\s*<loc>[^<]*?/rapor/[a-z_]+-\d{1,2}-(?:' + ($AyTers.Keys -join '|') + ')(?:-[a-z-]+)?\.html</loc>\s*</url>\s*', '')
$yeniUrl = New-Object System.Collections.Generic.List[string]
foreach ($d in $yeniDosyalar) {
    $yeniUrl.Add("<url>`r`n    <loc>$tabanUrl/rapor/$d</loc>`r`n  </url>") | Out-Null
}
$sm = $sm -replace '</urlset>', (($yeniUrl -join "`r`n") + "`r`n</urlset>")
YazDosya $sitemapYol $sm
Write-Output "OK sitemap: $($yeniUrl.Count) URL eklendi"

# ---------- 8. Ozet ----------
Write-Output '---'
Write-Output "Eklenen dosya: $($yeniDosyalar.Count), eklenen kart: $($yeniKartlar.Count)"
$eski = ($silinenTarihler -join ', ')
if ($eski -eq '') { $eski = 'yok' }
Write-Output "Silinen eski raporlar: $eski"
$commitGun = $Hedef.ToString('dd.MM.yyyy')
if ($silinenTarihler.Count -gt 0) {
    Write-Output "Onerilen commit mesaji: $commitGun raporlari eklendi, $eski raporlari silindi"
} else {
    Write-Output "Onerilen commit mesaji: $commitGun raporlari eklendi"
}
