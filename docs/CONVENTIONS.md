# Kurallar ve Konvansiyonlar (Conventions)

## Dosya İsimlendirme

| Tip | Format | Örnek |
|-----|--------|-------|
| Model | `{entity}_model.dart` | `series_model.dart` |
| Servis | Sabit bir kalıp yok — `{action}er.dart` (`zip_exporter.dart`, `bulk_importer.dart`), `{şey}_validator.dart` (`content_validator.dart`, `feedback_validator.dart`), `{şey}_client.dart` (`asset_server_client.dart`), veya sade betimleyici ad (`save_gating.dart`, `search_engine.dart`, `audio_playback.dart`) — hepsi anlamlı, öz İngilizce isimler | `json_parser.dart`, `zip_exporter.dart`, `content_validator.dart` |
| Provider | `{scope}_providers.dart` | `content_providers.dart` |
| Ekran | `{feature}_screen.dart` | `dashboard_screen.dart` |
| Widget | `{role}_panel.dart` veya `{role}_card.dart` | `tree_panel.dart`, `edit_panel.dart` |
| Form | `{entity}_form.dart` | `question_form.dart` |
| Sabitler | betimleyici ad, `_rules`/`_config` gibi sonekler yaygın ama zorunlu değil | `validation_rules.dart`, `asset_server_config.dart` |

## Dizin Yapısı

```
lib/
├── core/
│   ├── constants/          ← Sabitler
│   └── theme/              ← Tema tanımları
├── data/
│   ├── models/             ← İmmutable veri modelleri
│   └── services/           ← Stateless iş mantığı servisleri
└── presentation/
    ├── providers/          ← Riverpod provider tanımları
    ├── router/             ← go_router yapılandırması
    └── screens/
        ├── dashboard/      ← Dashboard ekranı
        ├── explorer/       ← Content Explorer (master-detail)
        ├── rewards/        ← Ödül yönetimi
        ├── hadiths/        ← Hadis yönetimi
        ├── assets/         ← Asset yönetimi (görsel/ses/lottie yükleme)
        ├── feedback/       ← Geri bildirim mesajı yönetimi
        ├── game_config/    ← Oyun mekaniği (game_config.json) yönetimi
        └── validation/     ← Validasyon raporu
```

## Kod Dili

- **Kod yorumları**: Türkçe (/// doc comments İngilizce)
- **UI metinleri**: İngilizce hedeflenir; pratikte bazı ekranlarda (ör. Explorer, Feedback preview) Türkçe metinler de var — ağırlıklı olarak İngilizce ama tutarlı biçimde uygulanmamış
- **Değişken/fonksiyon adları**: İngilizce (Dart konvansiyonu)
- **Sınıf adları**: İngilizce, PascalCase
- **Dosya adları**: İngilizce, snake_case

## Riverpod Konvansiyonları

| Pattern | Kullanım | Örnek |
|---------|----------|-------|
| `StateNotifierProvider` | Mutable CRUD state | `contentStateProvider` |
| `Provider` | Derived/computed değerler | `allSeriesProvider`, `healthScoreProvider` |
| `Provider.family` | Parametrik derived | `booksForSeriesProvider(seriesId)` |
| `FutureProvider` | Server'a bağlı async okuma | `assetListProvider(path)`, `missingAssetValidationProvider` |
| `StateProvider` | Tekil UI bayrağı / baseline | `jsonPreviewVisibleProvider`, `savedBaselineProvider` |

Kod generation kullanılmaz — `riverpod_annotation`/`riverpod_generator` bu projede
yok, tüm provider'lar elle yazılır.

### İsimlendirme

- Provider isimleri: `{feature}Provider` (camelCase)
- Notifier isimleri: `{Feature}Notifier` (PascalCase)
- State sınıfları: `{Feature}State` veya `{Entity}Model` (PascalCase)

### Kullanım Kuralları

- `ref.watch()` → build metodu içinde (reaktif dinleme)
- `ref.read()` → callback'ler ve event handler'lar içinde (tek seferlik okuma)
- Derived provider'lar `contentStateProvider`'ı watch eder → otomatik güncelleme

## JSON Key Format

| Bağlam | Format | Örnek |
|--------|--------|-------|
| JSON dosyaları | snake_case | `sort_order`, `book_id`, `content_file` |
| Dart model alanları | camelCase | `sortOrder`, `bookId`, `contentFile` |
| `fromJson` / `toJson` | Dönüşüm model içinde | `json['sort_order'] as int` → `sortOrder` |

## Validasyon Kuralları

- **Error-level**: Export'u bloklar. Yapısal bütünlük hataları (FK ihlali, duplicate ID, vb.)
- **Warning-level**: Export'u bloklamaz. Tavsiye niteliğinde (boş açıklama, tekrar soru)
- Health score: `max(0, 100 - (errorCount * 10 + warningCount * 2))`

## Dart/Flutter Konvansiyonları

- `const` constructor'lar mümkün olduğunca kullanılır
- Widget'lar `ConsumerWidget` veya `ConsumerStatefulWidget` extend eder
- Modeller immutable — `copyWith` ile güncelleme
- Servisler stateless — constructor injection ile bağımlılık
- `sealed class` ile tip-güvenli union tipler (`SelectedItem`)
- `==` ve `hashCode` override ile değer eşitliği

## Genel Komutlar

```bash
# Bağımlılıkları yükle
flutter pub get

# Uygulamayı çalıştır (Chrome)
flutter run -d chrome

# Testleri çalıştır
flutter test

# Web build
flutter build web

# Kod analizi
flutter analyze
```
