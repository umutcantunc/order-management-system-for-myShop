import '../models/customer_model.dart';
import '../models/customer_statistics_model.dart';
import '../services/firestore_service.dart';

class CustomerStatisticsService {
  final FirestoreService _firestoreService = FirestoreService();

  /// Müşterilerden günlük istatistikleri hesapla ve kaydet
  Future<void> calculateAndSaveDailyStatistics(DateTime date) async {
    final customers = await _firestoreService.getAllCustomers().first;
    
    int customerCount = 0;
    double cashAmount = 0.0;
    double cardAmount = 0.0;
    
    final targetDate = DateTime(date.year, date.month, date.day);
    
    for (var customer in customers) {
      for (var orderInfo in customer.orderInfos) {
        if (orderInfo.deliveredAt != null) {
          final deliveredDate = DateTime(
            orderInfo.deliveredAt!.year,
            orderInfo.deliveredAt!.month,
            orderInfo.deliveredAt!.day,
          );
          
          if (deliveredDate.isAtSameMomentAs(targetDate)) {
            customerCount++;
            if (orderInfo.price != null && orderInfo.price! > 0) {
              if (orderInfo.paymentType == 'nakit') {
                cashAmount += orderInfo.price!;
              } else if (orderInfo.paymentType == 'kart') {
                cardAmount += orderInfo.price!;
              }
            }
          }
        }
      }
    }
    
    final totalAmount = cashAmount + cardAmount;
    
    if (customerCount > 0 || totalAmount > 0) {
      final stats = CustomerStatisticsModel(
        id: '',
        date: targetDate,
        customerCount: customerCount,
        cashAmount: cashAmount,
        cardAmount: cardAmount,
        totalAmount: totalAmount,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await _firestoreService.createOrUpdateCustomerStatistics(stats);
    }
  }

  /// Belirli bir ay için istatistikleri hesapla
  Future<void> calculateMonthlyStatistics(DateTime month) async {
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0);
    
    for (int day = 1; day <= endDate.day; day++) {
      final date = DateTime(month.year, month.month, day);
      await calculateAndSaveDailyStatistics(date);
    }
  }
}
