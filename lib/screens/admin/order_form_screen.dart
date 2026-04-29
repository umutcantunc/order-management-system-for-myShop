import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show File;
import '../../providers/order_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../models/daily_sales_model.dart';
import '../../constants/app_colors.dart';
import '../../services/storage_service.dart';
import '../../services/firestore_service.dart';
import '../../services/pdf_service.dart';
import '../../widgets/cached_network_image_widget.dart';
import 'drawing_screen.dart';

class OrderFormScreen extends StatefulWidget {
  final OrderModel? order;

  const OrderFormScreen({Key? key, this.order}) : super(key: key);

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orderNumberController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _detailsController = TextEditingController();
  final _priceController = TextEditingController();
  final _productNameController = TextEditingController();
  final _productColorController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerAddressController = TextEditingController();
  DateTime? _dueDate;
  String _status = 'bekliyor';
  String? _paymentType; // 'nakit' veya 'kart'
  String? _drawingUrl;
  String? _photoUrl;
  File? _selectedPhoto; // Mobile için
  XFile? _selectedPhotoXFile; // Web için
  List<String> _selectedUserIds = []; // Seçilen personel ID'leri
  List<UserModel> _availableUsers = [];
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();
  final FirestoreService _firestoreService = FirestoreService();
  final PdfService _pdfService = PdfService();
  bool _isSaving = false; // Çift kayıt önleme flag'i
  String? _tempOrderId; // Kroki çizerken oluşturulan geçici sipariş ID'si
  bool _isPickingPhoto = false; // Fotoğraf seçme işlemi devam ediyor mu?

  @override
  void initState() {
    super.initState();
    _loadUsers();
    if (widget.order != null) {
      _orderNumberController.text = widget.order!.customOrderNumber;
      _customerNameController.text = widget.order!.customerName;
      _detailsController.text = widget.order!.details;
      _dueDate = widget.order!.dueDate;
      _status = widget.order!.status;
      _drawingUrl = widget.order!.drawingUrl;
      _photoUrl = widget.order!.photoUrl;
      _priceController.text = widget.order!.price?.toStringAsFixed(2) ?? '';
      _productNameController.text = widget.order!.productName ?? '';
      _productColorController.text = widget.order!.productColor ?? '';
      _customerPhoneController.text = widget.order!.customerPhone ?? '';
      _customerAddressController.text = widget.order!.customerAddress ?? '';
      _paymentType = widget.order!.paymentType;
      _selectedUserIds = widget.order!.assignedUserIds ?? [];
    } else {
      // Yeni sipariş için varsayılan durum
      _status = 'bekliyor';
    }
  }

  Future<void> _loadUsers() async {
    _firestoreService.getAllUsers().listen((users) {
      if (mounted) {
        setState(() {
          _availableUsers = users.where((u) => u.role == 'worker').toList();
        });
      }
    });
  }

