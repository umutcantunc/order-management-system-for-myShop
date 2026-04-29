import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../providers/shift_provider.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_colors.dart';
import '../../services/firestore_service.dart';
import '../../widgets/weather_widget.dart';
import 'worker_orders_screen.dart';
import 'request_advance_screen.dart';
import 'worker_calendar_screen.dart';
import 'worker_statistics_screen.dart';

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({Key? key}) : super(key: key);

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user != null) {
        Provider.of<ShiftProvider>(context, listen: false)
            .loadCurrentShift(authProvider.user!.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        title: const Text('Personel Paneli'),
        backgroundColor: AppColors.mediumGray,
        foregroundColor: AppColors.white,
        actions: [
          const WeatherWidget(),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış Yap',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppColors.mediumGray,
                  title: Text(
                    'Çıkış Yap',
                    style: TextStyle(color: AppColors.white),
                  ),
                  content: Text(
                    'Çıkış yapmak istediğinizden emin misiniz?',
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
                        'Çıkış Yap',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                await Provider.of<AuthProvider>(context, listen: false).signOut();
              }
            },
          ),
        ],
      ),
      body: _selectedIndex == 0
          ? const MesaiTab()
          : _selectedIndex == 1
              ? const WorkerCalendarScreen()
              : _selectedIndex == 2
                  ? const WorkerOrdersScreen()
                  : const WorkerStatisticsScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        backgroundColor: AppColors.mediumGray,
        selectedItemColor: AppColors.primaryOrange,
        unselectedItemColor: AppColors.textGray,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: 'Mesai',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Takvim',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work),
            label: 'Siparişler',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'İstatistikler',
          ),
        ],
      ),
    );
  }
}

class MesaiTab extends StatefulWidget {
  const MesaiTab({Key? key}) : super(key: key);

  @override
  State<MesaiTab> createState() => _MesaiTabState();
}

