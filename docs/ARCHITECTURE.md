# Mimari Yapı (Architecture)

## Genel Bakış

Proje **standalone Flutter Web** uygulamasıdır. Tüm veri **in-memory** tutulur — backend veya veritabanı yoktur. İçerik ZIP/JSON dosyaları olarak import edilir, düzenlenir ve tekrar ZIP olarak export edilir.

```
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
| `services/` | Stateless servisler: `JsonParser`, `JsonSerializer`, `ContentValidator`, `ZipImporter`, `ZipExporter`, `SearchEngine`, `BulkImporter`, `downloadFile` |

### 3. Presentation Katmanı (`lib/presentation/`)

Kullanıcı arayüzü, state yönetimi ve navigasyon.

| Dizin | İçerik |
|-------|--------|
| `providers/` | Riverpod provider tanımları: `content_providers.dart`, `validation_providers.dart`, `dashboard_providers.dart`, `history_providers.dart`, `search_providers.dart` |
| `screens/` | Ekran widget'ları (özellik bazlı alt dizinler): `dashboard/`, `explorer/`, `rewards/`, `hadiths/`, `validation/` |
| `widgets/` | Paylaşılan widget'lar: `tree/`, `forms/`, `shared/`, `shortcuts/` |
| `router/` | `go_router` yapılandırması ve `AppShell` (NavigationRail) |

## Bağımlılık Yönü

```
core ← data ← presentation
```

- `core` hiçbir katmana bağımlı değildir
- `data` yalnızca `core`'a bağımlıdır
- `presentation` hem `core` hem `data`'ya bağımlıdır

## Veri Akışı

### Import Akışı
```
1. Kullanıcı ZIP veya JSON dosyaları seçer (file_picker)
2. ZipImporter → ZIP'i açar, dosyaları normalize eder
3. JsonParser → Her JSON dosyasını ilgili modele parse eder
4. ContentNotifier.importContent() → ContentState güncellenir
5. savedBaselineProvider → Import edilen state baseline olarak kaydedilir
6. HistoryNotifier.clear() → Undo/redo geçmişi temizlenir
7. Tüm derived provider'lar otomatik yeniden hesaplanır
```

### Export Akışı
```
1. Kullanıcı "Export ZIP" butonuna tıklar (veya Ctrl/Cmd+S kısayolu)
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
| **file_picker** | Tarayıcıda dosya seçimi (ZIP + JSON) |
| **web** | Tarayıcı API'lerine erişim (Blob, URL, anchor download) |
| **In-memory state** | Backend gerektirmez, offline çalışır, basit mimari |

## Giriş Noktası (`main.dart`)

```dart
main() → runApp(ProviderScope(child: AdminApp()))

AdminApp → MaterialApp.router(
  routerConfig: ref.watch(routerProvider),
  theme: adminTheme,
  darkTheme: adminDarkTheme,
)
```

- `ProviderScope` tüm Riverpod provider'ları sarar
- `routerProvider` go_router instance'ını sağlar
- Uygulama başladığında `ContentState.empty()` ile başlar (veri yok)
- Kullanıcı import yapana kadar boş state gösterilir
