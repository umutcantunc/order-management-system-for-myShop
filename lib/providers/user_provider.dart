import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';

class UserProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  
  List<UserModel> _users = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<List<UserModel>>? _usersSubscription;

  List<UserModel> get users => _users;
  bool get isLoading => _isLoading;
  String? get error => _error;

  @override
  void dispose() {
    _usersSubscription?.cancel();
    super.dispose();
  }

  Future<void> loadUsers() async {
    // Zaten yükleniyorsa tekrar yükleme
    if (_isLoading) return;
    
    // Önceki subscription'ı iptal et
    await _usersSubscription?.cancel();
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _usersSubscription = _firestoreService.getAllUsers().listen(
        (users) {
          _users = users;
          _isLoading = false;
          notifyListeners();
        },
        onError: (error) {
          _error = error.toString();
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _firestoreService.updateUser(uid, data);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      throw e;
    }
  }

  UserModel? getUserById(String uid) {
    try {
      return _users.firstWhere((user) => user.uid == uid);
    } catch (e) {
      return null;
    }
  }
}
