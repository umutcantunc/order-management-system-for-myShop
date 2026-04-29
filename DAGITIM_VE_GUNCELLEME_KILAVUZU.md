# 📱 Uygulama Dağıtım ve Güncelleme Kılavuzu

## 🎯 Genel Bakış

Bu uygulama hem **Android** hem de **iOS** cihazlarda çalışır. Personellere uygulamayı dağıtmanın ve güncellemeleri yayınlamanın birkaç yolu vardır.

---

## 📦 İLK DAĞITIM: Uygulamayı Personellere Paylaşma

### Seçenek 1: Google Play Store (Android) ve App Store (iOS) - ÖNERİLEN ✅

**Avantajlar:**
- Otomatik güncellemeler
- Güvenli dağıtım
- Kolay yönetim
- Kullanıcılar için en kolay yöntem

**Dezavantajlar:**
- Google Play Store: $25 tek seferlik ücret
- App Store: $99/yıl ücret
- Onay süreci (1-3 gün)

#### Android için Google Play Store:

1. **Google Play Console hesabı oluşturun** (https://play.google.com/console)
2. **Uygulamayı hazırlayın:**
   ```bash
   flutter build appbundle --release
   ```
   Dosya: `build/app/outputs/bundle/release/app-release.aab`

3. **Google Play Console'da:**
   - Yeni uygulama oluşturun
   - Uygulama detaylarını doldurun
   - AAB dosyasını yükleyin
   - İnceleme için gönderin

4. **Personellere link paylaşın:**
   - Uygulama yayınlandıktan sonra Play Store linkini paylaşın
   - Personeller Play Store'dan indirebilir

#### iOS için App Store:

1. **Apple Developer hesabı oluşturun** (https://developer.apple.com) - $99/yıl
2. **Uygulamayı hazırlayın:**
   ```bash
   flutter build ipa --release
   ```
   Dosya: `build/ios/ipa/tunc_app.ipa`

3. **Xcode ile yükleyin:**
   - Xcode'u açın
   - Window → Organizer → Archives
   - IPA'yı App Store Connect'e yükleyin

4. **App Store Connect'te:**
   - Uygulama bilgilerini doldurun
   - İnceleme için gönderin

---

### Seçenek 2: Direct Distribution (Doğrudan Dağıtım) - Hızlı Başlangıç 🚀

**Avantajlar:**
- Ücretsiz
- Hızlı dağıtım
- Store onayı gerekmez

**Dezavantajlar:**
- Android: "Bilinmeyen kaynaklardan yükleme" izni gerekir
- iOS: TestFlight veya Enterprise sertifikası gerekir
- Manuel güncelleme yönetimi

#### Android için Direct APK Dağıtımı:

1. **APK oluşturun:**
   ```bash
   flutter build apk --release
   ```
   Dosya: `build/app/outputs/flutter-apk/app-release.apk`

2. **Dağıtım yöntemleri:**
   - **E-posta:** APK'yı e-posta ile gönderin
   - **WhatsApp:** APK'yı WhatsApp ile paylaşın
   - **Firebase Storage:** APK'yı Firebase Storage'a yükleyip link paylaşın
   - **Web sitesi:** Kendi web sitenizde indirme linki oluşturun

3. **Personeller için talimatlar:**
   ```
   1. APK dosyasını indirin
   2. Ayarlar → Güvenlik → Bilinmeyen kaynaklardan uygulama yükleme → AÇIK
   3. İndirilen APK'ya tıklayın
   4. "Yükle" butonuna tıklayın
   5. Uygulama yüklenecek
   ```

#### iOS için Direct Distribution:

**Seçenek A: TestFlight (ÖNERİLEN)**
1. **Apple Developer hesabı gerekli** ($99/yıl)
2. **TestFlight'a yükleyin:**
   ```bash
   flutter build ipa --release
   ```
3. **App Store Connect → TestFlight** bölümünden beta testçiler ekleyin
4. Personellere TestFlight linki gönderin

**Seçenek B: Enterprise Distribution**
- Şirket içi dağıtım için Enterprise sertifikası gerekir ($299/yıl)
- Daha karmaşık kurulum

---

## 🔄 GÜNCELLEME SİSTEMİ: Yeni Versiyonları Yayınlama

Uygulamanızda **otomatik güncelleme sistemi** mevcuttur. Bu sistem hem Android hem iOS için çalışır.

### Admin Paneli Üzerinden Güncelleme Yayınlama

1. **Yeni versiyonu hazırlayın:**
   ```bash
   # pubspec.yaml'da versiyonu güncelleyin
   version: 1.0.1+2  # 1.0.1 = versiyon numarası, +2 = build numarası
   
   # Android için
   flutter build apk --release
   
   # iOS için
   flutter build ipa --release
   ```

2. **Admin Paneli → Versiyon Yönetimi:**
   - Uygulamada: **Özet** → **⚙️ Ayarlar** → **Versiyon Yönetimi**
   - Veya: **Admin Dashboard** → **Versiyon Yönetimi** (eğer menüde varsa)

3. **Versiyon bilgilerini girin:**
   - **En Son Versiyon:** `1.0.1`
   - **Minimum Versiyon:** `1.0.0` (eski versiyonlar çalışmaya devam eder)
   - **Zorunlu Güncelleme:** Açık/Kapalı
   - **Güncelleme Mesajı:** "Yeni özellikler eklendi, hatalar düzeltildi"

4. **APK/IPA yükleyin:**
   - **Android:** APK dosyasını seçin ve Firebase Storage'a yükleyin
   - **iOS:** IPA dosyasını seçin ve Firebase Storage'a yükleyin
   - Sistem otomatik olarak `storage_path` oluşturur

5. **Kaydet** butonuna tıklayın

### Personeller Otomatik Güncelleme Alır

1. **Personel uygulamayı açtığında:**
   - Sistem otomatik olarak Firebase'den versiyon kontrolü yapar
   - Yeni versiyon varsa **"Güncelleme Mevcut"** dialogu gösterilir

2. **Güncelleme dialogu:**
   - Mevcut versiyon ve yeni versiyon gösterilir
   - Güncelleme mesajı gösterilir
   - **"Güncelle"** butonuna tıklanır

3. **Otomatik indirme ve yükleme:**
   - APK/IPA Firebase Storage'dan indirilir
   - İndirme tamamlandığında yükleme ekranı açılır
   - Personel **"Yükle"** butonuna tıklar
   - Uygulama güncellenir

### Zorunlu Güncelleme

- Admin **"Zorunlu Güncelleme"** açarsa:
  - Dialog kapatılamaz
  - Personel güncellemeyi yapmak zorundadır
  - Eski versiyonla uygulama kullanılamaz

---

## 📋 ADIM ADIM DAĞITIM REHBERİ

### İlk Kurulum (Android)

1. **APK oluşturun:**
   ```bash
   cd c:\tunc_app
   flutter clean
   flutter pub get
   flutter build apk --release
   ```

2. **APK'yı paylaşın:**
   - E-posta, WhatsApp veya Firebase Storage linki ile

3. **Personellere talimatlar:**
   ```
   📱 Uygulamayı İndirme ve Kurma:
   
   1. APK dosyasını indirin
   2. Telefonunuzda:
      Ayarlar → Güvenlik → Bilinmeyen kaynaklardan uygulama yükleme → AÇIK
   3. İndirilen APK dosyasına tıklayın
   4. "Yükle" butonuna tıklayın
   5. Kurulum tamamlandığında "Aç" butonuna tıklayın
   6. Firebase hesabınızla giriş yapın
   ```

### İlk Kurulum (iOS)

1. **IPA oluşturun:**
   ```bash
   cd c:\tunc_app
   flutter clean
   flutter pub get
   flutter build ipa --release
   ```

2. **TestFlight'a yükleyin:**
   - Xcode → Window → Organizer → Archives
   - "Distribute App" → "App Store Connect"
   - TestFlight'a yükleyin

3. **Personellere TestFlight linki gönderin**

---

## 🔧 GÜNCELLEME YAYINLAMA ADIMLARI

### Her Güncelleme İçin:

1. **Kodu güncelleyin ve test edin**

2. **Versiyon numarasını artırın** (`pubspec.yaml`):
   ```yaml
   version: 1.0.2+3  # Küçük güncelleme
   # veya
   version: 1.1.0+1  # Yeni özellik
   # veya
   version: 2.0.0+1  # Büyük güncelleme
   ```

3. **Build alın:**
   ```bash
   # Android
   flutter build apk --release
   
   # iOS
   flutter build ipa --release
   ```

4. **Admin Paneli → Versiyon Yönetimi:**
   - Yeni versiyon numarasını girin
   - APK/IPA yükleyin
   - Güncelleme mesajı yazın
   - Zorunlu güncelleme aç/kapat
   - Kaydet

5. **Personeller otomatik bildirim alır:**
   - Uygulamayı açtıklarında güncelleme dialogu görünür
   - "Güncelle" butonuna tıklayarak güncellerler

---

## 🌐 Firebase Storage Yapılandırması

### Storage Rules (Firebase Console → Storage → Rules):

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // APK/IPA dosyaları herkese açık (okuma için)
    match /apk/{fileName} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    
    match /ipa/{fileName} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    
    // Diğer dosyalar (fotoğraflar, çizimler)
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

## 📊 Versiyon Numaralandırma Stratejisi

### Semantic Versioning (SemVer):

- **Major (X.0.0):** Büyük değişiklikler, geriye dönük uyumsuzluk
- **Minor (0.X.0):** Yeni özellikler, geriye dönük uyumlu
- **Patch (0.0.X):** Hata düzeltmeleri, küçük iyileştirmeler

**Örnekler:**
- `1.0.0` → `1.0.1`: Hata düzeltmesi
- `1.0.1` → `1.1.0`: Yeni özellik eklendi
- `1.1.0` → `2.0.0`: Büyük değişiklik

---

## 🛠️ Sorun Giderme

### Android APK Yüklenemiyor:

1. **"Bilinmeyen kaynaklardan yükleme" izni verildi mi?**
   - Ayarlar → Güvenlik → Bilinmeyen kaynaklardan uygulama yükleme

2. **APK bozuk mu?**
   - Yeniden build alın: `flutter clean && flutter build apk --release`

3. **Eski versiyon kaldırıldı mı?**
   - Eski uygulamayı kaldırıp yeniden yükleyin

### iOS IPA Yüklenemiyor:

1. **TestFlight kullanıyorsanız:**
   - TestFlight uygulaması yüklü mü?
   - TestFlight linkine doğru erişiliyor mu?

2. **Enterprise Distribution:**
   - Sertifika geçerli mi?
   - Provisioning profile doğru mu?

### Güncelleme Dialogu Gözükmüyor:

1. **Firebase'de versiyon bilgisi var mı?**
   - Firebase Console → Firestore → `app_config` → `app_version_config`

2. **Versiyon numarası doğru mu?**
   - `latest_version` mevcut versiyondan büyük olmalı

3. **Uygulamayı yeniden başlatın**

---

## 📞 Destek ve İletişim

- **Firebase Console:** https://console.firebase.google.com
- **Google Play Console:** https://play.google.com/console
- **App Store Connect:** https://appstoreconnect.apple.com

---

## ✅ ÖNERİLEN YAKLAŞIM

**Küçük işletmeler için:**
1. **Android:** Direct APK dağıtımı + Otomatik güncelleme sistemi
2. **iOS:** TestFlight (Apple Developer hesabı gerekli)

**Büyük işletmeler için:**
1. **Android:** Google Play Store (Internal Testing veya Production)
2. **iOS:** App Store veya Enterprise Distribution

**Hibrit Yaklaşım:**
- İlk dağıtım: Direct APK/IPA
- Sonraki güncellemeler: Otomatik güncelleme sistemi üzerinden

---

## 🎯 HIZLI BAŞLANGIÇ CHECKLIST

- [ ] APK/IPA build alındı
- [ ] Firebase Storage'a yüklendi
- [ ] Versiyon bilgileri Firebase'e kaydedildi
- [ ] Personellere dağıtım linki gönderildi
- [ ] Personellere kurulum talimatları verildi
- [ ] İlk kurulum başarılı mı test edildi
- [ ] Güncelleme sistemi çalışıyor mu test edildi

---

**Son Güncelleme:** 2024
**Versiyon:** 1.0.0
