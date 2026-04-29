import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../constants/app_colors.dart';
import '../../models/company_model.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/cached_network_image_widget.dart';

class CompanyFormScreen extends StatefulWidget {
  final CompanyModel? company;

  const CompanyFormScreen({
    Key? key,
    this.company,
  }) : super(key: key);

  @override
  State<CompanyFormScreen> createState() => _CompanyFormScreenState();
}

class _CompanyFormScreenState extends State<CompanyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _debtController = TextEditingController();
  final _receivableController = TextEditingController();
  final _notesController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedPhoto;
  String? _photoUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.company != null) {
      _nameController.text = widget.company!.name;
      _contactPersonController.text = widget.company!.contactPerson ?? '';
      _phoneController.text = widget.company!.phone ?? '';
      _emailController.text = widget.company!.email ?? '';
      _debtController.text = widget.company!.debt.toStringAsFixed(2);
      _receivableController.text = widget.company!.receivable.toStringAsFixed(2);
      _notesController.text = widget.company!.notes;
      _photoUrl = widget.company!.photoUrl;
    } else {
      _debtController.text = '0.00';
      _receivableController.text = '0.00';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _debtController.dispose();
    _receivableController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedPhoto = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fotoğraf seçme hatası: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveCompany() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isUploading) {
      return; // Yükleme devam ediyorsa bekle
    }

    try {
      final name = _nameController.text.trim();
      final debt = double.parse(_debtController.text.trim());
      final receivable = double.parse(_receivableController.text.trim());

      String? finalPhotoUrl = _photoUrl;
      String? companyId;

      if (widget.company == null) {
        // Yeni şirket oluştur
        final company = CompanyModel(
          id: '',
          name: name,
          contactPerson: _contactPersonController.text.trim().isEmpty
              ? null
              : _contactPersonController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          debt: debt,
          receivable: receivable,
          photoUrl: null, // Önce şirketi oluştur, sonra fotoğraf yükle
          notes: _notesController.text.trim(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        companyId = await _firestoreService.createCompany(company);

        // Fotoğraf varsa yükle
        if (_selectedPhoto != null) {
          setState(() {
            _isUploading = true;
          });

          if (!_storageService.isAvailable) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Firebase Storage etkin değil. Fotoğraf yüklenemedi.'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          } else {
            try {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fotoğraf yükleniyor...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
              finalPhotoUrl = await _storageService.uploadCompanyPhoto(_selectedPhoto!, companyId);
              // Fotoğraf URL'ini şirkete kaydet
              await _firestoreService.updateCompany(companyId, {
                'photo_url': finalPhotoUrl,
              });
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Fotoğraf yükleme hatası: ${e.toString()}'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            }
          }

          setState(() {
            _isUploading = false;
          });
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Şirket başarıyla eklendi'),
              backgroundColor: AppColors.statusCompleted,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        // Mevcut şirketi güncelle
        companyId = widget.company!.id;

        // Yeni fotoğraf seçildiyse yükle
        if (_selectedPhoto != null) {
          setState(() {
            _isUploading = true;
          });

          if (!_storageService.isAvailable) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Firebase Storage etkin değil. Fotoğraf yüklenemedi.'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          } else {
            try {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fotoğraf yükleniyor...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
              finalPhotoUrl = await _storageService.uploadCompanyPhoto(_selectedPhoto!, companyId);
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Fotoğraf yükleme hatası: ${e.toString()}'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            }
          }

          setState(() {
            _isUploading = false;
          });
        }

        await _firestoreService.updateCompany(
          companyId,
          {
            'name': name,
            'contact_person': _contactPersonController.text.trim().isEmpty
                ? null
                : _contactPersonController.text.trim(),
            'phone': _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            'email': _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            'debt': debt,
            'receivable': receivable,
            'photo_url': finalPhotoUrl,
            'notes': _notesController.text.trim(),
          },
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Şirket başarıyla güncellendi'),
              backgroundColor: AppColors.statusCompleted,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        title: Text(
            widget.company == null ? 'Yeni Şirket/Toptancı' : 'Şirket Düzenle'),
        backgroundColor: AppColors.mediumGray,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveCompany,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Şirket Adı
              TextFormField(
                controller: _nameController,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Şirket/Toptancı Adı *',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  prefixIcon: Icon(Icons.business, color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen şirket adını girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // İletişim Kişisi
              TextFormField(
                controller: _contactPersonController,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'İletişim Kişisi (Opsiyonel)',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  prefixIcon:
                      Icon(Icons.person, color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Telefon
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Telefon (Opsiyonel)',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  prefixIcon: Icon(Icons.phone, color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // E-posta
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'E-posta (Opsiyonel)',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  prefixIcon: Icon(Icons.email, color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (!value.contains('@')) {
                      return 'Geçerli bir e-posta adresi girin';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Borç
              TextFormField(
                controller: _debtController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Borç (₺) *',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  prefixIcon: Icon(Icons.attach_money, color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen borç tutarını girin';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Geçerli bir sayı girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Alacak
              TextFormField(
                controller: _receivableController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Alacak (₺) *',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  prefixIcon: Icon(Icons.account_balance_wallet, color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen alacak tutarını girin';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Geçerli bir sayı girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Fotoğraf
              Text(
                'Fotoğraf',
                style: TextStyle(
                  color: AppColors.textGray,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _isUploading ? null : _pickImage,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.mediumGray,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.textGray.withOpacity(0.3),
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: _selectedPhoto != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _selectedPhoto!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : _photoUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImageWidget(
                                imageUrl: _photoUrl!,
                                fit: BoxFit.cover,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate,
                                  color: AppColors.textGray,
                                  size: 48,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Fotoğraf eklemek için tıklayın',
                                  style: TextStyle(color: AppColors.textGray),
                                ),
                              ],
                            ),
                ),
              ),
              if (_isUploading)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Fotoğraf yükleniyor...',
                        style: TextStyle(color: AppColors.textGray, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Notlar
              TextFormField(
                controller: _notesController,
                maxLines: 8,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Notlar *',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  hintText: 'Yapılan işler, borç detayları, önemli notlar...',
                  hintStyle: TextStyle(color: AppColors.textGray.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.note, color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen notlar bölümünü doldurun';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Kaydet Butonu
              ElevatedButton(
                onPressed: _saveCompany,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  widget.company == null ? 'Kaydet' : 'Güncelle',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
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
}
