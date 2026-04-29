import 'package:flutter/foundation.dart';
import '../services/firestore_service.dart';

class DashboardProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _last6MonthsData = [];
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic> get stats => _stats;
  List<Map<String, dynamic>> get last6MonthsData => _last6MonthsData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get activeShifts => _stats['active_shifts'] ?? 0;
  int get pendingOrders => _stats['pending_orders'] ?? 0;
  int get completedOrders => _stats['completed_orders'] ?? 0;
  int get deliveredOrders => _stats['delivered_orders'] ?? 0;
  double get monthlyPayments => (_stats['monthly_payments'] ?? 0).toDouble();
  String get monthName => _stats['month_name'] ?? '';
  List<Map<String, dynamic>> get topUsers {
    final topUsers = _stats['top_users'] as List?;
    return topUsers?.cast<Map<String, dynamic>>() ?? [];
  }

  List<Map<String, dynamic>> get employeePayments {
    final employeePayments = _stats['employee_payments'] as List?;
    return employeePayments?.cast<Map<String, dynamic>>() ?? [];
  }

  Future<void> loadStats({DateTime? selectedMonth}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _stats = await _firestoreService.getDashboardStats(selectedMonth: selectedMonth);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadLast6MonthsStats() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _last6MonthsData = await _firestoreService.getLast6MonthsStats();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
}
