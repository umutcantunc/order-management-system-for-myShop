import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../../constants/app_colors.dart';
import '../../services/version_service.dart';
import '../../services/storage_service.dart';

class AppVersionManagementScreen extends StatefulWidget {
  const AppVersionManagementScreen({Key? key}) : super(key: key);

  @override
  State<AppVersionManagementScreen> createState() => _AppVersionManagementScreenState();
}

class _AppVersionManagementScreenState extends State<AppVersionManagementScreen> {
  final VersionService _versionService = VersionService();
  final StorageService _storageService = StorageService();
  final _formKey = GlobalKey<FormState>();
  
  final _latestVersionController = TextEditingController();
  final _minimumVersionController = TextEditingController();
  final _currentVersionController = TextEditingController(); // Mevcut versiyon için controller eklendi
  final _updateUrlController = TextEditingController();
  final _storagePathController = TextEditingController();
  final _updateMessageController = TextEditingController();
  
  bool _forceUpdate = false;
  bool _isLoading = false;
  bool _isUploadingApk = false;
  String _currentAppVersion = '';
  VersionInfo? _currentVersionInfo;
  dynamic _selectedApkFile; // File (mobile) veya PlatformFile (web)
  String? _selectedApkFileName; // Seçilen dosya adı (her iki platform için)

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
    _loadVersionInfo();
  }

  Future<void> _loadCurrentVersion() async {
    try {
      final version = await _versionService.getCurrentAppVersion();
      setState(() {
        _currentAppVersion = version;
      });
    } catch (e) {
      debugPrint('Mevcut versiyon yüklenirken hata: $e');
    }
  }

  Future<void> _loadVersionInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final versionInfo = await _versionService.getVersionInfo();
      setState(() {
        _currentVersionInfo = versionInfo;
        if (versionInfo != null) {
          _latestVersionController.text = versionInfo.latestVersion;
          _minimumVersionController.text = versionInfo.minimumVersion;
          _currentVersionController.text = versionInfo.currentVersion; // Mevcut versiyon yüklendi
          _updateUrlController.text = versionInfo.updateUrl ?? '';
          _storagePathController.text = versionInfo.storagePath ?? '';
          _updateMessageController.text = versionInfo.updateMessage ?? '';
          _forceUpdate = versionInfo.forceUpdate;
        } else {
          // Varsayılan değerler
          _latestVersionController.text = _currentAppVersion;
          _minimumVersionController.text = _currentAppVersion;
          _currentVersionController.text = _currentAppVersion; // Varsayılan mevcut versiyon
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Versiyon bilgileri yüklenirken hata: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickApkFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['apk'],
        withData: kIsWeb, // Web'de bytes al, mobile'da false
        withReadStream: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.single;
        
        // Dosya uzantısı kontrolü
        if (!pickedFile.name.toLowerCase().endsWith('.apk')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Lütfen geçerli bir APK dosyası seçin'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }

        if (kIsWeb) {
          // Web için bytes kullan
          if (pickedFile.bytes == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('APK dosyası okunamadı. Lütfen tekrar deneyin.'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
            return;
          }

          setState(() {
            _selectedApkFile = pickedFile; // PlatformFile
            _selectedApkFileName = pickedFile.name;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('APK seçildi: ${pickedFile.name} (${(pickedFile.size / 1024 / 1024).toStringAsFixed(2)} MB)'),
                backgroundColor: AppColors.statusCompleted,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          // Mobile için File kullan
          if (pickedFile.path == null || pickedFile.path!.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('APK dosyası seçilemedi. Lütfen tekrar deneyin.'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
            return;
          }

          if (!kIsWeb) {
            final file = File(pickedFile.path!);
            if (!await file.exists()) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Seçilen dosya bulunamadı'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
              return;
            }

            setState(() {
              _selectedApkFile = file; // File
              _selectedApkFileName = pickedFile.name;
            });
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('APK seçildi: ${pickedFile.name}'),
                backgroundColor: AppColors.statusCompleted,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('APK seçme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('APK seçilirken hata: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _uploadApk() async {
    // Seçili dosya kontrolü
    if (_selectedApkFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen önce bir APK dosyası seçin'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_latestVersionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen önce "En Son Versiyon" alanını doldurun'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isUploadingApk = true;
    });

    try {
      if (!_storageService.isAvailable) {
        throw Exception('Firebase Storage etkin değil. Lütfen Firebase Console\'da Storage\'ı etkinleştirin.');
      }

      final version = _latestVersionController.text.trim();
      String storagePath;
      
      if (kIsWeb) {
        // Web için PlatformFile'dan bytes al
        if (_selectedApkFile is PlatformFile) {
          final platformFile = _selectedApkFile as PlatformFile;
          if (platformFile.bytes == null) {
            throw Exception('APK dosyası okunamadı');
          }
          storagePath = await _storageService.uploadApk(platformFile.bytes!, version);
        } else {
          throw Exception('Web platformunda PlatformFile bekleniyor');
        }
      } else {
        // Mobile için File kullan
        if (!kIsWeb && _selectedApkFile is File) {
          storagePath = await _storageService.uploadApk(_selectedApkFile as File, version);
        } else if (kIsWeb && _selectedApkFile is PlatformFile) {
          final platformFile = _selectedApkFile as PlatformFile;
          storagePath = await _storageService.uploadApk(platformFile.bytes!, version);
        } else {
          throw Exception('Mobile platformunda File bekleniyor');
        }
      }

      setState(() {
        _storagePathController.text = storagePath;
        _selectedApkFile = null;
        _selectedApkFileName = null;
        // APK yüklendikten sonra, en son versiyon mevcut versiyon olarak da ayarlanır
        _currentVersionController.text = _latestVersionController.text;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('APK başarıyla yüklendi. Mevcut versiyon ${_latestVersionController.text} olarak ayarlandı.'),
            backgroundColor: AppColors.statusCompleted,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('APK yüklenirken hata: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() {
        _isUploadingApk = false;
      });
    }
  }

  Future<void> _saveVersionInfo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _versionService.updateVersionInfo(
        currentVersion: _currentVersionController.text.trim(), // Mevcut versiyon eklendi
        latestVersion: _latestVersionController.text.trim(),
        minimumVersion: _minimumVersionController.text.trim(),
        forceUpdate: _forceUpdate,
        updateUrl: _updateUrlController.text.trim().isEmpty 
            ? null 
            : _updateUrlController.text.trim(),
        storagePath: _storagePathController.text.trim().isEmpty 
            ? null 
            : _storagePathController.text.trim(),
        updateMessage: _updateMessageController.text.trim().isEmpty 
            ? null 
            : _updateMessageController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Versiyon bilgileri güncellendi'),
            backgroundColor: AppColors.statusCompleted,
          ),
        );
        // Bilgileri yeniden yükle
        _loadVersionInfo();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Versiyon bilgileri güncellenirken hata: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _latestVersionController.dispose();
    _minimumVersionController.dispose();
    _currentVersionController.dispose(); // Controller dispose edildi
    _updateUrlController.dispose();
    _storagePathController.dispose();
    _updateMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        title: const Text('Uygulama Versiyon Yönetimi'),
        backgroundColor: AppColors.mediumGray,
        foregroundColor: AppColors.white,
      ),
      body: _isLoading && _currentVersionInfo == null
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryOrange,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mevcut Uygulama Versiyonu (Düzenlenebilir)
                    Card(
                      color: AppColors.mediumGray,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mevcut Uygulama Versiyonu',
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Cihazdaki Versiyon: $_currentAppVersion',
                              style: TextStyle(
                                color: AppColors.textGray,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _currentVersionController,
                              style: TextStyle(color: AppColors.white),
                              decoration: InputDecoration(
                                labelText: 'Mevcut Versiyon (Firestore) *',
                                labelStyle: TextStyle(color: AppColors.textGray),
                                prefixIcon: Icon(Icons.info, color: AppColors.textGray),
                                filled: true,
                                fillColor: AppColors.darkGray,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                helperText: 'Güncelleme sonrası tüm kullanıcılarda bu versiyon görünecek',
                                helperStyle: TextStyle(color: AppColors.textGray, fontSize: 11),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Mevcut versiyon gerekli';
                                }
                                if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(value.trim())) {
                                  return 'Geçerli bir versiyon formatı girin (örn: 1.0.1)';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // En Son Versiyon
                    TextFormField(
                      controller: _latestVersionController,
                      style: TextStyle(color: AppColors.white),
                      decoration: InputDecoration(
                        labelText: 'En Son Versiyon *',
                        labelStyle: TextStyle(color: AppColors.textGray),
                        prefixIcon: Icon(Icons.update, color: AppColors.textGray),
                        filled: true,
                        fillColor: AppColors.mediumGray,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        helperText: 'Örn: 1.0.1 (APK yüklendikten sonra mevcut versiyona kopyalanabilir)',
                        helperStyle: TextStyle(color: AppColors.textGray, fontSize: 11),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'En son versiyon gerekli';
                        }
                        // Versiyon formatını kontrol et (x.y.z)
                        if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(value.trim())) {
                          return 'Geçerli bir versiyon formatı girin (örn: 1.0.1)';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        // En son versiyon değiştiğinde, mevcut versiyona da kopyala (opsiyonel)
                        // Admin isterse manuel olarak değiştirebilir
                      },
                    ),
                    const SizedBox(height: 8),
                    // En son versiyonu mevcut versiyona kopyala butonu
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _currentVersionController.text = _latestVersionController.text;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('En son versiyon mevcut versiyona kopyalandı'),
                              backgroundColor: AppColors.statusCompleted,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: Icon(Icons.copy, color: AppColors.primaryOrange, size: 16),
                        label: Text(
                          'En Son Versiyonu Mevcut Versiyona Kopyala',
                          style: TextStyle(
                            color: AppColors.primaryOrange,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Minimum Versiyon
                    TextFormField(
                      controller: _minimumVersionController,
                      style: TextStyle(color: AppColors.white),
                      decoration: InputDecoration(
                        labelText: 'Minimum Versiyon *',
                        labelStyle: TextStyle(color: AppColors.textGray),
                        prefixIcon: Icon(Icons.warning, color: AppColors.textGray),
                        filled: true,
                        fillColor: AppColors.mediumGray,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        helperText: 'Bu versiyonun altındaki uygulamalar zorunlu güncelleme alır',
                        helperStyle: TextStyle(color: AppColors.textGray, fontSize: 11),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Minimum versiyon gerekli';
                        }
                        if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(value.trim())) {
                          return 'Geçerli bir versiyon formatı girin (örn: 1.0.0)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Firebase Storage Path ve APK Yükleme
                    Card(
                      color: AppColors.mediumGray,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'APK Yükleme',
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isUploadingApk ? null : _pickApkFile,
                                    icon: Icon(
                                      _selectedApkFile != null
                                          ? Icons.check_circle 
                                          : Icons.file_upload,
                                    ),
                                    label: Text(
                                      _selectedApkFile != null
                                          ? 'APK Seçildi' 
                                          : 'APK Seç',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _selectedApkFile != null
                                          ? AppColors.statusCompleted
                                          : AppColors.mediumGray,
                                      foregroundColor: AppColors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: (_isUploadingApk || _selectedApkFile == null) 
                                        ? null 
                                        : _uploadApk,
                                    icon: _isUploadingApk
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.white,
                                            ),
                                          )
                                        : const Icon(Icons.cloud_upload),
                                    label: Text(_isUploadingApk ? 'Yükleniyor...' : 'Yükle'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryOrange,
                                      foregroundColor: AppColors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_selectedApkFile != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Seçilen: ${_selectedApkFileName ?? (kIsWeb ? (_selectedApkFile as PlatformFile).name : (!kIsWeb && _selectedApkFile is File) ? (_selectedApkFile as File).path.split('/').last : '')}',
                                style: TextStyle(
                                  color: AppColors.textGray,
                                  fontSize: 12,
                                ),
                              ),
                              if (kIsWeb && _selectedApkFile is PlatformFile) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Boyut: ${((_selectedApkFile as PlatformFile).size / 1024 / 1024).toStringAsFixed(2)} MB',
                                  style: TextStyle(
                                    color: AppColors.textGray,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _storagePathController,
                              readOnly: true,
                              style: TextStyle(color: AppColors.white),
                              decoration: InputDecoration(
                                labelText: 'Firebase Storage Path',
                                labelStyle: TextStyle(color: AppColors.textGray),
                                prefixIcon: Icon(Icons.storage, color: AppColors.textGray),
                                filled: true,
                                fillColor: AppColors.darkGray,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                helperText: 'APK yüklendikten sonra otomatik doldurulur',
                                helperStyle: TextStyle(color: AppColors.textGray, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Güncelleme URL'i
                    TextFormField(
                      controller: _updateUrlController,
                      style: TextStyle(color: AppColors.white),
                      decoration: InputDecoration(
                        labelText: 'Güncelleme URL\'i (Alternatif)',
                        labelStyle: TextStyle(color: AppColors.textGray),
                        prefixIcon: Icon(Icons.link, color: AppColors.textGray),
                        filled: true,
                        fillColor: AppColors.mediumGray,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        helperText: 'APK indirme linki (Storage Path yoksa kullanılır)',
                        helperStyle: TextStyle(color: AppColors.textGray, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Güncelleme Mesajı
                    TextFormField(
                      controller: _updateMessageController,
                      maxLines: 3,
                      style: TextStyle(color: AppColors.white),
                      decoration: InputDecoration(
                        labelText: 'Güncelleme Mesajı (Opsiyonel)',
                        labelStyle: TextStyle(color: AppColors.textGray),
                        prefixIcon: Icon(Icons.message, color: AppColors.textGray),
                        filled: true,
                        fillColor: AppColors.mediumGray,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        helperText: 'Kullanıcılara gösterilecek mesaj',
                        helperStyle: TextStyle(color: AppColors.textGray, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Zorunlu Güncelleme
                    Card(
                      color: AppColors.mediumGray,
                      child: SwitchListTile(
                        title: Text(
                          'Zorunlu Güncelleme',
                          style: TextStyle(color: AppColors.white),
                        ),
                        subtitle: Text(
                          'Tüm kullanıcılar için güncelleme zorunlu olsun',
                          style: TextStyle(color: AppColors.textGray, fontSize: 12),
                        ),
                        value: _forceUpdate,
                        onChanged: (value) {
                          setState(() {
                            _forceUpdate = value;
                          });
                        },
                        activeColor: AppColors.primaryOrange,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Kaydet Butonu
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveVersionInfo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : const Text(
                                'Kaydet',
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