  @override
  void dispose() {
    _orderNumberController.dispose();
    _customerNameController.dispose();
    _detailsController.dispose();
    _priceController.dispose();
    _productNameController.dispose();
    _productColorController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('tr', 'TR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primaryOrange,
              onPrimary: AppColors.white,
              surface: AppColors.mediumGray,
              onSurface: AppColors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _openDrawingScreen() async {
    // Önce siparişi oluştur (eğer yeni sipariş ise)
    String orderId = widget.order?.id ?? _tempOrderId ?? '';
    
    if (orderId.isEmpty) {
      // Yeni sipariş için önce geçici bir sipariş oluştur
      if (!_formKey.currentState!.validate()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lütfen önce sipariş numarası ve müşteri adını girin'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      try {
        final orderProvider = Provider.of<OrderProvider>(context, listen: false);
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final currentUser = authProvider.user;
        
        // Fiyat ve diğer alanları parse et
        double? price;
        if (_priceController.text.trim().isNotEmpty) {
          price = double.tryParse(_priceController.text.trim().replaceAll(',', '.'));
        }
        
        OrderModel tempOrder = OrderModel(
          id: '',
          customOrderNumber: _orderNumberController.text.trim(),
          customerName: _customerNameController.text.trim(),
          details: _detailsController.text.trim(),
          drawingUrl: null,
          photoUrl: _photoUrl,
          status: _status,
          dueDate: _dueDate,
          createdAt: DateTime.now(),
          createdByName: currentUser?.name,
          createdByUid: currentUser?.uid,
          price: price,
          productName: _productNameController.text.trim().isEmpty 
              ? null 
              : _productNameController.text.trim(),
          productColor: _productColorController.text.trim().isEmpty 
              ? null 
              : _productColorController.text.trim(),
          customerPhone: _customerPhoneController.text.trim().isEmpty 
              ? null 
              : _customerPhoneController.text.trim(),
          customerAddress: _customerAddressController.text.trim().isEmpty 
              ? null 
              : _customerAddressController.text.trim(),
          paymentType: _paymentType,
          assignedUserIds: _selectedUserIds.isEmpty ? null : _selectedUserIds,
          movedToCustomers: false,
        );
        orderId = await orderProvider.createOrder(tempOrder);
        
        // Geçici sipariş ID'sini kaydet (tekrar oluşturmayı önlemek için)
        setState(() {
          _tempOrderId = orderId;
        });
        
        // Opsiyonel alanları da kaydet
        final updateData = {
          'price': tempOrder.price,
          'product_name': tempOrder.productName,
          'product_color': tempOrder.productColor,
          'customer_phone': tempOrder.customerPhone,
          'customer_address': tempOrder.customerAddress,
          'payment_type': tempOrder.paymentType,
          'assigned_user_ids': tempOrder.assignedUserIds,
        };
        await orderProvider.updateOrder(orderId, updateData);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sipariş oluşturma hatası: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DrawingScreen(
          existingDrawingUrl: _drawingUrl,
          orderId: orderId,
        ),
      ),
    );

    if (result != null && result is String) {
      setState(() => _drawingUrl = result);
    }
  }

  Future<void> _pickPhoto() async {
    // Çift tıklama önleme
    if (_isPickingPhoto) {
      debugPrint('Fotoğraf seçme işlemi zaten devam ediyor');
      return;
    }

    // Mounted kontrolü - her adımda kontrol et
    if (!mounted) {
      debugPrint('Widget unmounted, fotoğraf seçme iptal edildi');
      return;
    }

    setState(() {
      _isPickingPhoto = true;
    });

    try {
      debugPrint('=== FOTOĞRAF SEÇME İŞLEMİ BAŞLATILIYOR ===');
      
      // Kaynak seçimi dialog'u
      ImageSource? source;
      try {
        source = await _showImageSourceDialog();
      } catch (dialogError) {
        debugPrint('Dialog hatası: $dialogError');
        if (mounted) {
          setState(() {
            _isPickingPhoto = false;
          });
        }
        return;
      }
      
      if (source == null || !mounted) {
        debugPrint('Kullanıcı kaynak seçmedi veya widget unmounted');
        if (mounted) {
          setState(() {
            _isPickingPhoto = false;
          });
        }
        return;
      }

      debugPrint('Kaynak seçildi: $source');

      // İzin kontrolü ve isteme - hata olsa bile devam et
      try {
        final hasPermission = await _checkAndRequestPermission(source);
        if (!hasPermission && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fotoğraf erişimi için izin gerekiyor'),
              backgroundColor: AppColors.error,
              duration: Duration(seconds: 3),
            ),
          );
          if (mounted) {
            setState(() {
              _isPickingPhoto = false;
            });
          }
          return;
        }
      } catch (permError) {
        debugPrint('İzin kontrolü hatası (devam ediliyor): $permError');
        // İzin kontrolü başarısız olsa bile devam et
      }

      if (!mounted) {
        setState(() {
          _isPickingPhoto = false;
        });
        return;
      }

      // Fotoğraf seçme işlemi - en basit ve güvenli yöntem
      XFile? pickedFile;
      try {
        debugPrint('ImagePicker çağrılıyor...');
        
        // source null kontrolü yapıldı, burada non-null
        final ImageSource imageSource = source!;
        
        // ImagePicker'ı try-catch ile sar ve tüm hataları yakala
        pickedFile = await Future<XFile?>(() async {
          try {
            return await _imagePicker.pickImage(
              source: imageSource,
              imageQuality: 85,
              maxWidth: 1920,
              maxHeight: 1920,
            );
          } catch (e) {
            debugPrint('ImagePicker iç hatası: $e');
            rethrow;
          }
        }).timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            debugPrint('Fotoğraf seçme zaman aşımı');
            return null;
          },
        ).catchError((error, stackTrace) {
          debugPrint('=== IMAGEPICKER CATCHERROR ===');
          debugPrint('Hata: $error');
          debugPrint('Stack: $stackTrace');
          return null;
        });
      } catch (pickerError, pickerStack) {
        debugPrint('=== IMAGEPICKER TRY-CATCH HATASI ===');
        debugPrint('Hata: $pickerError');
        debugPrint('Hata tipi: ${pickerError.runtimeType}');
        debugPrint('Stack: $pickerStack');
        
        // Platform channel hatası olabilir - crash'i önle
        if (mounted) {
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Fotoğraf seçilemedi. Lütfen tekrar deneyin.'),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 4),
              ),
            );
          } catch (snackError) {
            debugPrint('SnackBar hatası: $snackError');
          }
          setState(() {
            _isPickingPhoto = false;
          });
        }
        return;
      }
      
      if (pickedFile == null || !mounted) {
        debugPrint('Fotoğraf seçilmedi veya widget unmounted');
        if (mounted) {
          setState(() {
            _isPickingPhoto = false;
          });
        }
        return;
      }

      debugPrint('Fotoğraf seçildi: ${pickedFile.path}');

      // Web ve mobile için dosya kontrolü
      File? imageFile;
      XFile? xFile;
      try {
        if (kIsWeb) {
          // Web için XFile kullan
          xFile = pickedFile;
          final fileSize = await xFile.length();
          debugPrint('Dosya boyutu: ${fileSize} bytes');
          if (fileSize > 50 * 1024 * 1024) { // 50MB limit
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Fotoğraf çok büyük (maksimum 50MB)'),
                  backgroundColor: AppColors.error,
                  duration: Duration(seconds: 3),
                ),
              );
              setState(() {
                _isPickingPhoto = false;
              });
            }
            return;
          }
        } else {
          // Mobile için File kullan
          if (!kIsWeb) {
            final file = File(pickedFile.path!);
            if (!await file.exists()) {
              debugPrint('Seçilen dosya bulunamadı: ${pickedFile.path}');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fotoğraf dosyası bulunamadı'),
                    backgroundColor: AppColors.error,
                    duration: Duration(seconds: 3),
                  ),
                );
                setState(() {
                  _isPickingPhoto = false;
                });
              }
              return;
            }

            // Dosya boyutu kontrolü
            final fileSize = await file.length();
            debugPrint('Dosya boyutu: ${fileSize} bytes');
            if (fileSize > 50 * 1024 * 1024) { // 50MB limit
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fotoğraf çok büyük (maksimum 50MB)'),
                    backgroundColor: AppColors.error,
                    duration: Duration(seconds: 3),
                  ),
                );
                setState(() {
                  _isPickingPhoto = false;
                });
              }
              return;
            }
            
            imageFile = file;
          }
        }
      } catch (fileError) {
        debugPrint('Dosya kontrolü hatası: $fileError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Dosya okuma hatası: ${fileError.toString()}'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 3),
            ),
          );
          setState(() {
            _isPickingPhoto = false;
          });
        }
        return;
      }

      if (!mounted || (kIsWeb ? xFile == null : imageFile == null)) {
        if (mounted) {
          setState(() {
            _isPickingPhoto = false;
          });
        }
        return;
      }

      // Önce orijinal fotoğrafı kaydet
      if (mounted) {
        setState(() {
          if (kIsWeb) {
            _selectedPhotoXFile = xFile;
            _selectedPhoto = null;
          } else {
            _selectedPhoto = imageFile;
            _selectedPhotoXFile = null;
          }
          _photoUrl = null;
        });
        debugPrint('Fotoğraf kaydedildi: ${kIsWeb ? xFile!.path : (imageFile as File).path}');
      }

      // Kırpma işlemini dene (opsiyonel) - hata olsa bile devam et
      // Web'de kırpma desteklenmiyor, sadece mobile'da dene
      if (mounted && !kIsWeb && imageFile != null) {
        await _tryCropImage(imageFile);
      }
      
      debugPrint('=== FOTOĞRAF SEÇME İŞLEMİ TAMAMLANDI ===');
      
    } catch (e, stackTrace) {
      debugPrint('=== FOTOĞRAF SEÇME KRİTİK HATASI ===');
      debugPrint('Hata: $e');
      debugPrint('Hata tipi: ${e.runtimeType}');
      debugPrint('Stack trace: $stackTrace');
      
      // Hata durumunda kullanıcıya bilgi ver ama crash'i önle
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fotoğraf seçilirken bir hata oluştu. Lütfen tekrar deneyin.'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        } catch (snackError) {
          debugPrint('SnackBar gösterim hatası: $snackError');
        }
      }
    } finally {
      // Her durumda flag'i sıfırla
      if (mounted) {
        setState(() {
          _isPickingPhoto = false;
        });
      }
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    try {
      return await showDialog<ImageSource>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            backgroundColor: AppColors.mediumGray,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Fotoğraf Kaynağı',
              style: GoogleFonts.poppins(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.camera_alt, color: AppColors.primaryOrange),
                  title: Text(
                    'Kamera',
                    style: GoogleFonts.poppins(
                      color: AppColors.white,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(dialogContext).pop(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library, color: AppColors.primaryOrange),
                  title: Text(
                    'Galeri',
                    style: GoogleFonts.poppins(
                      color: AppColors.white,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(dialogContext).pop(ImageSource.gallery);
                  },
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('Dialog gösterim hatası: $e');
      return null;
    }
  }

  Future<bool> _checkAndRequestPermission(ImageSource source) async {
    try {
      if (kIsWeb) {
        // Web'de izin kontrolü gerekmez
        return true;
      }
      
      if (!kIsWeb) {
        // Android kontrolü
        if (source == ImageSource.camera) {
          final status = await Permission.camera.status;
          if (status.isDenied) {
            final result = await Permission.camera.request();
            return result.isGranted;
          }
          return status.isGranted;
        } else {
          // Android 13+ (API 33+) için READ_MEDIA_IMAGES
          // Android 12 ve altı için READ_EXTERNAL_STORAGE
          // Permission handler otomatik olarak doğru izni kullanır
          final status = await Permission.photos.status;
          if (status.isDenied || status.isRestricted) {
            final result = await Permission.photos.request();
            if (result.isGranted) {
              return true;
            }
            // Eğer photos izni yoksa, storage iznini dene (eski Android)
            if (result.isPermanentlyDenied) {
              final storageStatus = await Permission.storage.status;
              if (storageStatus.isDenied) {
                final storageResult = await Permission.storage.request();
                return storageResult.isGranted;
              }
              return storageStatus.isGranted;
            }
            return false;
          }
          return status.isGranted;
        }
      } else {
        // iOS kontrolü
        if (source == ImageSource.camera) {
          final status = await Permission.camera.status;
          if (status.isDenied) {
            final result = await Permission.camera.request();
            return result.isGranted;
          }
          return status.isGranted;
        } else {
          final status = await Permission.photos.status;
          if (status.isDenied) {
            final result = await Permission.photos.request();
            return result.isGranted;
          }
          return status.isGranted;
        }
      }
      // Diğer platformlar için izin kontrolü yapma
      return true;
    } catch (e, stackTrace) {
      debugPrint('İzin kontrolü hatası: $e');
      debugPrint('Stack trace: $stackTrace');
      // Hata durumunda devam et (bazı cihazlarda izin sistemi farklı çalışabilir)
      // ImagePicker kendi izin kontrolünü yapabilir
      return true;
    }
  }

  Future<void> _tryCropImage(dynamic imageFile) async {
    if (!mounted) return;
    
    // Web'de kırpma işlemi farklı çalışır
    if (kIsWeb) {
      // Web için XFile kullan
      if (imageFile is! XFile) {
        debugPrint('Web için XFile bekleniyor');
        return;
      }
      // Web'de ImageCropper zaten XFile ile çalışır
      try {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: imageFile.path,
          compressQuality: 85,
          uiSettings: [
            WebUiSettings(
              context: context,
              presentStyle: WebPresentStyle.dialog,
            ),
          ],
        );
        
        if (croppedFile != null && mounted) {
          setState(() {
            _selectedPhotoXFile = XFile(croppedFile.path);
            _photoUrl = null;
          });
        }
      } catch (e) {
        debugPrint('Web kırpma hatası: $e');
      }
      return;
    }
    
    // Mobile için File kullan
    if (kIsWeb || imageFile is! File) {
      debugPrint('Mobile için File bekleniyor');
      return;
    }
    
    // Kırpma işlemini tamamen opsiyonel yap - hata durumunda orijinal fotoğraf kullanılacak
    try {
      final file = imageFile as File;
      debugPrint('=== Fotoğraf kırpma deneniyor: ${file.path} ===');
      
      // ImageCropper'ı güvenli şekilde çağır - tüm hataları yakala
      CroppedFile? croppedFile;
      try {
        croppedFile = await ImageCropper().cropImage(
          sourcePath: file.path,
          compressQuality: 85,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Fotoğrafı Kırp',
              toolbarColor: AppColors.primaryOrange,
              toolbarWidgetColor: AppColors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
              backgroundColor: AppColors.darkGray,
              activeControlsWidgetColor: AppColors.primaryOrange,
              dimmedLayerColor: AppColors.darkGray.withOpacity(0.8),
              cropFrameColor: AppColors.primaryOrange,
              cropGridColor: AppColors.primaryOrange.withOpacity(0.5),
              cropFrameStrokeWidth: 2,
              cropGridStrokeWidth: 1,
              hideBottomControls: false,
              showCropGrid: true,
            ),
            IOSUiSettings(
              title: 'Fotoğrafı Kırp',
              doneButtonTitle: 'Tamam',
              cancelButtonTitle: 'İptal',
              aspectRatioPresets: [
                CropAspectRatioPreset.original,
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio3x2,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.ratio16x9,
              ],
            ),
          ],
        ).timeout(
          const Duration(seconds: 120),
          onTimeout: () {
            debugPrint('Fotoğraf kırpma zaman aşımı');
            return null;
          },
        );
      } catch (cropError, cropStack) {
        debugPrint('=== IMAGECROPPER HATASI (Orijinal fotoğraf kullanılacak) ===');
        debugPrint('Hata: $cropError');
        debugPrint('Hata tipi: ${cropError.runtimeType}');
        debugPrint('Stack: $cropStack');
        // Kırpma başarısız olsa bile devam et - orijinal fotoğraf zaten kaydedilmiş
        croppedFile = null;
      }

      if (!mounted) return;

      if (croppedFile != null) {
        try {
          final croppedFileObj = File(croppedFile.path);
          if (await croppedFileObj.exists()) {
            debugPrint('Kırpılmış fotoğraf kaydedildi: ${croppedFile.path}');
            if (mounted) {
              setState(() {
                _selectedPhoto = croppedFileObj;
                _photoUrl = null;
              });
            }
          } else {
            debugPrint('Kırpılmış dosya bulunamadı, orijinal kullanılıyor');
          }
        } catch (fileError) {
          debugPrint('Kırpılmış dosya işleme hatası: $fileError');
          // Hata olsa bile orijinal fotoğraf zaten kaydedilmiş
        }
      } else {
        debugPrint('Kırpma iptal edildi veya başarısız, orijinal fotoğraf kullanılıyor');
        // Orijinal fotoğraf zaten _selectedPhoto'da, hiçbir şey yapma
      }
    } catch (e, stackTrace) {
      debugPrint('=== FOTOĞRAF KIRPMA KRİTİK HATASI (Orijinal fotoğraf kullanılacak) ===');
      debugPrint('Hata: $e');
      debugPrint('Stack trace: $stackTrace');
      // Kırpma başarısız olsa bile orijinal fotoğraf zaten kaydedilmiş, crash'i önle
    }
  }

  Future<void> _removePhoto() async {
    setState(() {
      _selectedPhoto = null;
      _selectedPhotoXFile = null;
      _photoUrl = null;
    });
  }

  Future<void> _saveOrder() async {
    if (_formKey.currentState!.validate()) {
      // Çift kayıt önleme
      if (_isSaving) {
        return;
      }
      
      setState(() {
        _isSaving = true;
      });

      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.user;

      try {
        // Mevcut siparişin eski durumunu kontrol et
        final oldStatus = widget.order?.status ?? 'bekliyor';
        final isStatusChangedToCompleted = oldStatus != 'tamamlandı' && _status == 'tamamlandı';

        // Fiyat ve diğer alanları parse et
        double? price;
        if (_priceController.text.trim().isNotEmpty) {
          price = double.tryParse(_priceController.text.trim().replaceAll(',', '.'));
        }

        // Önce siparişi oluştur veya güncelle
        OrderModel order = OrderModel(
          id: widget.order?.id ?? '',
          customOrderNumber: _orderNumberController.text.trim(),
          customerName: _customerNameController.text.trim(),
          details: _detailsController.text.trim(),
          drawingUrl: _drawingUrl,
          photoUrl: _photoUrl,
          status: _status,
          dueDate: _dueDate,
          createdAt: widget.order?.createdAt ?? DateTime.now(),
          createdByName: widget.order?.createdByName ?? currentUser?.name,
          createdByUid: widget.order?.createdByUid ?? currentUser?.uid,
          completedByName: isStatusChangedToCompleted 
              ? (currentUser?.name ?? widget.order?.completedByName)
              : widget.order?.completedByName,
          completedByUid: isStatusChangedToCompleted 
              ? (currentUser?.uid ?? widget.order?.completedByUid)
              : widget.order?.completedByUid,
          price: price,
          productName: _productNameController.text.trim().isEmpty 
              ? null 
              : _productNameController.text.trim(),
          productColor: _productColorController.text.trim().isEmpty 
              ? null 
              : _productColorController.text.trim(),
          customerPhone: _customerPhoneController.text.trim().isEmpty 
              ? null 
              : _customerPhoneController.text.trim(),
          customerAddress: _customerAddressController.text.trim().isEmpty 
              ? null 
              : _customerAddressController.text.trim(),
          paymentType: _paymentType,
          assignedUserIds: _selectedUserIds.isEmpty ? null : _selectedUserIds,
          deliveredAt: _status == 'teslim edildi' 
              ? (widget.order?.deliveredAt ?? DateTime.now())
              : widget.order?.deliveredAt,
          movedToCustomers: widget.order?.movedToCustomers ?? false,
        );

        String orderId;
        Map<String, dynamic> updateData = {
          'custom_order_number': order.customOrderNumber,
          'customer_name': order.customerName,
          'details': order.details,
          'status': order.status,
          'due_date': order.dueDate != null
              ? Timestamp.fromDate(order.dueDate!)
              : null,
          'price': order.price,
          'product_name': order.productName,
          'product_color': order.productColor,
          'customer_phone': order.customerPhone,
          'customer_address': order.customerAddress,
          'payment_type': order.paymentType,
          'assigned_user_ids': order.assignedUserIds,
          'delivered_at': order.deliveredAt != null
              ? Timestamp.fromDate(order.deliveredAt!)
              : null,
        };

        if (widget.order != null) {
          // Mevcut siparişi güncelle - tüm alanları güncelle
          orderId = widget.order!.id;
          updateData['drawing_url'] = order.drawingUrl;
          updateData['photo_url'] = order.photoUrl;
          updateData['moved_to_customers'] = order.movedToCustomers;
          
          // Durum "tamamlandı" olarak değiştirildiyse completedBy bilgilerini ekle
          if (isStatusChangedToCompleted && currentUser != null) {
            updateData['completed_by_name'] = currentUser.name;
            updateData['completed_by_uid'] = currentUser.uid;
          }
          
          // createdBy bilgisi yoksa ekle (eski siparişler için)
          if (widget.order!.createdByName == null && currentUser != null) {
            updateData['created_by_name'] = currentUser.name;
            updateData['created_by_uid'] = currentUser.uid;
          }
          
          // Tüm alanları güncelle (null değerler dahil)
          await orderProvider.updateOrder(orderId, updateData);
        } else {
          // Yeni sipariş oluştur - tüm alanları (opsiyonel dahil) ekle
          // Eğer _tempOrderId varsa, sipariş zaten oluşturulmuş demektir (kroki çizerken)
          if (_tempOrderId != null && _tempOrderId!.isNotEmpty) {
            // Sipariş zaten oluşturulmuş, sadece güncelle
            orderId = _tempOrderId!;
            updateData['drawing_url'] = order.drawingUrl;
            updateData['photo_url'] = order.photoUrl;
            updateData['moved_to_customers'] = order.movedToCustomers;
            
            await orderProvider.updateOrder(orderId, updateData);
          } else {
            // Yeni sipariş oluştur
            if (currentUser != null) {
              order = OrderModel(
                id: order.id,
                customOrderNumber: order.customOrderNumber,
                customerName: order.customerName,
                details: order.details,
                drawingUrl: order.drawingUrl,
                photoUrl: order.photoUrl,
                status: order.status,
                dueDate: order.dueDate,
                createdAt: order.createdAt,
                createdByName: currentUser.name,
                createdByUid: currentUser.uid,
                completedByName: order.completedByName,
                completedByUid: order.completedByUid,
                price: order.price,
                productName: order.productName,
                productColor: order.productColor,
                customerPhone: order.customerPhone,
                customerAddress: order.customerAddress,
                paymentType: order.paymentType,
                assignedUserIds: order.assignedUserIds,
                deliveredAt: order.deliveredAt,
                movedToCustomers: order.movedToCustomers,
              );
            }
            // Tüm alanları içeren updateData'yı kullanarak siparişi oluştur
            updateData['drawing_url'] = order.drawingUrl;
            updateData['photo_url'] = order.photoUrl;
            updateData['created_by_name'] = currentUser?.name;
            updateData['created_by_uid'] = currentUser?.uid;
            updateData['created_at'] = Timestamp.fromDate(order.createdAt);
            updateData['moved_to_customers'] = order.movedToCustomers;
            
            orderId = await orderProvider.createOrder(order);
            
            // Opsiyonel alanları da güncelle (null değerler dahil)
            await orderProvider.updateOrder(orderId, updateData);
          }
        }

        // Fotoğraf yükle (eğer yeni fotoğraf seçildiyse)
        if ((!kIsWeb && _selectedPhoto != null) || (kIsWeb && _selectedPhotoXFile != null)) {
          try {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Fotoğraf yükleniyor...'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
            final String photoUrl;
            if (kIsWeb) {
              photoUrl = await _storageService.uploadPhoto(_selectedPhotoXFile!, orderId);
            } else {
              photoUrl = await _storageService.uploadPhoto(_selectedPhoto!, orderId);
            }
            // Fotoğraf URL'ini siparişe kaydet
            await orderProvider.updateOrder(orderId, {
              'photo_url': photoUrl,
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Fotoğraf başarıyla yüklendi'),
                  backgroundColor: AppColors.statusCompleted,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              final String errorMessage = e.toString();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Fotoğraf yükleme hatası: $errorMessage'),
                  backgroundColor: AppColors.error,
                  duration: const Duration(seconds: 6),
                ),
              );
            }
            debugPrint('Fotoğraf yükleme hatası: $e');
          }
        }

        // Kroki URL'ini siparişe kaydet (eğer varsa)
        if (_drawingUrl != null) {
          await orderProvider.updateOrder(orderId, {
            'drawing_url': _drawingUrl,
          });
        }

        // Eğer sipariş "teslim edildi" durumuna geçtiyse ve fiyat varsa, günlük gelire kaydet
        final isStatusChangedToDelivered = oldStatus != 'teslim edildi' && _status == 'teslim edildi';
        if (isStatusChangedToDelivered && price != null && price! > 0) {
          try {
            final today = DateTime.now();
            final saleDate = DateTime(today.year, today.month, today.day);
            final notes = '${order.customerName} - ${order.customOrderNumber}';
            
            // Payment type'a göre nakit ve kart tutarlarını ayır
            double cashAmount = 0.0;
            double cardAmount = 0.0;
            
            if (_paymentType == 'nakit') {
              cashAmount = price!;
            } else if (_paymentType == 'kart') {
              cardAmount = price!;
            } else {
              // Eğer payment type belirtilmemişse, varsayılan olarak nakit kabul et
              cashAmount = price!;
            }
            
            final dailySale = DailySalesModel(
              id: '',
              date: saleDate,
              amount: price!,
              cashAmount: cashAmount,
              cardAmount: cardAmount,
              customerName: order.customerName,
              orderNumber: order.customOrderNumber,
              notes: notes,
            );
            
            await _firestoreService.createDailySales(dailySale);
          } catch (e) {
            debugPrint('Günlük gelir kaydı hatası: $e');
            // Hata olsa bile sipariş kaydedilsin
          }
        }

        if (mounted) {
          setState(() {
            _isSaving = false;
          });
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sipariş kaydedildi'),
              backgroundColor: AppColors.statusCompleted,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isAdmin = authProvider.isAdmin;
    
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        title: Text(widget.order == null ? 'Yeni Sipariş' : 'Sipariş Düzenle'),
        backgroundColor: AppColors.mediumGray,
        foregroundColor: AppColors.white,
        actions: [
          // PDF Paylaş butonu (sadece mevcut sipariş varsa)
          if (widget.order != null)
            IconButton(
              icon: Icon(Icons.picture_as_pdf, color: AppColors.primaryOrange),
              tooltip: 'PDF Paylaş',
              onPressed: () => _sharePdf(),
            ),
          // Sadece admin ve mevcut sipariş varsa silme butonu göster
          if (isAdmin && widget.order != null)
            IconButton(
              icon: Icon(Icons.delete, color: AppColors.error),
              onPressed: () => _showDeleteOrderDialog(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sipariş Numarası
              TextFormField(
                controller: _orderNumberController,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Sipariş Numarası *',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Sipariş numarası gerekli';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Müşteri Adı
              TextFormField(
                controller: _customerNameController,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Müşteri Adı *',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Müşteri adı gerekli';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Detaylar
              TextFormField(
                controller: _detailsController,
                maxLines: 4,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Detaylar',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Teslim Tarihi
              InkWell(
                onTap: _selectDueDate,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.mediumGray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: AppColors.textGray),
                      const SizedBox(width: 12),
                      Text(
                        _dueDate == null
                            ? 'Teslim Tarihi (Opsiyonel)'
                            : DateFormat('dd.MM.yyyy').format(_dueDate!),
                        style: TextStyle(
                          color: _dueDate == null
                              ? AppColors.textGray
                              : AppColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Durum
              DropdownButtonFormField<String>(
                value: _status,
                decoration: InputDecoration(
                  labelText: 'Durum',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                dropdownColor: AppColors.mediumGray,
                style: TextStyle(color: AppColors.white),
                items: ['bekliyor', 'tamamlandı', 'teslim edildi']
                    .map((status) => DropdownMenuItem(
                          value: status,
                          child: Text(status.toUpperCase()),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _status = value);
                },
              ),
              const SizedBox(height: 16),

              // Fiyat (Opsiyonel)
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Fiyat (Opsiyonel)',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixText: '₺',
                  suffixStyle: TextStyle(color: AppColors.textGray),
                ),
              ),
              const SizedBox(height: 16),

              // Ödeme Tipi (Sadece teslim edildi durumunda)
              if (_status == 'teslim edildi')
                DropdownButtonFormField<String>(
                  value: _paymentType,
                  decoration: InputDecoration(
                    labelText: 'Ödeme Tipi (Opsiyonel)',
                    labelStyle: TextStyle(color: AppColors.textGray),
                    filled: true,
                    fillColor: AppColors.mediumGray,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  dropdownColor: AppColors.mediumGray,
                  style: TextStyle(color: AppColors.white),
                  items: ['nakit', 'kart']
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _paymentType = value);
                  },
                ),
              if (_status == 'teslim edildi') const SizedBox(height: 16),

              // Ürün Adı (Opsiyonel)
              TextFormField(
                controller: _productNameController,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Ürün Adı (Opsiyonel)',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Ürün Rengi (Opsiyonel)
              TextFormField(
                controller: _productColorController,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Ürün Rengi (Opsiyonel)',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Müşteri Telefonu (Opsiyonel)
              TextFormField(
                controller: _customerPhoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Müşteri Telefonu (Opsiyonel)',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Müşteri Adresi (Opsiyonel)
              TextFormField(
                controller: _customerAddressController,
                maxLines: 2,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Müşteri Adresi (Opsiyonel)',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Personel Seçimi (Opsiyonel)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.mediumGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Atanan Personeller (Opsiyonel)',
                      style: TextStyle(
                        color: AppColors.textGray,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableUsers.map((user) {
                        final isSelected = _selectedUserIds.contains(user.uid);
                        return FilterChip(
                          label: Text(user.name),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedUserIds.add(user.uid);
                              } else {
                                _selectedUserIds.remove(user.uid);
                              }
                            });
                          },
                          selectedColor: AppColors.primaryOrange,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.white : AppColors.textGray,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Kroki ve Fotoğraf Bölümü
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _openDrawingScreen,
                      icon: Icon(Icons.draw),
                      label: Text(_drawingUrl != null ? 'Krokiyi Düzenle' : 'Kroki Çiz'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickPhoto,
                      icon: Icon(Icons.camera_alt),
                      label: Text(_photoUrl != null || _selectedPhoto != null || _selectedPhotoXFile != null ? 'Fotoğraf Değiştir' : 'Fotoğraf Ekle'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Seçilen/Kayıtlı Fotoğrafı Göster
              if (_selectedPhoto != null || _selectedPhotoXFile != null || _photoUrl != null)
                Container(
                  height: 200,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.mediumGray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: !kIsWeb && _selectedPhoto != null
                            ? Image.file(
                                _selectedPhoto!,
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                              )
                            : _selectedPhotoXFile != null
                                ? FutureBuilder<Uint8List>(
                                    future: _selectedPhotoXFile!.readAsBytes(),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData) {
                                        return Image.memory(
                                          snapshot.data!,
                                          width: double.infinity,
                                          height: 200,
                                          fit: BoxFit.cover,
                                        );
                                      }
                                      return Center(child: CircularProgressIndicator());
                                    },
                                  )
                                : _photoUrl != null
                                    ? CachedNetworkImageWidget(
                                        imageUrl: _photoUrl!,
                                        width: double.infinity,
                                        height: 200,
                                        fit: BoxFit.cover,
                                        borderRadius: BorderRadius.circular(12),
                                      )
                                    : SizedBox.shrink(),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: Icon(Icons.close, color: AppColors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.error,
                          ),
                          onPressed: _removePhoto,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Kaydet Butonu
              ElevatedButton(
                onPressed: _saveOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.statusCompleted,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'KAYDET',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteOrderDialog(BuildContext context) async {
    if (widget.order == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.mediumGray,
          title: Text(
            'Sipariş Sil',
            style: TextStyle(color: AppColors.white),
          ),
          content: Text(
            'Bu siparişi silmek istediğinizden emin misiniz?\n\n'
            'Müşteri: ${widget.order!.customerName}\n'
            'Sipariş No: ${widget.order!.customOrderNumber}',
            style: TextStyle(color: AppColors.textGray),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'İptal',
                style: TextStyle(color: AppColors.textGray),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                'Sil',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      try {
        final orderProvider = Provider.of<OrderProvider>(context, listen: false);
        await orderProvider.deleteOrder(widget.order!.id);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sipariş başarıyla silindi'),
              backgroundColor: AppColors.statusCompleted,
            ),
          );
          Navigator.pop(context); // Form ekranından çık
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _sharePdf() async {
    if (widget.order == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF oluşturmak için önce siparişi kaydedin'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      // Loading göster
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF oluşturuluyor...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Mevcut sipariş bilgilerini kullanarak OrderModel oluştur
      final order = OrderModel(
        id: widget.order!.id,
        customOrderNumber: _orderNumberController.text.trim().isNotEmpty
            ? _orderNumberController.text.trim()
            : widget.order!.customOrderNumber,
        customerName: _customerNameController.text.trim().isNotEmpty
            ? _customerNameController.text.trim()
            : widget.order!.customerName,
        details: _detailsController.text.trim().isNotEmpty
            ? _detailsController.text.trim()
            : widget.order!.details,
        drawingUrl: _drawingUrl ?? widget.order!.drawingUrl,
        photoUrl: _photoUrl ?? widget.order!.photoUrl,
        status: _status,
        dueDate: _dueDate ?? widget.order!.dueDate,
        createdAt: widget.order!.createdAt,
        createdByName: widget.order!.createdByName,
        createdByUid: widget.order!.createdByUid,
        completedByName: widget.order!.completedByName,
        completedByUid: widget.order!.completedByUid,
        price: _priceController.text.trim().isNotEmpty
            ? double.tryParse(_priceController.text.trim().replaceAll(',', '.'))
            : widget.order!.price,
        productName: _productNameController.text.trim().isNotEmpty
            ? _productNameController.text.trim()
            : widget.order!.productName,
        productColor: _productColorController.text.trim().isNotEmpty
            ? _productColorController.text.trim()
            : widget.order!.productColor,
        customerPhone: _customerPhoneController.text.trim().isNotEmpty
            ? _customerPhoneController.text.trim()
            : widget.order!.customerPhone,
        customerAddress: _customerAddressController.text.trim().isNotEmpty
            ? _customerAddressController.text.trim()
            : widget.order!.customerAddress,
        paymentType: _paymentType ?? widget.order!.paymentType,
        assignedUserIds: _selectedUserIds.isNotEmpty
            ? _selectedUserIds
            : widget.order!.assignedUserIds,
        deliveredAt: widget.order!.deliveredAt,
        movedToCustomers: widget.order!.movedToCustomers,
      );

      // PDF oluştur
      final pdfBytes = await _pdfService.generateOrderPdf(order);

      // Web ve mobile için farklı paylaşma yöntemleri
      if (kIsWeb) {
        // Web için PDF oluşturuldu mesajı göster
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF oluşturuldu. Tarayıcınızın yazdırma özelliğini kullanabilirsiniz.'),
              backgroundColor: AppColors.statusCompleted,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        // Mobile için dosya paylaş
        if (!kIsWeb) {
          final tempDir = await getTemporaryDirectory();
          final fileName = 'Siparis_${order.customOrderNumber}_${DateTime.now().millisecondsSinceEpoch}.pdf';
          final file = File('${tempDir.path}/$fileName');
          await file.writeAsBytes(pdfBytes);

          // Paylaş
          if (mounted) {
            await Share.shareXFiles(
              [XFile(file.path)],
              text: 'Sipariş Detayları - ${order.customOrderNumber}',
              subject: 'Sipariş: ${order.customOrderNumber}',
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF oluşturma hatası: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      print('PDF paylaşma hatası: $e');
    }
  }
}
