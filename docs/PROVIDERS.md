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
├── history_providers.dart      ← Undo/redo, saved baseline, dirty state
├── search_providers.dart       ← Arama query, sonuçlar, focus node
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
    ├── isDirtyProvider (← savedBaselineProvider)
    ├── searchResultProvider (← searchQueryProvider)
    └── validationResultsProvider
            ├── validationErrorsProvider
            ├── validationWarningsProvider
            └── healthScoreProvider

historyProvider (StateNotifierProvider)
    ├── canUndoProvider
    └── canRedoProvider

savedBaselineProvider (StateProvider)
searchQueryProvider (StateProvider)
searchFocusNodeProvider (Provider)
jsonPreviewVisibleProvider (StateProvider)

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

---

## History & Dirty State Provider'ları

### `historyProvider`
- **Tip**: `StateNotifierProvider<HistoryNotifier, HistoryState>`
- **Dosya**: `history_providers.dart`
- **Açıklama**: Undo/redo stack'lerini yönetir. Maksimum 50 state snapshot tutar.

**HistoryNotifier Metotları:**

| Metot | Açıklama |
|-------|----------|
| `pushState(ContentState)` | Mevcut state'i undo stack'e ekler, redo stack'i temizler |
| `undo(ContentState)` → `ContentState?` | Undo stack'ten geri alır, mevcut state'i redo'ya ekler |
| `redo(ContentState)` → `ContentState?` | Redo stack'ten ileri alır, mevcut state'i undo'ya ekler |
| `clear()` | Her iki stack'i temizler (import sonrası) |

### `canUndoProvider`
- **Tip**: `Provider<bool>`
- **Bağımlılık**: `historyProvider`
- **Açıklama**: Undo stack boş değilse `true`

### `canRedoProvider`
- **Tip**: `Provider<bool>`
- **Bağımlılık**: `historyProvider`
- **Açıklama**: Redo stack boş değilse `true`

### `savedBaselineProvider`
- **Tip**: `StateProvider<ContentState?>`
- **Dosya**: `history_providers.dart`
- **Açıklama**: Son import/export edilen state. Dirty karşılaştırması için kullanılır.

### `isDirtyProvider`
- **Tip**: `Provider<bool>`
- **Bağımlılık**: `contentStateProvider`, `savedBaselineProvider`
- **Açıklama**: `current != baseline` ise `true`. Baseline null ise `false`.

### `jsonPreviewVisibleProvider`
- **Tip**: `StateProvider<bool>`
- **Dosya**: `history_providers.dart`
- **Açıklama**: JSON preview panelinin görünürlük durumu.

---

## Search Provider'ları

### `searchQueryProvider`
- **Tip**: `StateProvider<String>`
- **Dosya**: `search_providers.dart`
- **Açıklama**: Kullanıcının girdiği arama metni.

### `searchResultProvider`
- **Tip**: `Provider<SearchResult?>`
- **Bağımlılık**: `searchQueryProvider`, `contentStateProvider`
- **Açıklama**: Query boş değilse `SearchEngine.filter()` sonucunu döndürür, boşsa `null`.

### `searchFocusNodeProvider`
- **Tip**: `Provider<FocusNode>`
- **Dosya**: `search_providers.dart`
- **Açıklama**: Arama alanının FocusNode'u. Ctrl+F kısayolu ile focus verilir.

---

## Undo/Redo Kullanım Kalıbı

```dart
// Committed işlem öncesi history push
ref.read(historyProvider.notifier).pushState(ref.read(contentStateProvider));
ref.read(contentStateProvider.notifier).updateSeries(updatedSeries);

// Undo tetikleme
final restored = ref.read(historyProvider.notifier).undo(ref.read(contentStateProvider));
if (restored != null) {
  ref.read(contentStateProvider.notifier).importContent(restored);
}
```
