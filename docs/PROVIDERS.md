# Riverpod Provider'lar (State Management)

## Genel Yaklaşım

- **flutter_riverpod 2.6.1** kullanılır
- İçerik state'i tek bir `StateNotifierProvider` (`contentStateProvider`) üzerinden yönetilir; feedback, game-config, history, auto-save/auto-load ve connectivity gibi bağımsız kanalların da kendi `StateNotifierProvider`'ları vardır — "tüm mutable state tek notifier'da" değil, her biri kendi state dilimini yönetir
- Derived `Provider`'lar ile hesaplanmış değerler reaktif olarak türetilir
- `autoDispose` kullanılmaz — tüm state uygulama boyunca bellekte kalır
- `family` parametrik derived provider'lar için kullanılır

## Provider Dosyaları

```
lib/presentation/providers/
├── content_providers.dart      ← Core state + derived content providers
├── history_providers.dart      ← Undo/redo, saved baseline, dirty state
├── search_providers.dart       ← Arama query, sonuçlar, focus node
├── validation_providers.dart   ← Validasyon sonuçları + health score + missing asset check
├── dashboard_providers.dart    ← Aggregate sayılar
├── asset_server_providers.dart ← AssetServerClient instance
├── connectivity_providers.dart ← Server bağlantı durumu (polling)
├── auto_load_providers.dart    ← Startup auto-load yönetimi
├── feedback_content_providers.dart
├── feedback_auto_save_providers.dart
├── game_config_providers.dart
├── game_config_auto_save_providers.dart
├── auto_save_providers.dart    ← Debounced auto-save controller
├── asset_providers.dart        ← Asset dizin listeleme
├── changelog_provider.dart     ← Baseline ↔ mevcut state farkı (Değişiklikler dialogu)
└── duplicate_check_provider.dart ← Soru metni tekrar tespiti (form uyarı banner'ı)
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
    ├── changelogProvider (← savedBaselineProvider)
    ├── duplicateCheckProvider(params)
    └── validationResultsProvider
            └── allValidationResultsProvider (← + missingAssetValidationProvider)
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

autoSaveControllerProvider + feedbackAutoSaveProvider + gameConfigAutoSaveProvider
    └── hasSaveErrorProvider   ← üç kanalın hepsini birden dinler

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
| Book | `deleteBook(int)` → `bool` | Siler (level'ı varsa **veya** bir ödül onu açıyorsa bloklanır) |
| Book | `reorderBooks(int, List<int>)` | Seri içi sıralama |
| Level | `addLevel(String, LevelModel)` | Yeni level ekler |
| Level | `updateLevel(String, LevelModel)` | Level'ı günceller |
| Level | `deleteLevel(String, int)` | Level ve sorularını siler, kalanları 1..N yeniden numaralar (`level_order` boşluğu error olur ve dosyanın kaydını bloklardı) |
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
- **Bağımlılık**: `allValidationResultsProvider` (senkron `validationResultsProvider` + async `missingAssetValidationProvider`'ın birleşimi — bkz. aşağıdaki "Missing Asset Validation Provider" bölümü)
- **Açıklama**: Sadece `ValidationSeverity.error` olanları filtreler

#### `validationWarningsProvider`
- **Tip**: `Provider<List<ValidationIssue>>`
- **Dosya**: `validation_providers.dart`
- **Bağımlılık**: `allValidationResultsProvider`
- **Açıklama**: Sadece `ValidationSeverity.warning` olanları filtreler (eksik asset uyarıları dahil)

#### `healthScoreProvider`
- **Tip**: `Provider<double>`
- **Dosya**: `validation_providers.dart`
- **Bağımlılık**: `allValidationResultsProvider`
- **Açıklama**: `max(0, 100 - (errorCount * 10 + warningCount * 2))` formülü ile 0–100 arası skor; eksik asset uyarıları da hesaba katılır

---

### Dashboard Provider'ları

#### `totalCountsProvider`
- **Tip**: `Provider<Map<String, int>>`
- **Dosya**: `dashboard_providers.dart`
- **Bağımlılık**: `contentStateProvider`
- **Döndürdüğü**: `{'series': n, 'books': n, 'levels': n, 'questions': n}`

#### `zipExporterProvider`
- **Tip**: `Provider<ZipExporter>`
- **Dosya**: `dashboard_providers.dart`
- **Açıklama**: `ZipExporter` instance'ı. Dashboard'ın export butonu bunu doğrudan `ZipExporter()` yerine buradan okur — tek seam, hata yolunu test edilebilir kılar.

---

### Router Provider

#### `routerProvider`
- **Tip**: `Provider<GoRouter>`
- **Dosya**: `router/app_router.dart`
- **Bağımlılık**: Yok
- **Açıklama**: `GoRouter` instance'ı, `StatefulShellRoute` ile 8 branch tanımlar (Dashboard, Explorer, Rewards, Hadiths, Assets, Feedback, Oyun, Validation)

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
- **Açıklama**: Son import/export edilen state, plus auto-save ile kaydedilmiş dosya dilimleri. Dirty karşılaştırması için kullanılır. Auto-save tüm state'i değil, kaydedilen dosyanın dilimini `mergeSavedFileIntoBaseline` ile işler.

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


---

## Asset Server Provider'ları

### `assetServerClientProvider`
- **Tip**: `Provider<AssetServerClient>`
- **Dosya**: `asset_server_providers.dart`
- **Açıklama**: `AssetServerClient` instance'ı (baseUrl: `http://localhost:8080`)

