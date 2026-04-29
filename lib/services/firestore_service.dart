import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shift_model.dart';
import '../models/order_model.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';
import '../models/daily_sales_model.dart';
import '../models/company_model.dart';
import '../models/promissory_note_model.dart';
import '../models/scheduled_notification_model.dart';
import '../models/customer_model.dart';
import '../models/daily_sales_model.dart';
import '../models/customer_statistics_model.dart';
import '../models/bonus_model.dart';
import '../models/salary_payment_model.dart';
import '../models/monthly_salary_data_model.dart';
import '../models/trash_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache ayarları - Offline desteği ve performans için
  FirestoreService() {
    // Firestore settings zaten varsayılan olarak cache enabled
    // Ekstra optimizasyon için burada ayarlar yapılabilir
  }

  // === TRASH OPERATIONS (Çöp Kutusu) ===
  /// Veriyi çöp kutusuna taşır (soft delete)
  Future<void> moveToTrash({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
    String? deletedBy,
    String? description,
  }) async {
    try {
      // Orijinal veriyi çöp kutusuna kopyala
      final trashData = TrashModel(
        id: '',
        originalCollection: collection,
        originalId: documentId,
        data: data,
        deletedAt: DateTime.now(),
        deletedBy: deletedBy,
        description: description,
      );

      await _firestore.collection('trash').add(trashData.toMap());

      // Orijinal veriyi sil
      await _firestore.collection(collection).doc(documentId).delete();
    } catch (e) {
      throw Exception('Çöp kutusuna taşıma hatası: $e');
    }
  }

  /// Çöp kutusundaki tüm verileri getir
  Stream<List<TrashModel>> getAllTrash() {
    return _firestore
        .collection('trash')
        .orderBy('deleted_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TrashModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  /// Çöp kutusundan belirli bir koleksiyona ait verileri getir
  Stream<List<TrashModel>> getTrashByCollection(String collection) {
    return _firestore
        .collection('trash')
        .where('original_collection', isEqualTo: collection)
        .orderBy('deleted_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TrashModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  /// Çöp kutusundan veriyi geri yükle
  Future<void> restoreFromTrash(String trashId) async {
    try {
      final trashDoc = await _firestore.collection('trash').doc(trashId).get();
      if (!trashDoc.exists) {
        throw Exception('Çöp kutusunda veri bulunamadı');
      }

      final trash = TrashModel.fromMap(trashDoc.data() as Map<String, dynamic>, trashDoc.id);

      // Orijinal koleksiyona geri ekle
      await _firestore
          .collection(trash.originalCollection)
          .doc(trash.originalId)
          .set(trash.data);

      // Çöp kutusundan sil
      await _firestore.collection('trash').doc(trashId).delete();
    } catch (e) {
      throw Exception('Geri yükleme hatası: $e');
    }
  }

  /// Çöp kutusundan kalıcı olarak sil
  Future<void> permanentlyDeleteFromTrash(String trashId) async {
    await _firestore.collection('trash').doc(trashId).delete();
  }

  // === USER OPERATIONS ===
  Future<void> createUser(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<UserModel?> getUser(String uid) async {
    // Önce cache'den oku, yoksa server'dan al
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, uid);
      }
    } catch (e) {
      debugPrint('Kullanıcı verisi alma hatası: $e');
    }
    return null;
  }

  Stream<List<UserModel>> getAllUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  // === SHIFT OPERATIONS ===
  Future<String> createShift(ShiftModel shift) async {
    DocumentReference ref =
        await _firestore.collection('shifts').add(shift.toMap());
    return ref.id;
  }

  Future<void> updateShift(String shiftId, Map<String, dynamic> data) async {
    await _firestore.collection('shifts').doc(shiftId).update(data);
  }

  Future<void> deleteShift(String shiftId, {String? deletedBy}) async {
    try {
      // Önce veriyi al
      final shiftDoc = await _firestore.collection('shifts').doc(shiftId).get();
      if (!shiftDoc.exists) {
        throw Exception('Mesai kaydı bulunamadı');
      }

      final shiftData = shiftDoc.data() as Map<String, dynamic>;
      
      // Çöp kutusuna taşı
      await moveToTrash(
        collection: 'shifts',
        documentId: shiftId,
        data: shiftData,
        deletedBy: deletedBy,
        description: 'Mesai kaydı silindi',
      );
    } catch (e) {
      throw Exception('Mesai silme hatası: $e');
    }
  }

  Stream<List<ShiftModel>> getUserShifts(String userId) {
    return _firestore
        .collection('shifts')
        .where('user_id', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      List<ShiftModel> shifts = snapshot.docs
          .map((doc) => ShiftModel.fromMap(doc.data(), doc.id))
          .toList();
      // Tarihe göre sıralama, aynı tarihtekiler için start_time'a göre
      shifts.sort((a, b) {
        final dateCompare = b.date.compareTo(a.date);
        if (dateCompare != 0) return dateCompare;
        return b.startTime.compareTo(a.startTime);
      });
      return shifts;
    });
  }

  Stream<List<ShiftModel>> getActiveShifts() {
    return _firestore
        .collection('shifts')
        .where('is_active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ShiftModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<ShiftModel?> getActiveShiftForUser(String userId) async {
    QuerySnapshot snapshot = await _firestore
        .collection('shifts')
        .where('user_id', isEqualTo: userId)
        .where('is_active', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return ShiftModel.fromMap(
          snapshot.docs.first.data() as Map<String, dynamic>,
          snapshot.docs.first.id);
    }
    return null;
  }

  // === ORDER OPERATIONS ===
  Future<String> createOrder(OrderModel order) async {
    DocumentReference ref =
        await _firestore.collection('orders').add(order.toMap());
    return ref.id;
  }

  Future<void> updateOrder(String orderId, Map<String, dynamic> data) async {
    await _firestore.collection('orders').doc(orderId).update(data);
  }

  Future<void> deleteOrder(String orderId, {String? deletedBy}) async {
    try {
      // Önce veriyi al
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) {
        throw Exception('Sipariş bulunamadı');
      }

      final orderData = orderDoc.data() as Map<String, dynamic>;
      
      // Çöp kutusuna taşı
      await moveToTrash(
        collection: 'orders',
        documentId: orderId,
        data: orderData,
        deletedBy: deletedBy,
        description: 'Sipariş silindi - Müşteri: ${orderData['customer_name'] ?? 'Bilinmiyor'}',
      );
    } catch (e) {
      throw Exception('Sipariş silme hatası: $e');
    }
  }

  Future<OrderModel?> getOrder(String orderId) async {
    try {
      final doc = await _firestore.collection('orders').doc(orderId).get();
      if (doc.exists) {
        return OrderModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Sipariş getirme hatası: $e');
      return null;
    }
  }

  Stream<List<OrderModel>> getAllOrders() {
    return _firestore
        .collection('orders')
        .orderBy('created_at', descending: true)
        .limit(100) // Performans için limit ekle
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Stream<List<OrderModel>> getOrdersByStatus(String status) {
    return _firestore
        .collection('orders')
        .where('status', isEqualTo: status)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // === TRANSACTION OPERATIONS ===
  Future<String> createTransaction(TransactionModel transaction) async {
    DocumentReference ref =
        await _firestore.collection('transactions').add(transaction.toMap());
    return ref.id;
  }

  Stream<List<TransactionModel>> getUserTransactions(String userId) {
    return _firestore
        .collection('transactions')
        .where('user_id', isEqualTo: userId)
        .orderBy('date', descending: true)
        .limit(200) // Son 200 işlem yeterli
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) =>
              TransactionModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Stream<List<TransactionModel>> getAllTransactions() {
    return _firestore
        .collection('transactions')
        .orderBy('date', descending: true)
        .limit(200) // Son 200 işlem yeterli
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) =>
              TransactionModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Stream<List<TransactionModel>> getAdvanceTransactions() {
    return _firestore
        .collection('transactions')
        .where('type', isEqualTo: 'advance')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) =>
              TransactionModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> updateTransaction(String transactionId, Map<String, dynamic> data) async {
    await _firestore.collection('transactions').doc(transactionId).update(data);
  }

  Future<void> deleteTransaction(String transactionId, {String? deletedBy}) async {
    try {
      // Önce veriyi al
      final transactionDoc = await _firestore.collection('transactions').doc(transactionId).get();
      if (!transactionDoc.exists) {
        throw Exception('İşlem bulunamadı');
      }

      final transactionData = transactionDoc.data() as Map<String, dynamic>;
      
      // Çöp kutusuna taşı
      await moveToTrash(
        collection: 'transactions',
        documentId: transactionId,
        data: transactionData,
        deletedBy: deletedBy,
        description: 'İşlem silindi - Tip: ${transactionData['type'] ?? 'Bilinmiyor'}, Tutar: ${transactionData['amount'] ?? 0} ₺',
      );
    } catch (e) {
      throw Exception('İşlem silme hatası: $e');
    }
  }

  // === STATISTICS ===
  Future<Map<String, dynamic>> getDashboardStats({DateTime? selectedMonth}) async {
    DateTime now = DateTime.now();
    DateTime targetMonth = selectedMonth ?? now;
    
    // Aktif mesai sayısı
    QuerySnapshot activeShifts =
        await _firestore.collection('shifts').where('is_active', isEqualTo: true).get();

    // Tüm siparişleri al
    QuerySnapshot allOrdersSnapshot = await _firestore.collection('orders').get();
    List<OrderModel> allOrders = allOrdersSnapshot.docs
        .map((doc) => OrderModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();

    // Bu ayın bekleyen, tamamlanan ve teslim edilen siparişleri
    int pendingOrders = 0;
    int completedOrders = 0;
    int deliveredOrders = 0;
    
    for (var order in allOrders) {
      // Sipariş bu ay içinde oluşturulmuşsa
      if (order.createdAt.year == targetMonth.year && order.createdAt.month == targetMonth.month) {
        if (order.status == 'bekliyor') {
          pendingOrders++;
        } else if (order.status == 'tamamlandı') {
          completedOrders++;
        } else if (order.status == 'teslim edildi') {
          deliveredOrders++;
        }
      }
    }

    // Tüm personelleri ve transaction'ları al
    QuerySnapshot usersSnapshot = await _firestore.collection('users').get();
    List<Map<String, dynamic>> users = usersSnapshot.docs
        .map((doc) => {
              'uid': doc.id,
              ...doc.data() as Map<String, dynamic>,
            })
        .toList();

    QuerySnapshot allTransactionsSnapshot = await _firestore.collection('transactions').get();
    List<TransactionModel> allTransactions = allTransactionsSnapshot.docs
        .map((doc) => TransactionModel.fromMap(
            doc.data() as Map<String, dynamic>, doc.id))
        .toList();

    // Bu ay ödenen toplam maaş (avanslar) - her personelin maaş gününe göre
    double totalMonthlyPayments = 0;
    Map<String, double> userPayments = {}; // user_id -> toplam avans

    for (var userData in users) {
      String userId = userData['uid'] as String;
      int salaryDay = userData['salary_day'] as int? ?? 1;
      
      // Maaş dönemi hesapla
      DateTime periodStart;
      DateTime periodEnd;
      
      if (targetMonth.month == 12) {
        periodStart = DateTime(targetMonth.year, targetMonth.month, salaryDay);
        periodEnd = DateTime(targetMonth.year + 1, 1, salaryDay - 1, 23, 59, 59);
      } else {
        periodStart = DateTime(targetMonth.year, targetMonth.month, salaryDay);
        periodEnd = DateTime(targetMonth.year, targetMonth.month + 1, salaryDay - 1, 23, 59, 59);
      }

      // Bu dönemdeki avansları hesapla
      double userTotal = 0;
      for (var transaction in allTransactions) {
        if (transaction.userId == userId &&
            transaction.type == 'advance' &&
            transaction.date.isAfter(periodStart.subtract(const Duration(days: 1))) &&
            transaction.date.isBefore(periodEnd.add(const Duration(days: 1)))) {
          userTotal += transaction.amount;
        }
      }
      
      userPayments[userId] = userTotal;
      totalMonthlyPayments += userTotal;
    }

    // Personel sıralaması (en çok avans alanlar)
    List<Map<String, dynamic>> topUsers = [];
    for (var userData in users) {
      String userId = userData['uid'] as String;
      String userName = userData['name'] as String? ?? '';
      double userTotal = userPayments[userId] ?? 0;
      
      if (userTotal > 0) {
        topUsers.add({
          'name': userName,
          'amount': userTotal,
          'uid': userId,
        });
      }
    }
    
    // Büyükten küçüğe sırala
    topUsers.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

    // Tüm personellerin ödeme detayları (isim ve miktar)
    List<Map<String, dynamic>> employeePayments = [];
    for (var userData in users) {
      String userId = userData['uid'] as String;
      String userName = userData['name'] as String? ?? '';
      String userRole = userData['role'] as String? ?? '';
      double userTotal = userPayments[userId] ?? 0;
      
      // Sadece worker'ları göster ve ödeme alanları listele
      if (userRole == 'worker' && userTotal > 0) {
        employeePayments.add({
          'name': userName,
          'amount': userTotal,
          'uid': userId,
        });
      }
    }
    
    // İsme göre alfabetik sırala
    employeePayments.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    return {
      'active_shifts': activeShifts.docs.length,
      'pending_orders': pendingOrders,
      'completed_orders': completedOrders,
      'delivered_orders': deliveredOrders,
      'monthly_payments': totalMonthlyPayments,
      'month_name': _getMonthName(targetMonth.month),
      'target_month': targetMonth,
      'top_users': topUsers,
      'employee_payments': employeePayments, // Yeni eklendi
    };
  }

  String _getMonthName(int month) {
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık'
    ];
    return months[month - 1];
  }

  // Son 3 ay verilerini al
  Future<List<Map<String, dynamic>>> getLast6MonthsStats() async {
    DateTime now = DateTime.now();
    List<Map<String, dynamic>> monthsData = [];

    for (int i = 0; i < 6; i++) {
      DateTime month = DateTime(now.year, now.month - i, 1);
      Map<String, dynamic> stats = await getDashboardStats(selectedMonth: month);
      final monthKey = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      final note = await getMonthlyOrderNote(month.year, month.month);
      monthsData.add({
        'month': month,
        'month_name': _getMonthName(month.month),
        'year': month.year,
        'month_key': monthKey,
        'stats': stats,
        'note': note,
      });
    }

    return monthsData;
  }

  // Aya özel sipariş notunu getir
  Future<String?> getMonthlyOrderNote(int year, int month) async {
    try {
      final monthKey = '$year-${month.toString().padLeft(2, '0')}';
      final doc = await _firestore
          .collection('monthly_order_notes')
          .doc(monthKey)
          .get();
      
      if (doc.exists && doc.data() != null) {
        return doc.data()!['note'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Aylık sipariş notu getirme hatası: $e');
      return null;
    }
  }

  // Aya özel sipariş notunu kaydet
  Future<void> saveMonthlyOrderNote({
    required int year,
    required int month,
    required String note,
    String? createdBy,
  }) async {
    try {
      final monthKey = '$year-${month.toString().padLeft(2, '0')}';
      await _firestore.collection('monthly_order_notes').doc(monthKey).set({
        'year': year,
        'month': month,
        'note': note,
        'created_by': createdBy,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Aylık sipariş notu kaydetme hatası: $e');
      rethrow;
    }
  }

  // === DAILY SALES OPERATIONS ===
  Future<String> createDailySales(DailySalesModel dailySales) async {
    DocumentReference ref = await _firestore.collection('daily_sales').add(dailySales.toMap());
    return ref.id;
  }

  Future<void> updateDailySales(String id, Map<String, dynamic> data) async {
    await _firestore.collection('daily_sales').doc(id).update(data);
  }

  Future<void> deleteDailySales(String id, {String? deletedBy}) async {
    try {
      // Önce veriyi al
      final doc = await _firestore.collection('daily_sales').doc(id).get();
      if (!doc.exists) {
        throw Exception('Günlük satış bulunamadı');
      }

      final data = doc.data() as Map<String, dynamic>;
      
      // Çöp kutusuna taşı
      await moveToTrash(
        collection: 'daily_sales',
        documentId: id,
        data: data,
        deletedBy: deletedBy,
        description: 'Günlük satış silindi - Tarih: ${data['date'] != null ? (data['date'] as Timestamp).toDate().toString() : 'Bilinmiyor'}',
      );
    } catch (e) {
      throw Exception('Günlük satış silme hatası: $e');
    }
  }

  Stream<List<DailySalesModel>> getAllDailySales() {
    return _firestore
        .collection('daily_sales')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) =>               DailySalesModel.fromMap(
              doc.data(), doc.id))
          .toList();
    });
  }

  Future<List<DailySalesModel>> getLast6MonthsDailySales() async {
    DateTime now = DateTime.now();
    DateTime sixMonthsAgo = DateTime(now.year, now.month - 6, 1);

    QuerySnapshot snapshot = await _firestore
        .collection('daily_sales')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(sixMonthsAgo))
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => DailySalesModel.fromMap(
            doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<DailySalesModel?> getDailySalesByDate(DateTime date) async {
    DateTime startOfDay = DateTime(date.year, date.month, date.day);
    DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    QuerySnapshot snapshot = await _firestore
        .collection('daily_sales')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return DailySalesModel.fromMap(
          snapshot.docs.first.data() as Map<String, dynamic>,
          snapshot.docs.first.id);
    }
    return null;
  }

  // === COMPANY OPERATIONS ===
  Future<String> createCompany(CompanyModel company) async {
    DocumentReference ref = await _firestore.collection('companies').add(company.toMap());
    return ref.id;
  }

  Future<void> updateCompany(String id, Map<String, dynamic> data) async {
    data['updated_at'] = Timestamp.fromDate(DateTime.now());
    await _firestore.collection('companies').doc(id).update(data);
  }

  Future<void> deleteCompany(String id, {String? deletedBy}) async {
    try {
      // Önce veriyi al
      final doc = await _firestore.collection('companies').doc(id).get();
      if (!doc.exists) {
        throw Exception('Şirket bulunamadı');
      }

      final data = doc.data() as Map<String, dynamic>;
      
      // Çöp kutusuna taşı
      await moveToTrash(
        collection: 'companies',
        documentId: id,
        data: data,
        deletedBy: deletedBy,
        description: 'Şirket silindi - İsim: ${data['name'] ?? 'Bilinmiyor'}',
      );
    } catch (e) {
      throw Exception('Şirket silme hatası: $e');
    }
  }

  Stream<List<CompanyModel>> getAllCompanies() {
    return _firestore
        .collection('companies')
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) =>               CompanyModel.fromMap(
              doc.data(), doc.id))
          .toList();
    });
  }

  Future<CompanyModel?> getCompany(String id) async {
    DocumentSnapshot doc = await _firestore.collection('companies').doc(id).get();
    if (doc.exists) {
      return CompanyModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  // === PROMISSORY NOTE OPERATIONS ===
  Future<String> createPromissoryNote(PromissoryNoteModel note) async {
    try {
      // Verilerin doğru formatlandığından emin ol
      final noteData = note.toMap();
      
      // Tüm gerekli alanların mevcut olduğunu kontrol et
      if (noteData['company_id'] == null || noteData['company_id'].toString().isEmpty) {
        throw Exception('Şirket ID boş olamaz');
      }
      if (noteData['items'] == null || (noteData['items'] as List).isEmpty) {
        throw Exception('En az bir ürün eklenmelidir');
      }
      if (noteData['payment_schedule'] == null || (noteData['payment_schedule'] as List).isEmpty) {
        throw Exception('Ödeme planı boş olamaz');
      }
      
      // Firestore'a kaydet
      DocumentReference ref = await _firestore.collection('promissory_notes').add(noteData);
      
      // Kayıt başarılı, ID'yi döndür
      return ref.id;
    } catch (e) {
      throw Exception('Senet kaydedilirken hata oluştu: $e');
    }
  }

  Future<void> updatePromissoryNote(String id, Map<String, dynamic> data) async {
    try {
      // Güncelleme tarihini ekle
      data['updated_at'] = Timestamp.fromDate(DateTime.now());
      
      // Mevcut dokümanı kontrol et
      final docRef = _firestore.collection('promissory_notes').doc(id);
      final docSnapshot = await docRef.get();
      
      if (!docSnapshot.exists) {
        throw Exception('Güncellenecek senet bulunamadı');
      }
      
      // created_at alanını koru (güncelleme sırasında silinmemeli)
      if (!data.containsKey('created_at')) {
        final existingData = docSnapshot.data() as Map<String, dynamic>;
        if (existingData.containsKey('created_at')) {
          data['created_at'] = existingData['created_at'];
        }
      }
      
      // Verileri güncelle
      await docRef.update(data);
    } catch (e) {
      throw Exception('Senet güncellenirken hata oluştu: $e');
    }
  }

  Future<void> deletePromissoryNote(String id, {String? deletedBy}) async {
    try {
      // Silmeden önce dokümanın varlığını kontrol et
      final docRef = _firestore.collection('promissory_notes').doc(id);
      final docSnapshot = await docRef.get();
      
      if (!docSnapshot.exists) {
        throw Exception('Silinecek senet bulunamadı');
      }

      final data = docSnapshot.data() as Map<String, dynamic>;
      
      // Çöp kutusuna taşı
      await moveToTrash(
        collection: 'promissory_notes',
        documentId: id,
        data: data,
        deletedBy: deletedBy,
        description: 'Senet silindi - Şirket ID: ${data['company_id'] ?? 'Bilinmiyor'}',
      );
    } catch (e) {
      throw Exception('Senet silinirken hata oluştu: $e');
    }
  }

  Stream<List<PromissoryNoteModel>> getAllPromissoryNotes() {
    return _firestore
        .collection('promissory_notes')
        .orderBy('first_payment_date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) =>               PromissoryNoteModel.fromMap(
              doc.data(), doc.id))
          .toList();
    });
  }

  Stream<List<PromissoryNoteModel>> getPromissoryNotesByCompany(String companyId) {
    return _firestore
        .collection('promissory_notes')
        .where('company_id', isEqualTo: companyId)
        .orderBy('first_payment_date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) =>               PromissoryNoteModel.fromMap(
              doc.data(), doc.id))
          .toList();
    });
  }

  Future<PromissoryNoteModel?> getPromissoryNote(String id) async {
    DocumentSnapshot doc = await _firestore.collection('promissory_notes').doc(id).get();
    if (doc.exists) {
      return PromissoryNoteModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  // === SCHEDULED NOTIFICATION OPERATIONS ===
  Future<String> createScheduledNotification(ScheduledNotificationModel notification) async {
    DocumentReference ref = await _firestore
        .collection('scheduled_notifications')
        .add(notification.toMap());
    return ref.id;
  }

  Future<void> updateScheduledNotification(String id, Map<String, dynamic> data) async {
    await _firestore.collection('scheduled_notifications').doc(id).update(data);
  }

  Future<void> deleteScheduledNotification(String id, {String? deletedBy}) async {
    try {
      // Önce veriyi al
      final doc = await _firestore.collection('scheduled_notifications').doc(id).get();
      if (!doc.exists) {
        throw Exception('Zamanlanmış bildirim bulunamadı');
      }

      final data = doc.data() as Map<String, dynamic>;
      
      // Çöp kutusuna taşı
      await moveToTrash(
        collection: 'scheduled_notifications',
        documentId: id,
        data: data,
        deletedBy: deletedBy,
        description: 'Zamanlanmış bildirim silindi - Başlık: ${data['title'] ?? 'Bilinmiyor'}',
      );
    } catch (e) {
      throw Exception('Bildirim silme hatası: $e');
    }
  }

  Future<List<ScheduledNotificationModel>> getActiveScheduledNotifications() async {
    QuerySnapshot snapshot = await _firestore
        .collection('scheduled_notifications')
        .where('is_active', isEqualTo: true)
        .get();
    
    return snapshot.docs
        .map((doc) => ScheduledNotificationModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Stream<List<ScheduledNotificationModel>> getAllScheduledNotifications() {
    return _firestore
        .collection('scheduled_notifications')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ScheduledNotificationModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  Future<ScheduledNotificationModel?> getScheduledNotificationById(String id) async {
    DocumentSnapshot doc = await _firestore.collection('scheduled_notifications').doc(id).get();
    if (doc.exists) {
      return ScheduledNotificationModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  // === CUSTOMER OPERATIONS ===
  Future<String> createCustomer(CustomerModel customer) async {
    DocumentReference ref = await _firestore.collection('customers').add(customer.toMap());
    return ref.id;
  }

  Future<void> updateCustomer(String id, Map<String, dynamic> data) async {
    data['updated_at'] = FieldValue.serverTimestamp();
    await _firestore.collection('customers').doc(id).update(data);
  }

  Future<void> deleteCustomer(String id, {String? deletedBy}) async {
    try {
      // Önce veriyi al
      final doc = await _firestore.collection('customers').doc(id).get();
      if (!doc.exists) {
        throw Exception('Müşteri bulunamadı');
      }

      final data = doc.data() as Map<String, dynamic>;
      
      // Çöp kutusuna taşı
      await moveToTrash(
        collection: 'customers',
        documentId: id,
        data: data,
        deletedBy: deletedBy,
        description: 'Müşteri silindi - İsim: ${data['name'] ?? 'Bilinmiyor'}, Telefon: ${data['phone'] ?? 'Bilinmiyor'}',
      );
    } catch (e) {
      throw Exception('Müşteri silme hatası: $e');
    }
  }

  Stream<List<CustomerModel>> getAllCustomers() {
    return _firestore
        .collection('customers')
        .orderBy('name', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CustomerModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  Future<CustomerModel?> getCustomerById(String id) async {
    DocumentSnapshot doc = await _firestore.collection('customers').doc(id).get();
    if (doc.exists) {
      return CustomerModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  Future<CustomerModel?> getCustomerByPhone(String phone) async {
    QuerySnapshot snapshot = await _firestore
        .collection('customers')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();
    
    if (snapshot.docs.isNotEmpty) {
      return CustomerModel.fromMap(
        snapshot.docs.first.data() as Map<String, dynamic>,
        snapshot.docs.first.id,
      );
    }
    return null;
  }

  // === DAILY SALES OPERATIONS ===
  Future<String> createDailySale(DailySalesModel sale) async {
    DocumentReference ref = await _firestore.collection('daily_sales').add(sale.toMap());
    return ref.id;
  }

  Future<void> updateDailySale(String id, Map<String, dynamic> data) async {
    await _firestore.collection('daily_sales').doc(id).update(data);
  }

  Future<void> deleteDailySale(String id, {String? deletedBy}) async {
    try {
      // Önce veriyi al
      final doc = await _firestore.collection('daily_sales').doc(id).get();
      if (!doc.exists) {
        throw Exception('Günlük satış bulunamadı');
      }

      final data = doc.data() as Map<String, dynamic>;
      
      // Çöp kutusuna taşı
      await moveToTrash(
        collection: 'daily_sales',
        documentId: id,
        data: data,
        deletedBy: deletedBy,
        description: 'Günlük satış silindi - Tarih: ${data['date'] != null ? (data['date'] as Timestamp).toDate().toString() : 'Bilinmiyor'}',
      );
    } catch (e) {
      throw Exception('Günlük satış silme hatası: $e');
    }
  }

  // === CUSTOMER STATISTICS OPERATIONS ===
  Future<String> createOrUpdateCustomerStatistics(CustomerStatisticsModel stats) async {
    // Aynı tarih için mevcut kaydı kontrol et
    final dateKey = DateTime(stats.date.year, stats.date.month, stats.date.day);
    final querySnapshot = await _firestore
        .collection('customer_statistics')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dateKey))
        .where('date', isLessThan: Timestamp.fromDate(dateKey.add(const Duration(days: 1))))
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      // Mevcut kaydı güncelle
      await _firestore.collection('customer_statistics').doc(querySnapshot.docs.first.id).update({
        ...stats.toMap(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      return querySnapshot.docs.first.id;
    } else {
      // Yeni kayıt oluştur
      final ref = await _firestore.collection('customer_statistics').add(stats.toMap());
      return ref.id;
    }
  }

  Future<void> updateCustomerStatistics(String id, Map<String, dynamic> data) async {
    data['updated_at'] = FieldValue.serverTimestamp();
    await _firestore.collection('customer_statistics').doc(id).update(data);
  }

  Future<void> deleteCustomerStatistics(String id, {String? deletedBy}) async {
    try {
      // Önce veriyi al
      final doc = await _firestore.collection('customer_statistics').doc(id).get();
      if (!doc.exists) {
        throw Exception('Müşteri istatistiği bulunamadı');
      }

      final data = doc.data() as Map<String, dynamic>;
      
      // Çöp kutusuna taşı
      await moveToTrash(
        collection: 'customer_statistics',
        documentId: id,
        data: data,
        deletedBy: deletedBy,
        description: 'Müşteri istatistiği silindi',
      );
    } catch (e) {
      throw Exception('İstatistik silme hatası: $e');
    }
  }

  Stream<List<CustomerStatisticsModel>> getCustomerStatisticsByMonth(DateTime month) {
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    
    return _firestore
        .collection('customer_statistics')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CustomerStatisticsModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  Future<List<CustomerStatisticsModel>> getCustomerStatisticsByMonthFuture(DateTime month) async {
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    
    final snapshot = await _firestore
        .collection('customer_statistics')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date', descending: false)
        .get();
    
    return snapshot.docs
        .map((doc) => CustomerStatisticsModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  // === BONUS OPERATIONS ===
  Future<String> createBonus(BonusModel bonus) async {
    DocumentReference ref = await _firestore.collection('bonuses').add(bonus.toMap());
    return ref.id;
  }

  Future<void> updateBonus(String id, Map<String, dynamic> data) async {
    data['updated_at'] = FieldValue.serverTimestamp();
    await _firestore.collection('bonuses').doc(id).update(data);
  }

  Future<void> deleteBonus(String id, {String? deletedBy}) async {
    try {
      // Önce veriyi al
      final doc = await _firestore.collection('bonuses').doc(id).get();
      if (!doc.exists) {
        throw Exception('Prim bulunamadı');
      }

      final data = doc.data() as Map<String, dynamic>;
      
      // Çöp kutusuna taşı
      await moveToTrash(
        collection: 'bonuses',
        documentId: id,
        data: data,
        deletedBy: deletedBy,
        description: 'Prim silindi - Miktar: ${data['amount'] ?? 0} ₺',
      );
    } catch (e) {
      throw Exception('Prim silme hatası: $e');
    }
  }

  Stream<List<BonusModel>> getUserBonuses(String userId) {
    try {
      return _firestore
          .collection('bonuses')
          .where('user_id', isEqualTo: userId)
          .orderBy('month', descending: true)
          .limit(100) // Son 100 prim yeterli - performans için
          .snapshots()
          .map((snapshot) {
        try {
          final bonuses = snapshot.docs
              .map((doc) {
                try {
                  return BonusModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
                } catch (e) {
                  debugPrint('Prim parse hatası (doc ${doc.id}): $e');
                  return null;
                }
              })
              .where((bonus) => bonus != null)
              .cast<BonusModel>()
              .toList();
          
          // Ay bazında sıralama (en yeni ay en üstte)
          bonuses.sort((a, b) {
            final aMonth = DateTime(a.month.year, a.month.month);
            final bMonth = DateTime(b.month.year, b.month.month);
            return bMonth.compareTo(aMonth);
          });
          
          return bonuses;
        } catch (e) {
          debugPrint('Prim stream map hatası: $e');
          return <BonusModel>[];
        }
      }).handleError((error) {
        debugPrint('Prim stream hatası: $error');
        return <BonusModel>[];
      });
    } catch (e) {
      print('Prim stream oluşturma hatası: $e');
      // Hata durumunda boş stream döndür
      return Stream.value(<BonusModel>[]);
    }
  }

  Future<List<BonusModel>> getUserBonusesByMonth(String userId, DateTime month) async {
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    
    final snapshot = await _firestore
        .collection('bonuses')
        .where('user_id', isEqualTo: userId)
        .where('month', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('month', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();
    
    return snapshot.docs
        .map((doc) => BonusModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<BonusModel?> getBonusById(String id) async {
    DocumentSnapshot doc = await _firestore.collection('bonuses').doc(id).get();
    if (doc.exists) {
      return BonusModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  // === SALARY PAYMENT OPERATIONS ===
  Future<String> createSalaryPayment(SalaryPaymentModel payment) async {
    DocumentReference ref = await _firestore.collection('salary_payments').add(payment.toMap());
    return ref.id;
  }

  Future<void> updateSalaryPayment(String id, Map<String, dynamic> data) async {
    await _firestore.collection('salary_payments').doc(id).update(data);
  }

  Future<void> deleteSalaryPayment(String id, {String? deletedBy}) async {
    try {
      // Önce veriyi al
      final doc = await _firestore.collection('salary_payments').doc(id).get();
      if (!doc.exists) {
        throw Exception('Maaş ödemesi bulunamadı');
      }

      final data = doc.data() as Map<String, dynamic>;
      
      // Çöp kutusuna taşı
      await moveToTrash(
        collection: 'salary_payments',
        documentId: id,
        data: data,
        deletedBy: deletedBy,
        description: 'Maaş ödemesi silindi - Ödenen: ${data['paid_amount'] ?? 0} ₺',
      );
    } catch (e) {
      throw Exception('Maaş ödemesi silme hatası: $e');
    }
  }

  Stream<List<SalaryPaymentModel>> getUserSalaryPayments(String userId) {
    return _firestore
        .collection('salary_payments')
        .where('user_id', isEqualTo: userId)
        .orderBy('month', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SalaryPaymentModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<SalaryPaymentModel?> getSalaryPaymentByMonth(String userId, DateTime month) async {
    // Ayın ilk gününü al
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 1);

    QuerySnapshot snapshot = await _firestore
        .collection('salary_payments')
        .where('user_id', isEqualTo: userId)
        .where('month', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
        .where('month', isLessThan: Timestamp.fromDate(monthEnd))
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return SalaryPaymentModel.fromMap(
          snapshot.docs.first.data() as Map<String, dynamic>,
          snapshot.docs.first.id);
    }
    return null;
  }

  Future<List<SalaryPaymentModel>> getAllSalaryPayments() async {
    QuerySnapshot snapshot = await _firestore
        .collection('salary_payments')
        .orderBy('month', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => SalaryPaymentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  // === MONTHLY SALARY DATA OPERATIONS ===
  Future<String> createOrUpdateMonthlySalaryData(MonthlySalaryDataModel data) async {
    try {
      // Eğer id varsa direkt güncelle
      if (data.id.isNotEmpty) {
        await _firestore.collection('monthly_salary_data').doc(data.id).update({
          'remaining_net_salary': data.remainingNetSalary,
          'total_advances': data.totalAdvances,
          'admin_notes': data.adminNotes,
          'updated_at': Timestamp.fromDate(data.updatedAt ?? DateTime.now()),
        });
        return data.id;
      }
      
      // Aynı ay için kayıt var mı kontrol et
      final monthStart = DateTime(data.month.year, data.month.month, 1);
      final monthEnd = DateTime(data.month.year, data.month.month + 1, 1);
      
      final existingSnapshot = await _firestore
          .collection('monthly_salary_data')
          .where('user_id', isEqualTo: data.userId)
          .get();

      // İstemci tarafında filtreleme yap (Firestore index sorununu önlemek için)
      MonthlySalaryDataModel? existingData;
      for (var doc in existingSnapshot.docs) {
        final docData = doc.data();
        final docMonth = (docData['month'] as Timestamp).toDate();
        if (docMonth.year == monthStart.year && docMonth.month == monthStart.month) {
          existingData = MonthlySalaryDataModel.fromMap(docData, doc.id);
          break;
        }
      }

      if (existingData != null) {
        // Mevcut kaydı güncelle
        await _firestore.collection('monthly_salary_data').doc(existingData.id).update({
          'remaining_net_salary': data.remainingNetSalary,
          'total_advances': data.totalAdvances,
          'admin_notes': data.adminNotes,
          'updated_at': Timestamp.fromDate(data.updatedAt ?? DateTime.now()),
        });
        return existingData.id;
      } else {
        // Yeni kayıt oluştur
        DocumentReference ref = await _firestore.collection('monthly_salary_data').add(data.toMap());
        return ref.id;
      }
    } catch (e) {
      debugPrint('createOrUpdateMonthlySalaryData hatası: $e');
      rethrow;
    }
  }

  Future<void> updateMonthlySalaryData(String id, Map<String, dynamic> data) async {
    data['updated_at'] = Timestamp.fromDate(DateTime.now());
    await _firestore.collection('monthly_salary_data').doc(id).update(data);
  }

  Stream<List<MonthlySalaryDataModel>> getUserMonthlySalaryData(String userId) {
    return _firestore
        .collection('monthly_salary_data')
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => MonthlySalaryDataModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      // İstemci tarafında sırala (orderBy index sorununu önlemek için)
      list.sort((a, b) => b.month.compareTo(a.month));
      return list;
    });
  }

  Future<MonthlySalaryDataModel?> getMonthlySalaryDataByMonth(String userId, DateTime month) async {
    try {
      final monthStart = DateTime(month.year, month.month, 1);
      final monthEnd = DateTime(month.year, month.month + 1, 1);
      
      final snapshot = await _firestore
          .collection('monthly_salary_data')
          .where('user_id', isEqualTo: userId)
          .get();

      // İstemci tarafında filtreleme yap (Firestore index sorununu önlemek için)
      for (var doc in snapshot.docs) {
        final docData = doc.data();
        final docMonth = (docData['month'] as Timestamp).toDate();
        if (docMonth.year == monthStart.year && docMonth.month == monthStart.month) {
          return MonthlySalaryDataModel.fromMap(docData, doc.id);
        }
      }
      return null;
    } catch (e) {
      debugPrint('getMonthlySalaryDataByMonth hatası: $e');
      return null;
    }
  }

  Future<void> deleteMonthlySalaryData(String id) async {
    await _firestore.collection('monthly_salary_data').doc(id).delete();
  }
}
