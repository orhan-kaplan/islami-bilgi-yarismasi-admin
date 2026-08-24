# Servisler (Services)

Servisler `lib/data/services/` altında tanımlıdır. Çoğu **stateless** olarak tasarlanmıştır — instance state tutmazlar, aynı girdi için her zaman aynı çıktıyı üretirler; `AssetServerClient` ve `DevicePreviewService` (HTTP client sarar) ve `WebAudioPlayback` (oynatma pozisyonu tutar) bu kuralın istisnalarıdır. `duplicateCheckProvider` ve `changelogProvider` Riverpod provider'larıdır (`lib/presentation/providers/`), servis değildir — bkz. `docs/PROVIDERS.md`.

## JsonParser

**Dosya**: `json_parser.dart`
**Pattern**: Stateless sınıf

Ham JSON string'lerini veri modellerine dönüştürür.

### Metotlar

| Metot | Girdi | Çıktı | Beklenen Format |
|-------|-------|-------|-----------------|
| `parseSeries(String)` | JSON string | `List<SeriesModel>` | JSON array |
| `parseBooks(String)` | JSON string | `List<BookModel>` | JSON array |
| `parseContentFile(String)` | JSON string | `List<LevelModel>` | `{"levels": [...]}` object |
| `parseRewards(String)` | JSON string | `List<RewardModel>` | JSON array |
| `parseHadiths(String)` | JSON string | `List<HadithModel>` | JSON array |

### Hata Yönetimi

- Geçersiz JSON → `FormatException` fırlatılır (açıklayıcı mesaj ile)
- Beklenmeyen yapı (array yerine object, vb.) → `FormatException`
- Her metot kendi hata mesajını üretir: `"Invalid JSON in {type} data: {detail}"`

---

## JsonSerializer

**Dosya**: `json_serializer.dart`
**Pattern**: Stateless sınıf

Veri modellerini JSON string'lerine dönüştürür. Ana uygulamanın beklediği formatta çıktı üretir.

### Metotlar

| Metot | Girdi | Çıktı Formatı |
|-------|-------|---------------|
| `serializeSeries(List<SeriesModel>)` | Seri listesi | JSON array |
| `serializeBooks(List<BookModel>)` | Kitap listesi | JSON array |
| `serializeContentFile(List<LevelModel>)` | Level listesi | `{"levels": [...]}` object |
| `serializeRewards(List<RewardModel>)` | Ödül listesi | JSON array |
| `serializeHadiths(List<HadithModel>)` | Hadis listesi | JSON array |

### Çıktı Özellikleri

- Pretty-print: 2-space indentation (`JsonEncoder.withIndent('  ')`)
- UTF-8 encoding
- Snake_case key'ler (model'in `toJson()` metodu tarafından sağlanır)

---

## ContentValidator

**Dosya**: `content_validator.dart`
**Pattern**: Pure-function validator

`ContentState` üzerinde yapısal ve semantik kuralları kontrol eder. Aynı state için her zaman aynı sonucu döndürür.

### Ana Metot

```dart
List<ValidationIssue> validateAll(ContentState state)
```

### Error-Level Kurallar (20 kural)