---

## Connectivity Provider'ları

### `serverConnectivityProvider`
- **Tip**: `StateNotifierProvider<ServerConnectivityNotifier, ServerConnectivity>`
- **Dosya**: `connectivity_providers.dart`
- **Açıklama**: `/api/health` endpoint'ini her 30 saniyede bir poll eder. `connected` veya `disconnected` durumu yayar.

### `isServerConnectedProvider`
- **Tip**: `Provider<bool>`
- **Dosya**: `connectivity_providers.dart`
- **Bağımlılık**: `serverConnectivityProvider`
- **Açıklama**: Server bağlıysa `true`

---

## Auto-Load Provider'ları

### `autoLoadProvider`
- **Tip**: `StateNotifierProvider<AutoLoadNotifier, AutoLoadStatus>`
- **Dosya**: `auto_load_providers.dart`
- **Bağımlılık**: `serverConnectivityProvider`, `assetServerClientProvider`, `contentStateProvider`, `savedBaselineProvider`, `historyProvider`
- **Açıklama**: Server bağlantısı kurulduğunda tüm JSON verilerini otomatik yükler. Status: `idle` → `loading` → `loaded` / `failed`

### `autoLoadCompleteProvider`
- **Tip**: `Provider<bool>`
- **Dosya**: `auto_load_providers.dart`
- **Bağımlılık**: `autoLoadProvider`
- **Açıklama**: Auto-load başarıyla tamamlandıysa `true`. Auto-save'i gate'lemek için kullanılır.

### `autoLoadErrorProvider`
- **Tip**: `StateProvider<AutoLoadFailure?>`
- **Dosya**: `auto_load_providers.dart`
- **Açıklama**: Son auto-load denemesinin hata detayını tutar (`serverReachable` + `message`), başarıda `null`. `serverReachable` ayrımı, banner'ın her hatayı "sunucu kapalı" diye göstermesini engeller — sorun sunucu değil okunan dosyalardan biri olabilir.

---

## Auto-Save Provider'ları

