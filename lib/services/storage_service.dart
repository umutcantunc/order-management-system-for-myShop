import 'dart:io' if (dart.library.html) 'dart:html' as io;
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' show File;

class StorageService {
  bool get isAvailable => Firebase.apps.isNotEmpty;

  FirebaseStorage get storage {
    if (Firebase.apps.isEmpty) {
      throw Exception('Firebase başlatılmadı (Firebase.initializeApp başarısız).');
    }
    return FirebaseStorage.instance;
  }

  // Resmi sıkıştır
  Future<Uint8List> _compressImage(Uint8List imageBytes, {int quality = 80}) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        imageBytes,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      return result;
    } catch (e) {
      print('Resim sıkıştırma hatası: $e');
      // Sıkıştırma başarısız olursa orijinal resmi döndür
      return imageBytes;
    }
  }

  // File'ı sıkıştır ve Uint8List'e çevir
  Future<Uint8List> _compressImageFile(dynamic imageFile, {int quality = 80}) async {
    try {
      Uint8List imageBytes;
      if (kIsWeb) {
        // Web için XFile kullan
        if (imageFile is XFile) {
          imageBytes = await imageFile.readAsBytes();
        } else {
          throw Exception('Web platformunda XFile bekleniyor');
        }
      } else {
        // Mobile için File kullan
        if (imageFile is File) {
          imageBytes = await imageFile.readAsBytes();
        } else {
          throw Exception('Mobile platformunda File bekleniyor');
        }
      }
      return await _compressImage(imageBytes, quality: quality);
    } catch (e) {
      print('Dosya okuma/sıkıştırma hatası: $e');
      // Hata durumunda orijinal dosyayı oku
      if (kIsWeb && imageFile is XFile) {
        return await imageFile.readAsBytes();
      } else if (!kIsWeb && imageFile is File) {
        return await imageFile.readAsBytes();
      }
      throw Exception('Dosya okunamadı: $e');
    }
  }

  // Kroki çizimini yükle (File veya XFile kabul eder)
  Future<String> uploadDrawing(dynamic imageFile, String orderId) async {
    try {
      // Resmi sıkıştır
      final compressedBytes = await _compressImageFile(imageFile, quality: 80);
      
      String fileName = 'order_${orderId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = storage.ref().child('drawings/$fileName');
      
      UploadTask uploadTask = ref.putData(
        compressedBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      TaskSnapshot snapshot = await uploadTask;
      
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Resim yükleme hatası: ${e.toString()}');
    }
  }

  // Byte data'dan yükle (signature paketi için)
  Future<String> uploadDrawingFromBytes(List<int> imageBytes, String orderId) async {
    try {
      // Resmi sıkıştır
      final compressedBytes = await _compressImage(
        Uint8List.fromList(imageBytes),
        quality: 80,
      );
      
      String fileName = 'order_${orderId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = storage.ref().child('drawings/$fileName');
      
      UploadTask uploadTask = ref.putData(
        compressedBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Resim yükleme hatası: ${e.toString()}');
    }
  }

  // Fotoğraf yükle (sipariş için) - File veya XFile kabul eder
  Future<String> uploadPhoto(dynamic imageFile, String orderId) async {
    try {
      // Web'de dosya kontrolü yapma, mobile'da kontrol et
      if (!kIsWeb && imageFile is File) {
        if (!await imageFile.exists()) {
          throw Exception('Fotoğraf dosyası bulunamadı');
        }
      }

      // Resmi sıkıştır (kalite: 80, format: jpg)
      final compressedBytes = await _compressImageFile(imageFile, quality: 80);

      String fileName = 'order_${orderId}_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = storage.ref().child('photos/$fileName');
      
      // Metadata ekle
      SettableMetadata metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'max-age=31536000',
      );
      
      UploadTask uploadTask = ref.putData(
        compressedBytes,
        metadata,
      );
      
      // Upload ilerlemesini dinle
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });
      
      TaskSnapshot snapshot = await uploadTask;
      
      // Hata kontrolü
      if (snapshot.state != TaskState.success) {
        throw Exception('Yükleme başarısız: ${snapshot.state}');
      }
      
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Fotoğraf yükleme hatası detayı: $e');
      if (e is FirebaseException) {
        throw Exception('Firebase hatası: ${e.code} - ${e.message}');
      }
      throw Exception('Fotoğraf yükleme hatası: ${e.toString()}');
    }
  }

  // Şirket fotoğrafı yükle - File veya XFile kabul eder
  Future<String> uploadCompanyPhoto(dynamic imageFile, String companyId) async {
    try {
      // Web'de dosya kontrolü yapma, mobile'da kontrol et
      if (!kIsWeb && imageFile is File) {
        if (!await imageFile.exists()) {
          throw Exception('Fotoğraf dosyası bulunamadı');
        }
      }

      // Resmi sıkıştır (kalite: 80, format: jpg)
      final compressedBytes = await _compressImageFile(imageFile, quality: 80);

      String fileName = 'company_${companyId}_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = storage.ref().child('company_photos/$fileName');
      
      // Metadata ekle
      SettableMetadata metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'max-age=31536000',
      );
      
      UploadTask uploadTask = ref.putData(
        compressedBytes,
        metadata,
      );
      
      TaskSnapshot snapshot = await uploadTask;
      
      // Hata kontrolü
      if (snapshot.state != TaskState.success) {
        throw Exception('Yükleme başarısız: ${snapshot.state}');
      }
      
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Şirket fotoğrafı yükleme hatası detayı: $e');
      if (e is FirebaseException) {
        throw Exception('Firebase hatası: ${e.code} - ${e.message}');
      }
      throw Exception('Fotoğraf yükleme hatası: ${e.toString()}');
    }
  }

  // APK dosyası yükle (File veya bytes kabul eder)
  Future<String> uploadApk(dynamic apkFileOrBytes, String version) async {
    try {
      Uint8List apkBytes;
      
      if (kIsWeb) {
        // Web için bytes kullan
        if (apkFileOrBytes is Uint8List) {
          apkBytes = apkFileOrBytes;
        } else if (apkFileOrBytes is List<int>) {
          apkBytes = Uint8List.fromList(apkFileOrBytes);
        } else {
          throw Exception('Web platformunda Uint8List veya List<int> bekleniyor');
        }
      } else {
        // Mobile için File kullan
        if (apkFileOrBytes is File) {
          if (!await apkFileOrBytes.exists()) {
            throw Exception('APK dosyası bulunamadı');
          }
          apkBytes = await apkFileOrBytes.readAsBytes();
        } else {
          throw Exception('Mobile platformunda File bekleniyor');
        }
      }

      // Dosya adını versiyona göre oluştur (örn: app-v1.0.1.apk)
      String fileName = 'app-v${version.replaceAll('.', '_')}.apk';
      Reference ref = storage.ref().child('apk/$fileName');
      
      // Metadata ekle
      SettableMetadata metadata = SettableMetadata(
        contentType: 'application/vnd.android.package-archive',
        cacheControl: 'max-age=31536000',
      );
      
      UploadTask uploadTask = ref.putData(
        apkBytes,
        metadata,
      );
      
      // Upload ilerlemesini dinle
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('APK Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });
      
      TaskSnapshot snapshot = await uploadTask;
      
      // Hata kontrolü
      if (snapshot.state != TaskState.success) {
        throw Exception('APK yükleme başarısız: ${snapshot.state}');
      }
      
      // Storage path'i döndür (örn: "apk/app-v1_0_1.apk")
      return 'apk/$fileName';
    } catch (e) {
      print('APK yükleme hatası detayı: $e');
      if (e is FirebaseException) {
        throw Exception('Firebase hatası: ${e.code} - ${e.message}');
      }
      throw Exception('APK yükleme hatası: ${e.toString()}');
    }
  }

  // Resmi sil
  Future<void> deleteDrawing(String url) async {
    if (Firebase.apps.isEmpty) {
      return; // Firebase başlatılmadıysa sessizce çık
    }
    try {
      Reference ref = storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      throw Exception('Resim silme hatası: ${e.toString()}');
    }
  }
}