| # | Kural | Açıklama |
|---|-------|----------|
| 1 | Series ID unique | Seri ID'leri pozitif ve benzersiz olmalı |
| 2 | Book ID unique | Kitap ID'leri pozitif ve benzersiz olmalı |
| 3 | Level ID unique (global) | Level ID'leri TÜM kitaplar genelinde benzersiz olmalı |
| 4 | Book → Series FK | Kitabın `series_id`'si mevcut bir seriye işaret etmeli |
| 5 | Level → Book FK | Level'ın `book_id`'si mevcut bir kitaba işaret etmeli |
| 6 | Reward → Book FK | Ödülün `unlock_book_id`'si mevcut bir kitaba işaret etmeli |
| 7 | Content-file book_id consistency | Content file içindeki level'ların book_id'si tutarlı olmalı |
| 8 | Series sort_order sequential | `sort_order` değerleri 1'den başlayarak ardışık olmalı |
| 9 | Book order sequential | Her seri içinde `book_order` ardışık olmalı |
| 10 | Level order sequential | Her content file içinde `level_order` ardışık olmalı |
| 11 | correct_option valid | `correct_option` sadece A, B, C, D olabilir |
| 12 | true_false: option_c/d empty | `true_false` sorularda option_c ve option_d boş string olmalı |
| 13 | matching: pipe separator | `matching` sorularda her option `\|` içermeli |
| 14 | sorting: correct_option = "A" | `sorting` sorularda correct_option "A" olmalı |
| 15 | content_file existence | Kitabın `content_file`'ı contentFiles map'inde bulunmalı |
| 16 | asset_image prefix | `asset_image` yolları "assets/" ile başlamalı |
| 17 | Required fields non-empty | Zorunlu alanlar boş string olmamalı |
| 18 | correct_option non-empty option | `correct_option`'ın işaret ettiği option boş string olamaz (uygulama harfi index'e çevirip o option'ı doğru cevap olarak gösterir) |
| 19 | Question type whitelist | `type`, uygulamanın render edebildiği 4 tipten biri olmalı; aksi halde diğer tüm tip-bazlı kurallar atlanır |
| 20 | sorting: dört öğe de dolu | `sorting` sorularında `option_c`/`option_d` boş olamaz (uygulama tüm 4 option'ı karıştırıp karşılaştırır) |

### Warning-Level Kurallar (2 kural)

| # | Kural | Açıklama |
|---|-------|----------|
| 1 | Empty explanation | Sorunun `explanation` alanı boş veya null |
| 2 | Duplicate question_text | Whitespace normalize edildikten sonra aynı soru metni birden fazla yerde |

### ValidationIssue Yapısı

```dart
class ValidationIssue {
  final ValidationSeverity severity;  // error | warning
  final String sourceFile;            // "series.json", "content/book_1.json"
  final String jsonPath;              // "$.levels[0].questions[2].correct_option"
  final String message;               // İnsan-okunabilir açıklama
}
```

---

## ZipImporter

**Dosya**: `zip_importer.dart`
**Pattern**: Stateless sınıf, `JsonParser` bağımlılığı

ZIP arşivlerini ve bireysel JSON dosyalarını import eder.

### Metotlar

| Metot | Girdi | Çıktı |
|-------|-------|-------|
| `importZip(Uint8List)` | ZIP bytes | `(ContentState, List<ImportIssue>)` |
| `importAll(Uint8List)` | ZIP bytes | `ZipImportBundle` (content + optional feedback/game_config) |
| `parseExtras(Map)` | Dosya adı → bytes | sidecar feedback/game_config |
| `importFiles(Map<String, Uint8List>)` | Dosya adı → bytes map | `(ContentState, List<ImportIssue>)` |

### Path Normalization

ZIP içindeki dosya yolları normalize edilir:
- `assets/data/` prefix'i strip edilir
- `data/` prefix'i strip edilir
- `__MACOSX` dosyaları atlanır
- Sonuç: `series.json`, `books.json`, `content/book_1.json` gibi temiz yollar

### importFiles Dosya Tanıma

| Dosya Adı | Parse Metodu |
|-----------|-------------|
| `series.json` | `parseSeries` |
| `books.json` | `parseBooks` |
| `rewards.json` | `parseRewards` |
| `hadiths.json` | `parseHadiths` |
| `book_*.json` (regex) | `parseContentFile` |
| Diğer | Warning: "Unrecognized filename" |

### ImportIssue Yapısı

```dart
class ImportIssue {
  final String fileName;
  final String message;
  final ImportIssueSeverity severity;  // error | warning
}
```

---

## ZipExporter

**Dosya**: `zip_exporter.dart`
**Pattern**: Stateless sınıf, `ContentValidator` + `JsonSerializer` bağımlılığı

İçeriği validate eder, serialize eder ve ZIP arşivi olarak paketler.

### Metot

```dart
Uint8List exportZip(
  ContentState state, {
  FeedbackContentState? feedback,
  GameConfigState? gameConfig,
})
```

`feedback` / `gameConfig` verilmezse ZIP şekli eskisi gibi kalır (4 top-level + `content/`). Dashboard ve bağlantısız Ctrl+S bunları ekler. Eski ZIP import'ta sidecar yoksa uyarı verilir; mevcut feedback/oyun state silinmez.

### Çalışma Akışı

1. `ContentValidator.validateAll(state)` çalıştırılır
2. Error-level issue varsa → `ValidationBlockedExportException` fırlatılır
3. Warning-level issue'lar export'u **bloklamaz**
4. `JsonSerializer` ile tüm modeller JSON'a dönüştürülür
5. `Archive` paketi ile ZIP oluşturulur

### ZIP Yapısı

```
├── series.json
├── books.json
├── rewards.json
├── hadiths.json
└── content/
    ├── book_1.json
    ├── book_2.json
    └── ...
```

### ValidationBlockedExportException

```dart
class ValidationBlockedExportException implements Exception {
  final List<ValidationIssue> errors;  // Sadece ERROR-level issue'lar
}
```

---

## downloadFile (Web)

**Dosya**: `file_download_web.dart`
**Pattern**: Top-level fonksiyon

Tarayıcıda dosya indirme tetikler. `web` paketi ile DOM API'lerine erişir.

### İmza

```dart
void downloadFile(Uint8List bytes, String filename)
```

### Çalışma Mekanizması

1. `Blob` oluşturulur (bytes + MIME type)
2. `URL.createObjectURL(blob)` ile geçici URL üretilir
3. Gizli `<a>` elementi oluşturulur (`download` attribute ile)
4. `anchor.click()` tetiklenir → tarayıcı indirme başlar
5. Element kaldırılır ve URL revoke edilir (bellek temizliği)


---

## AudioPlayback

**Dosya**: `audio_playback.dart`
**Pattern**: Interface (`AudioPlayback`) + tarayıcı implementasyonu (`WebAudioPlayback`), stateful (çalan elementi tutar)

Ses önizlemesi için `HTMLAudioElement`'in ince bir sarmalayıcısı. Doğrudan `HTMLAudioElement` kullanmak, oynatmanın başarısız oluşunu (404, desteklenmeyen format, tarayıcının autoplay engeli) görünmez kılıyordu — `play()`'in döndürdüğü promise dinlenmediği için buton kalıcı olarak "Pause" durumunda kalıyordu. Provider (`audioPlaybackProvider`, bkz. `docs/PROVIDERS.md`) üzerinden verilir; testler gerçek tarayıcı sesi olmadan durumu doğrulayabilir.

### Metotlar

| Metot | Açıklama |
|-------|----------|
| `play(url, {onEnded, onError})` | `url`'i baştan çalar; çalan başka bir şey varsa önce durdurur |
| `resume()` | Duraklatılmış sesi bulunduğu yerden devam ettirir |
| `pause()` | Konumu koruyarak duraklatır |
| `stop()` | Oynatmayı bitirir ve elementi bırakır |

---

## SearchEngine

**Dosya**: `search_engine.dart`
**Pattern**: Pure-function stateless sınıf

İçerik ağacında Türkçe-duyarlı metin araması yapar.

### Metotlar

| Metot | Girdi | Çıktı |
|-------|-------|-------|
| `normalize(String)` | Ham metin | Türkçe-aware lowercase metin |
| `filter(ContentState, String)` | State + query | `SearchResult` |

### Normalizasyon Kuralları

Türkçe büyük/küçük harf dönüşümü yapar. `ı` ve `i` farklı harfler olarak korunur:

| Girdi | Çıktı | Açıklama |
|-------|-------|----------|
| `İ` | `i` | Büyük İ → küçük i |
| `I` | `ı` | Büyük I → küçük ı (Türkçe kuralı) |
| `ı` | `ı` | Olduğu gibi kalır |
| `Ö` | `ö` | Büyük → küçük |
| `Ü` | `ü` | Büyük → küçük |
| `Ş` | `ş` | Büyük → küçük |
| `Ç` | `ç` | Büyük → küçük |
| `Ğ` | `ğ` | Büyük → küçük |
| Diğer | `toLowerCase()` | Standart lowercase |

### SearchResult Yapısı

```dart
class SearchResult {
  final Set<int> matchingSeriesIds;      // Doğrudan eşleşen seriler
  final Set<int> matchingBookIds;        // Doğrudan eşleşen kitaplar
  final Set<int> matchingLevelIds;       // Doğrudan eşleşen level'lar
  final Set<int> matchingQuestionIndices; // levelId * 1000 + questionIndex
  final Set<int> visibleSeriesIds;       // Eşleşen + ata seriler
  final Set<int> visibleBookIds;         // Eşleşen + ata kitaplar
  final Set<int> visibleLevelIds;        // Eşleşen + ata level'lar
}
```

### Arama Kapsamı

Aşağıdaki alanlarda substring eşleşmesi yapılır:
- Series: `name`
- Book: `title`
- Level: `title`
- Question: `questionText`

---

## BulkImporter

**Dosya**: `bulk_importer.dart`
**Pattern**: Stateless sınıf

Çoklu soru girişini JSON array veya satır bazlı formattan parse eder.

### Metot

```dart
BulkImportResult parse(String input)
```

### Parse Stratejisi

1. Input `[` ile başlıyorsa → JSON array olarak parse dener
2. JSON parse başarısız olursa → satır bazlı format olarak parse eder
3. Her iki format da başarısız → hata döndürür

### Satır Bazlı Format

```
soru_metni
seçenek_a
seçenek_b
seçenek_c
seçenek_d
doğru_cevap (A/B/C/D)
açıklama (opsiyonel)
tip (opsiyonel, varsayılan: multiple_choice)

(boş satır ile ayır)

sonraki_soru_metni
...
```

### Tip-Spesifik Normalizasyon

| Tip | Normalizasyon |
|-----|---------------|
| `true_false` | option_a → "Doğru", option_b → "Yanlış", option_c/d → "", correctOption A veya B olmalı |
| `sorting` | correctOption her zaman "A" yapılır |
| `matching` | Her option'da `\|` separator zorunlu, yoksa invalid |
| Geçersiz tip | Soru invalid olarak işaretlenir |

### BulkImportResult Yapısı

```dart
class BulkImportResult {
  final List<QuestionModel> validQuestions;
  final List<BulkImportError> errors;
  bool get hasErrors => errors.isNotEmpty;
  bool get hasValidQuestions => validQuestions.isNotEmpty;
}

class BulkImportError {
  final int questionIndex;  // 0-based
  final String reason;
}
```


---

## AssetServerClient

**Dosya**: `asset_server_client.dart`
**Pattern**: Stateful HTTP client (baseUrl + http.Client)

Yerel Asset Server ile HTTP iletişimi sağlar.

### Constructor

```dart
AssetServerClient({String baseUrl = 'http://localhost:8080', http.Client? client})
```

### Metotlar

| Metot | HTTP | Açıklama |
|-------|------|----------|
| `health()` | GET `/api/health` | Server durumu (5s timeout) |
| `getFile(String)` | GET `/api/files/{path}` | Dosya bytes |
| `getFileAsString(String)` | GET `/api/files/{path}` | Dosya string |
| `listDirectory(String)` | GET `/api/list/{path}` | Dizin listesi |
| `putFile(String, Uint8List)` | PUT `/api/files/{path}` | Dosya üzerine yaz |
| `createFile(String, Uint8List)` | POST `/api/files/{path}` | Yeni dosya (409 if exists) |
| `deleteFile(String)` | DELETE `/api/files/{path}` | Dosya sil |
| `createFolder(String)` | POST `/api/folders/{path}` | Klasör oluştur |
| `syncPubspec()` | POST `/api/sync-pubspec` | `images/` altındaki dizinleri ana projenin pubspec.yaml'ına yazar |

### Hata Yönetimi

Non-2xx yanıtlarda `AssetServerException(statusCode, message)` fırlatılır; `message` sunucunun JSON gövdesindeki `error` alanından gelir.

Sunucudan gelebilecek, istemci tarafında anlamı olan durumlar:

| Kod | Ne zaman |
|-----|----------|
| 403 | Yol assets kökünün dışına çıkıyor, adda kontrol karakteri var, ya da yazma isteği izinli olmayan bir `Origin` taşıyor |
| 409 | `createFile` için dosya zaten var; `syncPubspec` için pubspec.yaml'da `- assets/images/` çapa satırı yok (dosya değiştirilmedi) |
| 415 | Uzantı, hedef dizin için izinli listede değil |

---

## AssetPathUtils

**Dosya**: `asset_path_utils.dart`
**Pattern**: Static utility sınıfı

App_Path (JSON'da saklanan) ve API_Path (server'a gönderilen) arasında dönüşüm yapar.

### Metotlar

| Metot | Girdi | Çıktı |
|-------|-------|-------|
| `appPathToApiPath(String)` | `assets/images/book_1/cover.webp` | `images/book_1/cover.webp` |
| `apiPathToAppPath(String)` | `images/book_1/cover.webp` | `assets/images/book_1/cover.webp` |
| `isValidAppPath(String)` | Herhangi bir path | `true` if starts with `assets/` |
| `sanitizeFilename(String)` | Raw filename | Güvenli dosya adı (lowercase, unsafe chars removed) |

---

## AssetReferenceDetector

**Dosya**: `asset_reference_detector.dart`
**Pattern**: Static utility sınıfı

ContentState'teki `asset_image` referanslarını tarar. Silme işlemlerinde referans güvenliği sağlar.

### Metotlar

| Metot | Açıklama |
|-------|----------|
| `findReferences(ContentState, String)` | Verilen path'i referans eden tüm içerik öğelerini döndürür |
| `isReferenced(ContentState, String)` | Path herhangi bir öğe tarafından referans ediliyorsa `true` |
| `getAllReferencedPaths(ContentState)` | Tüm referans edilen asset path'lerini döndürür |

---

## UploadValidator

**Dosya**: `upload_validator.dart`
**Pattern**: Static utility sınıfı

Dosya yükleme öncesi client-side doğrulama yapar.

### Metotlar

| Metot | Açıklama |
|-------|----------|
| `isValidExtension(String, AssetCategory)` | Dosya uzantısı kategoriye uygun mu (case-insensitive) |
| `validateLottieStructure(List<int>)` | Lottie JSON yapısı geçerli mi (v, layers, w, h) |
| `getAllowedExtensions(AssetCategory)` | Kategori için izin verilen uzantılar |

### AssetCategory Enum

| Kategori | İzin Verilen Uzantılar |
|----------|----------------------|
| `images` | .png, .jpg, .jpeg, .webp, .gif |
| `audio` | .mp3, .wav, .m4a, .ogg |
| `lottie` | .json |
| `icons` | .png, .jpg, .jpeg, .webp, .ico |

---

## DevicePreviewService

**Dosya**: `device_preview_service.dart`
**Pattern**: Stateful HTTP client (opsiyonel `http.Client` bağımlılığı)

Admin aracından asset sunucuya preview isteği gönderir. Feedback mesajını emülatörde/simülatörde çalışan mobil uygulamada test etmeyi sağlar.

### Constructor

```dart
DevicePreviewService({http.Client? client})
```

### Metotlar

| Metot | Açıklama |
|-------|----------|
| `sendPreview({message, screenContext, category, subcategory})` | Preview verisini sunucuya POST eder |
| `dispose()` | HTTP client'ı kapatır |

### PreviewResult Sealed Class

```dart
sealed class PreviewResult {}
class PreviewResultSuccess extends PreviewResult {}
class PreviewResultConnectionError extends PreviewResult {}
class PreviewResultServerError extends PreviewResult { final String message; }
```

### Çalışma Akışı

1. `FeedbackMessageModel` + `PreviewContext` + category/subcategory → JSON payload oluşturulur
2. `POST http://localhost:8080/api/preview` adresine gönderilir (5s timeout)
3. 200 → Success, timeout/connection error → ConnectionError, 4xx/5xx → ServerError

### Kullanım Yeri

`FeedbackPreviewDialog` → "Cihazda Test Et" butonu

---

## ContentFileMapping

**Dosya**: `content_file_mapping.dart`
**Pattern**: Pure functions

İçerik değişiklik türlerini API dosya yollarına eşler. Auto-save tarafından kullanılır.

### Fonksiyonlar

| Fonksiyon | Açıklama |
|-----------|----------|
| `getApiPathForChange(ContentChangeType, {String? contentFileKey})` | Değişiklik türü → API_Path |
| `getChangedFiles(ContentState, ContentState)` | İki state karşılaştırır, değişen dosyaları döndürür |
| `mergeSavedFileIntoBaseline(baseline, saved, apiPath)` | Kaydedilen dosyanın dilimini baseline'a kopyalar; diğer dosyaları dirty bırakır |

### Eşleme

| ContentChangeType | API_Path |
|-------------------|----------|
| `series` | `data/series.json` |
| `books` | `data/books.json` |
| `rewards` | `data/rewards.json` |
| `hadiths` | `data/hadiths.json` |
| `contentFile` (key) | `data/content/{key}` |

---

## FeedbackValidator

**Dosya**: `feedback_validator.dart`
**Pattern**: Pure functions

`FeedbackContentState` (feedback.json) üzerinde senkron şema kontrolleri yapar — sunucuya hiç istek atmaz. Tam validasyon (lottie dosyalarının sunucuda var olup olmadığı dahil) `feedback_content_providers.dart` içindeki async `validateFeedbackData(state, {client})` sarmalayıcısında yapılır; `client` verilmezse yalnızca bu senkron şema kontrolü çalışır — ZIP export gibi sunucusuz akışlar bunu kullanır.

### Fonksiyonlar

| Fonksiyon | Açıklama |
|-----------|----------|
| `validateFeedbackSchema(FeedbackContentState)` → `List<String>` | Zorunlu üst kategorilerin (`quiz`, `speed_quiz`, `time`, `comeback`, `streak`, `titles`, `learned`) ve her birinin zorunlu alt kategorilerinin dolu olduğunu, `streak` anahtarlarının pozitif tamsayı olduğunu ve tüm `lottie_asset` yollarının geçerli olduğunu kontrol eder |
| `isValidLottieShortPath(String?)` → `bool` | `null`/boş → geçerli; `assets/` ile başlıyorsa, `/` ile başlıyorsa veya `..` içeriyorsa geçersiz. `game_config_validator.dart` tarafından da paylaşılır |

### Zorunlu Alt Kategoriler (`kRequiredFeedbackSubcategories`)

| Kategori | Alt Kategoriler |
|----------|-----------------|
| `quiz` | speed_demon, perfect, one_wrong, two_wrong, good, moderate, failure |
| `speed_quiz` | combo_master, high_score, time_expired, moderate, low |
| `time` | seher, morning, noon, afternoon, evening, night, teheccud |
| `learned` | 100, 75, 50, 25, 0 |

`streak` için sabit bir liste yoktur — her anahtar pozitif tamsayı olmalıdır (gün sayısı). `comeback` düz bir mesaj listesidir, alt kategorisi yoktur, yalnızca lottie yolları kontrol edilir.

### Hata Yönetimi

`ContentValidator`'dan farklı olarak `ValidationIssue`/severity üretmez — dönen her string bloklayıcıdır, warning ayrımı yoktur. `validationResultsProvider`/`healthScoreProvider`'a dahil değildir.

---

## GameConfigValidator

**Dosya**: `game_config_validator.dart`
**Pattern**: Pure-function validator

`GameConfigState` üzerinde yapısal/semantik kuralları kontrol eder — `ContentValidator`'ın game_config.json karşılığı. Game Config ekranında ve `gameConfigAutoSaveProvider` tarafından kayıt öncesi gate olarak kullanılır (`game_config_auto_save_providers.dart:66`).

`ContentValidator.validateAll`'dan farklı olarak `ValidationIssue`/severity üretmez: dönen her string bloklayıcıdır, warning-level bir ayrım yoktur. `SaveGating` de kullanmaz — auto-save controller listenin boş olup olmadığına doğrudan bakar. Bu kanal `validationResultsProvider`/`healthScoreProvider`'a dahil değildir; içerik health score'unu etkilemez, yalnızca kendi ekranını ve kendi auto-save'ini gate'ler. Lottie kısa-yol kontrolü için `feedback_validator.dart`'taki `isValidLottieShortPath`'i paylaşır.

### Ana Metot

```dart
List<String> validateGameConfigData(GameConfigState state)
```

### Kullanım Yeri

- `game_config_screen.dart` — ekran içi validasyon göstergesi
- `game_config_auto_save_providers.dart` — liste boş değilse auto-save'i bloklar

---

## SaveGating

**Dosya**: `save_gating.dart`
**Pattern**: Pure function

Kaydetme öncesi validasyon kontrolü. ERROR-level issue varsa kayıt bloklanır.

### Fonksiyon

```dart
bool isSaveAllowedForFile(String apiPath, List<ValidationIssue> issues)
```

- `true`: Hedef dosya için sıfır ERROR-level issue varsa
- WARNING-level issue'lar kayıt bloklamaz

Yalnızca `contentStateProvider`'ın (`series`/`books`/`rewards`/`hadiths`/`content/*`) auto-save kanalında kullanılır — feedback ve game-config auto-save'leri kendi `List<String>` hata listelerinin boş olup olmadığına doğrudan bakar, bu fonksiyonu çağırmaz.

Not: `duplicateCheckProvider` ve `changelogProvider` — bu servis dosyalarını (`content_file_mapping.dart` gibi) kullanan ama kendileri Riverpod provider'ı olan iki yardımcı — `docs/PROVIDERS.md`'deki "Changelog / Duplicate Provider'ları" bölümünde belgelenir, burada tekrar edilmez.
