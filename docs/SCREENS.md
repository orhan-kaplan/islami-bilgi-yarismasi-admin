# Ekranlar ve Navigasyon (Screens)

## Ana Navigasyon Yapısı

`AppShell` (`lib/presentation/router/app_router.dart`) uygulamanın ana iskeletidir. Sol tarafta `NavigationRail`, sağ tarafta aktif ekran gösterilir.

```
AppShell (Scaffold + Row) — ConsumerStatefulWidget
├── NavigationRail (sol panel)
│   ├── leading: Connectivity indicator (yeşil/kırmızı nokta)
│   ├── Tab 0: Dashboard     (Home)
│   ├── Tab 1: Explorer      (Content Explorer)
│   ├── Tab 2: Rewards       (Ödüller)
│   ├── Tab 3: Hadiths       (Hadisler)
│   ├── Tab 4: Assets        (Asset Yönetimi)
│   ├── Tab 5: Feedback     (Mesajlar)
│   ├── Tab 6: Oyun         (game_config.json)
│   ├── Tab 7: Validation   (Validasyon Raporu)
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
| `Ctrl/Cmd + S` | Server bağlıysa: Flush pending saves / Bağlı değilse: Export ZIP |
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
- Health Score (dairesel ilerleme göstergesi, %0–100) + skoru düşüren
  error/warning sayısı ("2 errors · 5 warnings need attention")
- Auto-load durumu (loading banner, failed banner with retry). Failed banner
  hatanın kendisini de gösterir; `/api/health` cevap verdiyse "sunucuyu başlat"
  komutu yerine bozuk dosyayı bildirir (`autoLoadErrorProvider`)
- Boş state uyarısı — `ContentState.hasAnyContent` false iken (hadis/ödül de
  içerik sayılır) ve auto-load sürerken gösterilmez
- Kritik hatalar özeti (ilk 5 error) — **yalnızca error varken**; satırlar ve
  "... and N more" tıklanınca `/validation`'a gider

**Kullanıcı etkileşimleri:**
- "Import" butonu → file_picker ile ZIP/JSON seçimi → `ZipImporter` → state güncelleme
  - ERROR seviyesinde import issue varsa hiçbir şey uygulanmaz ("Import Blocked")
  - Kaydedilmemiş değişiklik varsa önce onay sorulur: import mevcut state'i ezer
    **ve** undo geçmişini temizler, iptal edilirse hiçbir şey değişmez
  - Okunamayan dosya / desteklenmeyen tür / birden çok ZIP seçimi sessizce
    düşmez: SnackBar ya da "Import Issues" listesinde bildirilir
  - Sonuçta hangi dosyaların değiştiği ve undo geçmişinin silindiği söylenir
  - Auto-load sürerken devre dışı (biten yükleme ile yarışmasın)
- "Export ZIP" butonu → `zipExporterProvider` → tarayıcı indirme
  - İçerik yokken devre dışı, sebebi tooltip'te
  - ZIP indirmesi sunucuya yazmaz: yalnız **bağlı değilken** saved baseline'ı
    ilerletir, aksi halde dirty göstergesi susardı
  - Validation dışı hatalar "Export Failed" dialogunda gösterilir
- "Validate All" butonu → `/validation` sayfasına yönlendirme
- "Retry" butonu (auto-load başarısız olduğunda) → `performAutoLoad()` tekrar dener

**Kullandığı provider'lar:**
- `autoLoadProvider` / `autoLoadErrorProvider` — Auto-load durumu ve hata detayı
- `totalCountsProvider` — Aggregate sayılar
- `healthScoreProvider` — Sağlık skoru
- `validationErrorsProvider` / `validationWarningsProvider` — Sorun listeleri
- `contentStateProvider` — Import/export için state erişimi
- `zipExporterProvider` — Export servisi

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
- Unsaved changes göstergesi (turuncu nokta + metin) — yalnızca dirty iken
- "Değişiklikler" butonu (yalnızca dirty iken) → `changelogProvider`'ı listeleyen dialog
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

**Silme (edit modundaki formların başlığında kırmızı çöp kutusu):**

| Form | Tooltip | Guard |
|------|---------|-------|
| SeriesForm | `Delete series` | Kitabı varsa bloklanır, gerekçe snackbar'da |
| BookForm | `Delete book` | Level'ı varsa **veya** bir ödül onu açıyorsa bloklanır |
| LevelForm | `Delete level (cascades to questions)` | Guard yok; kalan level'lar 1..N yeniden numaralanır |
| QuestionForm | `Delete question` | Guard yok |

- Hepsi `ConfirmDialog` ile onay ister; iptal edilirse state'e de geçmişe de dokunulmaz.
- Guard bloklarsa undo yığınına hiçbir şey yazılmaz.
- Silme başarılıysa `_selectedItem` temizlenir ve panel "Select an item to edit"e
  döner — aksi halde EditPanel aynı `ValueKey`'i koruyup form State'ini yeniden
  kullanıyor, silinen kayıt eski değerleriyle dolu bir "create" formuna dönüşüyordu.
- Create modundaki formlarda silme butonu yoktur.

**Formların kaydı bloklayan içeriği engellemesi:**
- `MultipleChoiceForm`: Option C/D zorunlu değil, ama boş bir şıkkı `correct_option`
  olarak seçmek reddedilir — bkz. VALIDATION_RULES.md kural 20.
- `LevelForm` / `BookForm`: inline görsel seçici, yüklemeden sonra ContentState'e
  yazmadan önce formu `validate()` eder. Form geçersizse görsel sunucuya yüklenmiştir
  ama modele işlenmez; kullanıcıya alanları düzeltip Save'e basması söylenir.
  (Eskiden validasyonsuz commit ediliyor, boş zorunlu alanlar diske gidiyordu.)

**SelectedItem sealed class:**
```dart
sealed class SelectedItem {}
// Mevcut öğe seçimi → EditPanel edit modunda form açar (silme butonu görünür)
class SelectedSeries extends SelectedItem { final int seriesId; }
class SelectedBook extends SelectedItem { final int bookId; }
class SelectedLevel extends SelectedItem { final String contentFile; final int levelId; }
class SelectedQuestion extends SelectedItem { final String contentFile; final int levelId; final int questionIndex; }
// Create tetikleyicileri → EditPanel boş form açar (silme butonu yok)
class CreateSeries extends SelectedItem {}
class CreateBook extends SelectedItem { final int seriesId; }
class CreateLevel extends SelectedItem { final String contentFile; final int bookId; }
class CreateQuestion extends SelectedItem { final String contentFile; final int levelId; }
```
`null` → panel "Select an item to edit" gösterir (başlangıç ve silme sonrası).
Ağaçtaki `+` butonları (Add Series / Add Book / Add Level / Add Question) ilgili
`Create*` variant'ını seçer.

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
- Ödül silme (onay dialogu; iptal edilirse geçmişe de yazılmaz)
- Ödül önizleme (telefon mockup'ı)

**Kullandığı provider'lar:**
- `contentStateProvider` — Reward CRUD işlemleri
- `historyProvider` — Ekleme/güncelleme/silme undo yığınına yazılır
- `isServerConnectedProvider` — Thumbnail'ları asset sunucudan çekmek için

---

### HadithsScreen (`screens/hadiths/hadiths_screen.dart`)

Hadis listesi ve CRUD yönetimi.

**Gösterilen bilgiler:**
- Hadis listesi (text, source)
- Toplam hadis sayısı

**Kullanıcı etkileşimleri:**
- Yeni hadis ekleme (popup: Hadith, Source, Cancel, Save)
- Mevcut hadisi düzenleme (aynı popup)
- Hadis silme (onay dialogu; iptal edilirse geçmişe de yazılmaz)
- Hadis önizleme (telefon mockup'ı)

**Kullandığı provider'lar:**
- `contentStateProvider` — Hadith CRUD işlemleri
- `historyProvider` — Ekleme/güncelleme/silme undo yığınına yazılır

---

### AssetsScreen (`screens/assets/assets_screen.dart`)

Asset dosyalarını (görseller, ses, Lottie animasyonlar, ikonlar) görsel olarak yönetir.

**Layout:**
```
Scaffold
├── AppBar (title: "Assets")
│   └── TabBar (Images, Audio, Lottie, Icons)
└── TabBarView
    ├── ImagesTab — Klasör sidebar + görsel grid
    ├── AudioTab — Ses dosyaları listesi + oynatma
    ├── LottieTab — Animasyon önizleme kartları
    └── IconsTab — İkon grid
