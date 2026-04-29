import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/worker_statistics_service.dart';
import '../../constants/app_colors.dart';
import '../../models/shift_model.dart';
import '../../models/transaction_model.dart';
import '../../models/salary_payment_model.dart';
import '../../models/monthly_salary_data_model.dart';
import '../../models/bonus_model.dart';
import 'edit_shift_screen.dart';
import 'admin_personnel_calendar_screen.dart';

class PersonnelDetailScreen extends StatefulWidget {
  final UserModel user;

  const PersonnelDetailScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<PersonnelDetailScreen> createState() => _PersonnelDetailScreenState();
}

class _PersonnelDetailScreenState extends State<PersonnelDetailScreen> with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final WorkerStatisticsService _statisticsService = WorkerStatisticsService();
  DateTime _selectedMonth = DateTime.now();
  Map<String, double> _dailyAdvances = {};
  List<ShiftModel> _cachedShifts = [];
  bool _localeInitialized = false;
  late TabController _tabController;
  
  // Mesai geçmişi için
  List<MonthlyStatistics> _monthlyStats = [];
  bool _isLoadingStats = false;
  MonthlyStatistics? _selectedMonthStats;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeLocale();
    _loadStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      final stats = await _statisticsService.getLast6MonthsStatistics(widget.user.uid);
      
      setState(() {
        _monthlyStats = stats;
        if (stats.isNotEmpty) {
          _selectedMonthStats = stats.last; // En son ayı seç
        }
        _isLoadingStats = false;
      });
    } catch (e) {
      debugPrint('İstatistik yükleme hatası: $e');
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  String _getMonthName(int month) {
    switch (month) {
      case 1: return 'Ocak';
      case 2: return 'Şubat';
      case 3: return 'Mart';
      case 4: return 'Nisan';
      case 5: return 'Mayıs';
      case 6: return 'Haziran';
      case 7: return 'Temmuz';
      case 8: return 'Ağustos';
      case 9: return 'Eylül';
      case 10: return 'Ekim';
      case 11: return 'Kasım';
      case 12: return 'Aralık';
      default: return '';
    }
  }

  Future<void> _initializeLocale() async {
    await initializeDateFormatting('tr_TR', null);
    if (mounted) {
      setState(() {
        _localeInitialized = true;
      });
    }
  }

  Future<void> _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() => _selectedMonth = picked);
    }
  }

  String _getFormattedMonth(DateTime month) {
    try {
      if (_localeInitialized) {
        try {
          return DateFormat('MMMM yyyy', 'tr_TR').format(month);
        } catch (e) {
          debugPrint('Türkçe format hatası: $e');
          return DateFormat('MMMM yyyy').format(month);
        }
      } else {
        return DateFormat('MMMM yyyy').format(month);
      }
    } catch (e) {
      debugPrint('Ay formatlama hatası: $e');
      // Fallback: Basit format
      final months = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 
                      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
      return '${months[month.month - 1]} ${month.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        title: Text(widget.user.name),
        backgroundColor: AppColors.mediumGray,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminPersonnelCalendarScreen(user: widget.user),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // TabBar
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primaryOrange,
            unselectedLabelColor: AppColors.textGray,
            indicatorColor: AppColors.primaryOrange,
            tabs: const [
              Tab(text: 'Maaş & Mesai'),
              Tab(text: 'Mesai Geçmişi'),
            ],
          ),
          // TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Maaş & Mesai Sekmesi
                Column(
                  children: [
                    // Maaş Hesaplama Kartı - Maksimum yükseklik ile sınırlandırılmış ve scroll edilebilir
                    Flexible(
                      flex: 0,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.5, // Ekranın maksimum %50'si
                        ),
                        child: SingleChildScrollView(
                          child: Container(
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.mediumGray,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Maaş Hesaplama',
                                        style: TextStyle(
                                          color: AppColors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.edit, color: AppColors.primaryOrange),
                                      onPressed: () => _showEditSalaryDialog(context),
                                      tooltip: 'Maaş Düzenle',
                                    ),
                                    TextButton.icon(
                                      onPressed: _selectMonth,
                                      icon: Icon(Icons.calendar_today, color: AppColors.primaryOrange),
                                      label: Text(
                                        DateFormat('MM.yyyy').format(_selectedMonth),
                                        style: TextStyle(color: AppColors.primaryOrange),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                FutureBuilder<Map<String, dynamic>>(
                                  future: _calculateSalary(_selectedMonth),
                                  key: ValueKey('salary_${_selectedMonth.year}_${_selectedMonth.month}'), // Ay değiştiğinde yeniden hesapla
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(child: CircularProgressIndicator());
                                    }

                                    if (snapshot.hasError) {
                                      debugPrint('Maaş hesaplama hatası: ${snapshot.error}');
                                      return Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Text(
                                          'Maaş hesaplama hatası: ${snapshot.error}',
                                          style: TextStyle(color: AppColors.error),
                                        ),
                                      );
                                    }

                                    final data = snapshot.data ?? {};
                                    double totalAdvances = data['totalAdvances'] ?? 0.0;
                                    double monthlySalary = widget.user.monthlySalary ?? 0.0;
                                    double grossSalary = monthlySalary; // Prim sistemi kaldırıldı
                                    double netSalary = grossSalary - totalAdvances;
                                    DateTime? periodStart = data['periodStart'];
                                    DateTime? periodEnd = data['periodEnd'];

                                    int salaryDay = widget.user.salaryDay ?? 1;

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (widget.user.salaryDay != null)
                                          _buildSalaryRow('Maaş Günü', '$salaryDay. Gün'),
                                        if (periodStart != null && periodEnd != null)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 8.0),
                                            child: Text(
                                              'Dönem: ${DateFormat('dd.MM.yyyy').format(periodStart)} - ${DateFormat('dd.MM.yyyy').format(periodEnd)}',
                                              style: TextStyle(
                                                color: AppColors.textGray,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        // Hesaplanan Maaş Bilgileri (Otomatik - Günlük verilerden)
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppColors.darkGray,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppColors.textGray.withOpacity(0.3)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Hesaplanan Maaş Bilgileri',
                                                style: TextStyle(
                                                  color: AppColors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              _buildSalaryRow('Aylık Maaş', '${monthlySalary.toStringAsFixed(2)} ₺'),
                                              _buildSalaryRow('Alınan Avanslar', '-${totalAdvances.toStringAsFixed(2)} ₺', isNegative: true),
                                              Divider(color: AppColors.textGray),
                                              _buildSalaryRow(
                                                'Net Maaş',
                                                '${netSalary.toStringAsFixed(2)} ₺',
                                                isTotal: true,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        // Admin Düzenlemeleri (Manuel)
                                        StreamBuilder<List<MonthlySalaryDataModel>>(
                                          stream: _firestoreService.getUserMonthlySalaryData(widget.user.uid),
                                          builder: (context, monthlyDataSnapshot) {
                                            if (monthlyDataSnapshot.connectionState == ConnectionState.waiting) {
                                              return const SizedBox.shrink();
                                            }
                                            
                                            final monthlyDataList = monthlyDataSnapshot.data ?? [];
                                            final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
                                            
                                            // Seçilen ay için monthly salary data kaydını bul
                                            MonthlySalaryDataModel? monthlyData;
                                            for (var data in monthlyDataList) {
                                              if (data.month.year == monthStart.year && 
                                                  data.month.month == monthStart.month) {
                                                monthlyData = data;
                                                break;
                                              }
                                            }
                                            
                                            // Admin düzenlemeleri varsa göster
                                            if (monthlyData != null) {
                                              // Maaş/avans değerleri değiştirilmiş mi kontrol et
                                              final isSalaryModified = (monthlyData.remainingNetSalary != netSalary) || 
                                                                       (monthlyData.totalAdvances != totalAdvances);
                                              
                                              return Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: AppColors.mediumGray,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: AppColors.primaryOrange.withOpacity(0.5)),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(
                                                          isSalaryModified ? 'Admin Düzenlemeleri' : 'Admin Notu',
                                                          style: TextStyle(
                                                            color: AppColors.primaryOrange,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                        Row(
                                                          children: [
                                                            IconButton(
                                                              icon: Icon(Icons.edit, color: AppColors.primaryOrange, size: 20),
                                                              onPressed: () {
                                                                if (context.mounted) {
                                                                  _showEditMonthlySalaryDataDialog(
                                                                    context,
                                                                    monthlyData,
                                                                    monthStart,
                                                                    netSalary,
                                                                    totalAdvances,
                                                                    monthlySalary,
                                                                  );
                                                                }
                                                              },
                                                              tooltip: 'Düzenle',
                                                            ),
                                                            IconButton(
                                                              icon: Icon(Icons.delete, color: AppColors.error, size: 20),
                                                              onPressed: () async {
                                                                if (context.mounted) {
                                                                  final confirm = await showDialog<bool>(
                                                                    context: context,
                                                                    builder: (dialogContext) => AlertDialog(
                                                                      backgroundColor: AppColors.mediumGray,
                                                                      title: Text('Admin Düzenlemelerini Sil', style: TextStyle(color: AppColors.white)),
                                                                      content: Text('Bu ayın admin düzenlemelerini silmek istediğinize emin misiniz?', style: TextStyle(color: AppColors.textGray)),
                                                                      actions: [
                                                                        TextButton(
                                                                          onPressed: () => Navigator.pop(dialogContext, false),
                                                                          child: Text('İptal', style: TextStyle(color: AppColors.textGray)),
                                                                        ),
                                                                        ElevatedButton(
                                                                          onPressed: () => Navigator.pop(dialogContext, true),
                                                                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                                                          child: Text('Sil', style: TextStyle(color: AppColors.white)),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  );
                                                                  
                                                                  if (confirm == true && context.mounted) {
                                                                    try {
                                                                      await _firestoreService.deleteMonthlySalaryData(monthlyData!.id);
                                                                      if (context.mounted) {
                                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                                          const SnackBar(
                                                                            content: Text('Admin düzenlemeleri silindi'),
                                                                            backgroundColor: AppColors.statusCompleted,
                                                                          ),
                                                                        );
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
                                                              },
                                                              tooltip: 'Sil',
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                    // Sadece maaş/avans değerleri değiştirilmişse göster
                                                    if (isSalaryModified) ...[
                                                      const SizedBox(height: 8),
                                                      _buildSalaryRow('Düzenlenen Kalan Net Maaş', '${monthlyData.remainingNetSalary.toStringAsFixed(2)} ₺'),
                                                      _buildSalaryRow('Düzenlenen Toplam Avanslar', '-${monthlyData.totalAdvances.toStringAsFixed(2)} ₺', isNegative: true),
                                                      Divider(color: AppColors.textGray),
                                                      _buildSalaryRow(
                                                        'Düzenlenen Toplam Maaş',
                                                        '${(monthlyData.remainingNetSalary + monthlyData.totalAdvances).toStringAsFixed(2)} ₺',
                                                        isTotal: true,
                                                      ),
                                                    ],
                                                    
                                                    // Admin notu varsa göster
                                                    if (monthlyData.adminNotes != null && monthlyData.adminNotes!.isNotEmpty) ...[
                                                      if (isSalaryModified) ...[
                                                        const SizedBox(height: 8),
                                                        Divider(color: AppColors.textGray.withOpacity(0.3)),
                                                      ] else ...[
                                                        const SizedBox(height: 8),
                                                      ],
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'Admin Notu:',
                                                        style: TextStyle(
                                                          color: AppColors.textGray,
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        monthlyData.adminNotes!,
                                                        style: TextStyle(
                                                          color: AppColors.white,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              );
                                            }
                                            
                                            // Admin düzenlemesi yoksa sadece not ekleme butonu göster
                                            return SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton.icon(
                                                onPressed: () {
                                                  final userId = widget.user.uid;
                                                  if (context.mounted) {
                                                    _showAddAdminNoteDialog(
                                                      context,
                                                      userId,
                                                      monthStart,
                                                      netSalary,
                                                      totalAdvances,
                                                      monthlySalary,
                                                    );
                                                  }
                                                },
                                                icon: Icon(Icons.note_add, color: AppColors.white),
                                                label: Text(
                                                  'Admin Notu Ekle',
                                                  style: TextStyle(color: AppColors.white),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.primaryOrange,
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        // Maaş Ödeme Durumu - Firebase'den gerçek zamanlı çekiliyor
                                        StreamBuilder<List<SalaryPaymentModel>>(
                                          stream: _firestoreService.getUserSalaryPayments(widget.user.uid),
                                          builder: (context, paymentsSnapshot) {
                                            final payments = paymentsSnapshot.data ?? [];
                                            final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
                                            
                                            // Seçilen ay için ödeme kaydını bul
                                            SalaryPaymentModel? payment;
                                            for (var p in payments) {
                                              if (p.month.year == monthStart.year && 
                                                  p.month.month == monthStart.month) {
                                                payment = p;
                                                break;
                                              }
                                            }
                                            
                                            // Ödeme durumu gösterimi (varsa)
                                            if (payment != null) {
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 16.0),
                                                child: Container(
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.mediumGray.withOpacity(0.5),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: AppColors.textGray.withOpacity(0.3)),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        payment.paidAmount >= netSalary - 0.01 
                                                            ? Icons.check_circle 
                                                            : Icons.info_outline,
                                                        color: payment.paidAmount >= netSalary - 0.01 
                                                            ? AppColors.statusCompleted 
                                                            : AppColors.statusWaiting,
                                                        size: 16,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        'Ödenen: ${payment.paidAmount.toStringAsFixed(2)} ₺',
                                                        style: TextStyle(
                                                          color: AppColors.textGray,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Mesai Geçmişi
                    Expanded(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Mesai Geçmişi',
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: StreamBuilder<List<ShiftModel>>(
                              stream: _firestoreService.getUserShifts(widget.user.uid),
                              builder: (context, shiftSnapshot) {
                                if (shiftSnapshot.hasData && shiftSnapshot.data!.isNotEmpty) {
                                  _cachedShifts = shiftSnapshot.data!;
                                }

                                return StreamBuilder<List<TransactionModel>>(
                                  stream: _firestoreService.getUserTransactions(widget.user.uid),
                                  builder: (context, transactionSnapshot) {
                                    if (transactionSnapshot.hasData) {
                                      _dailyAdvances.clear();
                                      for (var transaction in transactionSnapshot.data!) {
                                        if (transaction.type == 'advance') {
                                          String dateKey = DateFormat('yyyy-MM-dd').format(transaction.date);
                                          _dailyAdvances[dateKey] = (_dailyAdvances[dateKey] ?? 0) + transaction.amount;
                                        }
                                      }
                                    }

                                    if (shiftSnapshot.connectionState == ConnectionState.waiting && _cachedShifts.isEmpty) {
                                      return const Center(child: CircularProgressIndicator());
                                    }

                                    final shifts = _cachedShifts;

                                    if (shifts.isEmpty) {
                                      return Center(
                                        child: Text(
                                          'Mesai kaydı bulunamadı',
                                          style: TextStyle(color: AppColors.textGray),
                                        ),
                                      );
                                    }

                                    return ListView.builder(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: shifts.length,
                                      itemBuilder: (context, index) {
                                        final shift = shifts[index];
                                        String dateKey = DateFormat('yyyy-MM-dd').format(shift.date);
                                        double advanceAmount = _dailyAdvances[dateKey] ?? 0;
                                        return _buildShiftCard(context, shift, advanceAmount);
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Mesai Geçmişi Sekmesi (İstatistiklerden)
                _buildShiftHistoryView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryRow(String label, String value, {bool isNegative = false, bool isPositive = false, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal ? AppColors.primaryOrange : AppColors.textGray,
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isTotal
                  ? AppColors.primaryOrange
                  : (isNegative ? AppColors.error : (isPositive ? AppColors.statusCompleted : AppColors.white)),
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableSalaryRow(
    BuildContext context,
    String label,
    double value,
    Function(double) onUpdate, {
    bool isNegative = false,
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal ? AppColors.primaryOrange : AppColors.textGray,
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Row(
            children: [
              Text(
                '${value.toStringAsFixed(2)} ₺',
                style: TextStyle(
                  color: isTotal
                      ? AppColors.primaryOrange
                      : (isNegative ? AppColors.error : AppColors.white),
                  fontSize: isTotal ? 18 : 14,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.edit,
                  color: AppColors.primaryOrange,
                  size: 18,
                ),
                onPressed: () => _showEditSingleValueDialog(
                  context,
                  label,
                  value,
                  onUpdate,
                ),
                tooltip: 'Düzenle',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showEditSingleValueDialog(
    BuildContext context,
    String label,
    double currentValue,
    Function(double) onUpdate,
  ) async {
    final TextEditingController controller = TextEditingController(
      text: currentValue.toStringAsFixed(2),
    );

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.mediumGray,
          title: Text(
            '$label Düzenle',
            style: TextStyle(color: AppColors.white),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: AppColors.white),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: AppColors.textGray),
              prefixIcon: Icon(Icons.attach_money, color: AppColors.primaryOrange),
              filled: true,
              fillColor: AppColors.darkGray,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primaryOrange, width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.dispose();
                Navigator.pop(dialogContext);
              },
              child: Text('İptal', style: TextStyle(color: AppColors.textGray)),
            ),
            ElevatedButton(
              onPressed: () {
                final newValue = double.tryParse(controller.text.replaceAll(',', '.')) ?? currentValue;
                if (newValue < 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Değer negatif olamaz'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }
                controller.dispose();
                Navigator.pop(dialogContext);
                onUpdate(newValue);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
              ),
              child: Text('Kaydet', style: TextStyle(color: AppColors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateMonthlySalaryData(
    BuildContext context,
    MonthlySalaryDataModel? existingData,
    DateTime month,
    double currentRemainingNetSalary,
    double currentTotalAdvances, {
    double? remainingNetSalary,
    double? totalAdvances,
    double? monthlySalary,
  }) async {
    try {
      // Mevcut değerleri koru, sadece güncellenenleri değiştir
      final finalRemainingNetSalary = remainingNetSalary ?? currentRemainingNetSalary;
      final finalTotalAdvances = totalAdvances ?? currentTotalAdvances;
      
      // MonthlySalaryDataModel için gerekli değerler
      final monthlyData = MonthlySalaryDataModel(
        id: existingData?.id ?? '',
        userId: widget.user.uid,
        month: month,
        remainingNetSalary: finalRemainingNetSalary,
        totalAdvances: finalTotalAdvances,
        adminNotes: existingData?.adminNotes,
        createdAt: existingData?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestoreService.createOrUpdateMonthlySalaryData(monthlyData);

      // Eğer monthlySalary değiştirildiyse, user modelini güncelle
      if (monthlySalary != null) {
        await _firestoreService.updateUser(widget.user.uid, {
          'monthly_salary': monthlySalary,
        });
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maaş bilgileri güncellendi'),
            backgroundColor: AppColors.statusCompleted,
          ),
        );
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

  Widget _buildShiftCard(BuildContext context, ShiftModel shift, double advanceAmount) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.mediumGray,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _localeInitialized
                    ? DateFormat('dd.MM.yyyy EEEE', 'tr_TR').format(shift.date)
                    : DateFormat('dd.MM.yyyy').format(shift.date),
                style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (advanceAmount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.statusWaiting.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${advanceAmount.toStringAsFixed(2)} ₺',
                  style: TextStyle(
                    color: AppColors.statusWaiting,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, color: AppColors.primaryOrange, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Giriş: ${DateFormat('HH:mm').format(shift.startTime)}',
                  style: TextStyle(color: AppColors.textGray),
                ),
              ],
            ),
            if (shift.endTime != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.logout, color: AppColors.primaryOrange, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Çıkış: ${DateFormat('HH:mm').format(shift.endTime!)}',
                    style: TextStyle(color: AppColors.textGray),
                  ),
                ],
              ),
            ],
            if (shift.totalHours != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.timer, color: AppColors.primaryOrange, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Toplam: ${shift.totalHours!.toStringAsFixed(2)} saat',
                    style: TextStyle(
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
            if (shift.note != null && shift.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.darkGray,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note, color: AppColors.textGray, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        shift.note!,
                        style: TextStyle(
                          color: AppColors.textGray,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: AppColors.primaryOrange),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditShiftScreen(shift: shift),
                  ),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.delete, color: AppColors.error),
              onPressed: () => _showDeleteShiftDialog(context, shift),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _calculateSalary(DateTime selectedMonth) async {
    try {
      // Maaş gününe göre ay başlangıç ve bitiş tarihlerini hesapla
      int salaryDay = widget.user.salaryDay ?? 1; // Varsayılan olarak 1. gün
      
      // Seçilen ay için maaş dönemini hesapla
      // Maaş dönemi: Seçilen ayın maaş gününden, bir sonraki ayın maaş gününden bir gün öncesine kadar
      int targetMonth = selectedMonth.month;
      int targetYear = selectedMonth.year;
      
      // Maaş gününe göre dönem başlangıcı: Seçilen ayın maaş günü
      DateTime periodStart = DateTime(targetYear, targetMonth, salaryDay);
      
      // Dönem bitişi: Bir sonraki ayın maaş gününden bir gün öncesi
      DateTime periodEnd;
      if (targetMonth == 12) {
        // Aralık ayıysa, bir sonraki yılın Ocak ayına geç
        periodEnd = DateTime(targetYear + 1, 1, salaryDay - 1, 23, 59, 59);
      } else {
        // Sonraki ayın maaş gününden bir gün öncesi
        periodEnd = DateTime(targetYear, targetMonth + 1, salaryDay - 1, 23, 59, 59);
      }

      // Bu dönemdeki avansları Firebase'den getir
      double totalAdvances = 0.0;
      try {
        final transactions = await _firestoreService.getUserTransactions(widget.user.uid).first;
        final periodAdvances = transactions.where((t) {
          return t.type == 'advance' &&
              t.date.isAfter(periodStart.subtract(const Duration(days: 1))) &&
              t.date.isBefore(periodEnd.add(const Duration(days: 1)));
        }).toList();

        for (var transaction in periodAdvances) {
          totalAdvances += transaction.amount;
        }
      } catch (e) {
        debugPrint('Avansları getirme hatası: $e');
        // Hata durumunda 0 olarak devam et
      }

      // Prim sistemi kaldırıldı - totalBonus her zaman 0
      double totalBonus = 0.0;

      return {
        'totalAdvances': totalAdvances,
        'totalBonus': totalBonus,
        'periodStart': periodStart,
        'periodEnd': periodEnd,
      };
    } catch (e) {
      debugPrint('Maaş hesaplama hatası: $e');
      // Hata durumunda varsayılan değerler döndür
      return {
        'totalAdvances': 0.0,
        'totalBonus': 0.0,
        'periodStart': DateTime(selectedMonth.year, selectedMonth.month, 1),
        'periodEnd': DateTime(selectedMonth.year, selectedMonth.month + 1, 0, 23, 59, 59),
      };
    }
  }

  Future<void> _showEditSalaryDialog(BuildContext context) async {
    final TextEditingController salaryController = TextEditingController(
      text: widget.user.monthlySalary?.toStringAsFixed(2) ?? '0.00',
    );
    final TextEditingController salaryDayController = TextEditingController(
      text: widget.user.salaryDay?.toString() ?? '1',
    );

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.mediumGray,
          title: Text(
            'Maaş Bilgilerini Düzenle',
            style: TextStyle(color: AppColors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Personel: ${widget.user.name}',
                  style: TextStyle(
                    color: AppColors.textGray,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: salaryController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: AppColors.white),
                  decoration: InputDecoration(
                    labelText: 'Aylık Maaş (₺)',
                    labelStyle: TextStyle(color: AppColors.textGray),
                    prefixIcon: Icon(Icons.attach_money, color: AppColors.primaryOrange),
                    filled: true,
                    fillColor: AppColors.darkGray,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primaryOrange, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: salaryDayController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppColors.white),
                  decoration: InputDecoration(
                    labelText: 'Maaş Günü (1-31)',
                    labelStyle: TextStyle(color: AppColors.textGray),
                    prefixIcon: Icon(Icons.calendar_today, color: AppColors.primaryOrange),
                    filled: true,
                    fillColor: AppColors.darkGray,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primaryOrange, width: 2),
                    ),
                    helperText: 'Her ay bu gün maaş yenilenir',
                    helperStyle: TextStyle(color: AppColors.textGray, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'İptal',
                style: TextStyle(color: AppColors.textGray),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final newSalary = double.tryParse(salaryController.text);
                if (newSalary == null || newSalary < 0) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Geçerli bir tutar giriniz'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                  return;
                }

                final newSalaryDay = int.tryParse(salaryDayController.text);
                if (newSalaryDay == null || newSalaryDay < 1 || newSalaryDay > 31) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Maaş günü 1-31 arasında olmalıdır'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                  return;
                }

                try {
                  final userProvider = Provider.of<UserProvider>(context, listen: false);
                  await userProvider.updateUser(widget.user.uid, {
                    'monthly_salary': newSalary,
                    'salary_day': newSalaryDay,
                  });

                  if (context.mounted) {
                    Navigator.pop(dialogContext);
                    // Kullanıcı bilgilerini güncelle
                    await userProvider.loadUsers();
                    // Sayfayı yenile
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Maaş bilgileri güncellendi: ${newSalary.toStringAsFixed(2)} ₺, Maaş Günü: $newSalaryDay'),
                        backgroundColor: AppColors.statusCompleted,
                      ),
                    );
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
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
              ),
              child: Text(
                'Kaydet',
                style: TextStyle(color: AppColors.white),
              ),
            ),
          ],
        ); // return AlertDialog
      },
    ); // showDialog
    
    // Controller'ları dialog kapandıktan sonra dispose et
    salaryController.dispose();
    salaryDayController.dispose();
  } // _showEditSalaryDialog

  Future<void> _showAddBonusDialog(BuildContext context) async {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController notesController = TextEditingController();
    DateTime selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.mediumGray,
              title: Text(
                'Prim Ekle',
                style: TextStyle(color: AppColors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ay seçici
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: selectedMonth,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          initialDatePickerMode: DatePickerMode.year,
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedMonth = DateTime(picked.year, picked.month, 1);
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.textGray),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _getFormattedMonth(selectedMonth),
                              style: TextStyle(color: AppColors.white),
                            ),
                            Icon(Icons.calendar_today, color: AppColors.primaryOrange),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: AppColors.white),
                      decoration: InputDecoration(
                        labelText: 'Prim Miktarı (₺)',
                        labelStyle: TextStyle(color: AppColors.textGray),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.textGray),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.textGray),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primaryOrange),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      style: TextStyle(color: AppColors.white),
                      decoration: InputDecoration(
                        labelText: 'Not (Opsiyonel)',
                        labelStyle: TextStyle(color: AppColors.textGray),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.textGray),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.textGray),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primaryOrange),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    amountController.dispose();
                    notesController.dispose();
                    Navigator.pop(dialogContext);
                  },
                  child: Text('İptal', style: TextStyle(color: AppColors.textGray)),
                ),
                TextButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text.trim().replaceAll(',', '.'));
                    if (amount == null || amount <= 0) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text('Geçerli bir miktar girin'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                      return;
                    }

                    try {
                      final bonus = BonusModel(
                        id: '',
                        userId: widget.user.uid,
                        amount: amount,
                        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                        month: selectedMonth,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );

                      await _firestoreService.createBonus(bonus);

                      if (dialogContext.mounted) {
                        amountController.dispose();
                        notesController.dispose();
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text('Prim eklendi'),
                            backgroundColor: AppColors.statusCompleted,
                          ),
                        );
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text('Hata: ${e.toString()}'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                  child: Text('Kaydet', style: TextStyle(color: AppColors.primaryOrange)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditBonusDialog(BuildContext context, BonusModel bonus) async {
    final TextEditingController amountController = TextEditingController(text: bonus.amount.toStringAsFixed(2));
    final TextEditingController notesController = TextEditingController(text: bonus.notes ?? '');
    DateTime selectedMonth = DateTime(bonus.month.year, bonus.month.month, 1);

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.mediumGray,
              title: Text(
                'Prim Düzenle',
                style: TextStyle(color: AppColors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ay seçici
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: selectedMonth,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          initialDatePickerMode: DatePickerMode.year,
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedMonth = DateTime(picked.year, picked.month, 1);
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.textGray),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _getFormattedMonth(selectedMonth),
                              style: TextStyle(color: AppColors.white),
                            ),
                            Icon(Icons.calendar_today, color: AppColors.primaryOrange),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: AppColors.white),
                      decoration: InputDecoration(
                        labelText: 'Prim Miktarı (₺)',
                        labelStyle: TextStyle(color: AppColors.textGray),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.textGray),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.textGray),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primaryOrange),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      style: TextStyle(color: AppColors.white),
                      decoration: InputDecoration(
                        labelText: 'Not (Opsiyonel)',
                        labelStyle: TextStyle(color: AppColors.textGray),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.textGray),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.textGray),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primaryOrange),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    amountController.dispose();
                    notesController.dispose();
                    Navigator.pop(dialogContext);
                  },
                  child: Text('İptal', style: TextStyle(color: AppColors.textGray)),
                ),
                TextButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text.trim().replaceAll(',', '.'));
                    if (amount == null || amount <= 0) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text('Geçerli bir miktar girin'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                      return;
                    }

                    try {
                      await _firestoreService.updateBonus(bonus.id, {
                        'amount': amount,
                        'month': Timestamp.fromDate(selectedMonth),
                        'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                        'updated_at': Timestamp.fromDate(DateTime.now()),
                      });

                      if (dialogContext.mounted) {
                        amountController.dispose();
                        notesController.dispose();
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text('Prim güncellendi'),
                            backgroundColor: AppColors.statusCompleted,
                          ),
                        );
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text('Hata: ${e.toString()}'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                  child: Text('Kaydet', style: TextStyle(color: AppColors.primaryOrange)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showDeleteBonusDialog(BuildContext context, BonusModel bonus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.mediumGray,
          title: Text(
            'Prim Sil',
            style: TextStyle(color: AppColors.white),
          ),
          content: Text(
            'Bu primi silmek istediğinizden emin misiniz?\n\n'
            'Ay: ${_getFormattedMonth(bonus.month)}\n'
            'Miktar: ${bonus.amount.toStringAsFixed(2)} ₺',
            style: TextStyle(color: AppColors.textGray),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('İptal', style: TextStyle(color: AppColors.textGray)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('Sil', style: TextStyle(color: AppColors.error)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await _firestoreService.deleteBonus(bonus.id, deletedBy: authProvider.user?.uid);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Prim silindi'),
              backgroundColor: AppColors.statusCompleted,
            ),
          );
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

  Future<void> _showDeleteShiftDialog(BuildContext context, ShiftModel shift) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.mediumGray,
          title: Text(
            'Mesai Sil',
            style: TextStyle(color: AppColors.white),
          ),
          content: Text(
            'Bu mesai kaydını silmek istediğinizden emin misiniz?\n\n'
            'Tarih: ${DateFormat('dd.MM.yyyy').format(shift.date)}\n'
            'Giriş: ${DateFormat('HH:mm').format(shift.startTime)}',
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
        final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await shiftProvider.deleteShift(shift.id, deletedBy: authProvider.user?.uid);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mesai kaydı başarıyla silindi'),
              backgroundColor: AppColors.statusCompleted,
            ),
          );
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

  Future<void> _showAddSalaryPaymentDialog(BuildContext context, DateTime month, double netSalary) async {
    final TextEditingController amountController = TextEditingController(text: netSalary.toStringAsFixed(2));
    final TextEditingController notesController = TextEditingController();
    DateTime selectedPaidDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.mediumGray,
              title: Text(
                'Maaş Ödemesi Ekle',
                style: TextStyle(color: AppColors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ay: ${_getFormattedMonth(month)}',
                      style: TextStyle(color: AppColors.textGray, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: AppColors.white),
                      decoration: InputDecoration(
                        labelText: 'Ödenen Tutar (₺)',
                        labelStyle: TextStyle(color: AppColors.textGray),
                        prefixIcon: Icon(Icons.attach_money, color: AppColors.primaryOrange),
                        filled: true,
                        fillColor: AppColors.darkGray,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primaryOrange, width: 2),
                        ),
                        helperText: 'Net Maaş: ${netSalary.toStringAsFixed(2)} ₺',
                        helperStyle: TextStyle(color: AppColors.textGray, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedPaidDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedPaidDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.textGray),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ödeme Tarihi: ${DateFormat('dd.MM.yyyy').format(selectedPaidDate)}',
                              style: TextStyle(color: AppColors.white),
                            ),
                            Icon(Icons.calendar_today, color: AppColors.primaryOrange),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      style: TextStyle(color: AppColors.white),
                      decoration: InputDecoration(
                        labelText: 'Notlar (Opsiyonel)',
                        labelStyle: TextStyle(color: AppColors.textGray),
                        prefixIcon: Icon(Icons.note, color: AppColors.primaryOrange),
                        filled: true,
                        fillColor: AppColors.darkGray,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primaryOrange, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    amountController.dispose();
                    notesController.dispose();
                    Navigator.pop(dialogContext);
                  },
                  child: Text('İptal', style: TextStyle(color: AppColors.textGray)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text);
                    if (amount == null || amount < 0) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Geçerli bir tutar girin'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                      return;
                    }

                    try {
                      final payment = SalaryPaymentModel(
                        id: '',
                        userId: widget.user.uid,
                        month: month,
                        paidAmount: amount,
                        paidDate: selectedPaidDate,
                        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                        createdAt: DateTime.now(),
                      );

                      await _firestoreService.createSalaryPayment(payment);

                      amountController.dispose();
                      notesController.dispose();

                      if (context.mounted) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Maaş ödemesi eklendi'),
                            backgroundColor: AppColors.statusCompleted,
                          ),
                        );
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
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                  ),
                  child: Text('Kaydet', style: TextStyle(color: AppColors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditSalaryPaymentDialog(BuildContext context, SalaryPaymentModel payment, DateTime month, double netSalary) async {
    final TextEditingController amountController = TextEditingController(text: payment.paidAmount.toStringAsFixed(2));
    final TextEditingController notesController = TextEditingController(text: payment.notes ?? '');
    DateTime selectedPaidDate = payment.paidDate;

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.mediumGray,
              title: Text(
                'Maaş Ödemesi Düzenle',
                style: TextStyle(color: AppColors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ay: ${_getFormattedMonth(month)}',
                      style: TextStyle(color: AppColors.textGray, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: AppColors.white),
                      decoration: InputDecoration(
                        labelText: 'Ödenen Tutar (₺)',
                        labelStyle: TextStyle(color: AppColors.textGray),
                        prefixIcon: Icon(Icons.attach_money, color: AppColors.primaryOrange),
                        filled: true,
                        fillColor: AppColors.darkGray,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primaryOrange, width: 2),
                        ),
                        helperText: 'Net Maaş: ${netSalary.toStringAsFixed(2)} ₺',
                        helperStyle: TextStyle(color: AppColors.textGray, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedPaidDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedPaidDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.textGray),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ödeme Tarihi: ${DateFormat('dd.MM.yyyy').format(selectedPaidDate)}',
                              style: TextStyle(color: AppColors.white),
                            ),
                            Icon(Icons.calendar_today, color: AppColors.primaryOrange),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      style: TextStyle(color: AppColors.white),
                      decoration: InputDecoration(
                        labelText: 'Notlar (Opsiyonel)',
                        labelStyle: TextStyle(color: AppColors.textGray),
                        prefixIcon: Icon(Icons.note, color: AppColors.primaryOrange),
                        filled: true,
                        fillColor: AppColors.darkGray,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primaryOrange, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    // Silme onayı
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: AppColors.mediumGray,
                        title: Text('Sil', style: TextStyle(color: AppColors.white)),
                        content: Text('Bu maaş ödeme kaydını silmek istediğinizden emin misiniz?', style: TextStyle(color: AppColors.textGray)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text('İptal', style: TextStyle(color: AppColors.textGray)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text('Sil', style: TextStyle(color: AppColors.error)),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      try {
                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                        await _firestoreService.deleteSalaryPayment(payment.id, deletedBy: authProvider.user?.uid);
                        amountController.dispose();
                        notesController.dispose();
                        if (context.mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Maaş ödeme kaydı silindi'),
                              backgroundColor: AppColors.statusCompleted,
                            ),
                          );
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
                  },
                  child: Text('Sil', style: TextStyle(color: AppColors.error)),
                ),
                TextButton(
                  onPressed: () {
                    amountController.dispose();
                    notesController.dispose();
                    Navigator.pop(dialogContext);
                  },
                  child: Text('İptal', style: TextStyle(color: AppColors.textGray)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text);
                    if (amount == null || amount < 0) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Geçerli bir tutar girin'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                      return;
                    }

                    try {
                      await _firestoreService.updateSalaryPayment(payment.id, {
                        'paid_amount': amount,
                        'paid_date': Timestamp.fromDate(selectedPaidDate),
                        'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                      });

                      amountController.dispose();
                      notesController.dispose();

                      if (context.mounted) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Maaş ödemesi güncellendi'),
                            backgroundColor: AppColors.statusCompleted,
                          ),
                        );
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
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                  ),
                  child: Text('Kaydet', style: TextStyle(color: AppColors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditMonthlySalaryDataDialog(
    BuildContext context,
    MonthlySalaryDataModel? existingData,
    DateTime month,
    double calculatedNetSalary,
    double calculatedTotalAdvances,
    double calculatedMonthlySalary,
  ) async {
    // Admin düzenlemesi için başlangıç değerleri
    final initialRemainingNetSalary = existingData?.remainingNetSalary ?? calculatedNetSalary;
    final initialTotalAdvances = existingData?.totalAdvances ?? calculatedTotalAdvances;
    final initialMonthlySalary = calculatedMonthlySalary;
    
    // Sadece not mu yoksa maaş/avans düzenlemesi de var mı kontrol et
    final isOnlyNote = existingData != null && 
                       (existingData.remainingNetSalary == calculatedNetSalary) && 
                       (existingData.totalAdvances == calculatedTotalAdvances) &&
                       (existingData.adminNotes != null && existingData.adminNotes!.isNotEmpty);
    
    final TextEditingController remainingSalaryController = TextEditingController(
      text: initialRemainingNetSalary.toStringAsFixed(2),
    );
    final TextEditingController totalAdvancesController = TextEditingController(
      text: initialTotalAdvances.toStringAsFixed(2),
    );
    final TextEditingController notesController = TextEditingController(
      text: existingData?.adminNotes ?? '',
    );

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.mediumGray,
              title: Text(
                isOnlyNote ? 'Admin Notu Düzenle' : 'Admin Maaş Düzenlemesi',
                style: TextStyle(color: AppColors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ay: ${_getFormattedMonth(month)}',
                      style: TextStyle(color: AppColors.textGray, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    // Sadece not ise maaş/avans alanlarını gösterme
                    if (!isOnlyNote) ...[
                      TextField(
                        controller: remainingSalaryController,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: AppColors.white),
                        decoration: InputDecoration(
                          labelText: 'Kalan Net Maaş (₺)',
                          labelStyle: TextStyle(color: AppColors.textGray),
                          prefixIcon: Icon(Icons.attach_money, color: AppColors.primaryOrange),
                          filled: true,
                          fillColor: AppColors.darkGray,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.primaryOrange, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: totalAdvancesController,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: AppColors.white),
                        decoration: InputDecoration(
                          labelText: 'Toplam Avanslar (₺)',
                          labelStyle: TextStyle(color: AppColors.textGray),
                          prefixIcon: Icon(Icons.account_balance_wallet, color: AppColors.error),
                          filled: true,
                          fillColor: AppColors.darkGray,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.error, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: notesController,
                      maxLines: 4,
                      style: TextStyle(color: AppColors.white),
                      decoration: InputDecoration(
                        labelText: 'Admin Notları',
                        labelStyle: TextStyle(color: AppColors.textGray),
                        prefixIcon: Icon(Icons.note, color: AppColors.primaryOrange),
                        filled: true,
                        fillColor: AppColors.darkGray,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primaryOrange, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    remainingSalaryController.dispose();
                    totalAdvancesController.dispose();
                    notesController.dispose();
                    Navigator.pop(dialogContext);
                  },
                  child: Text('İptal', style: TextStyle(color: AppColors.textGray)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final remainingSalary = isOnlyNote 
                        ? calculatedNetSalary 
                        : (double.tryParse(remainingSalaryController.text.replaceAll(',', '.')) ?? 0.0);
                    final totalAdvances = isOnlyNote 
                        ? calculatedTotalAdvances 
                        : (double.tryParse(totalAdvancesController.text.replaceAll(',', '.')) ?? 0.0);
                    final notes = notesController.text.trim().isEmpty ? null : notesController.text.trim();

                    if (!isOnlyNote && (remainingSalary < 0 || totalAdvances < 0)) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Maaş ve avans değerleri negatif olamaz'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                      return;
                    }

                    try {
                      final monthlyData = MonthlySalaryDataModel(
                        id: existingData?.id ?? '',
                        userId: widget.user.uid,
                        month: month,
                        remainingNetSalary: remainingSalary,
                        totalAdvances: totalAdvances,
                        adminNotes: notes,
                        createdAt: existingData?.createdAt ?? DateTime.now(),
                        updatedAt: DateTime.now(),
                      );

                      await _firestoreService.createOrUpdateMonthlySalaryData(monthlyData);

                      remainingSalaryController.dispose();
                      totalAdvancesController.dispose();
                      notesController.dispose();

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isOnlyNote ? 'Admin notu güncellendi' : 'Admin düzenlemesi kaydedildi'),
                              backgroundColor: AppColors.statusCompleted,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      debugPrint('Admin düzenleme kaydetme hatası: $e');
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text('Hata: ${e.toString()}'),
                            backgroundColor: AppColors.error,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                  ),
                  child: Text('Kaydet', style: TextStyle(color: AppColors.white)),
                ),
                // Hesap Sıfır butonu sadece maaş/avans düzenlemesi yapılırken görünsün
                if (!isOnlyNote)
                  ElevatedButton(
                    onPressed: () async {
                      // Hesap Sıfır - Maaş ödemesi kaydı oluştur ve admin düzenlemesini sıfırla
                      final remainingSalary = double.tryParse(remainingSalaryController.text.replaceAll(',', '.')) ?? 0.0;
                      
                      if (remainingSalary <= 0) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text('Ödenecek maaş bulunmuyor'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                        return;
                      }

                    try {
                      // Maaş ödemesi kaydı oluştur
                      final payment = SalaryPaymentModel(
                        id: '',
                        userId: widget.user.uid,
                        month: month,
                        paidAmount: remainingSalary,
                        paidDate: DateTime.now(),
                        notes: notesController.text.trim().isEmpty ? 'Hesap sıfırlandı' : notesController.text.trim(),
                        createdAt: DateTime.now(),
                      );

                      await _firestoreService.createSalaryPayment(payment);

                      // Admin düzenlemesini sıfırla
                      final monthlyData = MonthlySalaryDataModel(
                        id: existingData?.id ?? '',
                        userId: widget.user.uid,
                        month: month,
                        remainingNetSalary: 0.0,
                        totalAdvances: 0.0,
                        adminNotes: 'Hesap sıfırlandı - ${DateFormat('dd.MM.yyyy').format(DateTime.now())}',
                        createdAt: existingData?.createdAt ?? DateTime.now(),
                        updatedAt: DateTime.now(),
                      );

                      await _firestoreService.createOrUpdateMonthlySalaryData(monthlyData);

                      remainingSalaryController.dispose();
                      totalAdvancesController.dispose();
                      notesController.dispose();

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Maaş ödendi ve admin düzenlemesi sıfırlandı'),
                              backgroundColor: AppColors.statusCompleted,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text('Hata: ${e.toString()}'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.statusCompleted,
                  ),
                  child: Text('Hesap Sıfır', style: TextStyle(color: AppColors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildShiftHistoryView() {
    if (_isLoadingStats) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryOrange,
        ),
      );
    }

    if (_monthlyStats.isEmpty) {
      return Center(
        child: Text(
          'Veri bulunamadı',
          style: TextStyle(color: AppColors.textGray),
        ),
      );
    }

    if (_selectedMonthStats == null) {
      return Center(
        child: Text(
          'Lütfen bir ay seçin',
          style: TextStyle(color: AppColors.textGray),
        ),
      );
    }

    return Column(
      children: [
        // Ay seçici
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.mediumGray,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  if (_selectedMonthStats != null) {
                    final currentIndex = _monthlyStats.indexOf(_selectedMonthStats!);
                    if (currentIndex > 0) {
                      setState(() {
                        _selectedMonthStats = _monthlyStats[currentIndex - 1];
                      });
                    }
                  }
                },
                color: AppColors.primaryOrange,
              ),
              Text(
                '${_getMonthName(_selectedMonthStats!.month)} ${_selectedMonthStats!.year} - Mesai Geçmişi',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  if (_selectedMonthStats != null) {
                    final currentIndex = _monthlyStats.indexOf(_selectedMonthStats!);
                    if (currentIndex < _monthlyStats.length - 1) {
                      setState(() {
                        _selectedMonthStats = _monthlyStats[currentIndex + 1];
                      });
                    }
                  }
                },
                color: AppColors.primaryOrange,
              ),
            ],
          ),
        ),
        // Mesai Geçmişi Listesi
        Expanded(
          child: _selectedMonthStats!.dailyStats.isEmpty
              ? Center(
                  child: Text(
                    'Bu ay için mesai kaydı bulunmamaktadır.',
                    style: TextStyle(color: AppColors.textGray),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _selectedMonthStats!.dailyStats.length,
                  itemBuilder: (context, index) {
                    // En yeniden en eskiye sıralama için ters indeks
                    final reversedIndex = _selectedMonthStats!.dailyStats.length - 1 - index;
                    final daily = _selectedMonthStats!.dailyStats[reversedIndex];
                    return _buildDailyCard(daily);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDailyCard(DailyStatistics daily) {
    return Card(
      color: AppColors.mediumGray,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tarih başlığı
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _localeInitialized
                        ? DateFormat('dd MMMM yyyy EEEE', 'tr_TR').format(daily.date)
                        : DateFormat('dd MMMM yyyy').format(daily.date),
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (daily.workHours != null && daily.workHours! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${daily.workHours!.toStringAsFixed(1)} saat',
                      style: TextStyle(
                        color: AppColors.primaryOrange,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Giriş/Çıkış bilgileri
            if (daily.startTime != null || daily.endTime != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.darkGray,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    if (daily.startTime != null) ...[
                      Row(
                        children: [
                          Icon(Icons.login, color: AppColors.primaryOrange, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Giriş: ${DateFormat('HH:mm').format(daily.startTime!)}',
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (daily.endTime != null) const SizedBox(height: 8),
                    ],
                    if (daily.endTime != null) ...[
                      Row(
                        children: [
                          Icon(Icons.logout, color: AppColors.primaryOrange, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Çıkış: ${DateFormat('HH:mm').format(daily.endTime!)}',
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // Avans bilgisi
            if (daily.advanceAmount > 0) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.error.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.money_off, color: AppColors.error, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Avans: ${daily.advanceAmount.toStringAsFixed(2)} ₺',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showAddAdminNoteDialog(
    BuildContext context,
    String userId,
    DateTime month,
    double calculatedNetSalary,
    double calculatedTotalAdvances,
    double calculatedMonthlySalary,
  ) async {
    final TextEditingController notesController = TextEditingController();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext statefulContext, StateSetter setState) {
            return AlertDialog(
              backgroundColor: AppColors.mediumGray,
              title: Text(
                'Admin Notu Ekle',
                style: TextStyle(color: AppColors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ay: ${_getFormattedMonth(month)}',
                      style: TextStyle(color: AppColors.textGray, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      maxLines: 4,
                      enabled: !isSubmitting,
                      style: TextStyle(color: AppColors.white),
                      decoration: InputDecoration(
                        labelText: 'Admin Notu',
                        labelStyle: TextStyle(color: AppColors.textGray),
                        prefixIcon: Icon(Icons.note, color: AppColors.primaryOrange),
                        filled: true,
                        fillColor: AppColors.darkGray,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primaryOrange, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () {
                    Navigator.pop(dialogContext);
                  },
                  child: Text('İptal', style: TextStyle(color: AppColors.textGray)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : () async {
                    final notes = notesController.text.trim();
                    
                    if (notes.isEmpty) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Lütfen bir not girin'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                      return;
                    }

                    setState(() {
                      isSubmitting = true;
                    });

                    try {
                      // Sadece not eklemek için: mevcut kaydı kontrol et
                      // StreamBuilder'dan gelen veriyi kullanarak mevcut kaydı bul
                      final monthlyDataList = await _firestoreService.getUserMonthlySalaryData(userId).first;
                      final monthStart = DateTime(month.year, month.month, 1);
                      
                      MonthlySalaryDataModel? existingData;
                      for (var data in monthlyDataList) {
                        if (data.month.year == monthStart.year && 
                            data.month.month == monthStart.month) {
                          existingData = data;
                          break;
                        }
                      }
                      
                      MonthlySalaryDataModel monthlyData;
                      if (existingData != null) {
                        // Mevcut kayıt varsa sadece notu güncelle, maaş/avans değerlerini değiştirme
                        monthlyData = existingData.copyWith(
                          adminNotes: notes,
                          updatedAt: DateTime.now(),
                        );
                      } else {
                        // Yeni kayıt oluştur, maaş/avans değerlerini hesaplanan değerlerle set et
                        // (Böylece gösterimde kontrol edip sadece notu gösterebiliriz)
                        monthlyData = MonthlySalaryDataModel(
                          id: '',
                          userId: userId,
                          month: month,
                          remainingNetSalary: calculatedNetSalary,
                          totalAdvances: calculatedTotalAdvances,
                          adminNotes: notes,
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        );
                      }

                      await _firestoreService.createOrUpdateMonthlySalaryData(monthlyData);

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                        
                        // Ana ekrana snackbar göster
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Admin notu eklendi'),
                              backgroundColor: AppColors.statusCompleted,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      debugPrint('Admin notu ekleme hatası: $e');
                      setState(() {
                        isSubmitting = false;
                      });
                      
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text('Hata: ${e.toString()}'),
                            backgroundColor: AppColors.error,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                  ),
                  child: isSubmitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                          ),
                        )
                      : Text('Kaydet', style: TextStyle(color: AppColors.white)),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      // Dialog kapandıktan sonra controller'ı dispose et
      notesController.dispose();
    });
  }
}
