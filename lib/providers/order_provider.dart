import 'package:flutter/foundation.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../models/order_model.dart';

class OrderProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  
  List<OrderModel> _orders = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String sortBy = 'created_at'; // 'created_at' veya 'due_date'

  List<OrderModel> get orders => _filteredOrders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<OrderModel> get _filteredOrders {
    List<OrderModel> filtered = _orders;

    // Sadece müşteriler bölümüne taşınan siparişleri filtrele
    // "Teslim edildi" durumundaki siparişler görünmeye devam eder
    // Sadece admin "Müşteriler bölümüne taşı" butonuna basınca movedToCustomers = true olur
    filtered = filtered.where((order) => !order.movedToCustomers).toList();

    // Arama filtresi - tüm alanlarda arama
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((order) {
        return order.customerName.toLowerCase().contains(query) ||
            order.customOrderNumber.toLowerCase().contains(query) ||
            (order.customerPhone?.toLowerCase().contains(query) ?? false) ||
            (order.productName?.toLowerCase().contains(query) ?? false) ||
            (order.productColor?.toLowerCase().contains(query) ?? false) ||
            (order.customerAddress?.toLowerCase().contains(query) ?? false) ||
            order.details.toLowerCase().contains(query) ||
            order.status.toLowerCase().contains(query);
      }).toList();
    }

    // Sıralama
    filtered.sort((a, b) {
      if (sortBy == 'due_date') {
        DateTime? aDate = a.dueDate;
        DateTime? bDate = b.dueDate;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      } else {
        return b.createdAt.compareTo(a.createdAt);
      }
    });

    return filtered;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSortBy(String newSortBy) {
    sortBy = newSortBy;
    notifyListeners();
  }

  Future<void> loadOrders() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _firestoreService.getAllOrders().listen((orders) {
        _orders = orders;
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> createOrder(OrderModel order) async {
    try {
      String orderId = await _firestoreService.createOrder(order);
      return orderId;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      throw e;
    }
  }

  Future<void> updateOrder(String orderId, Map<String, dynamic> data) async {
    try {
      await _firestoreService.updateOrder(orderId, data);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      throw e;
    }
  }

  Future<String> uploadDrawingAndUpdateOrder(
      List<int> imageBytes, String orderId) async {
    if (!_storageService.isAvailable) {
      throw Exception('Firebase Storage etkin değil. Lütfen Firebase Console\'da Storage\'ı etkinleştirin.');
    }
    
    try {
      String drawingUrl =
          await _storageService.uploadDrawingFromBytes(imageBytes, orderId);
      await updateOrder(orderId, {'drawing_url': drawingUrl});
      return drawingUrl;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      // Storage hatası olsa bile hatayı fırlat
      if (e.toString().contains('Storage') || e.toString().contains('billing')) {
        throw Exception('Firebase Storage etkin değil. Lütfen Firebase Console\'da Storage\'ı etkinleştirin.');
      }
      throw e;
    }
  }

  Future<void> deleteOrder(String orderId, {String? deletedBy}) async {
    try {
      await _firestoreService.deleteOrder(orderId, deletedBy: deletedBy);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      throw e;
    }
  }
}
