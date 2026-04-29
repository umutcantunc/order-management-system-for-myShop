import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:animations/animations.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/order_provider.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_colors.dart';
import '../../widgets/cached_network_image_widget.dart';
import '../../services/firestore_service.dart';
import '../../services/customer_statistics_service.dart';
import '../../models/customer_model.dart';
import 'order_form_screen.dart';
import 'order_image_viewer_screen.dart';
import '../../models/order_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({Key? key}) : super(key: key);

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  final FirestoreService _firestoreService = FirestoreService();
  bool _localeInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeLocale();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(context, listen: false).loadOrders();
    });
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'tamamlandı':
        return AppColors.statusCompleted;
      case 'teslim edildi':
        return Colors.green;
      case 'bekliyor':
        return AppColors.statusWaiting;
      default:
        return AppColors.mediumGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      body: Column(
        children: [
          // Arama ve Filtre
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Arama Çubuğu
                TextField(
                  onChanged: (value) {
                    Provider.of<OrderProvider>(context, listen: false)
                        .setSearchQuery(value);
                  },
                  style: TextStyle(color: AppColors.white),
                  decoration: InputDecoration(
                    hintText: 'Müşteri adı, telefon, sipariş no, ürün adı...',
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
                const SizedBox(height: 12),
                // Sıralama Filtresi
                Consumer<OrderProvider>(
                  builder: (context, provider, child) {
                    return Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Oluşturma Tarihi'),
                            selected: provider.sortBy == 'created_at',
                            onSelected: (selected) {
                              if (selected) {
                                provider.setSortBy('created_at');
                              }
                            },
                            selectedColor: AppColors.primaryOrange,
                            labelStyle: TextStyle(
                              color: provider.sortBy == 'created_at'
                                  ? AppColors.white
                                  : AppColors.textGray,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Teslim Tarihi'),
                            selected: provider.sortBy == 'due_date',
                            onSelected: (selected) {
                              if (selected) {
                                provider.setSortBy('due_date');
                              }
                            },
                            selectedColor: AppColors.primaryOrange,
                            labelStyle: TextStyle(
                              color: provider.sortBy == 'due_date'
                                  ? AppColors.white
                                  : AppColors.textGray,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // Tab Bar
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primaryOrange,
            unselectedLabelColor: AppColors.textGray,
            indicatorColor: AppColors.primaryOrange,
            tabs: const [
              Tab(text: 'Liste'),
              Tab(text: 'Takvim'),
            ],
          ),

          // Sipariş Listesi / Takvim
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Liste Görünümü
                Consumer<OrderProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final orders = provider.orders;

                    if (orders.isEmpty) {
                      return Center(
                        child: Text(
                          'Sipariş bulunamadı',
                          style: TextStyle(color: AppColors.textGray),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        // Staggered fade-in animasyonu
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 300 + (index * 50)),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 20 * (1 - value)),
                                child: child,
                              ),
                            );
                          },
                          child: _buildOrderCard(context, order, index),
                        );
                      },
                    );
                  },
                ),
                // Takvim Görünümü
                _buildCalendarView(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const OrderFormScreen(),
            ),
          );
        },
        backgroundColor: AppColors.primaryOrange,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, OrderModel order, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: _getStatusColor(order.status).withOpacity(0.2),
      child: OpenContainer(
        closedColor: Colors.transparent,
        openColor: AppColors.darkGray,
        transitionDuration: const Duration(milliseconds: 400),
        transitionType: ContainerTransitionType.fadeThrough,
        closedBuilder: (context, action) {
          return InkWell(
            onTap: action,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.customerName,
                              style: GoogleFonts.poppins(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sipariş No: ${order.customOrderNumber}',
                              style: GoogleFonts.poppins(
                                color: AppColors.textGray,
                                fontSize: 13,
                              ),
                            ),
                        if (order.createdByName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Ekleyen: ${order.createdByName}',
                            style: GoogleFonts.poppins(
                              color: AppColors.textGray,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          _localeInitialized
                              ? 'Oluşturulma: ${DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(order.createdAt)}'
                              : 'Oluşturulma: ${DateFormat('dd.MM.yyyy HH:mm').format(order.createdAt)}',
                          style: GoogleFonts.poppins(
                            color: AppColors.textGray,
                            fontSize: 11,
                          ),
                        ),
                        if (order.status == 'tamamlandı' && order.completedByName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Tamamlayan: ${order.completedByName}',
                            style: GoogleFonts.poppins(
                              color: AppColors.statusCompleted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(order.status),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _getStatusColor(order.status).withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          order.status.toUpperCase(),
                          style: GoogleFonts.poppins(
                            color: AppColors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Consumer<AuthProvider>(
                        builder: (context, authProvider, child) {
                          if (authProvider.isAdmin) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (order.status == 'teslim edildi' && !order.movedToCustomers)
                                  IconButton(
                                    icon: Icon(Icons.person_add, color: AppColors.primaryOrange),
                                    tooltip: 'Müşteriler Bölümüne Taşı',
                                    onPressed: () => _moveToCustomers(context, order),
                                  ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: AppColors.error),
                                  onPressed: () => _showDeleteOrderDialog(context, order),
                                ),
                              ],
                            );
                          }
                          return SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ],
              ),
              if (order.details.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  order.details,
                  style: GoogleFonts.poppins(
                    color: AppColors.textGray,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (order.dueDate != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Teslim: ${DateFormat('dd.MM.yyyy').format(order.dueDate!)}',
                  style: GoogleFonts.poppins(
                    color: AppColors.textGray,
                    fontSize: 12,
                  ),
                ),
              ],
              // Resim önizlemeleri
              if (order.photoUrl != null || order.drawingUrl != null) ...[
                const SizedBox(height: 12),
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
                                  title: '${order.customerName} - Fotoğraf',
                                  heroTag: 'photo_${order.id}',
                                ),
                              ),
                            );
                          },
                          child: Hero(
                            tag: 'photo_${order.id}',
                            child: Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.mediumGray,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImageWidget(
                                      imageUrl: order.photoUrl!,
                                      width: double.infinity,
                                      height: 80,
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
                                  title: '${order.customerName} - Kroki',
                                ),
                              ),
                            );
                          },
                          child: Hero(
                            tag: 'drawing_${order.id}',
                            child: Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.mediumGray,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImageWidget(
                                      imageUrl: order.drawingUrl!,
                                      width: double.infinity,
                                      height: 80,
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
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
        },
        openBuilder: (context, action) {
          return OrderFormScreen(order: order);
        },
      ),
    );
  }

  Future<void> _showDeleteOrderDialog(BuildContext context, OrderModel order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.mediumGray,
          title: Text(
            'Sipariş Sil',
            style: TextStyle(color: AppColors.white),
          ),
          content: Text(
            'Bu siparişi silmek istediğinizden emin misiniz?\n\n'
            'Müşteri: ${order.customerName}\n'
            'Sipariş No: ${order.customOrderNumber}',
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
        final orderProvider = Provider.of<OrderProvider>(context, listen: false);
        await orderProvider.deleteOrder(order.id);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sipariş başarıyla silindi'),
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

  Future<void> _moveToCustomers(BuildContext context, OrderModel order) async {
    try {
      // ÖNEMLİ: Sipariş asla silinmez, sadece movedToCustomers flag'i set edilir
      // Bu sayede veri kaybı olmaz ve veritabanı şişmez
      
      // Müşteriyi bul veya oluştur
      CustomerModel? customer;
      if (order.customerPhone != null && order.customerPhone!.isNotEmpty) {
        customer = await _firestoreService.getCustomerByPhone(order.customerPhone!);
      }

      // Sipariş bilgilerini hazırla (sadece referans, orijinal sipariş korunur)
      final orderInfo = CustomerOrderInfo(
        orderId: order.id,
        orderNumber: order.customOrderNumber,
        details: order.details.isNotEmpty ? order.details : null,
        photoUrl: order.photoUrl,
        drawingUrl: order.drawingUrl,
        price: order.price,
        paymentType: order.paymentType,
        deliveredAt: order.deliveredAt ?? DateTime.now(),
      );

      if (customer == null) {
        // Yeni müşteri oluştur
        final now = DateTime.now();
        customer = CustomerModel(
          id: '',
          name: order.customerName,
          phone: order.customerPhone,
          address: order.customerAddress,
          notes: 'Sipariş: ${order.customOrderNumber}',
          createdAt: now,
          updatedAt: now,
          orderIds: [order.id],
          orderInfos: [orderInfo],
        );
        final customerId = await _firestoreService.createCustomer(customer);
        customer = customer.copyWith(id: customerId);
      } else {
        // Mevcut müşteriyi güncelle
        final updatedOrderIds = [...customer.orderIds];
        final updatedOrderInfos = [...customer.orderInfos];
        
        if (!updatedOrderIds.contains(order.id)) {
          updatedOrderIds.add(order.id);
          updatedOrderInfos.add(orderInfo);
        } else {
          // Sipariş zaten varsa, bilgilerini güncelle
          final index = updatedOrderInfos.indexWhere((info) => info.orderId == order.id);
          if (index != -1) {
            updatedOrderInfos[index] = orderInfo;
          } else {
            updatedOrderInfos.add(orderInfo);
          }
        }
        
        await _firestoreService.updateCustomer(customer.id, {
          'order_ids': updatedOrderIds,
          'order_infos': updatedOrderInfos.map((info) => info.toMap()).toList(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      // Siparişi müşteriler bölümüne taşındı olarak işaretle
      // ÖNEMLİ: Sipariş silinmez, sadece flag set edilir
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      await orderProvider.updateOrder(order.id, {
        'moved_to_customers': true,
      });

      // İstatistikleri güncelle
      if (order.deliveredAt != null) {
        final statisticsService = CustomerStatisticsService();
        await statisticsService.calculateAndSaveDailyStatistics(order.deliveredAt!);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sipariş müşteriler bölümüne taşındı. Sipariş veritabanında korunuyor.'),
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

  Widget _buildCalendarView() {
    return Consumer<OrderProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = provider.orders;
        Map<DateTime, List<OrderModel>> _ordersByDate = {};
        
        // Siparişleri tarihe göre grupla
        for (var order in orders) {
          if (order.dueDate != null) {
            final key = DateTime(
              order.dueDate!.year,
              order.dueDate!.month,
              order.dueDate!.day,
            );
            if (_ordersByDate.containsKey(key)) {
              _ordersByDate[key]!.add(order);
            } else {
              _ordersByDate[key] = [order];
            }
          }
        }

        return Container(
          padding: const EdgeInsets.all(8),
          child: TableCalendar<OrderModel>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.monday,
            locale: 'tr_TR',
            eventLoader: (day) {
              final key = DateTime(day.year, day.month, day.day);
              return _ordersByDate[key] ?? [];
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
              // Custom builder kullandığımız için decoration'ları kaldırdık
              selectedDecoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, date, focusedDay) {
                final key = DateTime(date.year, date.month, date.day);
                final dayOrders = _ordersByDate[key] ?? [];
                final orderCount = dayOrders.length;
                return _buildDayCell(context, date, orderCount);
              },
              todayBuilder: (context, date, focusedDay) {
                final key = DateTime(date.year, date.month, date.day);
                final dayOrders = _ordersByDate[key] ?? [];
                final orderCount = dayOrders.length;
                return _buildDayCell(context, date, orderCount, isToday: true);
              },
              selectedBuilder: (context, date, focusedDay) {
                final key = DateTime(date.year, date.month, date.day);
                final dayOrders = _ordersByDate[key] ?? [];
                final orderCount = dayOrders.length;
                return _buildDayCell(context, date, orderCount, isSelected: true);
              },
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
        );
      },
    );
  }

  Widget _buildDayCell(BuildContext context, DateTime date, int orderCount, {bool isToday = false, bool isSelected = false}) {
    final isSameDaySelected = isSameDay(_selectedDay, date);
    final isSameDayToday = isSameDay(DateTime.now(), date);
    
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isSameDaySelected
            ? AppColors.primaryOrange
            : isSameDayToday
                ? AppColors.primaryOrange.withOpacity(0.3)
                : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              color: isSameDaySelected
                  ? AppColors.white
                  : isSameDayToday
                      ? AppColors.primaryOrange
                      : AppColors.white,
              fontWeight: isSameDaySelected || isSameDayToday ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
            ),
          ),
          if (orderCount > 0) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSameDaySelected ? AppColors.white : AppColors.primaryOrange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$orderCount',
                style: TextStyle(
                  color: isSameDaySelected ? AppColors.primaryOrange : AppColors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
