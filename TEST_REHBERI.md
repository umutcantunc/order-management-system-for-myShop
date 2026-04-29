# Tunç Nur Branda - Uygulama Test Rehberi

## 📱 Uygulamayı Telefona Yükleme ve Test Etme

### Yöntem 1: USB ile Direkt Çalıştırma (En Kolay)

1. **Telefonu USB ile Bilgisayara Bağlayın**
   - USB kablosunu takın
   - Telefonda "USB hata ayıklama" seçeneğini etkinleştirin
   - İzin istenirse "İzin ver" deyin

2. **Terminal'de Şu Komutu Çalıştırın:**
   ```
   flutter run -d R5CW20CS7NT
   ```

3. **Uygulama Otomatik Olarak:**
   - Telefonunuza yüklenecek
   - Açılacak
   - Çalışmaya başlayacak

### Yöntem 2: APK Dosyası Oluşturup Yükleme

1. **APK Dosyası Oluşturun:**
   ```
   flutter build apk --debug
   ```
   
   Bu komut `build/app/outputs/flutter-apk/app-debug.apk` dosyasını oluşturur.

2. **APK'yı Telefona Aktarın:**
   - APK dosyasını telefonunuza kopyalayın (USB, email, cloud vs.)
   - Telefonda dosya yöneticisinde APK'ya tıklayın
   - "Bilinmeyen kaynaklardan yükleme" izni verin
   - Kurulumu tamamlayın

### Yöntem 3: Release Versiyonu (Production İçin)

```
flutter build apk --release
```

Release APK dosyası: `build/app/outputs/flutter-apk/app-release.apk`

## 🔄 Kod Değişikliği Yaptıktan Sonra

### Hot Reload (Hızlı Güncelleme)
- Uygulama çalışırken terminalde `r` tuşuna basın
- Değişiklikler anında uygulamada görünür

### Hot Restart (Yeniden Başlat)
- Terminalde `R` tuşuna basın
- Uygulama yeniden başlar

### Tam Yeniden Build
- `Ctrl+C` ile durdurun
- Tekrar `flutter run -d R5CW20CS7NT` çalıştırın

## 📊 Uygulama Logları ve Hataları Görmek

Uygulama çalışırken terminalde tüm loglar görünecektir:
- Debug mesajları
- Hata mesajları
- Firebase bağlantı durumu

## ✅ Test Checklist

### İlk Açılış
- [ ] Splash screen görünüyor mu?
- [ ] Logo görünüyor mu?
- [ ] Login ekranı açılıyor mu?

### Giriş
- [ ] Admin olarak giriş yapabiliyor musunuz?
- [ ] Personel olarak giriş yapabiliyor musunuz?
- [ ] "Beni Hatırla" çalışıyor mu?

### Admin Özellikleri
- [ ] Personel listesini görebiliyor musunuz?
- [ ] Yeni personel ekleyebiliyor musunuz?
- [ ] Siparişleri görebiliyor musunuz?
- [ ] Personel takvimini görebiliyor musunuz?

### Personel Özellikleri
- [ ] Mesai başlat/durdur çalışıyor mu?
- [ ] Avans talep edebiliyor musunuz?
- [ ] Takvimde kendi verilerinizi görebiliyor musunuz?
- [ ] İş listesini görebiliyor musunuz?

## 🐛 Sorun Giderme

### Uygulama Açılmıyor
1. Telefonu yeniden bağlayın
2. `flutter clean` çalıştırın
3. `flutter pub get` çalıştırın
4. `flutter run -d R5CW20CS7NT` tekrar deneyin

### Build Hatası
1. `flutter doctor` ile sorunları kontrol edin
2. `flutter clean` çalıştırın
3. Telefonu yeniden bağlayın

### Firebase Hatası
- İnternet bağlantınızı kontrol edin
- Firebase Console'da projenin aktif olduğundan emin olun

## 📝 Önemli Notlar

- **İlk Build Uzun Sürer**: İlk kez build ederken 5-10 dakika sürebilir
- **Sonraki Build'ler Hızlı**: İkinci build'den sonra 1-2 dakika sürer
- **Hot Reload Hızlı**: Kod değişikliğinde sadece `r` tuşuna basın, 1-2 saniye sürer

## 🚀 Uygulamayı Dağıtma

1. Release APK oluşturun: `flutter build apk --release`
2. APK dosyasını `build/app/outputs/flutter-apk/app-release.apk` konumundan alın
3. APK'yı paylaşın veya Google Play Store'a yükleyin
