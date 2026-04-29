import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_colors.dart';
import '../../services/worker_statistics_service.dart';
import '../../services/firestore_service.dart';
import '../../models/bonus_model.dart';
import '../../models/salary_payment_model.dart';
import '../../models/monthly_salary_data_model.dart';
import '../../models/shift_model.dart';
import '../../models/transaction_model.dart';

class WorkerStatisticsScreen extends StatefulWidget {
  final String? userId; // Admin için personel ID'si, null ise kendi istatistikleri

  const WorkerStatisticsScreen({Key? key, this.userId}) : super(key: key);

  @override
  State<WorkerStatisticsScreen> createState() => _WorkerStatisticsScreenState();
}

class _WorkerStatisticsScreenState extends State<WorkerStatisticsScreen> with SingleTickerProviderStateMixin {
  final WorkerStatisticsService _statisticsService = WorkerStatisticsService();
  final FirestoreService _firestoreService = FirestoreService();
  late TabController _tabController;
  
  List<MonthlyStatistics> _monthlyStats = [];
  bool _isLoading = true;
  MonthlyStatistics? _selectedMonth;
  bool _localeInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeLocale();
    _loadStatistics();
  }

  Future<void> _initializeLocale() async {
    await initializeDateFormatting('tr_TR', null);
    if (mounted) {
      setState(() {
        _localeInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String targetUserId;
      
      // Eğer userId verilmişse (admin için), onu kullan; yoksa kendi user ID'sini al
      if (widget.userId != null) {
        targetUserId = widget.userId!;
      } else {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.user == null) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
        targetUserId = authProvider.user!.uid;
      }

      final stats = await _statisticsService.getLast6MonthsStatistics(targetUserId);
      
      setState(() {
        _monthlyStats = stats;
        if (stats.isNotEmpty) {
          _selectedMonth = stats.last; // En son ayı seç
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('İstatistik yükleme hatası: $e');
      setState(() {
        _isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        title: Text(widget.userId != null ? 'Personel İstatistikleri' : 'İstatistiklerim'),
        backgroundColor: AppColors.mediumGray,
        foregroundColor: AppColors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryOrange,
          unselectedLabelColor: AppColors.textGray,
          indicatorColor: AppColors.primaryOrange,
          tabs: const [
            Tab(text: 'Tablo'),
            Tab(text: 'Mesai Geçmişi'),
            Tab(text: 'Takvim'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryOrange,
              ),
            )
          : _monthlyStats.isEmpty
              ? Center(
                  child: Text(
                    'Veri bulunamadı',
                    style: TextStyle(color: AppColors.textGray),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTableView(),
                    _buildShiftHistoryView(),
                    _buildCalendarView(),
                  ],
                ),
    );
  }

  Widget _buildTableView() {
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
                  if (_selectedMonth != null) {
                    final currentIndex = _monthlyStats.indexOf(_selectedMonth!);
                    if (currentIndex > 0) {
                      setState(() {
                        _selectedMonth = _monthlyStats[currentIndex - 1];
                      });
                    }
                  }
                },
                color: AppColors.primaryOrange,
              ),
              Text(
                _selectedMonth != null
                    ? '${_getMonthName(_selectedMonth!.month)} ${_selectedMonth!.year}'
                    : 'Ay Seçin',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  if (_selectedMonth != null) {
                    final currentIndex = _monthlyStats.indexOf(_selectedMonth!);
                    if (currentIndex < _monthlyStats.length - 1) {
                      setState(() {
                        _selectedMonth = _monthlyStats[currentIndex + 1];
                      });
                    }
                  }
                },
                color: AppColors.primaryOrange,
              ),
            ],
          ),
        ),

        // Aylık özet - Artık tam ekranı kaplıyor (mesai geçmişi ayrı tab'da)
        if (_selectedMonth != null)
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.mediumGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Toplam Çalışma Saati', '${_selectedMonth!.totalHours.toStringAsFixed(2)} saat'),
                    const Divider(color: AppColors.textGray),
                    _buildSummaryRow('Çalışılan Gün', '${_selectedMonth!.workDays} gün'),
                    const Divider(color: AppColors.textGray),
                    _buildSummaryRow('Toplam Avans', '${_selectedMonth!.totalAdvances.toStringAsFixed(2)} ₺'),
                    const Divider(color: AppColors.textGray),
                    _buildSummaryRow('Aylık Maaş', '${(_selectedMonth!.monthlySalary - _selectedMonth!.totalBonus).toStringAsFixed(2)} ₺'),
                    if (_selectedMonth!.totalBonus > 0) ...[
                      const Divider(color: AppColors.textGray),
                      _buildSummaryRow('Toplam Prim', '${_selectedMonth!.totalBonus.toStringAsFixed(2)} ₺'),
                    ],
                    const Divider(color: AppColors.textGray),
                    _buildSummaryRow(
                      'Net Maaş',
                      '${(_selectedMonth!.monthlySalary - _selectedMonth!.totalAdvances).toStringAsFixed(2)} ₺',
                      isTotal: true,
                    ),
                    // Maaş Ödeme Durumu ve Admin Notu
                    Builder(
                      builder: (context) {
                        String targetUserId;
                        if (widget.userId != null) {
                          targetUserId = widget.userId!;
                        } else {
                          final authProvider = Provider.of<AuthProvider>(context, listen: false);
                          targetUserId = authProvider.user?.uid ?? '';
                        }
                        
                        if (targetUserId.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        
                        final monthStart = DateTime(_selectedMonth!.year, _selectedMonth!.month, 1);
                        
                        // Önce admin notunu kontrol et
                        return StreamBuilder<List<MonthlySalaryDataModel>>(
                          stream: _firestoreService.getUserMonthlySalaryData(targetUserId),
                          builder: (context, monthlyDataSnapshot) {
                            if (monthlyDataSnapshot.connectionState == ConnectionState.waiting) {
                              return const SizedBox.shrink();
                            }
                            
                            final monthlyDataList = monthlyDataSnapshot.data ?? [];
                            
                            // Seçilen ay için monthly salary data kaydını bul
                            MonthlySalaryDataModel? monthlyData;
                            for (var data in monthlyDataList) {
                              if (data.month.year == monthStart.year && 
                                  data.month.month == monthStart.month) {
                                monthlyData = data;
                                break;
                              }
                            }
                            
                            // Admin notu varsa sadece onu göster, maaş ödeme durumunu gösterme
                            if (monthlyData != null && monthlyData.adminNotes != null && monthlyData.adminNotes!.isNotEmpty) {
                              return Column(
                                children: [
                                  const Divider(color: AppColors.textGray),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryOrange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.primaryOrange.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.note, color: AppColors.primaryOrange, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Admin Notu:',
                                                style: TextStyle(
                                                  color: AppColors.primaryOrange,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                monthlyData.adminNotes!,
                                                style: TextStyle(
                                                  color: AppColors.white,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }
                            
                            // Admin notu yoksa maaş ödeme durumunu göster
                            return StreamBuilder<SalaryPaymentModel?>(
                              stream: _firestoreService.getUserSalaryPayments(targetUserId).map((payments) {
                                // Seçilen ay için ödeme kaydını bul
                                for (var payment in payments) {
                                  if (payment.month.year == monthStart.year && 
                                      payment.month.month == monthStart.month) {
                                    return payment;
                                  }
                                }
                                return null;
                              }),
                              builder: (context, paymentSnapshot) {
                                if (paymentSnapshot.connectionState == ConnectionState.waiting) {
                                  return const SizedBox.shrink();
                                }
                                
                                final payment = paymentSnapshot.data;
                                final netSalary = _selectedMonth!.monthlySalary - _selectedMonth!.totalAdvances;
                                
                                if (payment != null) {
                                  // Maaş ödendi
                                  final remainingAmount = netSalary - payment.paidAmount;
                                  if (remainingAmount <= 0.01) {
                                    // Hesap bitti
                                    return Column(
                                      children: [
                                        const Divider(color: AppColors.textGray),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppColors.statusCompleted.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppColors.statusCompleted),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.check_circle, color: AppColors.statusCompleted, size: 20),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Hesap Bitti - Alacak Yok',
                                                      style: TextStyle(
                                                        color: AppColors.statusCompleted,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Ödenen: ${payment.paidAmount.toStringAsFixed(2)} ₺',
                                                      style: TextStyle(
                                                        color: AppColors.textGray,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    if (payment.paidDate != null) ...[
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        'Ödeme Tarihi: ${DateFormat('dd.MM.yyyy').format(payment.paidDate)}',
                                                        style: TextStyle(
                                                          color: AppColors.textGray,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  } else {
                                    // Kısmen ödendi
                                    return Column(
                                      children: [
                                        const Divider(color: AppColors.textGray),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppColors.statusWaiting.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppColors.statusWaiting),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.info_outline, color: AppColors.statusWaiting, size: 20),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Kalan Maaş: ${remainingAmount.toStringAsFixed(2)} ₺',
                                                      style: TextStyle(
                                                        color: AppColors.statusWaiting,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Ödenen: ${payment.paidAmount.toStringAsFixed(2)} ₺ / ${netSalary.toStringAsFixed(2)} ₺',
                                                      style: TextStyle(
                                                        color: AppColors.textGray,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    if (payment.paidDate != null) ...[
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        'Ödeme Tarihi: ${DateFormat('dd.MM.yyyy').format(payment.paidDate)}',
                                                        style: TextStyle(
                                                          color: AppColors.textGray,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                }
                                
                                // Maaş henüz ödenmedi ve admin notu da yok
                                return const SizedBox.shrink();
                              },
                            );
                          },
                        );
                      },
                    ),
                    // Prim Listesi
                    if (_selectedMonth!.totalBonus > 0)
                      Builder(
                        builder: (context) {
                          String targetUserId;
                          if (widget.userId != null) {
                            targetUserId = widget.userId!;
                          } else {
                            final authProvider = Provider.of<AuthProvider>(context, listen: false);
                            targetUserId = authProvider.user?.uid ?? '';
                          }
                          
                          if (targetUserId.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          
                          final monthStart = DateTime(_selectedMonth!.year, _selectedMonth!.month, 1);
                          
                          return StreamBuilder<List<BonusModel>>(
                            stream: _firestoreService.getUserBonuses(targetUserId),
                            builder: (context, bonusSnapshot) {
                              if (bonusSnapshot.connectionState == ConnectionState.waiting) {
                                return const SizedBox.shrink();
                              }
                              
                              final allBonuses = bonusSnapshot.data ?? [];
                              final monthBonuses = allBonuses.where((bonus) {
                                return bonus.month.year == monthStart.year && 
                                       bonus.month.month == monthStart.month;
                              }).toList();
                              
                              if (monthBonuses.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              
                              return Column(
                                children: [
                                  const Divider(color: AppColors.textGray),
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
                                          'Primler',
                                          style: TextStyle(
                                            color: AppColors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ...monthBonuses.map((bonus) {
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppColors.mediumGray,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.card_giftcard,
                                                  color: AppColors.statusCompleted,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        '${bonus.amount.toStringAsFixed(2)} ₺',
                                                        style: TextStyle(
                                                          color: AppColors.statusCompleted,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                      if (bonus.notes != null && bonus.notes!.isNotEmpty) ...[
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          bonus.notes!,
                                                          style: TextStyle(
                                                            color: AppColors.textGray,
                                                            fontSize: 11,
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildShiftHistoryView() {
    if (_selectedMonth == null) {
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
                  if (_selectedMonth != null) {
                    final currentIndex = _monthlyStats.indexOf(_selectedMonth!);
                    if (currentIndex > 0) {
                      setState(() {
                        _selectedMonth = _monthlyStats[currentIndex - 1];
                      });
                    }
                  }
                },
                color: AppColors.primaryOrange,
              ),
              Text(
                '${_getMonthName(_selectedMonth!.month)} ${_selectedMonth!.year} - Mesai Geçmişi',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  if (_selectedMonth != null) {
                    final currentIndex = _monthlyStats.indexOf(_selectedMonth!);
                    if (currentIndex < _monthlyStats.length - 1) {
                      setState(() {
                        _selectedMonth = _monthlyStats[currentIndex + 1];
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
          child: _selectedMonth!.dailyStats.isEmpty
              ? Center(
                  child: Text(
                    'Bu ay için mesai kaydı bulunmamaktadır.',
                    style: TextStyle(color: AppColors.textGray),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _selectedMonth!.dailyStats.length,
                  itemBuilder: (context, index) {
                    // En yeniden en eskiye sıralama için ters indeks
                    final reversedIndex = _selectedMonth!.dailyStats.length - 1 - index;
                    final daily = _selectedMonth!.dailyStats[reversedIndex];
                    return _buildDailyCard(daily);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildChartView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Çalışma Saatleri Grafiği
            _buildHoursChart(),
            const SizedBox(height: 24),
            
            // Son 6 Ay Toplam Maaşlar
            _buildTotalSalaryChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildHoursChart() {
    return Card(
      child: Container(
        color: AppColors.mediumGray,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(
              'Aylık Çalışma Saatleri',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _monthlyStats.isEmpty
                      ? 100
                      : (_monthlyStats.map((m) => m.totalHours).reduce((a, b) => a > b ? a : b) * 1.2).ceilToDouble().clamp(0.0, double.infinity),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => AppColors.primaryOrange,
                      tooltipRoundedRadius: 8,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final month = _monthlyStats[group.x.toInt()];
                        return BarTooltipItem(
                          '${month.totalHours.toStringAsFixed(1)} saat',
                          TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < _monthlyStats.length) {
                            final month = _monthlyStats[value.toInt()];
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${_getMonthName(month.month).substring(0, 3)}',
                                style: TextStyle(
                                  color: AppColors.textGray,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: AppColors.textGray,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: AppColors.textGray.withOpacity(0.1),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _monthlyStats.asMap().entries.map((entry) {
                    final index = entry.key;
                    final month = entry.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: month.totalHours,
                          color: AppColors.primaryOrange,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildTotalSalaryChart() {
    return Card(
      child: Container(
        color: AppColors.mediumGray,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Son 6 Ay Toplam Maaşlar',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _monthlyStats.isEmpty
                        ? 10000
                        : (_monthlyStats.map((m) => m.monthlySalary).reduce((a, b) => a > b ? a : b) * 1.2).ceilToDouble(),
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (group) => AppColors.primaryOrange,
                        tooltipRoundedRadius: 8,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final month = _monthlyStats[group.x.toInt()];
                          return BarTooltipItem(
                            '${month.monthlySalary.toStringAsFixed(2)} ₺',
                            TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= 0 && value.toInt() < _monthlyStats.length) {
                              final month = _monthlyStats[value.toInt()];
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '${_getMonthName(month.month).substring(0, 3)}',
                                  style: TextStyle(
                                    color: AppColors.textGray,
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${(value / 1000).toStringAsFixed(0)}K',
                              style: TextStyle(
                                color: AppColors.textGray,
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: AppColors.textGray.withOpacity(0.1),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: _monthlyStats.asMap().entries.map((entry) {
                      final index = entry.key;
                      final month = entry.value;
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: month.monthlySalary,
                            color: AppColors.primaryOrange,
                            width: 20,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
              color: isTotal ? AppColors.primaryOrange : AppColors.white,
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
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
                    DateFormat('dd MMMM yyyy EEEE', 'tr_TR').format(daily.date),
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

  // Takvim görünümü (salt görüntüleme)
  Widget _buildCalendarView() {
    String targetUserId;
    if (widget.userId != null) {
      targetUserId = widget.userId!;
    } else {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      targetUserId = authProvider.user?.uid ?? '';
    }

    if (targetUserId.isEmpty) {
      return Center(
        child: Text(
          'Kullanıcı bilgisi bulunamadı',
          style: TextStyle(color: AppColors.textGray),
        ),
      );
    }

    return _WorkerCalendarView(userId: targetUserId);
  }

}

// Takvim görünümü widget'ı (salt görüntüleme)
class _WorkerCalendarView extends StatefulWidget {
  final String userId;

  const _WorkerCalendarView({required this.userId});

  @override
  State<_WorkerCalendarView> createState() => _WorkerCalendarViewState();
}

class _WorkerCalendarViewState extends State<_WorkerCalendarView> {
  final FirestoreService _firestoreService = FirestoreService();
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  
  Map<DateTime, List<dynamic>> _events = {};
  List<ShiftModel> _shifts = [];
  List<TransactionModel> _transactions = [];
  bool _localeInitialized = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR', null).then((_) {
      if (mounted) {
        setState(() {});
      }
    });
    _loadData();
  }

  Future<void> _loadData() async {
    // Shifts ve transactions'ı dinle
    _firestoreService.getUserShifts(widget.userId).listen((shifts) {
      if (mounted) {
        setState(() {
          _shifts = shifts;
          _updateEvents();
        });
      }
    });

    _firestoreService.getUserTransactions(widget.userId).listen((transactions) {
      if (mounted) {
        setState(() {
          _transactions = transactions;
          _updateEvents();
        });
      }
    });
  }

  void _updateEvents() {
    _events = {};
    
    // Shifts ekle
    for (var shift in _shifts) {
      final date = DateTime(shift.date.year, shift.date.month, shift.date.day);
      if (!_events.containsKey(date)) {
        _events[date] = [];
      }
      _events[date]!.add({'type': 'shift', 'data': shift});
    }

    // Transactions ekle
    for (var transaction in _transactions) {
      if (transaction.type == 'advance') {
        final date = DateTime(transaction.date.year, transaction.date.month, transaction.date.day);
        if (!_events.containsKey(date)) {
          _events[date] = [];
        }
        _events[date]!.add({'type': 'transaction', 'data': transaction});
      }
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return _events[date] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final dayEvents = _getEventsForDay(_selectedDay);
    final shifts = dayEvents.where((e) => e['type'] == 'shift').map((e) => e['data'] as ShiftModel).toList();
    final transactions = dayEvents.where((e) => e['type'] == 'transaction').map((e) => e['data'] as TransactionModel).toList();

    return Column(
      children: [
        // Takvim
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.mediumGray,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            eventLoader: _getEventsForDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            locale: 'tr_TR',
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              weekendTextStyle: TextStyle(color: AppColors.textGray),
              defaultTextStyle: TextStyle(color: AppColors.white),
              selectedDecoration: BoxDecoration(
                color: AppColors.primaryOrange,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: AppColors.primaryOrange.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              markersMaxCount: 0,
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (BuildContext context, DateTime date, DateTime focusedDay) {
                final events = _getEventsForDay(date);
                return _buildDayCell(date, events);
              },
              todayBuilder: (BuildContext context, DateTime date, DateTime focusedDay) {
                final events = _getEventsForDay(date);
                return _buildDayCell(date, events, isToday: true);
              },
              selectedBuilder: (BuildContext context, DateTime date, DateTime focusedDay) {
                final events = _getEventsForDay(date);
                return _buildDayCell(date, events, isSelected: true);
              },
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              formatButtonShowsNext: false,
              formatButtonDecoration: BoxDecoration(
                color: AppColors.primaryOrange,
                borderRadius: BorderRadius.circular(8),
              ),
              formatButtonTextStyle: TextStyle(color: AppColors.white),
              titleTextStyle: TextStyle(color: AppColors.white, fontSize: 16),
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
            },
          ),
        ),

        // Seçilen günün detayları (salt görüntüleme - düzenleme butonları yok)
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.mediumGray,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('dd MMMM yyyy EEEE', 'tr_TR').format(_selectedDay),
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Mesai bilgileri
                  if (shifts.isNotEmpty) ...[
                    Text(
                      'Mesai Bilgileri',
                      style: TextStyle(
                        color: AppColors.primaryOrange,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...shifts.map((shift) => _buildShiftInfo(shift)),
                    const SizedBox(height: 16),
                  ] else ...[
                    Text(
                      'Bu gün için mesai kaydı bulunmamaktadır.',
                      style: TextStyle(color: AppColors.textGray),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Para çekme bilgileri
                  Text(
                    'Para Çekme İşlemleri',
                    style: TextStyle(
                      color: AppColors.statusWaiting,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (transactions.isNotEmpty) ...[
                    ...transactions.map((transaction) => _buildTransactionInfo(transaction)),
                  ] else ...[
                    Text(
                      'Bu gün için para çekme işlemi bulunmamaktadır.',
                      style: TextStyle(color: AppColors.textGray),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShiftInfo(ShiftModel shift) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkGray,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, color: AppColors.primaryOrange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Giriş: ${DateFormat('HH:mm').format(shift.startTime)}',
                style: TextStyle(color: AppColors.white),
              ),
            ],
          ),
          if (shift.endTime != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.logout, color: AppColors.primaryOrange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Çıkış: ${DateFormat('HH:mm').format(shift.endTime!)}',
                  style: TextStyle(color: AppColors.white),
                ),
              ],
            ),
          ],
          if (shift.totalHours != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.timer, color: AppColors.primaryOrange, size: 20),
                const SizedBox(width: 8),
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
                  Icon(Icons.note, color: AppColors.textGray, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      shift.note!,
                      style: TextStyle(
                        color: AppColors.textGray,
                        fontSize: 12,
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
    );
  }

  Widget _buildTransactionInfo(TransactionModel transaction) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkGray,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet, color: AppColors.statusWaiting, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${transaction.amount.toStringAsFixed(2)} ₺',
                  style: TextStyle(
                    color: AppColors.statusWaiting,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (transaction.description.isNotEmpty)
                  Text(
                    transaction.description,
                    style: TextStyle(color: AppColors.textGray, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(DateTime date, List<dynamic> events, {bool isToday = false, bool isSelected = false}) {
    final dateKey = DateTime(date.year, date.month, date.day);
    final dayShifts = _shifts.where((shift) {
      final shiftDate = DateTime(shift.date.year, shift.date.month, shift.date.day);
      return shiftDate == dateKey;
    }).toList();

    // O gün için para çekimlerini bul
    final dayTransactions = _transactions.where((transaction) {
      if (transaction.type != 'advance') return false;
      final transactionDate = DateTime(transaction.date.year, transaction.date.month, transaction.date.day);
      return transactionDate == dateKey;
    }).toList();

    // O gün çekilen toplam para
    double totalAdvance = 0;
    for (var transaction in dayTransactions) {
      totalAdvance += transaction.amount;
    }

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primaryOrange
            : isToday
                ? AppColors.primaryOrange.withOpacity(0.5)
                : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                color: isSelected || isToday ? AppColors.white : AppColors.white,
                fontSize: 12,
                fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            // Giriş-çıkış saatlerini göster
            if (dayShifts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: dayShifts.take(1).map((shift) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('HH:mm').format(shift.startTime),
                          style: TextStyle(
                            color: isSelected || isToday ? AppColors.white : AppColors.primaryOrange,
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (shift.endTime != null)
                          Text(
                            DateFormat('HH:mm').format(shift.endTime!),
                            style: TextStyle(
                              color: isSelected || isToday ? AppColors.white : AppColors.statusCompleted,
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            // Para çekimi bilgisi
            if (totalAdvance > 0)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  '${totalAdvance.toStringAsFixed(0)}₺',
                  style: TextStyle(
                    color: isSelected || isToday ? AppColors.white : AppColors.statusWaiting,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
