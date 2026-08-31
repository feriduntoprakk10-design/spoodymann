param(
    [string]$Tarih = (Get-Date -Format 'dd/MM/yyyy')
)

# TJK gunluk yaris programindan, o gun yaris kosan sehirlerin ilk kusu baslangic saatlerini ceker
# ve en erken ilk yaristan baslayacak sekilde sirali liste verir.
# Kullanim:  powershell -ExecutionPolicy Bypass -File .\scripts\tjk-ilk-yaris-saati.ps1 -Tarih 01/09/2026

$ErrorActionPreference = 'Stop'

$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36'
$headers = @{ 'User-Agent' = $ua; 'Accept-Language' = 'tr-TR,tr;q=0.9' }

function Get-DailyPage($tarih) {
    $enc = [uri]::EscapeDataString($tarih)
    $url = "https://www.tjk.org/TR/YarisSever/Info/Page/GunlukYarisProgrami?QueryParameter_Tarih=$enc"
    $r = Invoke-WebRequest -Uri $url -UseBasicParsing -Headers $headers -TimeoutSec 40
    return $r.Content
}

function Get-CityFirstRace($sehirId, $sehirAdi, $tarih) {
    $enc = [uri]::EscapeDataString($tarih)
    $url = "https://www.tjk.org/TR/YarisSever/Info/Sehir/GunlukYarisProgrami?SehirId=$sehirId&QueryParameter_Tarih=$enc&SehirAdi=$([uri]::EscapeDataString($sehirAdi))&Era=tomorrow"
    $r = Invoke-WebRequest -Uri $url -UseBasicParsing -Headers $headers -TimeoutSec 40
    $m = [regex]::Match($r.Content, '1\.\s*Ko\u015fu\s*([0-9]{2}\.[0-9]{2})')
    if ($m.Success) {
        return [datetime]::ParseExact($m.Groups[1].Value, 'HH.mm', $null)
    }
    return $null
}

$page = Get-DailyPage $Tarih

$cities = New-Object System.Collections.Generic.List[object]
$tabRegex = [regex]::Matches($page, '<a[^>]*id="([^"]+)"[^>]*data-sehir-id="([0-9]+)"[^>]*SehirAdi=([^&"]+)[^>]*>')
foreach ($t in $tabRegex) {
    $ad = [uri]::UnescapeDataString($t.Groups[3].Value)
    if ($ad -eq 'Karma') { continue }
    if ($ad -match 'Fransa|\u0130rlanda|Krall\u0131k|ABD|\u015eili') { continue }
    $cities.Add([pscustomobject]@{ Id = $t.Groups[2].Value; Ad = $ad })
}

if ($cities.Count -eq 0) {
    Write-Output "Sehir listesi bulunamadi (tarih icin program yok olabilir veya TJK engelledi)."
    exit 1
}

$rows = New-Object System.Collections.Generic.List[object]
foreach ($c in $cities) {
    try {
        $saat = Get-CityFirstRace $c.Id $c.Ad $Tarih
        if ($null -ne $saat) {
            $rows.Add([pscustomobject]@{ Sehir = $c.Ad; IlkYaris = $saat })
        }
    } catch {
        Write-Output "Hata ($($c.Ad)): $($_.Exception.Message)"
    }
}

Write-Output "Tarih: $Tarih"
Write-Output "Sehirler (ilk yarisa gore sirali):"
$rows | Sort-Object IlkYaris | ForEach-Object {
    Write-Output ("  {0,-12} -> ilk yaris {1}" -f $_.Sehir, $_.IlkYaris.ToString('HH:mm'))
}