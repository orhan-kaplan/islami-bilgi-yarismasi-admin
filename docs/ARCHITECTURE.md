# Mimari Yapı (Architecture)

## Genel Bakış

Proje **standalone Flutter Web** uygulamasıdır. Tüm veri **in-memory** tutulur ve iki farklı persistence modu desteklenir:

1. **Asset Server modu** (birincil): Yerel Dart HTTP server üzerinden dosya sistemi erişimi. Veriler otomatik yüklenir ve değişiklikler otomatik kaydedilir.
2. **ZIP modu** (fallback): İçerik ZIP/JSON dosyaları olarak import edilir, düzenlenir ve tekrar ZIP olarak export edilir.

```
Asset Server → Auto-Load → ContentState (Riverpod) → Auto-Save → Asset Server
ZIP/JSON → Parser → ContentState (Riverpod) → Serializer → ZIP
```

## Katmanlar

```
lib/
├── core/           ← Altyapı katmanı (sabitler, tema)
├── data/           ← Veri katmanı (modeller, servisler)
└── presentation/   ← Sunum katmanı (provider'lar, ekranlar, router)
```

### 1. Core Katmanı (`lib/core/`)

Uygulamanın temel altyapısını sağlar. Hiçbir katmana bağımlı değildir.

| Dizin | İçerik |
|-------|--------|
| `constants/` | Validasyon sabitleri (`ValidationRules`) |
| `theme/` | Material 3 tema tanımı (light + dark) |

### 2. Data Katmanı (`lib/data/`)

Veri modelleri ve iş mantığı servislerini barındırır.

| Dizin | İçerik |
|-------|--------|
| `models/` | İmmutable veri modelleri: `SeriesModel`, `BookModel`, `LevelModel`, `QuestionModel`, `RewardModel`, `HadithModel`, `ContentState` |
| `services/` | Stateless servisler: `JsonParser`, `JsonSerializer`, `ContentValidator`, `ZipImporter`, `ZipExporter`, `SearchEngine`, `BulkImporter`, `AssetServerClient`, `AssetPathUtils`, `AssetReferenceDetector`, `UploadValidator`, `ContentFileMapping`, `SaveGating`, `downloadFile` |

### 3. Presentation Katmanı (`lib/presentation/`)

Kullanıcı arayüzü, state yönetimi ve navigasyon.

| Dizin | İçerik |
|-------|--------|
| `providers/` | Riverpod provider tanımları: `content_providers.dart`, `validation_providers.dart`, `dashboard_providers.dart`, `history_providers.dart`, `search_providers.dart`, `asset_server_providers.dart`, `connectivity_providers.dart`, `auto_load_providers.dart`, `auto_save_providers.dart`, `asset_providers.dart` |
| `screens/` | Ekran widget'ları (özellik bazlı alt dizinler): `dashboard/`, `explorer/`, `rewards/`, `hadiths/`, `assets/`, `validation/` |
| `widgets/` | Paylaşılan widget'lar: `tree/`, `forms/` (InlineImagePicker dahil), `shared/`, `shortcuts/` |
| `router/` | `go_router` yapılandırması ve `AppShell` (NavigationRail) |

## Bağımlılık Yönü

```
core ← data ← presentation
```

- `core` hiçbir katmana bağımlı değildir
- `data` yalnızca `core`'a bağımlıdır
- `presentation` hem `core` hem `data`'ya bağımlıdır

## Veri Akışı

### Import Akışı (ZIP — Fallback)
```
1. Kullanıcı ZIP veya JSON dosyaları seçer (file_picker)
2. ZipImporter → ZIP'i açar, dosyaları normalize eder
3. JsonParser → Her JSON dosyasını ilgili modele parse eder
4. hasBlockingErrors() → ERROR seviyesinde import issue varsa hiçbir şey
   uygulanmaz (yarım parse edilmiş state diske yazılıyordu). WARNING bloklamaz
5. isDirtyProvider true ise → onay dialogu; kullanıcı iptal ederse akış durur
   (import mevcut state'i ezer ve undo geçmişini de siler, geri dönüşü yok)
6. mergeImportedSlices() → yalnızca gerçekten gelen dosyaların dilimleri
   uygulanır; verilmeyen dosyalar mevcut state'ten korunur
7. ContentNotifier.importContent() → ContentState güncellenir
8. savedBaselineProvider → Import edilen state baseline olarak kaydedilir
9. HistoryNotifier.clear() → Undo/redo geçmişi temizlenir
10. Tüm derived provider'lar otomatik yeniden hesaplanır
```

### Auto-Load Akışı (Asset Server — Birincil)
```
1. Uygulama başlar → serverConnectivityProvider health check yapar
2. Server bağlantısı kurulur → autoLoadProvider tetiklenir
3. GET /api/health → Server durumu doğrulanır
4. GET /api/files/data/series.json, books.json, rewards.json, hadiths.json → Fetch
5. GET /api/list/data/content → Content dosyaları listelenir
6. GET /api/files/data/content/{file} → Her content dosyası fetch edilir
7. JsonParser → Tüm veriler parse edilir
8. ContentNotifier.importContent() → ContentState güncellenir
9. savedBaselineProvider → Yüklenen state baseline olarak kaydedilir
10. HistoryNotifier.clear() → Undo/redo geçmişi temizlenir
```

