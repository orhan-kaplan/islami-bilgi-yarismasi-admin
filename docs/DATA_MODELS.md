# Veri Modelleri (Data Models)

Tüm modeller `lib/data/models/` altında tanımlıdır. Hepsi **immutable** olarak tasarlanmıştır — `copyWith` ile güncelleme yapılır.

> **Kapsam notu**: Bu dosya yalnızca `ContentState`'in kapsadığı quiz-içerik modellerini (series/book/level/question/reward/hadith) detaylandırır. `feedback.json` ve `game_config.json`'u besleyen modeller ayrı state kaynaklarıdır (`feedbackContentProvider`, `gameConfigProvider` — bkz. `docs/PROVIDERS.md`) ve aşağıda özet olarak listelenir.

## SeriesModel

**Dosya**: `series_model.dart`
**JSON Dosyası**: `series.json`

Bir içerik serisini temsil eder.

### Alanlar

| Alan | Tip | JSON Key | Açıklama |
|------|-----|----------|----------|
| `id` | `int` | `id` | Benzersiz seri ID (pozitif) |
| `name` | `String` | `name` | Seri adı |
| `sortOrder` | `int` | `sort_order` | Sıralama (1'den başlar, ardışık) |
| `isLocked` | `bool` | `is_locked` | Kilitli mi? |
| `iconEmoji` | `String` | `icon_emoji` | Seri ikonu (emoji) |
| `description` | `String?` | `description` | Opsiyonel açıklama |

### Metotlar

- `SeriesModel.fromJson(Map<String, dynamic>)` — JSON'dan oluşturma
- `toJson()` → `Map<String, dynamic>` — JSON'a dönüştürme
- `copyWith(...)` — İmmutable güncelleme

---

## BookModel

**Dosya**: `book_model.dart`
**JSON Dosyası**: `books.json`

Bir seri içindeki kitabı temsil eder.

### Alanlar

| Alan | Tip | JSON Key | Açıklama |
|------|-----|----------|----------|
| `id` | `int` | `id` | Benzersiz kitap ID (pozitif) |
| `title` | `String` | `title` | Kitap başlığı |
| `description` | `String` | `description` | Kitap açıklaması |
| `assetImage` | `String` | `asset_image` | Kapak görseli yolu ("assets/" ile başlar) |
| `bookOrder` | `int` | `book_order` | Seri içi sıralama (1'den başlar) |
| `seriesId` | `int` | `series_id` | Ait olduğu seri ID (FK) |
| `contentFile` | `String` | `content_file` | İçerik dosya adı (ör: "book_1.json") |

### Metotlar

- `BookModel.fromJson(Map<String, dynamic>)` — JSON'dan oluşturma
- `toJson()` → `Map<String, dynamic>` — JSON'a dönüştürme
- `copyWith(...)` — İmmutable güncelleme

---

## LevelModel

**Dosya**: `level_model.dart`
**JSON Dosyası**: `content/book_X.json` (levels array içinde)

Bir kitap içindeki quiz level'ını temsil eder. Her level bir soru listesi içerir.

### Alanlar

| Alan | Tip | JSON Key | Açıklama |
|------|-----|----------|----------|
| `id` | `int` | `id` | Benzersiz level ID (tüm kitaplar genelinde) |
| `bookId` | `int` | `book_id` | Ait olduğu kitap ID (FK) |
| `categoryName` | `String` | `category_name` | Kategori adı |
| `levelOrder` | `int` | `level_order` | Kitap içi sıralama (1'den başlar) |
| `title` | `String` | `title` | Level başlığı |
| `unlockScore` | `int` | `unlock_score` | Açılma için gereken puan |
| `assetImage` | `String?` | `asset_image` | Opsiyonel arka plan görseli |
| `questions` | `List<QuestionModel>` | `questions` | Soru listesi |

### Metotlar

- `LevelModel.fromJson(Map<String, dynamic>)` — JSON'dan oluşturma (questions dahil)
- `toJson()` → `Map<String, dynamic>` — JSON'a dönüştürme (questions dahil)
- `copyWith(...)` — İmmutable güncelleme

---

## QuestionModel

**Dosya**: `question_model.dart`
**JSON Dosyası**: `content/book_X.json` (level.questions array içinde)

Bir quiz sorusunu temsil eder. 4 soru tipi desteklenir: `multiple_choice`, `true_false`, `matching`, `sorting`.

### Alanlar

| Alan | Tip | JSON Key | Açıklama |
|------|-----|----------|----------|
| `questionText` | `String` | `question_text` | Soru metni |
| `optionA` | `String` | `option_a` | A şıkkı |
| `optionB` | `String` | `option_b` | B şıkkı |
| `optionC` | `String` | `option_c` | C şıkkı (true_false'da boş) |
| `optionD` | `String` | `option_d` | D şıkkı (true_false'da boş) |
| `correctOption` | `String` | `correct_option` | Doğru cevap: "A", "B", "C", "D" |
| `explanation` | `String?` | `explanation` | Opsiyonel açıklama |
| `type` | `String` | `type` | Soru tipi (varsayılan: "multiple_choice") |

### Soru Tipleri

| Tip | Özellik |
|-----|---------|
| `multiple_choice` | Standart 4 şıklı soru |
| `true_false` | 2 şıklı, option_c ve option_d boş string |
| `matching` | Her option `\|` separator içerir |
| `sorting` | correct_option her zaman "A" |

### Metotlar

- `QuestionModel.fromJson(Map<String, dynamic>)` — JSON'dan oluşturma
- `toJson()` → `Map<String, dynamic>` — JSON'a dönüştürme
- `copyWith(...)` — İmmutable güncelleme

---

## RewardModel

**Dosya**: `reward_model.dart`
**JSON Dosyası**: `rewards.json`

Kitap tamamlama ödülünü temsil eder.

### Alanlar

| Alan | Tip | JSON Key | Açıklama |
|------|-----|----------|----------|
| `title` | `String` | `title` | Ödül başlığı |
| `description` | `String` | `description` | Ödül açıklaması |
| `assetImage` | `String` | `asset_image` | Rozet görseli yolu |
| `unlockBookId` | `int` | `unlock_book_id` | Hangi kitap tamamlanınca açılır (FK) |

### Metotlar

- `RewardModel.fromJson(Map<String, dynamic>)` — JSON'dan oluşturma
- `toJson()` → `Map<String, dynamic>` — JSON'a dönüştürme
- `copyWith(...)` — İmmutable güncelleme

---

## HadithModel

**Dosya**: `hadith_model.dart`
**JSON Dosyası**: `hadiths.json`

Bir hadis kaydını temsil eder.

### Alanlar

| Alan | Tip | JSON Key | Açıklama |
|------|-----|----------|----------|
| `text` | `String` | `text` | Hadis metni |
| `source` | `String` | `source` | Kaynak (ör: "Buhârî") |

### Metotlar

- `HadithModel.fromJson(Map<String, dynamic>)` — JSON'dan oluşturma
- `toJson()` → `Map<String, dynamic>` — JSON'a dönüştürme
- `copyWith(...)` — İmmutable güncelleme

---

## ContentState

**Dosya**: `content_state.dart`

Tüm içeriği bir arada tutan aggregate state sınıfı. Admin aracının tek veri kaynağıdır.

### Alanlar

| Alan | Tip | Açıklama |
|------|-----|----------|
| `series` | `List<SeriesModel>` | Tüm seriler |
| `books` | `List<BookModel>` | Tüm kitaplar |
| `contentFiles` | `Map<String, List<LevelModel>>` | Dosya adı → level listesi |
| `rewards` | `List<RewardModel>` | Tüm ödüller |
| `hadiths` | `List<HadithModel>` | Tüm hadisler |

### Factory Metotlar

- `ContentState.empty()` — Boş state (uygulama başlangıcı)

### Metotlar

- `copyWith(...)` — İmmutable güncelleme

---

## SelectedItem (Sealed Class)

**Dosya**: `content_explorer_screen.dart`

Content Explorer'da seçili öğeyi temsil eden tip-güvenli union tipi.

Sekiz variant var: dördü mevcut bir öğeyi seçer, dördü EditPanel'de boş bir
"create" formu açar.

```dart
sealed class SelectedItem {}

// Mevcut öğe seçimi — EditPanel edit modunda form açar
class SelectedSeries extends SelectedItem {
  final int seriesId;
}

class SelectedBook extends SelectedItem {
  final int bookId;
}

class SelectedLevel extends SelectedItem {
  final String contentFile;
  final int levelId;
}

class SelectedQuestion extends SelectedItem {
  final String contentFile;
  final int levelId;
  final int questionIndex;
}

// Create tetikleyicileri — EditPanel boş form açar, silme butonu görünmez
class CreateSeries extends SelectedItem {}

class CreateBook extends SelectedItem {
  final int seriesId;
}

class CreateLevel extends SelectedItem {
  final String contentFile;
  final int bookId;
}

class CreateQuestion extends SelectedItem {
  final String contentFile;
  final int levelId;
}
```

`_selectedItem` null olduğunda panel "Select an item to edit" gösterir; silme
sonrası bu duruma döner.

---

## ImportIssue

**Dosya**: `zip_importer.dart`

Import sırasında karşılaşılan sorunları temsil eder.

### Alanlar

| Alan | Tip | Açıklama |
|------|-----|----------|
| `fileName` | `String` | Sorunlu dosya adı |
| `message` | `String` | Hata/uyarı mesajı |
| `severity` | `ImportIssueSeverity` | `error` veya `warning` |

---

## ValidationIssue

**Dosya**: `content_validator.dart`

Validasyon kontrollerinde bulunan sorunları temsil eder.

### Alanlar

| Alan | Tip | Açıklama |
|------|-----|----------|
| `severity` | `ValidationSeverity` | `error` veya `warning` |
| `sourceFile` | `String` | İlgili JSON dosyası (ör: "series.json") |
| `jsonPath` | `String` | JSON-path lokator (ör: "$.levels[0].id") |
| `message` | `String` | İnsan-okunabilir açıklama |

---

## Feedback Modelleri (`feedback_models.dart`)

**JSON Dosyası**: `feedback.json` — `feedbackContentProvider` üzerinden `ContentState`'ten ayrı yönetilir.

| Sınıf | Alanlar | Açıklama |
|-------|---------|----------|
| `FeedbackMessageModel` | `title`, `message`, `emoji`, `shouldRepeat` | Kategori/alt kategori altında gruplu tek bir geri bildirim mesajı |
| `PlayerTitleModel` | `title`, `icon`, `requiredBooks`, `profileImage` | Kitap sayısına göre kazanılan oyuncu ünvanı |
| `FeedbackContentState` | mesaj/ünvan koleksiyonları | `feedback.json`'un tamamının aggregate state'i |

Detaylı CRUD ve ekran davranışı için `docs/PROVIDERS.md` ("Feedback İçerik Provider'ları") ve `docs/SCREENS.md`'ye bakınız.

## Game Config Modelleri (`game_config_models.dart`)

**JSON Dosyası**: `game_config.json` — `gameConfigProvider` üzerinden `ContentState`'ten ayrı yönetilir; `GameConfigValidator` (bkz. `docs/SERVICES.md`) tarafından kayıt öncesi doğrulanır.

| Sınıf | Açıklama |
|-------|----------|
| `ScoreClause` | Min doğruluk/min doğru sayısı koşulu |
| `LearnedBand` | Öğrenme yüzdesi bandı (key + eşik) |
| `TimeSlotConfig` | Gün içi zaman dilimi persona tanımı |
| `QuizGameConfig` | Normal quiz kuralları (can, puan, süre) |
| `SpeedQuizGameConfig` | Hız modu skorlama/süre kuralları |
| `DailyGoalGameConfig` | Günlük hedef eşikleri |
| `LottieGameConfig` | Feedback Lottie animasyon yolları |
| `CopyGameConfig` | Yapılandırılabilir metin/kopya |
| `GameConfigState` | Tüm game_config.json'un aggregate state'i |

Bu sınıflar mobil uygulamanın `lib/core/services/game_config.dart` dosyasındaki karşılıklarıyla bire bir eşleşir (bkz. mobil app `docs/SERVICES.md`).
