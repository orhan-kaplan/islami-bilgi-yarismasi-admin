# Ekranlar ve Navigasyon (Screens)

## Ana Navigasyon Yapısı

`AppShell` (`lib/presentation/router/app_router.dart`) uygulamanın ana iskeletidir. Sol tarafta `NavigationRail`, sağ tarafta aktif ekran gösterilir.

```
AppShell (Scaffold + Row) — ConsumerWidget
├── NavigationRail (sol panel)
│   ├── Tab 0: Dashboard     (Home)
│   ├── Tab 1: Explorer      (Content Explorer)
│   ├── Tab 2: Rewards       (Ödüller)
│   ├── Tab 3: Hadiths       (Hadisler)
│   ├── Tab 4: Validation    (Validasyon Raporu)
│   └── trailing: Unsaved changes indicator (turuncu nokta, tüm sayfalarda görünür)
├── BeforeUnloadGuard (tarayıcı kapatma koruması)
├── AppShortcuts (global klavye kısayolları)
└── Expanded (sağ panel — aktif ekran)
```

### go_router ile StatefulShellRoute

```dart
StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) {
    return Consumer(builder: (context, ref, _) {
      return BeforeUnloadGuard(
        child: AppShortcuts(
          onUndo: ..., onRedo: ..., onExport: ...,
          onFocusSearch: ..., onShowHelp: ...,
          child: AppShell(navigationShell: navigationShell),
        ),
      );
    });
  },
  branches: [...],
)
```

### Klavye Kısayolları (AppShortcuts)

| Kısayol | Aksiyon |
|---------|---------|
| `Ctrl/Cmd + Z` | Undo (metin alanı dışında) |
| `Ctrl/Cmd + Shift + Z` | Redo (metin alanı dışında) |
| `Ctrl/Cmd + S` | Export ZIP |
| `Ctrl/Cmd + E` | Export ZIP |
| `Ctrl/Cmd + F` | Arama alanına focus |
| `?` | Kısayollar yardım dialogu (metin alanı dışında) |

Metin alanı aktifken undo/redo/? kısayolları bastırılır (native text editing korunur).

### BeforeUnloadGuard

Unsaved changes varken tarayıcı sekmesini kapatmaya çalışıldığında native `beforeunload` dialogu gösterilir.

- `StatefulShellRoute.indexedStack` ile her branch kendi state'ini korur
- `NavigationRail.onDestinationSelected` → `navigationShell.goBranch(index)`
- `labelType: NavigationRailLabelType.all` — tüm etiketler her zaman görünür

## Ekran Detayları

### DashboardScreen (`screens/dashboard/dashboard_screen.dart`)

Ana sayfa. İçerik durumunu özetler ve import/export işlemlerini başlatır.

**Gösterilen bilgiler:**
- Aggregate sayı kartları (Series, Books, Levels, Questions)
- Health Score (dairesel ilerleme göstergesi, %0–100)
- Boş state uyarısı (içerik yüklenmemişse)
- Kritik hatalar özeti (ilk 5 error)

**Kullanıcı etkileşimleri:**
- "Import" butonu → file_picker ile ZIP/JSON seçimi → `ZipImporter` → state güncelleme
- "Export ZIP" butonu → `ZipExporter` → tarayıcı indirme
- "Validate All" butonu → `/validation` sayfasına yönlendirme

**Kullandığı provider'lar:**
- `totalCountsProvider` — Aggregate sayılar
- `healthScoreProvider` — Sağlık skoru
- `validationErrorsProvider` — Error listesi
- `contentStateProvider` — Import/export için state erişimi

---

### ContentExplorerScreen (`screens/explorer/content_explorer_screen.dart`)

Master-detail layout ile içerik ağacını görüntüler ve düzenler.

**Layout:**
```
Column
├── Toolbar (undo, redo, unsaved indicator, bulk add, JSON preview toggle)
└── Row
    ├── TreePanel (sol, resizable 200-600px) — Hiyerarşik ağaç + arama + drag-drop
    ├── Resizable Divider (sürüklenebilir)
    ├── EditPanel (orta, Expanded) — Seçili öğenin düzenleme formu
    └── JsonPreviewPanel (sağ, 300px, opsiyonel) — Seçili öğenin JSON çıktısı
```

