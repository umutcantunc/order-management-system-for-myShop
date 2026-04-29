import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../providers/order_provider.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_colors.dart';
import '../../widgets/cached_network_image_widget.dart';
import '../admin/order_image_viewer_screen.dart';
import '../admin/order_form_screen.dart';
import '../../models/order_model.dart';

class WorkerOrdersScreen extends StatefulWidget {
  const WorkerOrdersScreen({Key? key}) : super(key: key);

  @override
  State<WorkerOrdersScreen> createState() => _WorkerOrdersScreenState();
}

class _WorkerOrdersScreenState extends State<WorkerOrdersScreen> {
  bool _localeInitialized = false;

  @override
  void initState() {
    super.initState();
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'Siparişler',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
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
          Expanded(
            child: Consumer2<OrderProvider, AuthProvider>(
              builder: (context, orderProvider, authProvider, child) {
                if (orderProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final currentUser = authProvider.user;
                final allOrders = orderProvider.orders;
                
                // Sadece kendine atanan siparişleri veya atanmamış siparişleri göster
                final orders = allOrders.where((order) {
                  // Eğer siparişe hiç personel atanmamışsa, herkes görebilir
                  if (order.assignedUserIds == null || order.assignedUserIds!.isEmpty) {
                    return true;
                  }
                  // Eğer kendine atanmışsa göster
                  if (currentUser != null && order.assignedUserIds!.contains(currentUser.uid)) {
                    return true;
                  }
                  return false;
                }).toList();

                if (orders.isEmpty) {
                  return Center(
                    child: Text(
                      'Sipariş bulunamadı',
                      style: TextStyle(color: AppColors.textGray),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _buildOrderCard(context, order);
                  },
                );
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
              builder: (context) => const OrderFormScreen(),
            ),
          ).then((_) {
            // Sipariş eklendikten sonra listeyi yenile
            Provider.of<OrderProvider>(context, listen: false).loadOrders();
          });
        },
        backgroundColor: AppColors.primaryOrange,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, OrderModel order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.mediumGray,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderFormScreen(order: order),
            ),
          ).then((_) {
            // Sipariş düzenlendikten sonra listeyi yenile
            Provider.of<OrderProvider>(context, listen: false).loadOrders();
          });
        },
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
                          style: TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sipariş No: ${order.customOrderNumber}',
                          style: TextStyle(color: AppColors.textGray),
                        ),
                        if (order.createdByName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Ekleyen: ${order.createdByName}',
                            style: TextStyle(
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
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 11,
                          ),
                        ),
                        if (order.status == 'tamamlandı' && order.completedByName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Tamamlayan: ${order.completedByName}',
                            style: TextStyle(
                              color: AppColors.statusCompleted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: order.status == 'tamamlandı'
                          ? AppColors.statusCompleted
                          : AppColors.statusWaiting,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      order.status.toUpperCase(),
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            if (order.details.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                order.details,
                style: TextStyle(color: AppColors.textGray),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (order.dueDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Teslim: ${DateFormat('dd.MM.yyyy').format(order.dueDate!)}',
                style: TextStyle(color: AppColors.textGray),
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
                              ),
                            ),
                          );
                        },
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.darkGray,
                            borderRadius: BorderRadius.circular(8),
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
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.darkGray,
                            borderRadius: BorderRadius.circular(8),
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
                ],
              ),
            ],
            ],
          ),
        ),
      ),
    );
  }
}
