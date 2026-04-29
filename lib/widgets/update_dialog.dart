import 'package:flutter/material.dart';
import 'dart:io';
import '../constants/app_colors.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final String message;
  final String? updateUrl;
  final String? storagePath;
  final bool forceUpdate;
  final String currentVersion;
  final String latestVersion;

  const UpdateDialog({
    Key? key,
    required this.message,
    this.updateUrl,
    this.storagePath,
    this.forceUpdate = false,
    required this.currentVersion,
    required this.latestVersion,
  }) : super(key: key);

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  final UpdateService _updateService = UpdateService();
  bool _isDownloading = false;
  bool _isInstalling = false;
  String _statusMessage = '';

  Future<void> _downloadAndInstall() async {
    if (widget.updateUrl == null && widget.storagePath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Güncelleme dosyası bulunamadı'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() {
      _isDownloading = true;
      _statusMessage = 'APK indiriliyor...';
    });

    try {
      // APK'yı indir ve yükle
      final success = await _updateService.downloadAndInstallApk(
        widget.updateUrl,
        widget.storagePath,
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isInstalling = false;
        });

        if (success) {
          _statusMessage = 'APK yükleme ekranı açıldı. Lütfen yükleme işlemini tamamlayın.';
          
          // Zorunlu güncelleme değilse dialog'u kapat
          if (!widget.forceUpdate) {
            Navigator.of(context).pop();
          }
        } else {
          _statusMessage = 'APK yükleme izni verilmedi. Lütfen ayarlardan izin verin.';
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('APK yükleme izni gerekli. Lütfen ayarlardan izin verin.'),
              backgroundColor: AppColors.error,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isInstalling = false;
          _statusMessage = 'Hata: ${e.toString()}';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Güncelleme hatası: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.forceUpdate, // Zorunlu güncellemede geri tuşu çalışmasın
      child: AlertDialog(
        backgroundColor: AppColors.mediumGray,
        title: Row(
          children: [
            Icon(
              Icons.system_update,
              color: AppColors.primaryOrange,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Güncelleme Mevcut',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.message,
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.darkGray,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mevcut Versiyon:',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          widget.currentVersion,
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Yeni Versiyon:',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          widget.latestVersion,
                          style: TextStyle(
                            color: AppColors.primaryOrange,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_statusMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isDownloading || _isInstalling
                        ? AppColors.primaryOrange.withOpacity(0.2)
                        : AppColors.mediumGray,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      if (_isDownloading || _isInstalling)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryOrange,
                          ),
                        )
                      else
                        Icon(
                          _statusMessage.contains('Hata')
                              ? Icons.error
                              : Icons.info,
                          color: _statusMessage.contains('Hata')
                              ? AppColors.error
                              : AppColors.primaryOrange,
                          size: 20,
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (widget.forceUpdate) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.error,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning,
                        color: AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bu güncelleme zorunludur. Uygulamayı kullanmaya devam etmek için güncellemeniz gerekiyor.',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!widget.forceUpdate && !_isDownloading && !_isInstalling)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Daha Sonra',
                style: TextStyle(color: AppColors.textGray),
              ),
            ),
          ElevatedButton(
            onPressed: (_isDownloading || _isInstalling) ? null : _downloadAndInstall,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: AppColors.white,
              disabledBackgroundColor: AppColors.textGray,
            ),
            child: _isDownloading || _isInstalling
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : const Text('Güncelle'),
          ),
        ],
      ),
    );
  }
}
