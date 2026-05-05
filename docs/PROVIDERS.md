# Riverpod Provider'lar (State Management)

## Genel Yaklaşım

- **flutter_riverpod 2.6.1** kullanılır
- Tek bir `StateNotifierProvider` tüm mutable state'i yönetir
- Derived `Provider`'lar ile hesaplanmış değerler reaktif olarak türetilir
- `autoDispose` kullanılmaz — tüm state uygulama boyunca bellekte kalır
- `family` parametrik derived provider'lar için kullanılır

## Provider Dosyaları

```
lib/presentation/providers/
├── content_providers.dart      ← Core state + derived content providers
├── validation_providers.dart   ← Validasyon sonuçları + health score
└── dashboard_providers.dart    ← Aggregate sayılar
```

## Bağımlılık Grafiği

```
contentStateProvider (StateNotifierProvider)
    ├── allSeriesProvider
    ├── booksForSeriesProvider(seriesId)
    ├── levelsForBookProvider(contentFile)
    ├── totalCountsProvider
    └── validationResultsProvider
            ├── validationErrorsProvider
            ├── validationWarningsProvider
            └── healthScoreProvider

(Bağımsız)
└── routerProvider
```

## Provider Detayları

### Core State Provider

#### `contentStateProvider`
- **Tip**: `StateNotifierProvider<ContentNotifier, ContentState>`
- **Dosya**: `content_providers.dart`
- **Açıklama**: Tüm içeriğin tek kaynağı. CRUD işlemleri `ContentNotifier` üzerinden yapılır.

**ContentNotifier Metotları:**

| Kategori | Metot | Açıklama |
|----------|-------|----------|
| Import | `importContent(ContentState)` | Tüm state'i değiştirir |
| Series | `addSeries(SeriesModel)` | Yeni seri ekler |
| Series | `updateSeries(SeriesModel)` | Seriyi günceller |
| Series | `deleteSeries(int)` → `bool` | Siler (kitabı varsa bloklanır) |
| Series | `reorderSeries(List<int>)` | Sıralama günceller |
| Book | `addBook(BookModel)` | Yeni kitap ekler |
| Book | `updateBook(BookModel)` | Kitabı günceller |
| Book | `deleteBook(int)` → `bool` | Siler (level'ı varsa bloklanır) |
| Book | `reorderBooks(int, List<int>)` | Seri içi sıralama |
| Level | `addLevel(String, LevelModel)` | Yeni level ekler |
| Level | `updateLevel(String, LevelModel)` | Level'ı günceller |
| Level | `deleteLevel(String, int)` | Level ve sorularını siler |
| Level | `reorderLevels(String, List<int>)` | Level sıralaması |
| Question | `addQuestion(String, int, QuestionModel)` | Yeni soru ekler |
| Question | `updateQuestion(String, int, int, QuestionModel)` | Soruyu günceller |
| Question | `deleteQuestion(String, int, int)` | Soruyu siler |
| Reward | `addReward(RewardModel)` | Yeni ödül ekler |
| Reward | `updateReward(int, RewardModel)` | Ödülü günceller |
| Reward | `deleteReward(int)` | Ödülü siler |
| Hadith | `addHadith(HadithModel)` | Yeni hadis ekler |
| Hadith | `updateHadith(int, HadithModel)` | Hadisi günceller |
| Hadith | `deleteHadith(int)` | Hadisi siler |
| Auto-ID | `nextSeriesId` → `int` | Sonraki kullanılabilir seri ID |
| Auto-ID | `nextBookId` → `int` | Sonraki kullanılabilir kitap ID |
| Auto-ID | `nextLevelId` → `int` | Sonraki kullanılabilir level ID |

---

### Derived Content Provider'ları

#### `allSeriesProvider`
- **Tip**: `Provider<List<SeriesModel>>`
- **Dosya**: `content_providers.dart`
- **Bağımlılık**: `contentStateProvider`
- **Açıklama**: Tüm serileri `sortOrder`'a göre sıralı döndürür

#### `booksForSeriesProvider`
- **Tip**: `Provider.family<List<BookModel>, int>`
- **Dosya**: `content_providers.dart`
- **Parametre**: `seriesId`
- **Bağımlılık**: `contentStateProvider`
- **Açıklama**: Belirli bir seriye ait kitapları `bookOrder`'a göre sıralı döndürür

#### `levelsForBookProvider`
- **Tip**: `Provider.family<List<LevelModel>, String>`
- **Dosya**: `content_providers.dart`
- **Parametre**: `contentFile` (dosya adı)
- **Bağımlılık**: `contentStateProvider`
- **Açıklama**: Belirli bir content file'daki level'ları `levelOrder`'a göre sıralı döndürür

---

### Validasyon Provider'ları

#### `validationResultsProvider`
- **Tip**: `Provider<List<ValidationIssue>>`
- **Dosya**: `validation_providers.dart`
- **Bağımlılık**: `contentStateProvider`
- **Açıklama**: `ContentValidator().validateAll(state)` çalıştırır, tüm issue'ları döndürür

#### `validationErrorsProvider`
- **Tip**: `Provider<List<ValidationIssue>>`
- **Dosya**: `validation_providers.dart`
- **Bağımlılık**: `validationResultsProvider`
- **Açıklama**: Sadece `ValidationSeverity.error` olanları filtreler

#### `validationWarningsProvider`
- **Tip**: `Provider<List<ValidationIssue>>`
- **Dosya**: `validation_providers.dart`
- **Bağımlılık**: `validationResultsProvider`
- **Açıklama**: Sadece `ValidationSeverity.warning` olanları filtreler

#### `healthScoreProvider`
- **Tip**: `Provider<double>`
- **Dosya**: `validation_providers.dart`
- **Bağımlılık**: `validationResultsProvider`
- **Açıklama**: `max(0, 100 - (errorCount * 10 + warningCount * 2))` formülü ile 0–100 arası skor

---

### Dashboard Provider'ları

#### `totalCountsProvider`
- **Tip**: `Provider<Map<String, int>>`
- **Dosya**: `dashboard_providers.dart`
- **Bağımlılık**: `contentStateProvider`
- **Döndürdüğü**: `{'series': n, 'books': n, 'levels': n, 'questions': n}`

---

### Router Provider

#### `routerProvider`
- **Tip**: `Provider<GoRouter>`
- **Dosya**: `router/app_router.dart`
- **Bağımlılık**: Yok
- **Açıklama**: `GoRouter` instance'ı, `StatefulShellRoute` ile 5 branch tanımlar

## Kullanım Kalıpları

### Veri Okuma (Widget'ta)
```dart
class MyScreen extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(allSeriesProvider);
    return ListView.builder(
      itemCount: series.length,
      itemBuilder: (_, i) => Text(series[i].name),
    );
  }
}
```

### CRUD İşlemi
```dart
// Yeni seri ekleme
final notifier = ref.read(contentStateProvider.notifier);
final newId = notifier.nextSeriesId;
notifier.addSeries(SeriesModel(id: newId, name: 'Yeni Seri', ...));
```

### Parametrik Provider Kullanımı
```dart
// Belirli bir serinin kitaplarını getir
final books = ref.watch(booksForSeriesProvider(seriesId));
```
