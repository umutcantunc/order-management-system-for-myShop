import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/shift_model.dart';
import '../../providers/shift_provider.dart';
import '../../constants/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditShiftScreen extends StatefulWidget {
  final ShiftModel shift;

  const EditShiftScreen({Key? key, required this.shift}) : super(key: key);

  @override
  State<EditShiftScreen> createState() => _EditShiftScreenState();
}

class _EditShiftScreenState extends State<EditShiftScreen> {
  late DateTime _startTime;
  late DateTime? _endTime;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startTime = widget.shift.startTime;
    _endTime = widget.shift.endTime;
    _noteController.text = widget.shift.note ?? '';
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
    );
    if (picked != null) {
      setState(() {
        _startTime = DateTime(
          _startTime.year,
          _startTime.month,
          _startTime.day,
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
          : TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _endTime = DateTime(
          _startTime.year,
          _startTime.month,
          _startTime.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_endTime != null && _endTime!.isBefore(_startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Çıkış saati giriş saatinden önce olamaz'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
      
      double? totalHours;
      bool isActive = true;

      if (_endTime != null) {
        totalHours = _endTime!.difference(_startTime).inMinutes / 60.0;
        isActive = false;
      }

      await shiftProvider.updateShiftManually(widget.shift.id, {
        'start_time': Timestamp.fromDate(_startTime),
        'end_time': _endTime != null ? Timestamp.fromDate(_endTime!) : null,
        'total_hours': totalHours,
        'is_active': isActive,
        'date': Timestamp.fromDate(DateTime(
          widget.shift.date.year,
          widget.shift.date.month,
          widget.shift.date.day,
        )),
        'note': _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mesai güncellendi'),
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

  @override
  Widget build(BuildContext context) {
    double? totalHours;
    if (_endTime != null) {
      totalHours = _endTime!.difference(_startTime).inMinutes / 60.0;
    }

    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        title: const Text('Mesai Düzenle'),
        backgroundColor: AppColors.mediumGray,
        foregroundColor: AppColors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                          ? 'Çıkış: Belirtilmemiş'
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
              onPressed: _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
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
    );
  }
}
