# Spoodyman - Proje Talimatları

Bu repo, Spoodyman at yarışı raporları sitesidir (`raporlar.html` liste sayfası, raporlar `rapor/` klasöründe).

## Günlük rapor ekleme iş akışı (HER GÜN otomatik uygula)

Yeni günün raporları geldiğinde şu sırayla yap:

1. **Günün ilk yarışını belirle (rapor sıralaması için):**
   `scripts/tjk-ilk-yaris-saati.ps1` scriptini çalıştır (parametre: `-Tarih dd/MM/yyyy`).
   Bu, TJK günlük programından her şehrin 1. koşu saatini çeker.
   Şehirler, **en erken ilk yarış saati önce olacak şekilde** `raporlar.html`'de sıralanır.
   Örn: Ankara 1. koşu 14:30, Kocaeli 1. koşu 17:45 ise önce Ankara kartları gelir.

2. **Rapor dosyalarını `rapor/` klasörüne ekle.**
   İsimlendirme: `<sehir>-<gun>-<ay>.html` (örn. `ankara-1-eylul.html`, `kocaeli-1-eylul-kilit-yaris.html`).
   Tür ekleri: `-kilit-yaris`, `-tempo`, `-istatistik`, `-sinif-dusme`.

3. **Her rapor dosyasına Google Analytics ekle** (yoksa):
   ```html
   <script async src="https://www.googletagmanager.com/gtag/js?id=G-N0CWBQ8K4X"></script>
   <script>
     window.dataLayer = window.dataLayer || [];
     function gtag(){dataLayer.push(arguments);}
     gtag('js', new Date());
     gtag('config', 'G-N0CWBQ8K4X');
   </script>
   ```
   `</head>` etiketinden hemen önce.

4. **Hız Figürü (beyer) raporlarında `Beyer` etiketi temizliği:**
   - `Beyer\s+(\d+)` → `$1`
   - ` Beyer ` → ` ` (boşluklu)
   - NOT: `mesafe-fark-note` blokları (`class="mesafe-fark-note"`) ve başlıklardaki mesafe bilgisi (örn. `ANKARA 1. Koşu 1200m - Kum`) ASLA silinmez.

5. **`raporlar.html`'e kart ekle** (her rapor için 1 kart):
   - `div.cards-grid` içine, aynı gün içinde önce en erken ilk yarışlı şehir, sonra diğerleri.
   - Kart etiketleri: `Hız Figürleri`, `Kilit Yarış Analizi`, `Tempo Analizi`, `İstatistik ve Galoplar`, `Sınıf Düşme/Yükselme Analizi`.
   - Açıklamada koşu sayısı belirtilir (örn. "Ankara 8 koşu için ...").

6. **ÖNCEKİ GÜNÜN RAPORLARINI SİL (kritik kural):**
   Yeni günün raporları eklenince bir önceki günün tüm raporları **silinir**:
   - `index.html` ve `raporlar.html`'deki eski günün kartlarını kaldır.
   - `rapor/` klasöründeki eski günün dosyalarını sil (git rm).
   Sitede yalnızca en güncel günün raporları kalır.

## Diğer kurallar
- Kullanıcıya raporları commit/push için adım adım talimat ver (GitHub Desktop: Commit to main → Push origin).
- TJK sitesi otomatik isteklerde bazen 403 verir; script browser User-Agent kullanır. 403 olursa kullanıcıdan saat bilgisini iste.