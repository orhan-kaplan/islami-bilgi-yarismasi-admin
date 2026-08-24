# Validasyon Kuralları (Validation Rules)

`ContentValidator` sınıfı (`lib/data/services/content_validator.dart`) quiz içeriğinin (series/books/rewards/hadiths/content) tüm yapısal ve semantik kurallarını kontrol eder.

> `game_config.json` için ayrı bir validator vardır: `GameConfigValidator.validateGameConfigData()` (`lib/data/services/game_config_validator.dart`), Game Config ekranını ve `gameConfigAutoSaveProvider`'ı aynı error/warning + save-gating modeliyle korur — bkz. `docs/SERVICES.md`.

## Error-Level Kurallar

Error-level kurallar iki yeri birden bloklar:

- **ZIP export** — tek bir error bile tüm export'u durdurur (`ValidationBlockedExportException`).
- **Per-file auto-save** — `isSaveAllowedForFile()` yalnızca issue'nun `sourceFile`'ına bakar, yani bir content dosyasındaki tek bir error o dosyanın tamamının (içindeki bütün level ve soruların) sunucuya yazılmasını durdurur. Diğer dosyalar kaydedilmeye devam eder.

Warning-level kurallar ikisini de bloklamaz.

| # | Kural Adı | Açıklama | sourceFile | jsonPath Örneği |
|---|-----------|----------|------------|-----------------|
| 1 | Series ID unique | Seri ID'leri pozitif tamsayı ve benzersiz olmalı | `series.json` | `$[0].id` |
| 2 | Book ID unique | Kitap ID'leri pozitif tamsayı ve benzersiz olmalı | `books.json` | `$[1].id` |
| 3 | Level ID unique (global) | Level ID'leri tüm kitaplar genelinde benzersiz olmalı. Çakışma, ID'yi taşıyan **her** content dosyasına ayrı ayrı raporlanır — per-file save gating yalnızca issue'nun adını verdiği dosyayı bloklar | `content/book_1.json` | `$.levels[0].id` |
| 4 | Book → Series FK | Kitabın `series_id`'si mevcut bir seriye işaret etmeli | `books.json` | `$[0].series_id` |
| 5 | Level → Book FK | Level'ın `book_id`'si mevcut bir kitaba işaret etmeli | `content/book_1.json` | `$.levels[0].book_id` |
| 6 | Reward → Book FK | Ödülün `unlock_book_id`'si mevcut bir kitaba işaret etmeli | `rewards.json` | `$[0].unlock_book_id` |
| 7 | Content-file book_id consistency | Content file içindeki tüm level'ların book_id'si, o dosyayı referans eden kitabın ID'si ile eşleşmeli | `content/book_1.json` | `$.levels[0].book_id` |
| 8 | Series sort_order sequential | `sort_order` değerleri 1'den başlayarak ardışık olmalı | `series.json` | `$[2].sort_order` |
| 9 | Book order sequential | Her seri içinde `book_order` değerleri 1'den başlayarak ardışık olmalı | `books.json` | `$[1].book_order` |
| 10 | Level order sequential | Her content file içinde `level_order` değerleri 1'den başlayarak ardışık olmalı | `content/book_1.json` | `$.levels` |
| 11 | correct_option valid | `correct_option` sadece "A", "B", "C", "D" değerlerinden biri olabilir | `content/book_1.json` | `$.levels[0].questions[2].correct_option` |
| 12 | true_false: option_c/d empty | `true_false` tipindeki sorularda `option_c` ve `option_d` boş string olmalı | `content/book_1.json` | `$.levels[0].questions[0].option_c` |
| 13 | matching: pipe separator | `matching` tipindeki sorularda her option **tam olarak bir** `\|` karakteri içermeli (uygulama option'ı sol/sağ olarak ikiye böler; başka her durumda "Hata" render eder) | `content/book_2.json` | `$.levels[1].questions[3].option_a` |
| 14 | sorting: correct_option = "A" | `sorting` tipindeki sorularda `correct_option` her zaman "A" olmalı | `content/book_1.json` | `$.levels[2].questions[0].correct_option` |
| 15 | content_file existence | Kitabın `content_file` alanı sadece dosya adı olmalı (path prefix yok) ve contentFiles map'inde bulunmalı | `books.json` | `$[0].content_file` |
| 16 | asset_image prefix | `asset_image` yolları "assets/" ile başlamalı (books, levels, rewards) | `books.json` | `$[0].asset_image` |
| 17 | Required fields non-empty | Zorunlu alanlar boş string olmamalı (series.name, book.title/description/content_file, level.title/category_name, question.question_text/option_a/option_b/correct_option, reward.title/description/asset_image, hadith.text/source) | çeşitli | `$[0].title` |
| 18 | sorting: 4 dolu item | `sorting` tipindeki sorularda `option_c` ve `option_d` boş olamaz (uygulama dört option'ı karıştırıp tüm listeyi karşılaştırır) | `content/book_1.json` | `$.levels[2].questions[0].option_c` |
| 19 | type whitelist | `type` yalnızca `multiple_choice`, `true_false`, `matching`, `sorting` olabilir (uygulama tanımadığı tipi sessizce çoktan seçmeliye düşürür) | `content/book_1.json` | `$.levels[0].questions[1].type` |
| 20 | correct_option dolu şıkka işaret etmeli | `correct_option`'ın gösterdiği `option_x` boş string olamaz — uygulama harfi index'e çevirip o option'ı doğru cevap diye render eder, boş string seçilemeyen bir cevaptır. `option_c`/`option_d` zorunlu olmadığı için en sık buradan kaçar | `content/book_1.json` | `$.levels[0].questions[2].correct_option` |

## Warning-Level Kurallar

Warning-level kurallar **export'u bloklamaz**. Tavsiye niteliğindedir.

| # | Kural Adı | Açıklama | sourceFile | jsonPath Örneği |
|---|-----------|----------|------------|-----------------|
| 1 | Empty explanation | Sorunun `explanation` alanı null veya boş string | `content/book_1.json` | `$.levels[0].questions[1].explanation` |
| 2 | Duplicate question_text | Whitespace normalize edildikten sonra (trim + collapse) aynı soru metni birden fazla yerde bulunuyor | `content/book_2.json` | `$.levels[1].questions[0].question_text` |
| 3 | Missing asset file | `asset_image` (books/levels/rewards) sunucudaki dosya sisteminde bulunamıyor | ilgili dosya (`books.json`/`content/*.json`/`rewards.json`) | `$[0].asset_image` |

### Missing asset file kontrolü — `ContentValidator`'ın dışında

Kural 3, `ContentValidator`'da değil ayrı bir provider'da yaşar:
`missingAssetValidationProvider` (`lib/presentation/providers/validation_providers.dart`,
`FutureProvider`). Yalnızca asset sunucusu bağlıyken çalışır — bağlantı yoksa
(veya kontrol hata verirse) hiç sonuç üretmez ve Validation ekranı "Asset checks
skipped" uyarısı gösterir; bu durumda health score de yalnızca senkron kuralları
yansıtır. Klasörleri bir kez listeleyip bir var-olma indeksi kurar, sonra tüm
`asset_image` referanslarını bu indekse karşı kontrol eder. `allValidationResultsProvider`,
senkron `ContentValidator` sonuçlarıyla bu async sonucu birleştirir; async provider
her içerik değişiminde yeniden çalıştığından, `skipLoadingOnReload: true` ile
yeniden yüklenirken önceki sonuç korunur — aksi halde her düzenlemede health score
geçici olarak zıplardı.

## Health Score Formülü

```
healthScore = max(0, 100 - (errorCount × 10 + warningCount × 2))
```

| Durum | Sonuç |
|-------|-------|
| 0 error, 0 warning | 100 |
| 1 error, 0 warning | 90 |
| 0 error, 5 warning | 90 |
| 5 error, 0 warning | 50 |
| 10 error, 0 warning | 0 |
| 3 error, 10 warning | max(0, 100 - 50) = 50 |

Score her zaman 0–100 arasında clamp edilir.

## Export Davranışı

| Durum | Export |
|-------|--------|
| 0 error, 0 warning | ✅ Başarılı |
| 0 error, N warning | ✅ Başarılı (warning'ler göz ardı edilir) |
| N error, M warning | ❌ Bloklanır (`ValidationBlockedExportException`) |

### ValidationBlockedExportException

Export bloklandığında fırlatılan exception, sadece ERROR-level issue'ları içerir:

```dart
class ValidationBlockedExportException implements Exception {
  final List<ValidationIssue> errors;
}
```

## Formda Önlenen Kurallar

Bazı kurallar ContentValidator'a hiç ulaşmadan formda durdurulur — bir dosyanın
tamamının kaydını bloklayan içeriğin en baştan üretilmemesi için:

| Kural | Nerede durdurulur |
|-------|-------------------|
| 20 — correct_option dolu şıkka işaret etmeli | `MultipleChoiceForm` dropdown validator'ı boş `option_x` seçimini reddeder |
| 17 — zorunlu alanlar boş olamaz (level/kitap) | `LevelForm`/`BookForm` hem Save'de hem görsel seçici commit'inde `validate()` çalıştırır |

Bu kapılar validator'ın yerini almaz; import ve elle düzenlenmiş JSON hâlâ
yalnızca ContentValidator'dan geçer.

## Validasyon Sabitleri

`lib/core/constants/validation_rules.dart` dosyasında merkezi olarak tanımlıdır:

```dart
class ValidationRules {
  static const validCorrectOptions = {'A', 'B', 'C', 'D'};
  static const validTrueFalseCorrectOptions = {'A', 'B'};
  static const validQuestionTypes = {'multiple_choice', 'true_false', 'matching', 'sorting'};
  static const matchingSeparator = '|';
  static const sortingCorrectOption = 'A';
  static const assetImagePrefix = 'assets/';
}
```