### `autoSaveControllerProvider`
- **Tip**: `StateNotifierProvider<AutoSaveController, SaveStatus>`
- **Dosya**: `auto_save_providers.dart`
- **Bağımlılık**: `autoLoadCompleteProvider`, `isServerConnectedProvider`, `contentStateProvider`, `assetServerClientProvider`, `savedBaselineProvider`, `validationResultsProvider`
- **Açıklama**: ContentState değişikliklerini dinler, per-file 2s debounce ile server'a kaydeder. Status: `idle`, `saving`, `saved`, `error`. `AdminApp` tarafından eager `watch` edilir; aksi halde notifier oluşmaz ve kayıt yapılmaz. Başarılı PUT sonrası `savedBaselineProvider` yalnızca ilgili dosya dilimiyle güncellenir. `feedbackAutoSaveProvider` ve `gameConfigAutoSaveProvider` aynı şekilde `AdminApp`'te eager initialize edilir.

### `gameConfigProvider` / `gameConfigLoadProvider` / `gameConfigAutoSaveProvider`
- **Dosya**: `game_config_providers.dart`, `game_config_auto_save_providers.dart`
- **Açıklama**: `data/game_config.json` yükleme ve 2s debounce PUT. ContentState'e karışmaz. 404 → seed defaults.

### `saveStatusProvider`
- **Tip**: `Provider<SaveStatus>`
- **Dosya**: `auto_save_providers.dart`
- **Bağımlılık**: `autoSaveControllerProvider`
- **Açıklama**: Mevcut kaydetme durumu

---

## Asset List Provider

### `assetListProvider`
- **Tip**: `FutureProvider.family<List<FileEntry>, String>`
- **Dosya**: `asset_providers.dart`
- **Parametre**: API_Path (dizin yolu, ör. `images`, `audio`, `icons`)
- **Bağımlılık**: `assetServerClientProvider`
- **Açıklama**: Server'dan dizin içeriğini listeler. Assets sayfasındaki tüm tab'lar tarafından kullanılır.

### `audioPlaybackProvider`
- **Tip**: `Provider<AudioPlayback>`
- **Dosya**: `asset_providers.dart`
- **Açıklama**: Ses önizlemesini çalan `WebAudioPlayback` (`HTMLAudioElement` sarmalayıcısı, `lib/data/services/audio_playback.dart`) instance'ı. Testlerin gerçek tarayıcı sesi olmadan oynatma durumunu doğrulayabilmesi için provider üzerinden verilir.

---

## Missing Asset Validation Provider

### `missingAssetValidationProvider`
- **Tip**: `FutureProvider<List<ValidationIssue>>`
- **Dosya**: `validation_providers.dart`
- **Bağımlılık**: `isServerConnectedProvider`, `contentStateProvider`, `assetServerClientProvider`
- **Açıklama**: Server bağlıyken, referans edilen asset dosyalarının varlığını kontrol eder. Eksik dosyalar için warning-level issue üretir.

### `allValidationResultsProvider`
- **Tip**: `Provider<List<ValidationIssue>>`
- **Dosya**: `validation_providers.dart`
- **Bağımlılık**: `validationResultsProvider`, `missingAssetValidationProvider`
- **Açıklama**: Senkron validasyon + async missing asset kontrolünü birleştirir.


---

## Changelog / Duplicate Provider'ları

### `changelogProvider`
- **Tip**: `Provider<List<ChangeEntry>>`
- **Dosya**: `changelog_provider.dart`
- **Bağımlılık**: `savedBaselineProvider`, `contentStateProvider`
- **Açıklama**: Baseline ile mevcut state arasındaki farkı ekle/değiştir/sil olarak listeler. Explorer toolbar'ındaki "Değişiklikler" dialogu bunu gösterir.

### `duplicateCheckProvider`
- **Tip**: `Provider.family<List<String>, DuplicateCheckParams>`
- **Dosya**: `duplicate_check_provider.dart`
- **Parametre**: `DuplicateCheckParams` (soru metni + hariç tutulacak konum)
- **Bağımlılık**: `contentStateProvider`
- **Açıklama**: Aynı soru metninin başka nerelerde geçtiğini döndürür. `QuestionForm` bunu amber uyarı banner'ında gösterir; düzenlenen sorunun kendisi hariç tutulur.

