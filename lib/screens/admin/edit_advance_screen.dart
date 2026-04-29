import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/transaction_provider.dart';
import '../../models/transaction_model.dart';
import '../../constants/app_colors.dart';

class EditAdvanceScreen extends StatefulWidget {
  final TransactionModel transaction;

  const EditAdvanceScreen({Key? key, required this.transaction}) : super(key: key);

  @override
  State<EditAdvanceScreen> createState() => _EditAdvanceScreenState();
}

class _EditAdvanceScreenState extends State<EditAdvanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.transaction.amount.toStringAsFixed(2);
    _descriptionController.text = widget.transaction.description;
    _selectedDate = widget.transaction.date;
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

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);

        await transactionProvider.updateTransaction(widget.transaction.id, {
          'amount': double.parse(_amountController.text),
          'date': Timestamp.fromDate(_selectedDate),
          'description': _descriptionController.text.trim().isEmpty
              ? 'Maaş avansı'
              : _descriptionController.text.trim(),
        });

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Avans güncellendi'),
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

  Future<void> _deleteAdvance() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.mediumGray,
        title: Text(
          'Avansı Sil',
          style: TextStyle(color: AppColors.white),
        ),
        content: Text(
          'Bu avans kaydını silmek istediğinize emin misiniz?',
          style: TextStyle(color: AppColors.textGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'İptal',
              style: TextStyle(color: AppColors.textGray),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Sil',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      try {
        final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
        await transactionProvider.deleteTransaction(widget.transaction.id);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Avans silindi'),
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
        title: const Text('Avans Düzenle'),
        backgroundColor: AppColors.mediumGray,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.delete, color: AppColors.error),
            onPressed: _isLoading ? null : _deleteAdvance,
          ),
        ],
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
                onTap: _isLoading ? null : _selectDate,
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
                enabled: !_isLoading,
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

              // Açıklama
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                style: TextStyle(color: AppColors.white),
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Açıklama',
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

              // Kaydet Butonu
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: AppColors.white)
                      : Text(
                          'KAYDET',
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
