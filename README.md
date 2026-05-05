# İlim Yolculuğu — İçerik Yönetim Aracı (Admin Tool)

**İslami Bilgi Yarışması** mobil uygulamasının içerik verilerini (seriler, kitaplar, level'lar, sorular, ödüller, hadisler) görsel arayüz üzerinden yönetmek için tasarlanmış standalone Flutter Web uygulamasıdır.

## Özellikler

- 📦 ZIP/JSON import ve export
- 🌳 Hiyerarşik içerik gezgini (Series → Books → Levels → Questions)
- ✏️ CRUD işlemleri (ekleme, düzenleme, silme, sıralama)
- ✅ 17 error-level + 2 warning-level validasyon kuralı
- 📊 Health score ile içerik sağlığı takibi
- 🚫 Hatalı içerik export'u otomatik engelleme

## Kurulum

```bash
flutter pub get
```

## Çalıştırma

```bash
flutter run -d chrome
```

## Test

```bash
flutter test
```

## Build

```bash
flutter build web
```

## Proje Yapısı

```
lib/
├── core/           ← Sabitler, tema
├── data/
│   ├── models/     ← İmmutable veri modelleri
│   └── services/   ← Parser, serializer, validator, importer, exporter
└── presentation/
    ├── providers/  ← Riverpod state yönetimi
    ├── router/     ← go_router navigasyon
    └── screens/    ← UI ekranları (5 ana sekme)
```

## Teknoloji

| Paket | Versiyon | Kullanım |
|-------|----------|----------|
| flutter_riverpod | ^2.6.1 | State yönetimi |
| go_router | ^14.8.1 | Navigasyon (StatefulShellRoute) |
| archive | ^4.0.4 | ZIP encode/decode |
| file_picker | ^8.3.7 | Dosya seçimi |
| web | ^1.1.0 | Tarayıcı API (download) |

## Dokümantasyon

Detaylı teknik dokümantasyon `docs/` klasöründe:

| Dosya | İçerik |
|-------|--------|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Mimari yapı, katmanlar, veri akışı |
| [CONVENTIONS.md](docs/CONVENTIONS.md) | Kod kuralları ve konvansiyonlar |
| [SCREENS.md](docs/SCREENS.md) | Ekranlar ve navigasyon |
| [PROVIDERS.md](docs/PROVIDERS.md) | Riverpod provider'lar |
| [SERVICES.md](docs/SERVICES.md) | Servisler (parser, validator, vb.) |
| [DATA_MODELS.md](docs/DATA_MODELS.md) | Veri modelleri |
| [VALIDATION_RULES.md](docs/VALIDATION_RULES.md) | Validasyon kuralları detayı |
