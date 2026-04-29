import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../constants/app_colors.dart';

class AddAdvanceScreen extends StatefulWidget {
  final UserModel user;
  final DateTime selectedDate;

  const AddAdvanceScreen({
    Key? key,
    required this.user,
    required this.selectedDate,
  }) : super(key: key);

  @override
  State<AddAdvanceScreen> createState() => _AddAdvanceScreenState();
}

class _AddAdvanceScreenState extends State<AddAdvanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveAdvance() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);

        TransactionModel transaction = TransactionModel(
          id: '',
          userId: widget.user.uid,
          amount: double.parse(_amountController.text),
          type: 'advance',
          date: _selectedDate,
          description: _descriptionController.text.trim().isEmpty
              ? 'Maaş avansı'
              : _descriptionController.text.trim(),
        );

        await transactionProvider.createTransaction(transaction);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Avans eklendi'),
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
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        title: Text('${widget.user.name} - Avans Ekle'),
        backgroundColor: AppColors.mediumGray,
        foregroundColor: AppColors.white,
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tarih Seçimi
              InkWell(
                onTap: _selectDate,
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
                        style: TextStyle(color: AppColors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Miktar
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Miktar (₺)',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.textGray),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primaryOrange),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.attach_money, color: AppColors.textGray),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Miktar gerekli';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Geçerli bir sayı girin';
                  }
                  if (double.parse(value) <= 0) {
                    return 'Miktar 0\'dan büyük olmalı';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Açıklama
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Açıklama (Opsiyonel)',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.textGray),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primaryOrange),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const Spacer(),

              // Kaydet Butonu
              ElevatedButton(
                onPressed: _isLoading ? null : _saveAdvance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: AppColors.white)
                    : const Text(
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
}
