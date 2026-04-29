import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/transaction_model.dart';
import '../../constants/app_colors.dart';

class RequestAdvanceScreen extends StatefulWidget {
  const RequestAdvanceScreen({Key? key}) : super(key: key);

  @override
  State<RequestAdvanceScreen> createState() => _RequestAdvanceScreenState();
}

class _RequestAdvanceScreenState extends State<RequestAdvanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

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

  Future<void> _requestAdvance() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);

        if (authProvider.user == null) {
          throw Exception('Kullanıcı bilgisi bulunamadı');
        }

        final transaction = TransactionModel(
          id: '',
          userId: authProvider.user!.uid,
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
              content: Text('Avans talebi kaydedildi'),
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
        title: const Text('Maaş Avansı Talep Et'),
        backgroundColor: AppColors.mediumGray,
        foregroundColor: AppColors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
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
                        style: TextStyle(color: AppColors.white),
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
                  labelText: 'Miktar (₺) *',
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
                    return 'Miktar gerekli';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Geçerli bir miktar girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Açıklama (Opsiyonel)
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Açıklama (Opsiyonel)',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Talep Et Butonu
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _requestAdvance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: AppColors.white)
                      : Text(
                          'TALEP ET',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
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
