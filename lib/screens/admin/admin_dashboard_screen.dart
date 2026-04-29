import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_colors.dart';
import 'admin_orders_screen.dart';
import 'admin_personnel_screen.dart';
import 'admin_daily_sales_screen.dart';
import 'admin_companies_screen.dart';
import 'admin_customers_screen.dart';
import 'admin_trash_screen.dart';
import 'send_notification_screen.dart';
import 'scheduled_notifications_screen.dart';
import 'app_version_management_screen.dart';
import '../../widgets/stats_card.dart';
import '../../widgets/weather_widget.dart';
import '../../services/firestore_service.dart';
import '../../models/trash_model.dart';
import 'dart:async';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  final FirestoreService _firestoreService = FirestoreService();

  final List<Widget> _screens = [
    const DashboardTab(),
    const AdminOrdersScreen(),
    const AdminPersonnelScreen(),
    const AdminDailySalesScreen(),
    const AdminCompaniesScreen(),
    const AdminCustomersScreen(),
  ];

  // Çöp kutusundaki öğe sayısını stream olarak döndür
  Stream<int> _getTrashCountStream() {
    return _firestoreService.getAllTrash().map((trashList) => trashList.length);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardProvider>(context, listen: false).loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'Yönetici Paneli',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
        ),
        backgroundColor: AppColors.mediumGray,
        foregroundColor: AppColors.white,
        actions: [
          const WeatherWidget(),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.schedule),
            tooltip: 'Zamanlanmış Bildirimler',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ScheduledNotificationsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Versiyon Yönetimi',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AppVersionManagementScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active),
            tooltip: 'Bildirim Gönder',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SendNotificationScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.delete_outline),
                StreamBuilder<int>(
                  stream: _getTrashCountStream(),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    if (count == 0) return const SizedBox.shrink();
                    return Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                        child: Text(
                          count > 9 ? '9+' : count.toString(),
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            tooltip: 'Çöp Kutusu',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminTrashScreen(),
                ),
              );
            },
          ),
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
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        backgroundColor: AppColors.mediumGray,
        selectedItemColor: AppColors.primaryOrange,
        unselectedItemColor: AppColors.textGray,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Özet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Siparişler',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Personel',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: 'Günlük Satış',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business),
            label: 'Şirketler',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Müşteriler',
          ),
        ],
      ),
    );
  }
}

class DashboardTab extends StatefulWidget {
  const DashboardTab({Key? key}) : super(key: key);

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  bool _showOrdersHistory = false;
  bool _showSalaryHistory = false;
  String? _expandedMonthKey; // Genişletilmiş ay (YYYY-MM formatında)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardProvider>(context, listen: false).loadStats();
      Provider.of<DashboardProvider>(context, listen: false).loadLast6MonthsStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;


