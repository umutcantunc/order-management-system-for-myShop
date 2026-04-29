import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../constants/app_colors.dart';
import '../../services/firestore_service.dart';
import '../../services/customer_statistics_service.dart';
import '../../models/customer_model.dart';
import '../../models/customer_statistics_model.dart';
import '../../models/order_model.dart';
import 'customer_form_screen.dart';
import 'customer_statistics_edit_screen.dart';
import 'order_image_viewer_screen.dart';
import '../../widgets/cached_network_image_widget.dart';

class AdminCustomersScreen extends StatefulWidget {
  const AdminCustomersScreen({Key? key}) : super(key: key);

  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final CustomerStatisticsService _statisticsService = CustomerStatisticsService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late TabController _tabController;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  DateTime _selectedMonth = DateTime.now();
  bool _localeInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        title: const Text('Müşteriler'),
        backgroundColor: AppColors.mediumGray,
        foregroundColor: AppColors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryOrange,
          unselectedLabelColor: AppColors.textGray,
          indicatorColor: AppColors.primaryOrange,
          tabs: const [
            Tab(text: 'Liste'),
            Tab(text: 'Takvim'),
            Tab(text: 'Tablo'),
            Tab(text: 'Grafik'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildListView(),
          _buildCalendarView(),
          _buildTableView(),
          _buildChartView(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CustomerFormScreen(),
                  ),
                );
              },
              backgroundColor: AppColors.primaryOrange,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildListView() {
    return Column(
      children: [
        // Arama çubuğu
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
            style: TextStyle(color: AppColors.white),
            decoration: InputDecoration(
              hintText: 'Müşteri adı, telefon veya adres ile ara...',
              hintStyle: TextStyle(color: AppColors.textGray),
              prefixIcon: Icon(Icons.search, color: AppColors.textGray),
              filled: true,
              fillColor: AppColors.mediumGray,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // Müşteri listesi
        Expanded(
          child: StreamBuilder<List<CustomerModel>>(
            stream: _firestoreService.getAllCustomers(),
            builder: (context, snapshot) {
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

              final customers = snapshot.data ?? [];
              
              // Arama filtresi
              final filteredCustomers = customers.where((customer) {
                if (_searchQuery.isEmpty) return true;
                return customer.name.toLowerCase().contains(_searchQuery) ||
                    (customer.phone?.toLowerCase().contains(_searchQuery) ?? false) ||
                    (customer.address?.toLowerCase().contains(_searchQuery) ?? false);
              }).toList();

              if (filteredCustomers.isEmpty) {
                return Center(
                  child: Text(
                    'Müşteri bulunamadı',
                    style: TextStyle(color: AppColors.textGray),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredCustomers.length,
                itemBuilder: (context, index) {
                  final customer = filteredCustomers[index];
                  return _buildCustomerCard(context, customer);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _getFirstOrderInfo(CustomerModel customer) {
    if (customer.orderInfos.isEmpty) return '';
    
    // İlk siparişi bul (en eski teslim tarihine göre veya ilk sipariş)
    final firstOrder = customer.orderInfos.first;
    
    if (firstOrder.deliveredAt != null) {
      final year = firstOrder.deliveredAt!.year;
      return '$year - ${firstOrder.orderNumber}';
    } else {
      // Eğer deliveredAt yoksa, müşterinin oluşturulma tarihini kullan
      final year = customer.createdAt.year;
      return '$year - ${firstOrder.orderNumber}';
    }
  }

  Widget _buildCustomerCard(BuildContext context, CustomerModel customer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.mediumGray,
      child: ExpansionTile(
        title: Text(
          customer.name,
          style: TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: customer.orderInfos.isNotEmpty
            ? Text(
                _getFirstOrderInfo(customer),
                style: TextStyle(color: AppColors.textGray),
              )
            : null,
        trailing: IconButton(
          icon: Icon(Icons.delete, color: AppColors.error),
          onPressed: () => _showDeleteDialog(context, customer),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (customer.address != null && customer.address!.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on, color: AppColors.textGray, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          customer.address!,
                          style: TextStyle(color: AppColors.textGray),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (customer.notes != null && customer.notes!.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.note, color: AppColors.textGray, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          customer.notes!,
                          style: TextStyle(color: AppColors.textGray),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (customer.orderInfos.isNotEmpty) ...[
                  Text(
                    'Siparişler:',
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<OrderModel>>(
                    future: _getFullOrderDetails(customer.orderIds),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      
                      final orders = snapshot.data ?? [];
                      
                      // Eğer tam sipariş bilgileri yüklenemediyse, CustomerOrderInfo'dan göster
                      if (orders.isEmpty) {
                        return Column(
                          children: customer.orderInfos
                              .map((orderInfo) => _buildOrderInfoCard(orderInfo, customer.name))
                              .toList(),
                        );
                      }
                      
                      // Tam sipariş bilgilerini göster
                      return Column(
                        children: orders
                            .map((order) => _buildFullOrderCard(order, customer.name))
                            .toList(),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarView() {
    return StreamBuilder<List<CustomerModel>>(
      stream: _firestoreService.getAllCustomers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final customers = snapshot.data ?? [];
        Map<DateTime, int> _customersByDate = {};
        
        // Müşterileri tarihe göre grupla
        for (var customer in customers) {
          for (var orderInfo in customer.orderInfos) {
            if (orderInfo.deliveredAt != null) {
              final key = DateTime(
                orderInfo.deliveredAt!.year,
                orderInfo.deliveredAt!.month,
                orderInfo.deliveredAt!.day,
              );
              _customersByDate[key] = (_customersByDate[key] ?? 0) + 1;
            }
          }
        }

        return Column(
          children: [
            TableCalendar<int>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.monday,
              locale: 'tr_TR',
              eventLoader: (day) {
                final key = DateTime(day.year, day.month, day.day);
                return _customersByDate.containsKey(key) ? [_customersByDate[key]!] : [];
              },
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(color: AppColors.textGray),
                defaultTextStyle: TextStyle(color: AppColors.white),
                selectedTextStyle: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
                todayTextStyle: TextStyle(
                  color: AppColors.primaryOrange,
                  fontWeight: FontWeight.bold,
                ),
                selectedDecoration: BoxDecoration(
                  color: AppColors.primaryOrange,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: AppColors.primaryOrange.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: AppColors.primaryOrange,
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: AppColors.primaryOrange,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: AppColors.primaryOrange,
                ),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: AppColors.textGray),
                weekendStyle: TextStyle(color: AppColors.textGray),
              ),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
            ),
            
            // Seçili günün müşteri sayısı
            if (_customersByDate.containsKey(DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day)))
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.mediumGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_customersByDate[DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day)]} müşteri',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        );
      },
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
                  setState(() {
                    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                  });
                },
                color: AppColors.primaryOrange,
              ),
              Text(
                DateFormat('MMMM yyyy', 'tr_TR').format(_selectedMonth),
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                  });
                },
                color: AppColors.primaryOrange,
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<CustomerStatisticsModel>>(
            stream: _firestoreService.getCustomerStatisticsByMonth(_selectedMonth),
            builder: (context, snapshot) {
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

              final stats = snapshot.data ?? [];
              
              if (stats.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Bu ay için veri bulunamadı',
                        style: TextStyle(color: AppColors.textGray),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async {
                          await _statisticsService.calculateMonthlyStatistics(_selectedMonth);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('İstatistikler hesaplandı'),
                                backgroundColor: AppColors.statusCompleted,
                              ),
                            );
                          }
                        },
                        child: const Text('İstatistikleri Hesapla'),
                      ),
                    ],
                  ),
                );
              }

              // Toplam hesapla
              int totalCustomers = 0;
              double totalCash = 0.0;
              double totalCard = 0.0;
              double totalAmount = 0.0;
              
              for (var stat in stats) {
                totalCustomers += stat.customerCount;
                totalCash += stat.cashAmount;
                totalCard += stat.cardAmount;
                totalAmount += stat.totalAmount;
              }

              return Column(
                children: [
                  // Toplam özet
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.mediumGray,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow('Toplam Müşteri', totalCustomers.toString()),
                        const Divider(color: AppColors.textGray),
                        _buildSummaryRow('Toplam Nakit', '${totalCash.toStringAsFixed(2)} ₺'),
                        const Divider(color: AppColors.textGray),
                        _buildSummaryRow('Toplam Kart', '${totalCard.toStringAsFixed(2)} ₺'),
                        const Divider(color: AppColors.textGray),
                        _buildSummaryRow('Toplam Gelir', '${totalAmount.toStringAsFixed(2)} ₺', isTotal: true),
                      ],
                    ),
                  ),
                  
                  // Günlük detaylar
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: stats.length,
                      itemBuilder: (context, index) {
                        final stat = stats[index];
                        return Card(
                          color: AppColors.mediumGray,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(
                              DateFormat('dd MMMM yyyy', 'tr_TR').format(stat.date),
                              style: TextStyle(color: AppColors.white),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Müşteri: ${stat.customerCount}'),
                                Text('Nakit: ${stat.cashAmount.toStringAsFixed(2)} ₺'),
                                Text('Kart: ${stat.cardAmount.toStringAsFixed(2)} ₺'),
                                Text('Toplam: ${stat.totalAmount.toStringAsFixed(2)} ₺'),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.edit, color: AppColors.primaryOrange),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CustomerStatisticsEditScreen(statistics: stat),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
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

  Widget _buildChartView() {
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
                  setState(() {
                    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                  });
                },
                color: AppColors.primaryOrange,
              ),
              Text(
                DateFormat('MMMM yyyy', 'tr_TR').format(_selectedMonth),
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                  });
                },
                color: AppColors.primaryOrange,
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<CustomerStatisticsModel>>(
            stream: _firestoreService.getCustomerStatisticsByMonth(_selectedMonth),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
                return Center(
                  child: Text(
                    'Veri bulunamadı',
                    style: TextStyle(color: AppColors.textGray),
                  ),
                );
              }

              final stats = snapshot.data!;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Müşteri sayısı grafiği
                    _buildCustomerCountChart(stats),
                    const SizedBox(height: 24),
                    // Gelir grafiği
                    _buildRevenueChart(stats),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerCountChart(List<CustomerStatisticsModel> stats) {
    return Card(
      color: AppColors.mediumGray,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Günlük Müşteri Sayısı',
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
                  maxY: stats.map((s) => s.customerCount.toDouble()).reduce((a, b) => a > b ? a : b) + 2,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < stats.length) {
                            return Text(
                              stats[value.toInt()].date.day.toString(),
                              style: TextStyle(color: AppColors.textGray, fontSize: 10),
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
                            style: TextStyle(color: AppColors.textGray, fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: stats.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.customerCount.toDouble(),
                          color: AppColors.primaryOrange,
                          width: 12,
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
    );
  }

  Widget _buildRevenueChart(List<CustomerStatisticsModel> stats) {
    return Card(
      color: AppColors.mediumGray,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Günlük Gelir (Nakit vs Kart)',
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
                  maxY: stats.map((s) => s.totalAmount).reduce((a, b) => a > b ? a : b) * 1.2,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < stats.length) {
                            return Text(
                              stats[value.toInt()].date.day.toString(),
                              style: TextStyle(color: AppColors.textGray, fontSize: 10),
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
                            '${(value / 1000).toStringAsFixed(1)}k',
                            style: TextStyle(color: AppColors.textGray, fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: stats.asMap().entries.map((entry) {
                    final stat = entry.value;
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: stat.cashAmount,
                          color: Colors.green,
                          width: 8,
                        ),
                        BarChartRodData(
                          toY: stat.cardAmount,
                          color: Colors.blue,
                          width: 8,
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Nakit', Colors.green),
                const SizedBox(width: 24),
                _buildLegendItem('Kart', Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: AppColors.textGray),
        ),
      ],
    );
  }


  // Müşteriye ait tam sipariş bilgilerini getir
  Future<List<OrderModel>> _getFullOrderDetails(List<String> orderIds) async {
    if (orderIds.isEmpty) return [];
    
    try {
      final orders = <OrderModel>[];
      for (final orderId in orderIds) {
        final orderDoc = await _firestoreService.getOrder(orderId);
        if (orderDoc != null) {
          orders.add(orderDoc);
        }
      }
      return orders;
    } catch (e) {
      debugPrint('Sipariş detayları alınırken hata: $e');
      return [];
    }
  }

  // Tam sipariş bilgilerini gösteren kart
  Widget _buildFullOrderCard(OrderModel order, String customerName) {
    return Card(
      color: AppColors.darkGray,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sipariş No: ${order.customOrderNumber}',
              style: TextStyle(
                color: AppColors.primaryOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (order.details.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Detaylar: ${order.details}',
                style: TextStyle(color: AppColors.textGray),
              ),
            ],
            if (order.productName != null && order.productName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Ürün: ${order.productName}',
                style: TextStyle(color: AppColors.white),
              ),
            ],
            if (order.productColor != null && order.productColor!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Renk: ${order.productColor}',
                style: TextStyle(color: AppColors.white),
              ),
            ],
            if (order.price != null && order.price! > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Fiyat: ${order.price!.toStringAsFixed(2)} ₺ (${order.paymentType ?? 'belirtilmemiş'})',
                style: TextStyle(color: AppColors.white),
              ),
            ],
            if (order.customerPhone != null && order.customerPhone!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.phone, color: AppColors.textGray, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    order.customerPhone!,
                    style: TextStyle(color: AppColors.textGray),
                  ),
                ],
              ),
            ],
            if (order.customerAddress != null && order.customerAddress!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on, color: AppColors.textGray, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.customerAddress!,
                      style: TextStyle(color: AppColors.textGray),
                    ),
                  ),
                ],
              ),
            ],
            if (order.createdByName != null) ...[
              const SizedBox(height: 4),
              Text(
                'Oluşturan: ${order.createdByName}',
                style: TextStyle(color: AppColors.textGray, fontSize: 12),
              ),
            ],
            if (order.completedByName != null) ...[
              const SizedBox(height: 4),
              Text(
                'Tamamlayan: ${order.completedByName}',
                style: TextStyle(color: AppColors.textGray, fontSize: 12),
              ),
            ],
            if (order.dueDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Teslim Tarihi: ${DateFormat('dd.MM.yyyy').format(order.dueDate!)}',
                style: TextStyle(color: AppColors.textGray, fontSize: 12),
              ),
            ],
            if (order.deliveredAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Teslim Edildi: ${DateFormat('dd.MM.yyyy').format(order.deliveredAt!)}',
                style: TextStyle(color: AppColors.statusCompleted, fontSize: 12),
              ),
            ],
            if (order.createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Oluşturulma: ${DateFormat('dd.MM.yyyy HH:mm').format(order.createdAt)}',
                style: TextStyle(color: AppColors.textGray, fontSize: 12),
              ),
            ],
            if (order.photoUrl != null || order.drawingUrl != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (order.photoUrl != null)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OrderImageViewerScreen(
                                imageUrl: order.photoUrl!,
                                title: '$customerName - Fotoğraf',
                              ),
                            ),
                          );
                        },
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.mediumGray,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImageWidget(
                                  imageUrl: order.photoUrl!,
                                  width: double.infinity,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.darkGray.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    Icons.photo,
                                    color: AppColors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (order.photoUrl != null && order.drawingUrl != null)
                    const SizedBox(width: 8),
                  if (order.drawingUrl != null)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OrderImageViewerScreen(
                                imageUrl: order.drawingUrl!,
                                title: '$customerName - Kroki',
                              ),
                            ),
                          );
                        },
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.mediumGray,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImageWidget(
                                  imageUrl: order.drawingUrl!,
                                  width: double.infinity,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.darkGray.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    Icons.draw,
                                    color: AppColors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // CustomerOrderInfo'dan basit sipariş kartı (fallback)
  Widget _buildOrderInfoCard(CustomerOrderInfo orderInfo, String customerName) {
    return Card(
      color: AppColors.darkGray,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sipariş No: ${orderInfo.orderNumber}',
              style: TextStyle(
                color: AppColors.primaryOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (orderInfo.details != null && orderInfo.details!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                orderInfo.details!,
                style: TextStyle(color: AppColors.textGray),
              ),
            ],
            if (orderInfo.price != null && orderInfo.price! > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Fiyat: ${orderInfo.price!.toStringAsFixed(2)} ₺ (${orderInfo.paymentType ?? 'belirtilmemiş'})',
                style: TextStyle(color: AppColors.white),
              ),
            ],
            if (orderInfo.photoUrl != null || orderInfo.drawingUrl != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (orderInfo.photoUrl != null)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OrderImageViewerScreen(
                                imageUrl: orderInfo.photoUrl!,
                                title: '$customerName - Fotoğraf',
                              ),
                            ),
                          );
                        },
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.mediumGray,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImageWidget(
                                  imageUrl: orderInfo.photoUrl!,
                                  width: double.infinity,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.darkGray.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    Icons.photo,
                                    color: AppColors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (orderInfo.photoUrl != null && orderInfo.drawingUrl != null)
                    const SizedBox(width: 8),
                  if (orderInfo.drawingUrl != null)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OrderImageViewerScreen(
                                imageUrl: orderInfo.drawingUrl!,
                                title: '$customerName - Kroki',
                              ),
                            ),
                          );
                        },
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.mediumGray,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImageWidget(
                                  imageUrl: orderInfo.drawingUrl!,
                                  width: double.infinity,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.darkGray.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    Icons.draw,
                                    color: AppColors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context, CustomerModel customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.mediumGray,
        title: Text(
          'Müşteriyi Sil',
          style: TextStyle(color: AppColors.white),
        ),
        content: Text(
          '${customer.name} müşterisini silmek istediğinizden emin misiniz?',
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
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await _firestoreService.deleteCustomer(customer.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Müşteri başarıyla silindi'),
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
}