**Toolbar özellikleri:**
- Undo/Redo butonları (canUndo/canRedo durumuna göre aktif/pasif)
- Unsaved changes göstergesi (turuncu nokta + metin)
- "Bulk Add Questions" butonu (sadece level seçiliyken görünür)
- JSON Preview toggle butonu

**Arama:**
- TreePanel üstünde arama alanı (Ctrl+F ile focus)
- Türkçe-duyarlı case-insensitive arama
- Sadece eşleşen öğeler ve ataları gösterilir
- Eşleşen öğeler highlight edilir (bold + primary color)

**Drag & Drop:**
- Arama kapalıyken seri, kitap ve level'lar sürüklenebilir
- Drag handle (≡) ile sıralama değiştirme
- Arama aktifken drag devre dışı

**Kullanıcı etkileşimleri:**
- Ağaçta öğe seçimi → sağ panelde form açılır
- Form üzerinden CRUD işlemleri (history push ile undo desteği)
- Sıralama değiştirme (drag-drop)
- Toplu soru ekleme (Bulk Add)
- JSON preview görüntüleme
- Panel genişliği ayarlama (divider sürükleme)

**SelectedItem sealed class:**
```dart
sealed class SelectedItem {}
class SelectedSeries extends SelectedItem { final int seriesId; }
class SelectedBook extends SelectedItem { final int bookId; }
class SelectedLevel extends SelectedItem { final String contentFile; final int levelId; }
class SelectedQuestion extends SelectedItem { final String contentFile; final int levelId; final int questionIndex; }
```

**Kullandığı provider'lar:**
- `contentStateProvider` — CRUD işlemleri
- `historyProvider` — Undo/redo
- `canUndoProvider`, `canRedoProvider` — Buton durumları
- `isDirtyProvider` — Unsaved indicator
- `jsonPreviewVisibleProvider` — JSON panel toggle
- `searchQueryProvider`, `searchResultProvider` — Arama
- `searchFocusNodeProvider` — Ctrl+F focus
- `allSeriesProvider` — Sıralı seri listesi
- `booksForSeriesProvider(seriesId)` — Seri bazlı kitaplar
- `levelsForBookProvider(contentFile)` — Kitap bazlı level'lar

---

### RewardsScreen (`screens/rewards/rewards_screen.dart`)

Ödül rozetlerinin listesi ve CRUD yönetimi.

**Gösterilen bilgiler:**
- Ödül listesi (title, description, asset_image, unlock_book_id)
- Toplam ödül sayısı

**Kullanıcı etkileşimleri:**
- Yeni ödül ekleme
- Mevcut ödülü düzenleme
- Ödül silme

**Kullandığı provider'lar:**
- `contentStateProvider` — Reward CRUD işlemleri

---

### HadithsScreen (`screens/hadiths/hadiths_screen.dart`)

Hadis listesi ve CRUD yönetimi.

**Gösterilen bilgiler:**
- Hadis listesi (text, source)
- Toplam hadis sayısı

**Kullanıcı etkileşimleri:**
- Yeni hadis ekleme
- Mevcut hadisi düzenleme
- Hadis silme

**Kullandığı provider'lar:**
- `contentStateProvider` — Hadith CRUD işlemleri

---

### ValidationReportScreen (`screens/validation/validation_report_screen.dart`)

Tüm validasyon sonuçlarını detaylı gösterir.

**Gösterilen bilgiler:**
- Error bölümü: Kırmızı ikonlu error listesi
- Warning bölümü: Turuncu ikonlu warning listesi
- Her issue: sourceFile, jsonPath, message
- Toplam error/warning sayıları

**Kullanıcı etkileşimleri:**
- Hata detaylarını inceleme
- JSON path ile sorunlu alanı bulma

**Kullandığı provider'lar:**
- `validationErrorsProvider` — Error-level issue'lar
- `validationWarningsProvider` — Warning-level issue'lar
- `healthScoreProvider` — Genel sağlık skoru
