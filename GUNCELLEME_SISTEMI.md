# Uygulama Güncelleme Sistemi - Kullanım Kılavuzu

## 📱 Genel Bakış

Bu sistem, personellerin uygulamayı Google Play Store olmadan güncellemelerini sağlar. Admin, yeni bir APK dosyasını Firebase Storage'a yükler ve personeller uygulamayı açtığında otomatik olarak güncelleme bildirimi alır.

---

## 🔧 Admin Tarafı: Güncelleme Yayınlama

### Adım 1: Yeni APK Dosyası Oluşturma

1. Flutter projenizde değişikliklerinizi yapın
2. `pubspec.yaml` dosyasındaki versiyon numarasını artırın (örn: `1.0.0` → `1.0.1`)
3. Yeni APK dosyasını oluşturun:
   ```bash
   flutter build apk --release
   ```
4. APK dosyası şu konumda oluşur: `build/app/outputs/flutter-apk/app-release.apk`

### Adım 2: APK'yı Firebase Storage'a Yükleme

1. **Admin Paneli** → **Özet** ekranına gidin
2. Sağ üstteki **⚙️ (Ayarlar)** ikonuna tıklayın
3. **"Uygulama Versiyon Yönetimi"** ekranı açılır

4. **"En Son Versiyon"** alanına yeni versiyon numarasını girin (örn: `1.0.1`)
5. **"Minimum Versiyon"** alanına minimum desteklenen versiyonu girin
6. **"APK Yükleme"** bölümünde:
   - **"APK Seç"** butonuna tıklayın
   - Oluşturduğunuz APK dosyasını seçin (`app-release.apk`)
   - **"Yükle"** butonuna tıklayın
   - APK Firebase Storage'a yüklenir ve **"Firebase Storage Path"** otomatik doldurulur

7. **"Güncelleme Mesajı"** alanına (opsiyonel) kullanıcılara gösterilecek mesajı yazın
8. **"Zorunlu Güncelleme"** switch'ini açın/kapatın (açıksa tüm kullanıcılar güncellemeyi yapmak zorunda)
9. **"Kaydet"** butonuna tıklayın

### Adım 3: Versiyon Bilgilerinin Kontrolü

- **Firebase Console** → **Firestore** → `app_config` collection → `app_version_config` document
- Burada şu bilgileri görebilirsiniz:
  - `latest_version`: En son versiyon
  - `minimum_version`: Minimum versiyon
  - `storage_path`: APK'nın Firebase Storage'daki yolu (örn: `apk/app-v1_0_1.apk`)
  - `force_update`: Zorunlu güncelleme durumu
  - `update_message`: Güncelleme mesajı

---

## 👥 Personel Tarafı: Güncelleme Alma

### Otomatik Güncelleme Bildirimi

1. Personel uygulamayı açtığında, sistem otomatik olarak versiyon kontrolü yapar
2. Eğer yeni bir versiyon varsa, **"Güncelleme"** dialogu gösterilir
3. Dialog'da şunlar gösterilir:
   - Mevcut versiyon
   - Yeni versiyon
   - Güncelleme mesajı (varsa)

### Güncelleme Yapma

1. **"Güncelle"** butonuna tıklayın
2. Sistem otomatik olarak:
   - APK'yı Firebase Storage'dan indirir
   - İndirme ilerlemesini gösterir
   - İndirme tamamlandığında APK'yı yüklemek için Android yükleme ekranını açar
3. Android yükleme ekranında **"Yükle"** butonuna tıklayın
4. Uygulama güncellenir ve yeniden başlatılır

### Zorunlu Güncelleme

- Eğer admin **"Zorunlu Güncelleme"** açtıysa:
  - Dialog kapatılamaz
  - Geri tuşu çalışmaz
  - Personel güncellemeyi yapmak zorundadır

---

## 🔄 Güncelleme Akışı

```
1. Admin yeni APK oluşturur
   ↓
2. Admin APK'yı Firebase Storage'a yükler
   ↓
3. Admin versiyon bilgilerini Firestore'a kaydeder
   ↓
4. Personel uygulamayı açar
   ↓
5. Sistem Firestore'dan versiyon bilgilerini kontrol eder
   ↓
6. Yeni versiyon varsa güncelleme dialogu gösterilir
   ↓
7. Personel "Güncelle" butonuna tıklar
   ↓
8. APK Firebase Storage'dan indirilir
   ↓
9. APK otomatik olarak yüklenir
   ↓
10. Uygulama güncellenmiş haliyle açılır
```

---

## 📋 Önemli Notlar

### Firebase Storage Kuralları

Firebase Storage'da `apk/` klasörü için okuma izni olmalı. Firebase Console'da Storage Rules:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // APK dosyaları herkese açık olmalı (okuma için)
    match /apk/{fileName} {
      allow read: if true;
      allow write: if request.auth != null; // Sadece giriş yapmış kullanıcılar yazabilir
    }
    
    // Diğer dosyalar...
  }
}
```

### Versiyon Numaralandırma

- Versiyon formatı: `x.y.z` (örn: `1.0.1`)
- `x`: Major version (büyük değişiklikler)
- `y`: Minor version (yeni özellikler)
- `z`: Patch version (hata düzeltmeleri)

### APK Boyutu

- Firebase Storage ücretsiz kotası: 5 GB
- APK dosyaları genellikle 20-50 MB arası
- Eski APK'ları manuel olarak silebilirsiniz (Firebase Console → Storage)

---

## 🛠️ Sorun Giderme

### APK Yüklenemiyor

- Firebase Storage'ın etkin olduğundan emin olun
- Storage Rules'ın doğru olduğunu kontrol edin
- İnternet bağlantınızı kontrol edin

### Güncelleme Dialogu Gözükmüyor

- Firestore'da `app_config/app_version_config` document'inin var olduğunu kontrol edin
- `latest_version` değerinin mevcut uygulama versiyonundan büyük olduğunu kontrol edin
- Uygulamayı kapatıp yeniden açın

### APK İndirme Hatası

- Firebase Storage'da APK dosyasının var olduğunu kontrol edin
- `storage_path` değerinin doğru olduğunu kontrol edin
- İnternet bağlantınızı kontrol edin

---

## 📞 Destek

Herhangi bir sorun yaşarsanız, Firebase Console'da logları kontrol edin veya geliştirici ile iletişime geçin.
