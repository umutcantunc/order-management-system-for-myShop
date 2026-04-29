import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';
import '../../services/firestore_service.dart';
import '../../models/customer_model.dart';

class CustomerFormScreen extends StatefulWidget {
  final CustomerModel? customer;

  const CustomerFormScreen({Key? key, this.customer}) : super(key: key);

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    if (widget.customer != null) {
      _nameController.text = widget.customer!.name;
      _phoneController.text = widget.customer!.phone ?? '';
      _addressController.text = widget.customer!.address ?? '';
      _notesController.text = widget.customer!.notes ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    if (_formKey.currentState!.validate()) {
      try {
        final now = DateTime.now();
        if (widget.customer != null) {
          // Güncelle
          await _firestoreService.updateCustomer(widget.customer!.id, {
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
            'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
            'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            'updated_at': Timestamp.fromDate(now),
          });
        } else {
          // Yeni müşteri oluştur
          final customer = CustomerModel(
            id: '',
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
            address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            createdAt: now,
            updatedAt: now,
          );
          await _firestoreService.createCustomer(customer);
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Müşteri kaydedildi'),
              backgroundColor: AppColors.statusCompleted,
            ),
          );
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        title: Text(widget.customer == null ? 'Yeni Müşteri' : 'Müşteri Düzenle'),
        backgroundColor: AppColors.mediumGray,
        foregroundColor: AppColors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Müşteri Adı
              TextFormField(
                controller: _nameController,
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

              // Telefon
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Telefon (Opsiyonel)',
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

              // Adres
              TextFormField(
                controller: _addressController,
                maxLines: 3,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Adres (Opsiyonel)',
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

              // Notlar
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Notlar (Opsiyonel)',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Kaydet butonu
              ElevatedButton(
                onPressed: _saveCustomer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
