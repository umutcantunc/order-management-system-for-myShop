import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UpdateService {
  // Firebase Storage'dan APK indir
  Future<File?> downloadApkFromStorage(String storagePath) async {
    try {
      final storage = FirebaseStorage.instance;
      final ref = storage.ref(storagePath);
      
      // Geçici dizin al
      final tempDir = await getTemporaryDirectory();
      final fileName = 'app_update.apk';
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);

      // Dosya varsa sil
      if (await file.exists()) {
        await file.delete();
      }

      // İndirme URL'ini al
      final downloadUrl = await ref.getDownloadURL();
      
      debugPrint('APK indiriliyor: $downloadUrl');

      // APK'yı indir
      final response = await http.get(Uri.parse(downloadUrl));
      
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        debugPrint('APK indirildi: $filePath');
        return file;
      } else {
        throw Exception('APK indirme hatası: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('APK indirme hatası: $e');
      rethrow;
    }
  }

  // URL'den APK indir
  Future<File?> downloadApkFromUrl(String url) async {
    try {
      // Geçici dizin al
      final tempDir = await getTemporaryDirectory();
      final fileName = 'app_update.apk';
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);

      // Dosya varsa sil
      if (await file.exists()) {
        await file.delete();
      }

      debugPrint('APK indiriliyor: $url');

      // APK'yı indir
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        debugPrint('APK indirildi: $filePath');
        return file;
      } else {
        throw Exception('APK indirme hatası: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('APK indirme hatası: $e');
      rethrow;
    }
  }

  // APK yükleme izni kontrolü ve isteme
  Future<bool> requestInstallPermission() async {
    if (Platform.isAndroid) {
      // Android 8.0+ için REQUEST_INSTALL_PACKAGES izni
      final status = await Permission.requestInstallPackages.request();
      return status.isGranted;
    }
    return true;
  }

  // APK'yı yükle
  Future<bool> installApk(File apkFile) async {
    try {
      // İzin kontrolü
      final hasPermission = await requestInstallPermission();
      if (!hasPermission && Platform.isAndroid) {
        debugPrint('APK yükleme izni verilmedi');
        return false;
      }

      // Dosyanın var olduğunu kontrol et
      if (!await apkFile.exists()) {
        throw Exception('APK dosyası bulunamadı');
      }

      debugPrint('APK yükleniyor: ${apkFile.path}');

      // APK'yı aç (Android otomatik olarak yükleme ekranını gösterir)
      final result = await OpenFile.open(apkFile.path);
      
      debugPrint('APK açma sonucu: ${result.message}');
      
      // ResultType kontrolü - başarılı veya uygulama bulunamadıysa true döndür
      return result.type == ResultType.done || 
             result.type == ResultType.noAppToOpen;
    } catch (e) {
      debugPrint('APK yükleme hatası: $e');
      rethrow;
    }
  }

  // Güncelleme URL'inden veya Storage path'inden APK indir ve yükle
  Future<bool> downloadAndInstallApk(String? updateUrl, String? storagePath) async {
    try {
      File? apkFile;

      // Önce Firebase Storage'dan dene
      if (storagePath != null && storagePath.isNotEmpty) {
        try {
          apkFile = await downloadApkFromStorage(storagePath);
        } catch (e) {
          debugPrint('Storage\'dan indirme hatası: $e, URL\'den deneniyor...');
        }
      }

      // Storage başarısız olursa URL'den dene
      if (apkFile == null && updateUrl != null && updateUrl.isNotEmpty) {
        apkFile = await downloadApkFromUrl(updateUrl);
      }

      if (apkFile == null) {
        throw Exception('APK indirilemedi: URL veya Storage path gerekli');
      }

      // APK'yı yükle
      return await installApk(apkFile);
    } catch (e) {
      debugPrint('APK indirme ve yükleme hatası: $e');
      rethrow;
    }
  }
}