```

**Images Tab (`images_tab.dart`):**
- Sol sidebar: `images/` altındaki klasörleri listeler (natural sort)
- Sağ grid: Seçili klasördeki görselleri thumbnail olarak gösterir (natural sort)
- Her kart: Thumbnail, dosya adı, boyut, Replace/Delete butonları
- "Add New Image" butonu → file_picker → server'a upload
- "New Folder" butonu → klasör adı dialogu → server'da oluşturma
- Delete: Referans kontrolü → referanslıysa blokla, değilse onay al

**Audio Tab (`audio_tab.dart`):**
- Ses dosyaları listesi (filename, boyut, play/pause, Replace, Delete)
- Browser audio playback (HTMLAudioElement via `package:web`)
- "Add New Audio" butonu

**Lottie Tab (`lottie_tab.dart`):**
- İki bölüm: Root level (`lottie/`) ve Feedback (`lottie/feedback/`)
- Canlı animasyon önizleme kartları (`Lottie.network()`)
- Kart tıklama → büyük önizleme dialogu (Replace/Delete)
- Upload öncesi Lottie yapı doğrulama (v, layers, w, h alanları)

**Icons Tab (`icons_tab.dart`):**
- İkon grid (thumbnail, dosya adı, Replace/Delete)
- "Add New Icon" butonu

**Kullandığı provider'lar:**
- `assetListProvider(path)` — Dizin listeleme (FutureProvider.family)
- `assetServerClientProvider` — HTTP işlemleri
- `contentStateProvider` — Referans kontrolü için
- `isServerConnectedProvider` — Bağlantı durumu

---

### FeedbackScreen (`screens/feedback/feedback_screen.dart`)

Feedback mesajlarının yönetimi. Kategorilere göre tab'lı yapı.

**Layout:**
```
Scaffold
├── AppBar (title: "Feedback", search icon)
│   └── TabBar (Quiz, Speed Quiz, Time, Comeback, Streak, Titles, Learned)
└── TabBarView
    ├── Quiz — Subcategory accordion + mesaj kartları
    ├── Speed Quiz — Subcategory accordion + mesaj kartları
    ├── Time — Subcategory accordion + mesaj kartları
    ├── Comeback — Düz mesaj listesi + FAB
    ├── Streak — Subcategory accordion + mesaj kartları
    ├── Titles — Ünvan kartları + FAB
    └── Learned — Subcategory accordion + mesaj kartları
