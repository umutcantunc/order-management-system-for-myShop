TUNC APP - DAĞITIM KLASÖRLERİ
================================

Bu klasörde Android ve iOS kullanıcıları için hazır dağıtım klasörleri bulunmaktadır.

📱 ANDROID KULLANICILARI İÇİN:
--------------------------------
1. "Android_Dagitim" klasörüne gidin
2. "tunc_app.apk" dosyasını WhatsApp üzerinden paylaşın
3. Kullanıcılar dosyayı indirip kurabilir
4. Detaylı kurulum talimatları: Android_Dagitim/OKU_BENI.txt

🍎 iOS KULLANICILARI İÇİN:
---------------------------
1. "iOS_Dagitim" klasörüne gidin
2. TestFlight kullanarak dağıtım yapın (önerilen)
3. VEYA Mac bilgisayarda .ipa dosyası oluşturup paylaşın
4. Detaylı kurulum talimatları: iOS_Dagitim/OKU_BENI.txt

NOT: iOS için .ipa dosyası oluşturmak için Mac bilgisayar ve Xcode gereklidir.
Windows'ta iOS build yapılamaz.

YENİ SÜRÜM OLUŞTURMA:
---------------------
Android için:
  flutter build apk --release
  Oluşan APK: build/app/outputs/flutter-apk/app-release.apk
  Bu dosyayı Android_Dagitim klasörüne kopyalayın

iOS için (Mac'te):
  flutter build ipa --release
  Oluşan IPA: build/ios/ipa/tunc_app.ipa
  Bu dosyayı iOS_Dagitim klasörüne kopyalayın

Son Güncelleme: ${DateTime.now().toString().split(' ')[0]}
