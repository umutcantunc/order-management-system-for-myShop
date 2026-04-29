import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../services/firestore_service.dart';
import '../../models/customer_statistics_model.dart';

class CustomerStatisticsEditScreen extends StatefulWidget {
  final CustomerStatisticsModel statistics;

  const CustomerStatisticsEditScreen({Key? key, required this.statistics}) : super(key: key);

  @override
  State<CustomerStatisticsEditScreen> createState() => _CustomerStatisticsEditScreenState();
}

class _CustomerStatisticsEditScreenState extends State<CustomerStatisticsEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerCountController = TextEditingController();
  final _cashAmountController = TextEditingController();
  final _cardAmountController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _customerCountController.text = widget.statistics.customerCount.toString();
    _cashAmountController.text = widget.statistics.cashAmount.toStringAsFixed(2);
    _cardAmountController.text = widget.statistics.cardAmount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _customerCountController.dispose();
    _cashAmountController.dispose();
    _cardAmountController.dispose();
    super.dispose();
  }

  Future<void> _saveStatistics() async {
    if (_formKey.currentState!.validate()) {
      try {
        final customerCount = int.tryParse(_customerCountController.text) ?? 0;
        final cashAmount = double.tryParse(_cashAmountController.text.replaceAll(',', '.')) ?? 0.0;
        final cardAmount = double.tryParse(_cardAmountController.text.replaceAll(',', '.')) ?? 0.0;
        final totalAmount = cashAmount + cardAmount;

        await _firestoreService.updateCustomerStatistics(widget.statistics.id, {
          'customer_count': customerCount,
          'cash_amount': cashAmount,
          'card_amount': cardAmount,
          'total_amount': totalAmount,
          'updated_at': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('İstatistikler güncellendi'),
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
        title: const Text('İstatistikleri Düzenle'),
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
              Text(
                'Tarih: ${DateFormat('dd MMMM yyyy', 'tr_TR').format(widget.statistics.date)}',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _customerCountController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Müşteri Sayısı',
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
                    return 'Müşteri sayısı gerekli';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Geçerli bir sayı girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cashAmountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Nakit Miktarı (₺)',
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
                    return 'Nakit miktarı gerekli';
                  }
                  if (double.tryParse(value.replaceAll(',', '.')) == null) {
                    return 'Geçerli bir sayı girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cardAmountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Kart Miktarı (₺)',
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
                    return 'Kart miktarı gerekli';
                  }
                  if (double.tryParse(value.replaceAll(',', '.')) == null) {
                    return 'Geçerli bir sayı girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveStatistics,
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
