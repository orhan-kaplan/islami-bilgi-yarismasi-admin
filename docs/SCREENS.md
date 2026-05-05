# Ekranlar ve Navigasyon (Screens)

## Ana Navigasyon Yapısı

`AppShell` (`lib/presentation/router/app_router.dart`) uygulamanın ana iskeletidir. Sol tarafta `NavigationRail`, sağ tarafta aktif ekran gösterilir.

```
AppShell (Scaffold + Row)
├── NavigationRail (sol panel)
│   ├── Tab 0: Dashboard     (Home)
│   ├── Tab 1: Explorer      (Content Explorer)
│   ├── Tab 2: Rewards       (Ödüller)
│   ├── Tab 3: Hadiths       (Hadisler)
│   └── Tab 4: Validation    (Validasyon Raporu)
└── Expanded (sağ panel — aktif ekran)
```

### go_router ile StatefulShellRoute

```dart
StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
  branches: [
    StatefulShellBranch(routes: [GoRoute(path: '/')]),           // Dashboard
    StatefulShellBranch(routes: [GoRoute(path: '/explorer')]),   // Explorer
    StatefulShellBranch(routes: [GoRoute(path: '/rewards')]),    // Rewards
    StatefulShellBranch(routes: [GoRoute(path: '/hadiths')]),    // Hadiths
    StatefulShellBranch(routes: [GoRoute(path: '/validation')]), // Validation
  ],
)
```

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
Row
├── TreePanel (sol, 300px) — Hiyerarşik ağaç: Series → Books → Levels → Questions
├── VerticalDivider
└── EditPanel (sağ, Expanded) — Seçili öğenin düzenleme formu
```

**Gösterilen bilgiler:**
- Sol panel: Genişletilebilir ağaç yapısı (series > books > levels > questions)
- Sağ panel: Seçili öğeye göre düzenleme formu

**Kullanıcı etkileşimleri:**
- Ağaçta öğe seçimi → sağ panelde form açılır
- Form üzerinden CRUD işlemleri
- Sıralama değiştirme (reorder)

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
