# Spoodyman - Proje Talimatları

Bu repo, Spoodyman at yarışı raporları sitesidir (`raporlar.html` liste sayfası, raporlar `rapor/` klasöründe).

**ÖNEMLİ:** Çalışılacak asıl repo klasörü: `C:\Users\Monster\OneDrive\Belgeler\GitHub\spoodyman`
(Düzenlemeler buraya yapılır; kullanıcı GitHub Desktop ile commit/push eder.)

## Günlük rapor ekleme iş akışı (HER GÜN otomatik uygula)

Yeni günün raporları (kaynak dosyalar) masaüstündeki şu klasörlerde hazır gelir:
- `C:\Users\Monster\OneDrive\Desktop\kilit yarış arşivi\` → kilit yarış
- `C:\Users\Monster\OneDrive\Desktop\beyer raporu\` → hız figürü (beyer)
- `C:\Users\Monster\OneDrive\Desktop\istatistik\` → istatistik ve galop
- `C:\Users\Monster\OneDrive\Desktop\gidişhat analizi\` → **sınıf düşme/yükselme** (`*_sinif_dusme_analizi.html`)
- `C:\Users\Monster\OneDrive\Desktop\frontrunner\` → tempo analizi (`2026-09-02_onde_giden_*.html`)

Şu sırayla yap:

1. **Günün ilk yarışını belirle (rapor sıralaması için):**
   `scripts/tjk-ilk-yaris-saati.ps1` scriptini çalıştır: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tjk-ilk-yaris-saati.ps1 -Tarih dd/MM/yyyy`
   Şehirler, **en erken ilk yarış saati önce olacak şekilde** `raporlar.html` ve `index.html`'de sıralanır.

2. **Rapor dosyalarını `rapor/` klasörüne ekle.**
   İsimlendirme: `<sehir>-<gun>-<ay>.html` (örn. `istanbul-2-eylul.html`, `elazig-2-eylul-kilit-yaris.html`).
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
   - NOT: `mesafe-fark-note` blokları (`class="mesafe-fark-note"`) ve başlıklardaki mesafe bilgisi (örn. `İSTANBUL 1. Koşu 1300m - Sentetik`) ASLA silinmez.

5. **`raporlar.html` VE `index.html`'e kart ekle** (her rapor için 1 kart):
   - `div.cards-grid` içine, aynı gün içinde önce en erken ilk yarışlı şehir, sonra diğerleri.
   - Kart etiketleri: `Hız Figürleri`, `Kilit Yarış Analizi`, `Tempo Analizi`, `İstatistik ve Galoplar`, `Sınıf Düşme/Yükselme Analizi`.
   - Açıklamada koşu sayısı belirtilir (örn. "İstanbul 9 koşu için ...").

6. **`sitemap.xml` güncelle:** Eski günün rapor URL'lerini sil, yeni günün 10 rapor URL'sini ekle (rehber URL'leri sabit kalır).

7. **ÖNCEKİ GÜNÜN RAPORLARINI SİL (kritik kural):**
   Yeni günün raporları eklenince bir önceki günün tüm raporları **silinir**:
   - `index.html` ve `raporlar.html`'deki eski günün kartlarını kaldır.
   - `rapor/` klasöründeki eski günün dosyalarını sil (git rm).
   - `sitemap.xml`'deki eski gün URL'lerini kaldır.
   Sitede yalnızca en güncel günün raporları kalır.

8. **Önceki günün sonuç değerlendirmesini üret (HER GÜN):**
   Bu rapor, **bir önceki günün yarış sonuçlarına** göre hız figürü metriklerinin
   (Erken / Kapanış / Son 3 Ort. / Son Hız) doğruluk analizidir.
   Beyer projesinde çalıştır:
   ```
   python src\daily_result_evaluation.py --date <YYYY-MM-DD> --split-tracks
   ```
   (çalışma dizini: `C:\Users\Monster\Documents\Codex\2026-05-25\tjk-org-sitesinden-son-1-y\tjk_beyer_project`)
   - `--date`: **önceki günün** ISO tarihi (örn. bugün 07.09 ise `2026-09-06`).
   - Sonuçlar DB'de (`tjk_beyer_v2.db`) olmalıdır; DB'de sonuç yoksa değerlendirme üretilemez
     (sonuçlar genellikle yarış günü akşamı/sonrasında DB'ye işlenir).
   - `reports\daily_beyer\<date>_<sehir>_evaluation.html` dosyaları oluşur; sadece
     şehir başına değerlendirme dosyaları kullanılır (`general` dosyası yüklenmez).
   - Değerlendirmede "Aynı Yüzey" kartları/sütunları ve "Kontrol edilmesi gereken
     yüksek Son Hız liderleri" notu ÜRETİLMEZ (kullanıcı onayladı, HER ZAMAN UYGULA).

9. **Değerlendirme dosyalarını `rapor/` klasörüne ekle + kart + sitemap:**
   - Dosyaları `<sehir>-<gun>-<ay>-degerlendirme.html` adıyla kopyala
     (örn. `istanbul-6-eylul-degerlendirme.html`). gtag bloğunu `</head>` öncesine ekle.
   - `raporlar.html` ve `index.html`'e, diğer kartların **üstüne** 1'er kart ekle.
     Etiket: `Önceki Günün Değerlendirmesi`. Açıklamada koşu sayısı belirtilir.
   - `sitemap.xml`'e değerlendirme URL'lerini ekle (rapor URL'leriyle birlikte).
   - Eski günün değerlendirme dosyasını/kartlarını/URL'lerini SİL (yalnızca en güncel
     "önceki günün değerlendirmesi" kalır).

9b. **Adana sentetik par time güncellemesi (beyer projesinde otomatik):**
   Adana hipodromunda sentetik pist yeni olduğundan par time örneği azdır.
   `daily_results_beyer.py` (beyer projesi `src/`) her sonuç işlemede, o gün Adana
   sentetik koşusu varsa Adana SENTETIK par time'larını otomatik yeniden hesaplar
   (`rebuild_par_times` track/surface filtreli; diğer par time'lar ve aylık kilit
   değişmez). Manuel çağrı gerekirse:
   ```
   python src\daily_results_beyer.py --date YYYY-MM-DD
   ```
   Bu komut özetinde "Adana sentetik par time güncelleme" satırı görünür.

10. **Commit/push talimatı:** Kullanıcıya kısa commit mesajı ver, örn:
   `02.09.2026 raporlari eklendi, 01.09 raporlari silindi`
   (GitHub Desktop: Commit to main → Push origin)

## Diğer kurallar
- Kullanıcıya raporları commit/push için adım adım talimat ver (GitHub Desktop: Commit to main → Push origin).
- TJK sitesi otomatik isteklerde bazen 403 verir; script browser User-Agent kullanır. 403 olursa kullanıcıdan saat bilgisini iste.
- `rapor/` içindeki rehber dosyaları (`hiz-figur-rehberi`, `kilit-yaris-rehberi`, `istatistik-galop-rehberi`, `tempo-analizi-rehberi`) günlük temizlikte SİLİNMEZ.
- `gidişhat analizi` klasöründeki `*_gidisat_raporu.html` / `gidisat_tempo_stil_raporu.html` dosyaları site kategorisi olmadığı için yüklenmez; sadece `*_sinif_dusme_analizi.html` kullanılır.