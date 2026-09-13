param(
    [string]$Tarih = (Get-Date -Format 'dd/MM/yyyy')
)

# TJK gunluk yaris programindan, o gun yaris kosan sehirlerin ilk kusu baslangic saatlerini ceker
# ve en erken ilk yaristan baslayacak sekilde sirali liste verir.
# Kullanim:  powershell -ExecutionPolicy Bypass -File .\scripts\tjk-ilk-yaris-saati.ps1 -Tarih 01/09/2026

$ErrorActionPreference = 'Stop'

$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
$headers = @{
    'User-Agent' = $ua
    'Accept' = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8'
    'Accept-Language' = 'tr-TR,tr;q=0.9,en-US;q=0.8'
    'Cache-Control' = 'max-age=0'
    'Upgrade-Insecure-Requests' = '1'
    'Sec-Ch-Ua' = '"Chromium";v="126", "Google Chrome";v="126", "Not-A.Brand";v="99"'
    'Sec-Ch-Ua-Mobile' = '?0'
    'Sec-Ch-Ua-Platform' = '"Windows"'
    'Sec-Fetch-Dest' = 'document'
    'Sec-Fetch-Mode' = 'navigate'
    'Sec-Fetch-Site' = 'none'
    'Sec-Fetch-User' = '?1'
    'Referer' = 'https://www.tjk.org/'
}

# Incapsula cookie warmup: önce ana sayfa, session korunur
$session = $null
try {
    $warm = Invoke-WebRequest -Uri 'https://www.tjk.org/' -UseBasicParsing -Headers $headers -SessionVariable session -TimeoutSec 40
} catch {
    Write-Output "Warmup uyarisi: $($_.Exception.Message) (devam ediliyor)"
    $session = $null
}
Start-Sleep -Seconds 2

function Invoke-Tjk($url, $attempts = 3) {
    $lastErr = $null
    for ($i = 1; $i -le $attempts; $i++) {
        try {
            Start-Sleep -Milliseconds (1500 + (Get-Random -Minimum 0 -Maximum 1500))
            if ($null -ne $session) {
                return Invoke-WebRequest -Uri $url -UseBasicParsing -Headers $headers -WebSession $session -TimeoutSec 40
            }
            return Invoke-WebRequest -Uri $url -UseBasicParsing -Headers $headers -TimeoutSec 40
        } catch {
            $lastErr = $_
            $msg = $_.Exception.Message
            if ($msg -match '403|Incapsula') {
                Write-Output "403/Incapsula (deneme $i/$attempts), 4 sn bekleniyor..."
                Start-Sleep -Seconds 4
                # session yenile
                try {
                    $tmp = Invoke-WebRequest -Uri 'https://www.tjk.org/' -UseBasicParsing -Headers $headers -TimeoutSec 30
                } catch {}
                continue
            }
            if ($i -lt $attempts) { Start-Sleep -Seconds (2 * $i); continue }
            throw
        }
    }
    throw $lastErr
}

function Get-DailyPage($tarih) {
    $enc = [uri]::EscapeDataString($tarih)
    $url = "https://www.tjk.org/TR/YarisSever/Info/Page/GunlukYarisProgrami?QueryParameter_Tarih=$enc"
    $r = Invoke-Tjk $url
    return $r.Content
}

function Get-CityFirstRace($sehirId, $sehirAdi, $tarih) {
    $enc = [uri]::EscapeDataString($tarih)
    $url = "https://www.tjk.org/TR/YarisSever/Info/Sehir/GunlukYarisProgrami?SehirId=$sehirId&QueryParameter_Tarih=$enc&SehirAdi=$([uri]::EscapeDataString($sehirAdi))&Era=tomorrow"
    $r = Invoke-Tjk $url
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