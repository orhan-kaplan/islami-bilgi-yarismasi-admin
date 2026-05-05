# Servisler (Services)

Tüm servisler `lib/data/services/` altında tanımlıdır. Hepsi **stateless** olarak tasarlanmıştır — instance state tutmazlar, aynı girdi için her zaman aynı çıktıyı üretirler.

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

### Error-Level Kurallar (17 kural)

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
Uint8List exportZip(ContentState state)
```

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
