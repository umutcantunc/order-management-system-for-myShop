import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/shift_model.dart';
import '../../models/user_model.dart';
import '../../providers/shift_provider.dart';
import '../../constants/app_colors.dart';

class AddShiftScreen extends StatefulWidget {
  final UserModel user;
  final DateTime selectedDate;

  const AddShiftScreen({
    Key? key,
    required this.user,
    required this.selectedDate,
  }) : super(key: key);

  @override
  State<AddShiftScreen> createState() => _AddShiftScreenState();
}

class _AddShiftScreenState extends State<AddShiftScreen> {
  late DateTime _selectedDate;
  late DateTime _startTime;
  DateTime? _endTime;
  bool _isLoading = false;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
    _startTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      9,
      0,
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
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
      setState(() {
        _selectedDate = picked;
        _startTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _startTime.hour,
          _startTime.minute,
        );
        if (_endTime != null) {
          _endTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            _endTime!.hour,
            _endTime!.minute,
          );
        }
      });
    }
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
    );
    if (picked != null) {
      setState(() {
        _startTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime != null
          ? TimeOfDay.fromDateTime(_endTime!)
          : TimeOfDay.fromDateTime(_startTime.add(const Duration(hours: 8))),
    );
    if (picked != null) {
      setState(() {
        _endTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _saveShift() async {
    if (_endTime != null && _endTime!.isBefore(_startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Çıkış saati giriş saatinden önce olamaz'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
      
      double? totalHours;
      bool isActive = _endTime == null;

      if (_endTime != null) {
        totalHours = _endTime!.difference(_startTime).inMinutes / 60.0;
      }

      ShiftModel shift = ShiftModel(
        id: '',
        userId: widget.user.uid,
        startTime: _startTime,
        endTime: _endTime,
        isActive: isActive,
        totalHours: totalHours,
        date: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );

      await shiftProvider.createShiftManually(shift);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mesai eklendi'),
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

  @override
  Widget build(BuildContext context) {
    double? totalHours;
    if (_endTime != null) {
      totalHours = _endTime!.difference(_startTime).inMinutes / 60.0;
    }

    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        title: Text('${widget.user.name} - Mesai Ekle'),
        backgroundColor: AppColors.mediumGray,
        foregroundColor: AppColors.white,
      ),
      body: Padding(
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

            // Giriş Saati
            InkWell(
              onTap: _selectStartTime,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.mediumGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: AppColors.textGray),
                    const SizedBox(width: 12),
                    Text(
                      'Giriş: ${DateFormat('HH:mm').format(_startTime)}',
                      style: TextStyle(color: AppColors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Çıkış Saati
            InkWell(
              onTap: _selectEndTime,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.mediumGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: AppColors.textGray),
                    const SizedBox(width: 12),
                    Text(
                      _endTime == null
                          ? 'Çıkış: Belirtilmemiş (Aktif Mesai)'
                          : 'Çıkış: ${DateFormat('HH:mm').format(_endTime!)}',
                      style: TextStyle(
                        color: _endTime == null ? AppColors.textGray : AppColors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Not (Opsiyonel)
            TextField(
              controller: _noteController,
              maxLines: 3,
              style: TextStyle(color: AppColors.white),
              decoration: InputDecoration(
                labelText: 'Not (Opsiyonel)',
                labelStyle: TextStyle(color: AppColors.textGray),
                hintText: 'Bu gün için not ekleyin...',
                hintStyle: TextStyle(color: AppColors.textGray),
                prefixIcon: Icon(Icons.note, color: AppColors.textGray),
                filled: true,
                fillColor: AppColors.mediumGray,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Toplam Saat
            if (totalHours != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Toplam: ${totalHours.toStringAsFixed(2)} saat',
                  style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            const Spacer(),

            // Kaydet Butonu
            ElevatedButton(
              onPressed: _isLoading ? null : _saveShift,
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
    );
  }
}
