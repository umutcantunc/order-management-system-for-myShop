import 'package:flutter/foundation.dart';
import '../services/firestore_service.dart';
import '../models/shift_model.dart';

class ShiftProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  
  ShiftModel? _currentShift;
  List<ShiftModel> _userShifts = [];
  bool _isLoading = false;
  String? _error;

  ShiftModel? get currentShift => _currentShift;
  List<ShiftModel> get userShifts => _userShifts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasActiveShift => _currentShift != null && _currentShift!.isActive;

  Future<void> loadCurrentShift(String userId) async {
    try {
      _currentShift = await _firestoreService.getActiveShiftForUser(userId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadUserShifts(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _firestoreService.getUserShifts(userId).listen((shifts) {
        _userShifts = shifts;
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> startShift(String userId) async {
    try {
      DateTime now = DateTime.now();
      ShiftModel shift = ShiftModel(
        id: '',
        userId: userId,
        startTime: now,
        isActive: true,
        date: DateTime(now.year, now.month, now.day),
      );

      String shiftId = await _firestoreService.createShift(shift);
      shift = ShiftModel(
        id: shiftId,
        userId: userId,
        startTime: now,
        isActive: true,
        date: DateTime(now.year, now.month, now.day),
      );

      _currentShift = shift;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      throw e;
    }
  }

  Future<void> endShift(String shiftId) async {
    try {
      if (_currentShift == null) return;

      DateTime endTime = DateTime.now();
      DateTime startTime = _currentShift!.startTime;
      double totalHours = endTime.difference(startTime).inMinutes / 60.0;

      await _firestoreService.updateShift(shiftId, {
        'end_time': endTime,
        'is_active': false,
        'total_hours': totalHours,
      });

      _currentShift = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      throw e;
    }
  }

  Future<void> updateShiftManually(
      String shiftId, Map<String, dynamic> data) async {
    try {
      await _firestoreService.updateShift(shiftId, data);
      // Eğer güncellenen shift aktif shift ise, currentShift'i güncelle
      if (_currentShift?.id == shiftId) {
        await loadCurrentShift(_currentShift!.userId);
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      throw e;
    }
  }

  Future<void> createShiftManually(ShiftModel shift) async {
    try {
      await _firestoreService.createShift(shift);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      throw e;
    }
  }

  Future<void> deleteShift(String shiftId, {String? deletedBy}) async {
    try {
      await _firestoreService.deleteShift(shiftId, deletedBy: deletedBy);
      // Eğer silinen shift aktif shift ise, currentShift'i temizle
      if (_currentShift?.id == shiftId) {
        _currentShift = null;
      }
      // Liste güncellenecek (stream sayesinde)
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      throw e;
    }
  }
}