    return RefreshIndicator(
      onRefresh: () async {
        final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
        await dashboardProvider.loadStats();
        await dashboardProvider.loadLast6MonthsStats();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hoş Geldiniz Mesajı
            if (user != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  // Gradient arka plan
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryOrange.withOpacity(0.15),
                      AppColors.primaryOrange.withOpacity(0.05),
                      AppColors.mediumGray.withOpacity(0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primaryOrange.withOpacity(0.3),
                    width: 1,
                  ),
                  // Gölge efekti
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryOrange.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.admin_panel_settings,
                      size: 48,
                      color: AppColors.primaryOrange,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Hoş geldiniz ${user.name}',
                      style: GoogleFonts.poppins(
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

            Consumer<DashboardProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                return Column(
                  children: [
                    // Siparişler - Tıklanabilir
                    InkWell(
                      onTap: () {
                        setState(() {
                          _showOrdersHistory = !_showOrdersHistory;
                        });
                      },
                      child: Card(
                        elevation: 4,
                        shadowColor: Colors.black.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            // Gradient arka plan
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.mediumGray,
                                AppColors.mediumGray.withOpacity(0.8),
                                AppColors.lightGray.withOpacity(0.6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.receipt_long,
                                            color: AppColors.primaryOrange,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            '${provider.monthName} Siparişleri',
                                            style: GoogleFonts.poppins(
                                              color: AppColors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: [
                                          _buildOrderStat(
                                            'Bekleyen',
                                            '${provider.pendingOrders}',
                                            AppColors.statusWaiting,
                                          ),
                                          _buildOrderStat(
                                            'Tamamlanan',
                                            '${provider.completedOrders}',
                                            AppColors.statusCompleted,
                                          ),
                                          _buildOrderStat(
                                            'Teslim Edilen',
                                            '${provider.deliveredOrders}',
                                            AppColors.primaryOrange,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  _showOrdersHistory
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: AppColors.primaryOrange,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Son 6 Ay Sipariş Listesi
                    if (_showOrdersHistory && provider.last6MonthsData.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ...provider.last6MonthsData.map((monthData) {
                        final stats = monthData['stats'] as Map<String, dynamic>;
                        final monthName = monthData['month_name'] as String;
                        final year = monthData['year'] as int;
                        final month = monthData['month'] as DateTime;
                        final note = monthData['note'] as String?;
                        return Card(
                          color: AppColors.mediumGray,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ExpansionTile(
                            leading: Icon(
                              Icons.receipt_long,
                              color: AppColors.primaryOrange,
                            ),
                            title: Text(
                              '$monthName $year',
                              style: TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                note != null ? Icons.note : Icons.note_add,
                                color: note != null ? AppColors.primaryOrange : AppColors.textGray,
                              ),
                              onPressed: () => _showMonthlyNoteDialog(context, year, month.month, monthName, note),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Bekleyen: ${stats['pending_orders'] ?? 0}',
                                          style: TextStyle(
                                            color: AppColors.statusWaiting,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          'Tamamlanan: ${stats['completed_orders'] ?? 0}',
                                          style: TextStyle(
                                            color: AppColors.statusCompleted,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          'Teslim Edilen: ${stats['delivered_orders'] ?? 0}',
                                          style: TextStyle(
                                            color: AppColors.primaryOrange,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (note != null && note.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.darkGray,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: AppColors.primaryOrange.withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.note,
                                              color: AppColors.primaryOrange,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                note,
                                                style: TextStyle(
                                                  color: AppColors.white,
                                                  fontSize: 14,
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
                            ],
                          ),
                        );
                      }).toList(),
                    ],

                    const SizedBox(height: 16),

                    // Maaş - Tıklanabilir
                    StatsCard(
                      title: '${provider.monthName} Ödenen Maaş',
                      value: '${provider.monthlyPayments.toStringAsFixed(2)} ₺',
                      icon: Icons.payments,
                      color: AppColors.statusCompleted,
                      onTap: () {
                        setState(() {
                          _showSalaryHistory = !_showSalaryHistory;
                        });
                      },
                    ),

                    // Eleman Bazında Maaş Detayları
                    if (provider.employeePayments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        margin: const EdgeInsets.only(left: 16, right: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.darkGray,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.textGray.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Eleman Bazında Ödemeler:',
                              style: TextStyle(
                                color: AppColors.textGray,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...provider.employeePayments.map((employee) {
                              final name = employee['name'] as String;
                              final amount = (employee['amount'] as num).toDouble();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          color: AppColors.white,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '${amount.toStringAsFixed(2)} ₺',
                                      style: TextStyle(
                                        color: AppColors.statusCompleted,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
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

                    // Son 6 Ay Maaş Listesi
                    if (_showSalaryHistory && provider.last6MonthsData.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ...provider.last6MonthsData.map((monthData) {
                        final stats = monthData['stats'] as Map<String, dynamic>;
                        final monthName = monthData['month_name'] as String;
                        final year = monthData['year'] as int;
                        final month = monthData['month'] as DateTime;
                        final monthlyPayments = (stats['monthly_payments'] ?? 0.0).toDouble();
                        final employeePayments = (stats['employee_payments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                        final monthKey = '${year}-${month.month.toString().padLeft(2, '0')}';
                        final isExpanded = _expandedMonthKey == monthKey;

                        return Card(
                          color: AppColors.mediumGray,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ExpansionTile(
                            leading: Icon(
                              Icons.attach_money,
                              color: AppColors.statusCompleted,
                            ),
                            title: Text(
                              '$monthName $year',
                              style: TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${monthlyPayments.toStringAsFixed(2)} ₺',
                                  style: TextStyle(
                                    color: AppColors.statusCompleted,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  isExpanded ? Icons.expand_less : Icons.expand_more,
                                  color: AppColors.primaryOrange,
                                ),
                              ],
                            ),
                            onExpansionChanged: (expanded) {
                              setState(() {
                                _expandedMonthKey = expanded ? monthKey : null;
                              });
                            },
                            children: [
                              // Eleman Bazında Ödemeler
                              if (employeePayments.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.darkGray,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.textGray.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Eleman Bazında Ödemeler:',
                                          style: TextStyle(
                                            color: AppColors.textGray,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ...employeePayments.map((employee) {
                                          final name = employee['name'] as String;
                                          final amount = (employee['amount'] as num).toDouble();
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 6),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    name,
                                                    style: TextStyle(
                                                      color: AppColors.white,
                                                      fontSize: 13,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Text(
                                                  '${amount.toStringAsFixed(2)} ₺',
                                                  style: TextStyle(
                                                    color: AppColors.statusCompleted,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                    ),
                                  ),
                                ),
                              ] else ...[
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    'Bu ay için ödeme kaydı bulunmamaktadır.',
                                    style: TextStyle(
                                      color: AppColors.textGray,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ],

                    const SizedBox(height: 24),

                    // En Çok Maaş Alan Personeller
                    if (provider.topUsers.isNotEmpty) ...[
                      Text(
                        'En Çok Maaş Alan Personeller (${provider.monthName})',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...provider.topUsers.asMap().entries.map((entry) {
                        int index = entry.key;
                        Map<String, dynamic> user = entry.value;
                        String name = user['name'] as String;
                        double amount = (user['amount'] as num).toDouble();
                        
                        return Card(
                          color: AppColors.mediumGray,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primaryOrange,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              name,
                              style: TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: Text(
                              '${amount.toStringAsFixed(2)} ₺',
                              style: TextStyle(
                                color: AppColors.statusCompleted,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: AppColors.textGray,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Future<void> _showMonthlyNoteDialog(
    BuildContext context,
    int year,
    int month,
    String monthName,
    String? existingNote,
  ) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    
    if (user == null || user.role != 'admin') {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sadece adminler not ekleyebilir'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final noteController = TextEditingController(text: existingNote ?? '');
    final firestoreService = FirestoreService();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.mediumGray,
        title: Text(
          '$monthName $year Notu',
          style: TextStyle(color: AppColors.white),
        ),
        content: TextField(
          controller: noteController,
          style: TextStyle(color: AppColors.white),
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Bu ay için not ekleyin...',
            hintStyle: TextStyle(color: AppColors.textGray),
            filled: true,
            fillColor: AppColors.darkGray,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.textGray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.primaryOrange),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              noteController.dispose();
              Navigator.pop(dialogContext);
            },
            child: Text(
              'İptal',
              style: TextStyle(color: AppColors.textGray),
            ),
          ),
          TextButton(
            onPressed: () async {
              final note = noteController.text.trim();
              try {
                await firestoreService.saveMonthlyOrderNote(
                  year: year,
                  month: month,
                  note: note,
                  createdBy: user.uid,
                );
                noteController.dispose();
                if (context.mounted) {
                  Navigator.pop(dialogContext);
                  // Dashboard'ı yenile
                  Provider.of<DashboardProvider>(context, listen: false).loadLast6MonthsStats();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Not kaydedildi'),
                      backgroundColor: AppColors.statusCompleted,
                    ),
                  );
                }
              } catch (e) {
                noteController.dispose();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Not kaydedilirken hata: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: Text(
              'Kaydet',
              style: TextStyle(color: AppColors.primaryOrange),
            ),
          ),
        ],
      ),
    );
  }
}