```

**Önizleme Diyaloğu (`FeedbackPreviewDialog`):**
- Telefon mockup çerçevesi içinde feedback mesajının mobil görünümü
- Ekran bağlamı kategoriye göre **otomatik** belirlenir (tab seçimi yok):
  - quiz, speed_quiz → QuizResultPreview
  - time, comeback, streak → DashboardPreview
  - learned → LearnedQuizResultPreview
- "Cihazda Test Et" butonu: Asset sunucu bağlıysa aktif, preview'ı emülatöre gönderir
- Asset sunucu bağlı değilse uyarı banner'ı gösterilir

**Mesaj Ekleme/İptal Davranışı:**
- "+" butonu → boş mesaj oluşturulur ve edit modunda açılır
- İptal edilirse → boş mesaj listeden kaldırılır (hiçbir şey oluşmaz)
- Mevcut mesaj düzenlenip iptal edilirse → eski hali korunur

**Kullandığı provider'lar:**
- `feedbackContentProvider` — Feedback CRUD işlemleri
- `feedbackAutoSaveProvider` — Otomatik kaydetme
- `gameConfigProvider` — Eşik / saat dilimi etiketleri (salt okunur)

Streak sekmeleri `feedback.json` anahtarlarından üretilir (`3 gün serisi`); 3/7/30 zorunlu değildir. Bant ekleme FAB'ı yoktur.

---

### GameConfigScreen (`screens/game_config/game_config_screen.dart`)

`data/game_config.json` düzenleme. ContentState'e karışmaz.

**Bölümler:** Quiz (can, puan, routing), Hızlı quiz süre/eşikler, öğrenilen bantlar, günlük hedef, saat dilimleri, lottie kısa yolları, copy.

Debounced auto-save (`data/game_config.json`). Validasyon hatası kaydı bloklar.

**Kullandığı provider'lar:**
- `gameConfigProvider`
- `gameConfigLoadProvider`
- `gameConfigAutoSaveProvider`

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