class _MesaiTabState extends State<MesaiTab> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _localeInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeLocale();
  }

  Future<void> _initializeLocale() async {
    await initializeDateFormatting('tr_TR', null);
    if (mounted) {
      setState(() {
        _localeInitialized = true;
      });
    }
  }

  Future<Map<String, dynamic>> _calculateCurrentMonthSalary(String userId, int? salaryDay, double? monthlySalary) async {
    // Maaş gününe göre ay başlangıç ve bitiş tarihlerini hesapla
    int salaryDayValue = salaryDay ?? 1; // Varsayılan olarak 1. gün
    
    // Şu anki ay için maaş dönemini hesapla
    DateTime now = DateTime.now();
    int currentMonth = now.month;
    int currentYear = now.year;
    
    // Maaş gününe göre dönem başlangıcı
    DateTime periodStart;
    if (now.day >= salaryDayValue) {
      // Bu ayın maaş günü geçtiyse, dönem bu ayın maaş gününden başlar
      periodStart = DateTime(currentYear, currentMonth, salaryDayValue);
    } else {
      // Bu ayın maaş günü henüz gelmediyse, dönem geçen ayın maaş gününden başlar
      if (currentMonth == 1) {
        periodStart = DateTime(currentYear - 1, 12, salaryDayValue);
      } else {
        periodStart = DateTime(currentYear, currentMonth - 1, salaryDayValue);
      }
    }
    
    // Dönem bitişi: Bir sonraki ayın maaş gününden bir gün öncesi
    DateTime periodEnd;
    if (now.day >= salaryDayValue) {
      // Maaş günü geçtiyse, dönem bir sonraki ayın maaş gününden bir gün öncesine kadar
      if (currentMonth == 12) {
        periodEnd = DateTime(currentYear + 1, 1, salaryDayValue - 1, 23, 59, 59);
      } else {
        periodEnd = DateTime(currentYear, currentMonth + 1, salaryDayValue - 1, 23, 59, 59);
      }
    } else {
      // Maaş günü henüz gelmediyse, dönem bu ayın maaş gününden bir gün öncesine kadar
      periodEnd = DateTime(currentYear, currentMonth, salaryDayValue - 1, 23, 59, 59);
    }

    // Bu dönemdeki avansları getir
    final transactions = await _firestoreService.getUserTransactions(userId).first;
    final periodAdvances = transactions.where((t) {
      return t.type == 'advance' &&
          t.date.isAfter(periodStart.subtract(const Duration(days: 1))) &&
          t.date.isBefore(periodEnd.add(const Duration(days: 1)));
    }).toList();

    double totalAdvances = 0;
    for (var transaction in periodAdvances) {
      totalAdvances += transaction.amount;
    }

    return {
      'totalAdvances': totalAdvances,
      'periodStart': periodStart,
      'periodEnd': periodEnd,
      'monthlySalary': monthlySalary ?? 0.0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final shiftProvider = Provider.of<ShiftProvider>(context);
    final user = authProvider.user;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Hoş Geldiniz Mesajı
            if (user != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primaryOrange.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.person,
                      size: 48,
                      color: AppColors.primaryOrange,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Hoş geldiniz ${user.name}',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],

            // Maaş Bilgileri
            if (user != null) ...[
              // Locale yüklenene kadar bekle
              if (!_localeInitialized)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppColors.mediumGray,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                )
              else
                FutureBuilder<Map<String, dynamic>>(
                  future: _calculateCurrentMonthSalary(
                    user.uid,
                    user.salaryDay,
                    user.monthlySalary,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: AppColors.mediumGray,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    }

                    final data = snapshot.data ?? {};
                    double totalAdvances = data['totalAdvances'] ?? 0.0;
                    double monthlySalary = data['monthlySalary'] ?? 0.0;
                    double remainingSalary = monthlySalary - totalAdvances;
                    DateTime? periodStart = data['periodStart'];
                    DateTime? periodEnd = data['periodEnd'];

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: AppColors.mediumGray,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primaryOrange.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet,
                                color: AppColors.primaryOrange,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Maaş Bilgileri',
                                      style: TextStyle(
                                        color: AppColors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (periodStart != null) ...[
                                      Text(
                                        '${DateFormat('MMMM yyyy', 'tr_TR').format(periodStart)}',
                                        style: TextStyle(
                                          color: AppColors.textGray,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (periodStart != null && periodEnd != null) ...[
                            Text(
                              'Dönem: ${DateFormat('dd.MM.yyyy').format(periodStart)} - ${DateFormat('dd.MM.yyyy').format(periodEnd)}',
                              style: TextStyle(
                                color: AppColors.textGray,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        _buildSalaryInfoRow(
                          'Aylık Maaş',
                          '${monthlySalary.toStringAsFixed(2)} ₺',
                          isHighlight: false,
                        ),
                        const SizedBox(height: 8),
                        _buildSalaryInfoRow(
                          'Bu Ay Çekilen Avans',
                          '-${totalAdvances.toStringAsFixed(2)} ₺',
                          isHighlight: false,
                          isNegative: true,
                        ),
                        const Divider(color: AppColors.textGray, height: 24),
                        _buildSalaryInfoRow(
                          'Kalan Maaş',
                          '${remainingSalary.toStringAsFixed(2)} ₺',
                          isHighlight: true,
                          isNegative: remainingSalary < 0,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],

            // Mevcut Mesai Durumu
            if (shiftProvider.hasActiveShift)
              Container(
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.only(bottom: 32),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryOrange, width: 2),
                ),
                child: Column(
                  children: [
                    Text(
                      'Mesai Başladı',
                      style: TextStyle(
                        color: AppColors.primaryOrange,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (shiftProvider.currentShift != null)
                      StreamBuilder<DateTime>(
                        stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox.shrink();
                          }

                          final now = snapshot.data!;
                          final startTime = shiftProvider.currentShift!.startTime;
                          final duration = now.difference(startTime);

                          final hours = duration.inHours;
                          final minutes = duration.inMinutes.remainder(60);
                          final seconds = duration.inSeconds.remainder(60);

                          return Text(
                            '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),

            // Maaş Avansı Butonu
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RequestAdvanceScreen(),
                    ),
                  );
                },
                icon: Icon(Icons.account_balance_wallet, color: AppColors.primaryOrange),
                label: Text(
                  'MAAŞ AVANSI TALEP ET',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryOrange,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.primaryOrange, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Mesai Başlat/Bitir Butonları
            SizedBox(
              width: double.infinity,
              height: 120,
              child: ElevatedButton(
                onPressed: () async {
                  if (shiftProvider.hasActiveShift) {
                    // Mesai Bitir
                    if (shiftProvider.currentShift != null) {
                      try {
                        await shiftProvider.endShift(shiftProvider.currentShift!.id);
                        // CurrentShift'i yeniden yükle
                        if (authProvider.user != null) {
                          await shiftProvider.loadCurrentShift(authProvider.user!.uid);
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Mesai sonlandırıldı'),
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
                  } else {
                    // Mesai Başlat
                    if (authProvider.user != null) {
                      try {
                        await shiftProvider.startShift(authProvider.user!.uid);
                        // CurrentShift'i yeniden yükle
                        await shiftProvider.loadCurrentShift(authProvider.user!.uid);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Mesai başlatıldı'),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: shiftProvider.hasActiveShift
                      ? AppColors.error
                      : AppColors.statusCompleted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  shiftProvider.hasActiveShift ? 'MESAİ BİTİR' : 'MESAİ BAŞLAT',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24), // Bottom padding for scroll
          ],
        ),
      ),
    );
  }

  Widget _buildSalaryInfoRow(String label, String value, {bool isHighlight = false, bool isNegative = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isHighlight ? AppColors.primaryOrange : AppColors.textGray,
            fontSize: isHighlight ? 16 : 14,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isNegative
                ? AppColors.error
                : (isHighlight ? AppColors.primaryOrange : AppColors.white),
            fontSize: isHighlight ? 18 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
