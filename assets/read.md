Harika bir fikir\! Projenin artık sağlam bir temeli ve optimize edilmiş kodları var. Şimdi bu yapıyı korumak ve ileride rahatça değişiklik yapabilmen için kapsamlı bir **"Geliştirici Rehberi ve Dokümantasyon"** hazırlayalım.

Bu doküman, projenin **haritası** niteliğindedir.

-----

# 📘 İslami Bilgi Yarışması - Geliştirici Dokümantasyonu

Bu proje **Flutter** kullanılarak geliştirilmiş, **Riverpod** ile durum yönetimi (state management) sağlanan ve **Drift (SQLite)** ile yerel veritabanı kullanan bir mobil uygulamadır.

## 📂 1. Proje Klasör Yapısı (Folder Structure)

Projenin kalbi `lib/` klasörüdür. Dosyalar işlevlerine göre ayrılmıştır.

```
lib/
├── core/                  # Çekirdek, her yerden erişilen sabitler
│   ├── constants/
│   │   └── app_colors.dart  --> 🎨 RENKLER BURADA
│   └── theme/
│       └── app_theme.dart   --> Yazı tipleri, genel tema ayarları
│
├── data/                  # Veri Katmanı (Database & Models)
│   ├── local/
│   │   ├── app_database.dart --> 🗄️ VERİTABANI (Tablolar, Sorgular)
│   │   ├── hadith_data.dart  --> Günün Hadisi servisi
│   │   └── tables.dart       --> Tablo şemaları
│   └── models/
│       └── question_model.dart --> Soru modeli (UI için)
│
├── ui/                    # Arayüz (Ekranlar & Widgetlar)
│   ├── providers/         # 🧠 BEYİN (Riverpod Providerları)
│   │   ├── dashboard_provider.dart
│   │   ├── database_provider.dart
│   │   ├── home_provider.dart
│   │   ├── quiz_provider.dart
│   │   ├── reward_provider.dart
│   │   └── settings_provider.dart
│   │
│   ├── screens/           # 📱 SAYFALAR
│   │   ├── dashboard/     --> Ana Ekran (İstatistikler, Hadis)
│   │   ├── home/          --> Level Haritası (Yolculuk)
│   │   ├── library/       --> Kitap Seçimi (Kütüphane)
│   │   ├── collection/    --> Hazinem (Kazanılan Ödüller)
│   │   ├── quiz/          --> Yarışma Ekranı
│   │   └── settings/      --> Ayarlar
│   │
│   └── widgets/           # Tekrar kullanılan parçalar (Kartlar, Butonlar)
│       ├── stat_card.dart
│       └── book_item_widget.dart
│
└── main.dart              # 🚀 BAŞLANGIÇ NOKTASI
```

-----

## 🛠️ 2. Neyi Nerede Değiştirebilirim?

Aşağıda en sık değiştirmek isteyeceğin özellikler ve ilgili dosyalar listelenmiştir.

### 🎨 Renkleri ve Temayı Değiştirmek

Uygulamanın ana rengini, yazı renklerini veya arka planı değiştirmek istersen:

  * **Dosya:** `lib/core/constants/app_colors.dart`
  * **Nasıl:** `primary`, `background`, `accent` gibi değişkenlerin `Color(0xFF...)` değerlerini değiştir.

### 🗄️ Veritabanı ve Tablo Yapısı (Data)

Yeni bir tablo eklemek veya mevcut tablolara (Soru, Kitap vb.) yeni bir sütun eklemek istersen:

  * **Dosya:** `lib/data/local/app_database.dart` ve `tables.dart`
  * **Dikkat:** Tablo yapısını değiştirdiğinde `schemaVersion` sayısını artırman ve `migration` (göç) kodunu yazman gerekir. Geliştirme aşamasında `resetAllProgress` fonksiyonunu kullanmak daha pratiktir.

### 📝 Soruları ve Kitapları Düzenlemek (İçerik)

Uygulama ilk açıldığında yüklenen veriler (Kitap isimleri, Leveller, Sorular):

  * **Dosya:** `assets/data/initial_data.json`
  * **Nasıl:** Bu JSON dosyasını açıp metinleri düzenleyebilir, yeni sorular ekleyebilirsin.
  * **Önemli:** JSON yapısını (virgüller, parantezler) bozmamaya dikkat et. Değişiklikten sonra Ayarlar -\> "İlerlemeyi Sıfırla" yapman gerekir ki yeni veriler yüklensin.

