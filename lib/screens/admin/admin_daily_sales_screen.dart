import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../constants/app_colors.dart';
import '../../models/daily_sales_model.dart';
import '../../services/firestore_service.dart';
import 'daily_sales_form_screen.dart';

class AdminDailySalesScreen extends StatefulWidget {
  const AdminDailySalesScreen({Key? key}) : super(key: key);

  @override
  State<AdminDailySalesScreen> createState() => _AdminDailySalesScreenState();
}

class _AdminDailySalesScreenState extends State<AdminDailySalesScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _showLast6Months = false;
  bool _localeInitialized = false;
  String? _selectedMonthKey; // Seçili ay (yyyy-MM formatında)

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

  Future<void> _showDeleteDialog(BuildContext context, DailySalesModel dailySales) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.mediumGray,
          title: Text(
            'Günlük Satışı Sil',
            style: TextStyle(color: AppColors.white),
          ),
          content: Text(
            '${DateFormat('dd.MM.yyyy').format(dailySales.date)} tarihli satış kaydını silmek istediğinizden emin misiniz?',
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
        await _firestoreService.deleteDailySales(dailySales.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Günlük satış başarıyla silindi'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      body: Column(
        children: [
          // Başlık ve Filtre
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Günlük Satışlar',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showLast6Months = !_showLast6Months;
                    });
                  },
                  icon: Icon(
                    _showLast6Months ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.primaryOrange,
                  ),
                  label: Text(
                    _showLast6Months ? 'Son 6 Ay' : 'Tüm Zamanlar',
                    style: TextStyle(color: AppColors.primaryOrange),
                  ),
                ),
              ],
            ),
          ),

          // Günlük Satış Listesi
          Expanded(
            child: _showLast6Months
                ? FutureBuilder<List<DailySalesModel>>(
                    future: _firestoreService.getLast6MonthsDailySales(),
                    builder: (context, snapshot) {
                      return _buildSalesList(snapshot);
                    },
                  )
                : StreamBuilder<List<DailySalesModel>>(
                    stream: _firestoreService.getAllDailySales(),
                    builder: (context, snapshot) {
                      return _buildSalesList(snapshot);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DailySalesFormScreen(),
            ),
          );
        },
        backgroundColor: AppColors.primaryOrange,
        child: const Icon(Icons.add, color: AppColors.white),
      ),
    );
  }

  Widget _buildSalesList(AsyncSnapshot<List<DailySalesModel>> snapshot) {
    if (!_localeInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return Center(
        child: Text(
          'Hata: ${snapshot.error}',
          style: TextStyle(color: AppColors.error),
        ),
      );
    }

    final dailySales = snapshot.data ?? [];

    if (dailySales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 64,
              color: AppColors.textGray,
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz satış kaydı yok',
              style: TextStyle(
                color: AppColors.textGray,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // Eğer bir ay seçilmişse, sadece o ayın günlerini göster
    if (_selectedMonthKey != null) {
      final selectedMonthSales = dailySales.where((sale) {
        String saleMonthKey = DateFormat('yyyy-MM').format(sale.date);
        return saleMonthKey == _selectedMonthKey;
      }).toList();

      if (selectedMonthSales.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long,
                size: 64,
                color: AppColors.textGray,
              ),
              const SizedBox(height: 16),
              Text(
                'Bu ay için satış kaydı yok',
                style: TextStyle(
                  color: AppColors.textGray,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedMonthKey = null;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                ),
                child: const Text('Geri Dön'),
              ),
            ],
          ),
        );
      }

      // Günlere göre sırala (en yeni önce)
      selectedMonthSales.sort((a, b) => b.date.compareTo(a.date));

      double monthCashTotal = 0;
      double monthCardTotal = 0;
      for (var sale in selectedMonthSales) {
        monthCashTotal += sale.cashAmount;
        monthCardTotal += sale.cardAmount;
      }
      double monthTotal = monthCashTotal + monthCardTotal;

      DateTime monthDate = DateTime.parse('$_selectedMonthKey-01');
      String monthName = DateFormat('MMMM yyyy', 'tr_TR').format(monthDate);

      return Column(
        children: [
          // Ay Bilgisi ve Geri Dön Butonu
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.mediumGray,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: AppColors.primaryOrange),
                      onPressed: () {
                        setState(() {
                          _selectedMonthKey = null;
                        });
                      },
                    ),
                    Expanded(
                      child: Text(
                        monthName,
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          'Nakit',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${monthCashTotal.toStringAsFixed(2)} ₺',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          'Kart',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${monthCardTotal.toStringAsFixed(2)} ₺',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          'Toplam',
                          style: TextStyle(
                            color: AppColors.primaryOrange,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${monthTotal.toStringAsFixed(2)} ₺',
                          style: TextStyle(
                            color: AppColors.primaryOrange,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Günlük Satış Listesi
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: selectedMonthSales.length,
              itemBuilder: (context, index) {
                final sale = selectedMonthSales[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: AppColors.mediumGray,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DailySalesFormScreen(
                            dailySales: sale,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  DateFormat('dd MMMM yyyy EEEE', 'tr_TR').format(sale.date),
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit, color: AppColors.primaryOrange),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DailySalesFormScreen(
                                            dailySales: sale,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: AppColors.error),
                                    onPressed: () => _showDeleteDialog(context, sale),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (sale.notes != null && sale.notes!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              sale.notes!,
                              style: TextStyle(
                                color: AppColors.textGray,
                                fontSize: 14,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    'Nakit',
                                    style: TextStyle(
                                      color: AppColors.textGray,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${sale.cashAmount.toStringAsFixed(2)} ₺',
                                    style: TextStyle(
                                      color: AppColors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Text(
                                    'Kart',
                                    style: TextStyle(
                                      color: AppColors.textGray,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${sale.cardAmount.toStringAsFixed(2)} ₺',
                                    style: TextStyle(
                                      color: AppColors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Text(
                                    'Toplam',
                                    style: TextStyle(
                                      color: AppColors.primaryOrange,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${sale.amount.toStringAsFixed(2)} ₺',
                                    style: TextStyle(
                                      color: AppColors.primaryOrange,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    // Yıl bazında grupla, sonra ay bazında
    Map<int, Map<String, List<DailySalesModel>>> groupedByYearAndMonth = {};
    for (var sale in dailySales) {
      int year = sale.date.year;
      String monthKey = DateFormat('yyyy-MM').format(sale.date);
      
      if (!groupedByYearAndMonth.containsKey(year)) {
        groupedByYearAndMonth[year] = {};
      }
      if (!groupedByYearAndMonth[year]!.containsKey(monthKey)) {
        groupedByYearAndMonth[year]![monthKey] = [];
      }
      groupedByYearAndMonth[year]![monthKey]!.add(sale);
    }

    // Yılları sırala (en yeni önce)
    final sortedYears = groupedByYearAndMonth.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    // Toplam hesapla
    double totalCashAmount = 0;
    double totalCardAmount = 0;
    for (var sale in dailySales) {
      totalCashAmount += sale.cashAmount;
      totalCardAmount += sale.cardAmount;
    }
    double totalAmount = totalCashAmount + totalCardAmount;

    return Column(
      children: [
        // Toplam Kartı
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.mediumGray,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primaryOrange.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _showLast6Months
                        ? 'Son 6 Ay Toplam'
                        : 'Toplam Gelir',
                    style: TextStyle(
                      color: AppColors.textGray,
                      fontSize: 14,
                    ),
                  ),
                  Icon(
                    Icons.account_balance_wallet,
                    color: AppColors.primaryOrange,
                    size: 32,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Nakit',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${totalCashAmount.toStringAsFixed(2)} ₺',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: AppColors.textGray.withOpacity(0.3),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Kart',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${totalCardAmount.toStringAsFixed(2)} ₺',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: AppColors.textGray.withOpacity(0.3),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Toplam',
                          style: TextStyle(
                            color: AppColors.primaryOrange,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${totalAmount.toStringAsFixed(2)} ₺',
                          style: TextStyle(
                            color: AppColors.primaryOrange,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Yıl bazında ListView
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sortedYears.length,
            itemBuilder: (context, yearIndex) {
              int year = sortedYears[yearIndex];
              Map<String, List<DailySalesModel>> yearMonths =
                  groupedByYearAndMonth[year]!;

              // Yılın aylarını sırala (en yeni önce)
              final sortedYearMonths = yearMonths.keys.toList()
                ..sort((a, b) => b.compareTo(a));

              // Yıl toplamı
              double yearCashTotal = 0;
              double yearCardTotal = 0;
              for (var monthKey in sortedYearMonths) {
                for (var sale in yearMonths[monthKey]!) {
                  yearCashTotal += sale.cashAmount;
                  yearCardTotal += sale.cardAmount;
                }
              }
              double yearTotal = yearCashTotal + yearCardTotal;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                color: AppColors.darkGray,
                child: ExpansionTile(
                  title: Text(
                    '$year Yılı',
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Text(
                    '${sortedYearMonths.length} ay • Nakit: ${yearCashTotal.toStringAsFixed(2)} ₺ • Kart: ${yearCardTotal.toStringAsFixed(2)} ₺ • Toplam: ${yearTotal.toStringAsFixed(2)} ₺',
                    style: TextStyle(
                      color: AppColors.primaryOrange,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  children: sortedYearMonths.map((monthKey) {
                    List<DailySalesModel> monthSales =
                        yearMonths[monthKey]!;

                    // Ay adını al
                    DateTime monthDate = DateTime.parse('$monthKey-01');
                    String monthName = DateFormat('MMMM yyyy', 'tr_TR')
                        .format(monthDate);

                    // Ay toplamı
                    double monthCashTotal = 0;
                    double monthCardTotal = 0;
                    for (var sale in monthSales) {
                      monthCashTotal += sale.cashAmount;
                      monthCardTotal += sale.cardAmount;
                    }
                    double monthTotal = monthCashTotal + monthCardTotal;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      color: AppColors.mediumGray,
                      child: ListTile(
                        title: Text(
                          monthName,
                          style: TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${monthSales.length} gün • Nakit: ${monthCashTotal.toStringAsFixed(2)} ₺ • Kart: ${monthCardTotal.toStringAsFixed(2)} ₺ • Toplam: ${monthTotal.toStringAsFixed(2)} ₺',
                          style: TextStyle(color: AppColors.textGray, fontSize: 12),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: AppColors.primaryOrange,
                        ),
                        onTap: () {
                          setState(() {
                            _selectedMonthKey = monthKey;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
