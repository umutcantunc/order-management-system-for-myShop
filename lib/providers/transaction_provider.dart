import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/firestore_service.dart';
import '../models/transaction_model.dart';

class TransactionProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  
  List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<List<TransactionModel>>? _transactionsSubscription;

  List<TransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  @override
  void dispose() {
    _transactionsSubscription?.cancel();
    super.dispose();
  }

  Future<void> loadUserTransactions(String userId) async {
    // Zaten yükleniyorsa tekrar yükleme
    if (_isLoading) return;
    
    // Önceki subscription'ı iptal et
    await _transactionsSubscription?.cancel();
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _transactionsSubscription = _firestoreService.getUserTransactions(userId).listen(
        (transactions) {
          _transactions = transactions;
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

  Future<void> loadAllTransactions() async {
    // Zaten yükleniyorsa tekrar yükleme
    if (_isLoading) return;
    
    // Önceki subscription'ı iptal et
    await _transactionsSubscription?.cancel();
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _transactionsSubscription = _firestoreService.getAllTransactions().listen(
        (transactions) {
          _transactions = transactions;
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

  Future<void> loadAdvanceTransactions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Önceki subscription'ı iptal et
      await _transactionsSubscription?.cancel();
      
      // İlk veriyi almak için first kullan
      final firstData = await _firestoreService.getAdvanceTransactions().first;
      _transactions = firstData;
      _isLoading = false;
      notifyListeners();

      // Sonra stream'i dinle
      _transactionsSubscription = _firestoreService.getAdvanceTransactions().listen(
        (transactions) {
          _transactions = transactions;
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

  Future<String> createTransaction(TransactionModel transaction) async {
    try {
      String transactionId = await _firestoreService.createTransaction(transaction);
      return transactionId;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      throw e;
    }
  }

  Future<void> updateTransaction(String transactionId, Map<String, dynamic> data) async {
    try {
      await _firestoreService.updateTransaction(transactionId, data);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      throw e;
    }
  }

  Future<void> deleteTransaction(String transactionId, {String? deletedBy}) async {
    try {
      await _firestoreService.deleteTransaction(transactionId, deletedBy: deletedBy);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      throw e;
    }
  }
}