---

## Kayıt Durumu Provider'ları

### `hasSaveErrorProvider`
- **Tip**: `Provider<bool>`
- **Dosya**: `auto_save_providers.dart`
- **Bağımlılık**: `saveStatusProvider`, `feedbackSaveStatusProvider`, `gameConfigSaveStatusProvider`
- **Açıklama**: Üç auto-save kanalından herhangi biri hata durumundaysa true. `AppShell` bunu kırmızı noktaya çevirir. Validasyonla bloklanan yazım yalnızca kendi status provider'ında görünür, o yüzden üç kanalın da burada listelenmesi şart — eksik bırakılan kanal, kullanıcı o ekrandan ayrılır ayrılmaz sessizce kaybolur.

### `feedbackSaveStatusProvider`
- **Tip**: `Provider<FeedbackSaveStatus>`
- **Dosya**: `feedback_auto_save_providers.dart`
- **Açıklama**: `feedback.json` kaydetme durumu

### `gameConfigSaveStatusProvider`
- **Tip**: `Provider<GameConfigSaveStatus>`
- **Dosya**: `game_config_auto_save_providers.dart`
- **Açıklama**: `game_config.json` kaydetme durumu

### `autoLoadStatusProvider`
- **Tip**: `Provider<AutoLoadStatus>`
- **Dosya**: `auto_load_providers.dart`
- **Açıklama**: Auto-load durumunu (`idle`/`loading`/`loaded`/`failed`) notifier'a dokunmadan okumak için kolaylık provider'ı

### `hasUnsavedWorkProvider`
- **Tip**: `Provider<bool>`
- **Dosya**: `auto_save_providers.dart`
- **Bağımlılık**: `isDirtyProvider`, `hasSaveErrorProvider`, `savedBaselineProvider`, `contentStateProvider`, üç auto-save controller'ın `hasPendingChange`/`hasPendingSaves`'i
- **Açıklama**: Kaybedilmemesi gereken herhangi bir iş var mı — sayfadan ayrılma uyarısı (`beforeunload`) ve reconnect dialogu bunu kullanır. `isDirtyProvider` yalnızca içerik state'ini baseline'a karşı kıyaslar; feedback/game-config'teki bekleyen yazımlar ve hiç baseline almamış (ZIP/local) bir oturum bu olmadan görünmez kalırdı.

### `hasUnsyncedLocalSessionProvider`
- **Tip**: `Provider<bool>`
- **Dosya**: `auto_save_providers.dart`
- **Bağımlılık**: `autoLoadProvider`
- **Açıklama**: ZIP import'tan gelen veya sunucudan hiç `GET` ile yüklenmemiş bir oturum varsa `true` (`hasLoadedOnce && !loadedFromServer`)

---

## Feedback İçerik Provider'ları

### `feedbackContentProvider`
- **Tip**: `StateNotifierProvider<FeedbackContentNotifier, FeedbackContentState>`
- **Dosya**: `feedback_content_providers.dart`
- **Açıklama**: `feedback.json` içeriğinin tek kaynağı. Kategori/alt kategori bazlı mesaj ve ünvan CRUD'u. ContentState'ten ayrıdır.

### `feedbackLoadProvider`
- **Tip**: `StateNotifierProvider<FeedbackLoadNotifier, FeedbackLoadStatus>`
- **Dosya**: `feedback_content_providers.dart`
- **Açıklama**: `feedback.json`'ı asset sunucudan yükler

### `feedbackNeedsInitialDataProvider`
- **Tip**: `Provider<bool>`
- **Dosya**: `feedback_content_providers.dart`
- **Açıklama**: Sunucuda dosya yoksa (404) true — ilk verinin oluşturulması gerektiğini bildirir
