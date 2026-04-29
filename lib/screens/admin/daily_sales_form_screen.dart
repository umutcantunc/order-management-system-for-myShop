import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';
import '../../models/daily_sales_model.dart';
import '../../services/firestore_service.dart';

class DailySalesFormScreen extends StatefulWidget {
  final DailySalesModel? dailySales;

  const DailySalesFormScreen({
    Key? key,
    this.dailySales,
  }) : super(key: key);

  @override
  State<DailySalesFormScreen> createState() => _DailySalesFormScreenState();
}

class _DailySalesFormScreenState extends State<DailySalesFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cashAmountController = TextEditingController();
  final _cardAmountController = TextEditingController();
  final _notesController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.dailySales != null) {
      _cashAmountController.text = widget.dailySales!.cashAmount.toStringAsFixed(2);
      _cardAmountController.text = widget.dailySales!.cardAmount.toStringAsFixed(2);
      _notesController.text = widget.dailySales!.notes ?? '';
      _selectedDate = widget.dailySales!.date;
    }
    // Toplam tutarı otomatik hesapla
    _cashAmountController.addListener(_calculateTotal);
    _cardAmountController.addListener(_calculateTotal);
  }

  void _calculateTotal() {
    setState(() {}); // Toplamı göstermek için rebuild
  }

  double _getTotal() {
    final cash = double.tryParse(_cashAmountController.text) ?? 0.0;
    final card = double.tryParse(_cardAmountController.text) ?? 0.0;
    return cash + card;
  }

  @override
  void dispose() {
    _cashAmountController.removeListener(_calculateTotal);
    _cardAmountController.removeListener(_calculateTotal);
    _cashAmountController.dispose();
    _cardAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
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
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveDailySales() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final cashAmount = double.tryParse(_cashAmountController.text.trim()) ?? 0.0;
      final cardAmount = double.tryParse(_cardAmountController.text.trim()) ?? 0.0;
      final totalAmount = cashAmount + cardAmount;

      if (widget.dailySales == null) {
        // Yeni günlük satış oluştur
        final dailySales = DailySalesModel(
          id: '',
          date: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
          amount: totalAmount,
          cashAmount: cashAmount,
          cardAmount: cardAmount,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

        // Bu tarihte zaten bir kayıt var mı kontrol et
        final existing = await _firestoreService.getDailySalesByDate(dailySales.date);
        if (existing != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bu tarih için zaten bir kayıt bulunmaktadır. Lütfen mevcut kaydı düzenleyin.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }

        await _firestoreService.createDailySales(dailySales);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Günlük satış başarıyla eklendi'),
              backgroundColor: AppColors.statusCompleted,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        // Mevcut günlük satışı güncelle
        await _firestoreService.updateDailySales(
          widget.dailySales!.id,
          {
            'date': Timestamp.fromDate(
              DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
            ),
            'amount': totalAmount,
            'cash_amount': cashAmount,
            'card_amount': cardAmount,
            'notes': _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          },
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Günlük satış başarıyla güncellendi'),
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
        title: Text(widget.dailySales == null
            ? 'Yeni Günlük Satış'
            : 'Günlük Satış Düzenle'),
        backgroundColor: AppColors.mediumGray,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveDailySales,
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
              // Tarih Seçimi
              GestureDetector(
                onTap: () => _selectDate(context),
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
                        DateFormat('dd.MM.yyyy').format(_selectedDate),
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_drop_down, color: AppColors.textGray),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Nakit Tutar
              TextFormField(
                controller: _cashAmountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Nakit Tutar (₺)',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  prefixIcon: Icon(Icons.money, color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen nakit tutarını girin (0 yazabilirsiniz)';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Geçerli bir sayı girin';
                  }
                  if (double.parse(value) < 0) {
                    return 'Tutar negatif olamaz';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Kart Tutar
              TextFormField(
                controller: _cardAmountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Kart Tutar (₺)',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  prefixIcon: Icon(Icons.credit_card, color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Lütfen kart tutarını girin (0 yazabilirsiniz)';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Geçerli bir sayı girin';
                  }
                  if (double.parse(value) < 0) {
                    return 'Tutar negatif olamaz';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Toplam Tutar Gösterimi
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.mediumGray,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryOrange.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Toplam Tutar:',
                      style: TextStyle(
                        color: AppColors.textGray,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${_getTotal().toStringAsFixed(2)} ₺',
                      style: TextStyle(
                        color: AppColors.primaryOrange,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Notlar
              TextFormField(
                controller: _notesController,
                maxLines: 5,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Notlar (Opsiyonel)',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  prefixIcon: Icon(Icons.note, color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Kaydet Butonu
              ElevatedButton(
                onPressed: _saveDailySales,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  widget.dailySales == null ? 'Kaydet' : 'Güncelle',
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