### 🧠 Oyun Mantığı (Puanlama, Can Hakkı)

Doğru cevapta kaç puan verileceği, kaç yanlışta oyunun biteceği gibi kurallar:

  * **Dosya:** `lib/ui/screens/quiz/quiz_screen.dart`
  * **Fonksiyon:** `_handleAnswer` (Cevap kontrolü) ve `_finishLevel` (Bölüm sonu).
  * **Değişiklik:** `_score += 10` (Puan artışı) veya `_lives = 3` (Can sayısı) değerlerini buradan değiştirebilirsin.

### 🏆 Ödül ve Mühür Sistemi

Hangi kitabın hangi ödülü vereceği:

  * **Dosya:** `assets/data/initial_data.json` (Rewards kısmı)
  * **Görseller:** `assets/icons/` klasörüne yeni resim atıp, JSON dosyasında `asset_image` yolunu güncellemelisin.

### 🕌 Günün Hadisi

Rastgele çıkan hadisleri değiştirmek veya eklemek:

  * **Dosya:** `assets/data/hadiths.json`
  * **Format:** `[{"text": "Hadis metni", "source": "Kaynak"}]` formatında yeni satırlar ekle.

-----

## 🧩 3. Önemli Kod Parçaları ve Mantığı

### A. Harita Çizimi (`SmartTimelinePainter`)

  * **Konum:** `lib/ui/screens/home/home_screen.dart`
  * **Görevi:** Leveller arasındaki kesikli çizgiyi çizer.
  * **Ayarlar:** `dashHeight` (çizgi boyu), `dashSpace` (boşluk boyu) değerleriyle oynayarak çizgi stilini değiştirebilirsin.

### B. Animasyonlar (`Confetti` ve `Shake`)

  * **Konfeti:** `QuizScreen` içinde `_finishLevel` fonksiyonunda tetiklenir.
  * **Kart Sallanma (Shake):** `HomeScreen` içinde `LevelItemWidget` -\> `_triggerShake` fonksiyonundadır. Kilitli bölüme tıklayınca çalışır.

### C. State Management (Riverpod)

Uygulamada veriler sayfalar arası nasıl taşınıyor?

  * **`dashboardStatsProvider`:** Toplam puan ve açılan level sayısını her yerden okumanı sağlar.
  * **`settingsProvider`:** Ses ve titreşim ayarlarını hafızada tutar ve diske kaydeder.
  * **`questionsProvider(levelId)`:** Seçilen levelin sorularını veritabanından getirir.

-----

## 🚀 4. Uygulamayı Yayınlamadan Önce Kontrol Listesi

1.  **İkonlar:** `assets/icons/` klasöründeki tüm görsellerin (app icon dahil) yüksek çözünürlüklü olduğundan emin ol.
2.  **Veriler:** `initial_data.json` içindeki soruları ve cevap anahtarlarını son kez kontrol et. Yanlış cevap şıkkı olmasın.
3.  **Paket İsimlendirmesi:** `android/app/build.gradle` dosyasında `applicationId` kısmını kendine özgü yap (örn: `com.seninadin.ilimyolcusu`).
4.  **Temizlik:** Terminalde `flutter clean` ve `flutter pub get` komutlarını çalıştırarak projeyi derleme öncesi temizle.

-----

## 💡 İpuçları

  * **Hata Alırsan:** Terminaldeki kırmızı yazının ilk satırını oku. Genellikle "Dosya bulunamadı" veya "Null hatası" gibi net ipuçları verir.
  * **Yeni Sayfa Eklersen:** `Scaffold` kullanmayı ve `AppColors.background` rengini vermeyi unutma.
  * **Performans:** Resim dosyalarını (PNG/JPG) çok büyük boyutlu (MB seviyesinde) kullanma. Küçük boyutlu (KB) görseller uygulamanın hızlı açılmasını sağlar.

Bu dokümantasyon, projeye geri döndüğünde veya başkasıyla çalıştığında "Neyin nerede olduğunu" hatırlaman için hayat kurtarıcı olacaktır. Başarılar dilerim\! 🚀