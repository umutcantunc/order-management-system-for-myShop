import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';

class VersionInfo {
  final String currentVersion;
  final String minimumVersion;
  final String latestVersion;
  final bool forceUpdate;
  final String? updateUrl;
  final String? storagePath; // Firebase Storage path (örn: "apk/app-v1.0.1.apk")
  final String? updateMessage;
  final DateTime? lastUpdated;

  VersionInfo({
    required this.currentVersion,
    required this.minimumVersion,
    required this.latestVersion,
    this.forceUpdate = false,
    this.updateUrl,
    this.storagePath,
    this.updateMessage,
    this.lastUpdated,
  });

  factory VersionInfo.fromMap(Map<String, dynamic> map) {
    return VersionInfo(
      currentVersion: map['current_version'] ?? '1.0.0',
      minimumVersion: map['minimum_version'] ?? '1.0.0',
      latestVersion: map['latest_version'] ?? '1.0.0',
      forceUpdate: map['force_update'] ?? false,
      updateUrl: map['update_url'],
      storagePath: map['storage_path'],
      updateMessage: map['update_message'],
      lastUpdated: map['last_updated'] != null
          ? (map['last_updated'] as Timestamp).toDate()
          : null,
    );
  }

  // Versiyon karşılaştırması (1.0.0 formatında)
  // version1 > version2 ise true döner
  bool isVersionGreater(String version1, String version2) {
    // Versiyon string'lerini temizle (boşlukları kaldır)
    final v1 = version1.trim();
    final v2 = version2.trim();
    
    // Eğer tamamen eşitse false döndür
    if (v1 == v2) return false;
    
    try {
      final v1Parts = v1.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
      final v2Parts = v2.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();

      // Eksik parçaları 0 ile doldur
      while (v1Parts.length < 3) v1Parts.add(0);
      while (v2Parts.length < 3) v2Parts.add(0);

      for (int i = 0; i < 3; i++) {
        if (v1Parts[i] > v2Parts[i]) return true;
        if (v1Parts[i] < v2Parts[i]) return false;
      }
      return false; // Eşitse false
    } catch (e) {
      debugPrint('Versiyon karşılaştırma hatası: $e');
      return false;
    }
  }

  // Cihazdaki versiyon, sunucudaki latest versiyondan küçük mü?
  bool needsUpdate(String appVersion) {
    // Eğer versiyonlar eşitse güncelleme gerekmez
    if (latestVersion.trim() == appVersion.trim()) return false;
    return isVersionGreater(latestVersion, appVersion);
  }

  // Cihazdaki versiyon, minimum versiyondan küçük mü?
  bool isBelowMinimum(String appVersion) {
    // Eğer versiyonlar eşitse minimum altında değil
    if (minimumVersion.trim() == appVersion.trim()) return false;
    return isVersionGreater(minimumVersion, appVersion);
  }
}

class VersionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _configDocId = 'app_version_config';

  // Firestore'dan versiyon bilgilerini getir
  Future<VersionInfo?> getVersionInfo() async {
    try {
      final doc = await _firestore
          .collection('app_config')
          .doc(_configDocId)
          .get();

      if (doc.exists && doc.data() != null) {
        return VersionInfo.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Versiyon bilgisi alınırken hata: $e');
      return null;
    }
  }

  // Uygulamanın mevcut versiyonunu al
  Future<String> getCurrentAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      debugPrint('Uygulama versiyonu alınırken hata: $e');
      return '1.0.0';
    }
  }

  // Versiyon karşılaştırması - version1 >= version2 ise true döner
  bool isVersionGreaterOrEqual(String version1, String version2) {
    final v1 = version1.trim();
    final v2 = version2.trim();
    
    // Eğer tamamen eşitse true döndür
    if (v1 == v2) return true;
    
    try {
      final v1Parts = v1.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
      final v2Parts = v2.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();

      // Eksik parçaları 0 ile doldur
      while (v1Parts.length < 3) v1Parts.add(0);
      while (v2Parts.length < 3) v2Parts.add(0);

      for (int i = 0; i < 3; i++) {
        if (v1Parts[i] > v2Parts[i]) return true;
        if (v1Parts[i] < v2Parts[i]) return false;
      }
      return true; // Eşitse true
    } catch (e) {
      debugPrint('Versiyon karşılaştırma hatası: $e');
      return false;
    }
  }

  // Güncelleme kontrolü yap
  Future<Map<String, dynamic>> checkForUpdate() async {
    try {
      final appVersion = await getCurrentAppVersion();
      final versionInfo = await getVersionInfo();

      if (versionInfo == null) {
        return {
          'needsUpdate': false,
          'forceUpdate': false,
          'message': null,
          'updateUrl': null,
        };
      }

      // Versiyonları temizle ve karşılaştır
      final cleanAppVersion = appVersion.trim();
      final cleanLatestVersion = versionInfo.latestVersion.trim();
      final cleanMinimumVersion = versionInfo.minimumVersion.trim();
      
      debugPrint('Güncelleme kontrolü: Cihaz=$cleanAppVersion, Latest=$cleanLatestVersion, Minimum=$cleanMinimumVersion');

      // Eğer cihazdaki versiyon, latest versiyon ile eşit veya büyükse güncelleme gerekmez
      if (isVersionGreaterOrEqual(cleanAppVersion, cleanLatestVersion)) {
        debugPrint('Cihaz versiyonu ($cleanAppVersion) >= Latest versiyon ($cleanLatestVersion), güncelleme gerekmez');
        return {
          'needsUpdate': false,
          'forceUpdate': false,
          'message': null,
          'updateUrl': null,
          'currentVersion': versionInfo.currentVersion,
          'latestVersion': versionInfo.latestVersion,
          'minimumVersion': versionInfo.minimumVersion,
          'deviceVersion': appVersion,
        };
      }

      // Minimum versiyon kontrolü
      final isBelowMinimum = !isVersionGreaterOrEqual(cleanAppVersion, cleanMinimumVersion);
      final needsUpdate = !isVersionGreaterOrEqual(cleanAppVersion, cleanLatestVersion);
      final forceUpdate = isBelowMinimum || versionInfo.forceUpdate;

      debugPrint('Güncelleme durumu: needsUpdate=$needsUpdate, isBelowMinimum=$isBelowMinimum, forceUpdate=$forceUpdate');

      return {
        'needsUpdate': needsUpdate || isBelowMinimum,
        'forceUpdate': forceUpdate,
        'message': versionInfo.updateMessage ??
            'Yeni bir güncelleme mevcut. Lütfen uygulamayı güncelleyin.',
        'updateUrl': versionInfo.updateUrl,
        'storagePath': versionInfo.storagePath,
        'currentVersion': versionInfo.currentVersion, // Firestore'daki current_version kullanılıyor
        'latestVersion': versionInfo.latestVersion,
        'minimumVersion': versionInfo.minimumVersion,
        'deviceVersion': appVersion, // Cihazdaki versiyon ayrı olarak döndürülüyor
      };
    } catch (e) {
      debugPrint('Güncelleme kontrolü yapılırken hata: $e');
      return {
        'needsUpdate': false,
        'forceUpdate': false,
        'message': null,
        'updateUrl': null,
      };
    }
  }

  // Admin için: Versiyon bilgilerini güncelle
  Future<void> updateVersionInfo({
    required String currentVersion, // Mevcut versiyon parametresi eklendi
    required String latestVersion,
    required String minimumVersion,
    bool forceUpdate = false,
    String? updateUrl,
    String? storagePath,
    String? updateMessage,
  }) async {
    try {
      await _firestore.collection('app_config').doc(_configDocId).set({
        'current_version': currentVersion, // Mevcut versiyon kaydediliyor
        'latest_version': latestVersion,
        'minimum_version': minimumVersion,
        'force_update': forceUpdate,
        'update_url': updateUrl,
        'storage_path': storagePath,
        'update_message': updateMessage,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('Versiyon bilgileri güncellendi: current=$currentVersion, latest=$latestVersion');
    } catch (e) {
      debugPrint('Versiyon bilgileri güncellenirken hata: $e');
      rethrow;
    }
  }
}