### Auto-Save Akışı (Asset Server)
```
1. Kullanıcı içerik düzenler → contentStateProvider değişir
2. AutoSaveController değişikliği algılar → getChangedFiles() ile etkilenen dosyalar belirlenir
3. Her dosya için 2 saniyelik debounce timer başlar
4. Timer dolduğunda → isSaveAllowedForFile() ile validasyon kontrolü
5. ERROR-level issue yoksa → JsonSerializer ile serialize → PUT /api/files/{path}
6. Başarılı kayıt → `mergeSavedFileIntoBaseline()` ile yalnızca o dosyanın dilimi `savedBaselineProvider`'a işlenir
7. Diğer dosyalarda kayıt edilmemiş değişiklik varsa `isDirtyProvider` true kalır
```

### Export Akışı (ZIP — Fallback)
```
1. Kullanıcı "Export ZIP" butonuna tıklar (veya Ctrl/Cmd+E; Ctrl/Cmd+S yalnızca
   sunucu bağlı değilken export eder, bağlıyken pending save'leri flush eder)
2. ZipExporter → ContentValidator.validateAll() çalıştırır
3. Error varsa → ValidationBlockedExportException fırlatılır
4. Error yoksa → JsonSerializer ile tüm modeller JSON'a dönüştürülür
5. Archive paketi ile ZIP oluşturulur
6. downloadFile() → Tarayıcı indirme tetiklenir
7. savedBaselineProvider → Export edilen state baseline olarak kaydedilir
```

### State Yönetimi Akışı
```
1. Widget: ConsumerWidget veya ConsumerStatefulWidget
2. ref.watch(contentStateProvider) → Tüm içerik state'i
3. Derived provider'lar (allSeriesProvider, validationResultsProvider, vb.)
4. CRUD işlemleri → ContentNotifier metotları → state güncellenir
5. Tüm dinleyen widget'lar otomatik rebuild olur
```

## Teknoloji Kararları

| Karar | Neden |
|-------|-------|
| **Flutter Web** | Ana uygulama Flutter olduğu için aynı dil ve model paylaşımı |
| **Riverpod** | Compile-time güvenlik, derived provider'lar ile reaktif validasyon |
| **go_router** | StatefulShellRoute ile NavigationRail entegrasyonu |
| **archive** | Dart-native ZIP encode/decode, web uyumlu |
| **file_picker** | Tarayıcıda dosya seçimi (ZIP + JSON + asset dosyaları) |
| **http** | AssetServerClient için HTTP istekleri |
| **lottie** | Lottie animasyon önizleme (Assets sayfası) |
| **web** | Tarayıcı API'lerine erişim (Blob, URL, anchor download, audio playback) |
| **shelf (server)** | Hafif Dart HTTP server, middleware pipeline desteği |
| **In-memory state** | Backend gerektirmez, offline çalışır, basit mimari |

## Asset Server (`server/` paketi)

Admin tool ile aynı workspace'te bulunan bağımsız Dart paketi. `assets/` dizinine REST API erişimi sağlar.

```
server/
├── bin/server.dart          ← Giriş noktası (--port, --assets-root args)
├── lib/
│   ├── asset_server.dart    ← Barrel export
│   └── src/
│       ├── server_app.dart  ← Pipeline: CORS → Path Security → Extension Guard → Router
│       ├── handlers/        ← health, file, list, folder endpoint'leri
│       ├── middleware/      ← cors, path_security, extension_guard
│       └── utils/           ← mime_types
├── test/                    ← Unit + property-based testler
└── pubspec.yaml
```

### Başlatma
```bash
cd server && dart run bin/server.dart --assets-root ../assets
```

### Endpoint'ler
| Method | Path | Açıklama |
|--------|------|----------|
| GET | `/api/health` | Server durumu |
| GET | `/api/files/{path}` | Dosya oku |
| PUT | `/api/files/{path}` | Dosya üzerine yaz |
| POST | `/api/files/{path}` | Yeni dosya oluştur |
| DELETE | `/api/files/{path}` | Dosya sil |
| GET | `/api/list/{path}` | Dizin listele |
| POST | `/api/folders/{path}` | Klasör oluştur |

## Giriş Noktası (`main.dart`)

```dart
main() → runApp(ProviderScope(child: AdminApp()))

AdminApp → MaterialApp.router(
  routerConfig: ref.watch(routerProvider),
  theme: adminTheme,
  darkTheme: adminDarkTheme,
)
// Eager initialization:
ref.watch(serverConnectivityProvider)  // Health polling başlatır
ref.watch(autoLoadProvider)            // Auto-load tetikler
ref.watch(autoSaveControllerProvider)  // Content auto-save dinlemeye başlar
ref.watch(feedbackAutoSaveProvider)    // Feedback auto-save dinlemeye başlar
ref.watch(gameConfigAutoSaveProvider)  // game_config.json auto-save dinlemeye başlar
```

- `ProviderScope` tüm Riverpod provider'ları sarar
- `routerProvider` go_router instance'ını sağlar
- Uygulama başladığında connectivity check yapılır
- Server bağlıysa → auto-load ile veriler otomatik yüklenir
- Auto-save provider'ları lazy'dir; `AdminApp` onları `watch` etmezse içerik değişikliklerine abone olmaz
- Server bağlı değilse → kullanıcı ZIP import yapabilir
