import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/shift_model.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';
import '../models/bonus_model.dart';

class MonthlyStatistics {
  final int year;
  final int month;
  final double totalAdvances;
  final double monthlySalary;
  final double totalBonus; // Prim toplamı
  final double totalHours;
  final int workDays;
  final List<DailyStatistics> dailyStats;

  MonthlyStatistics({
    required this.year,
    required this.month,
    required this.totalAdvances,
    required this.monthlySalary,
    this.totalBonus = 0.0,
    required this.totalHours,
    required this.workDays,
    required this.dailyStats,
  });
}

class DailyStatistics {
  final DateTime date;
  final double advanceAmount;
  final double? workHours;
  final DateTime? startTime;
  final DateTime? endTime;
  final double? salary;

  DailyStatistics({
    required this.date,
    this.advanceAmount = 0.0,
    this.workHours,
    this.startTime,
    this.endTime,
    this.salary,
  });
}

class WorkerStatisticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Son 6 ay istatistiklerini getir
  Future<List<MonthlyStatistics>> getLast6MonthsStatistics(String userId) async {
    final now = DateTime.now();
    final sixMonthsAgo = DateTime(now.year, now.month - 5, 1); // 6 ay öncesi

    // Kullanıcı bilgisini al (maaş bilgisi için)
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final userData = userDoc.data();
    final monthlySalary = (userData?['monthly_salary'] ?? 0.0).toDouble();

    // Son 6 ayın shifts'lerini al
    // Firestore'da date alanı Timestamp olarak saklanıyor, bu yüzden sorgu yaparken Timestamp kullanmalıyız
    final shiftsSnapshot = await _firestore
        .collection('shifts')
        .where('user_id', isEqualTo: userId)
        .get();

    final shifts = shiftsSnapshot.docs
        .map((doc) => ShiftModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .where((shift) => shift.date.isAfter(sixMonthsAgo.subtract(const Duration(days: 1))) || 
                         shift.date.isAtSameMomentAs(sixMonthsAgo))
        .toList();
    
    // Tarihe göre sırala
    shifts.sort((a, b) => a.date.compareTo(b.date));

    // Son 6 ayın transactions'larını al (advance'ler)
    final transactionsSnapshot = await _firestore
        .collection('transactions')
        .where('user_id', isEqualTo: userId)
        .where('type', isEqualTo: 'advance')
        .get();

    final transactions = transactionsSnapshot.docs
        .map((doc) => TransactionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .where((transaction) => transaction.date.isAfter(sixMonthsAgo.subtract(const Duration(days: 1))) || 
                                transaction.date.isAtSameMomentAs(sixMonthsAgo))
        .toList();
    
    // Tarihe göre sırala
    transactions.sort((a, b) => a.date.compareTo(b.date));

    // Son 6 ayın primlerini al
    final bonusesSnapshot = await _firestore
        .collection('bonuses')
        .where('user_id', isEqualTo: userId)
        .get();

    final bonuses = bonusesSnapshot.docs
        .map((doc) => BonusModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .where((bonus) => bonus.month.isAfter(sixMonthsAgo.subtract(const Duration(days: 1))) || 
                         bonus.month.isAtSameMomentAs(sixMonthsAgo))
        .toList();

    // Ay bazlı gruplama
    final Map<String, MonthlyStatistics> monthlyMap = {};

    // Son 6 ay için boş aylar oluştur
    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final key = '${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}';
      monthlyMap[key] = MonthlyStatistics(
        year: monthDate.year,
        month: monthDate.month,
        totalAdvances: 0.0,
        monthlySalary: monthlySalary,
        totalBonus: 0.0,
        totalHours: 0.0,
        workDays: 0,
        dailyStats: [],
      );
    }

    // Shifts'leri işle
    for (var shift in shifts) {
      final key = '${shift.date.year}-${shift.date.month.toString().padLeft(2, '0')}';
      if (monthlyMap.containsKey(key)) {
        final monthly = monthlyMap[key]!;
        
        // Günlük istatistik oluştur veya güncelle
        final dayKey = DateTime(shift.date.year, shift.date.month, shift.date.day);
        var dailyStatIndex = monthly.dailyStats.indexWhere(
          (d) => d.date.year == shift.date.year &&
                 d.date.month == shift.date.month &&
                 d.date.day == shift.date.day,
        );

        if (dailyStatIndex == -1) {
          // Yeni günlük istatistik oluştur
          monthly.dailyStats.add(DailyStatistics(
            date: dayKey,
            workHours: shift.totalHours ?? 0.0,
            startTime: shift.startTime,
            endTime: shift.endTime,
          ));
        } else {
          // Mevcut günlük istatistiği güncelle (saatleri topla)
          final existing = monthly.dailyStats[dailyStatIndex];
          monthly.dailyStats[dailyStatIndex] = DailyStatistics(
            date: dayKey,
            advanceAmount: existing.advanceAmount,
            workHours: (existing.workHours ?? 0.0) + (shift.totalHours ?? 0.0),
            startTime: shift.startTime, // Son giriş saati
            endTime: shift.endTime ?? existing.endTime, // Son çıkış saati
            salary: existing.salary,
          );
        }

        // Aylık toplamları güncelle
        final updatedMonthly = monthlyMap[key]!;
        final totalHours = updatedMonthly.dailyStats
            .where((d) => d.workHours != null)
            .fold(0.0, (sum, d) => sum + (d.workHours ?? 0.0));
        
        monthlyMap[key] = MonthlyStatistics(
          year: updatedMonthly.year,
          month: updatedMonthly.month,
          totalAdvances: updatedMonthly.totalAdvances,
          monthlySalary: updatedMonthly.monthlySalary,
          totalBonus: updatedMonthly.totalBonus,
          totalHours: totalHours,
          workDays: updatedMonthly.dailyStats.length,
          dailyStats: updatedMonthly.dailyStats,
        );
      }
    }

    // Transactions'ları işle (advance'ler)
    for (var transaction in transactions) {
      final key = '${transaction.date.year}-${transaction.date.month.toString().padLeft(2, '0')}';
      if (monthlyMap.containsKey(key)) {
        final monthly = monthlyMap[key]!;
        
        // Günlük istatistiği bul veya oluştur
        final dayKey = DateTime(transaction.date.year, transaction.date.month, transaction.date.day);
        var dailyStatIndex = monthly.dailyStats.indexWhere(
          (d) => d.date.year == transaction.date.year &&
                 d.date.month == transaction.date.month &&
                 d.date.day == transaction.date.day,
        );

        if (dailyStatIndex == -1) {
          // Yeni günlük istatistik oluştur
          monthly.dailyStats.add(DailyStatistics(
            date: dayKey,
            advanceAmount: transaction.amount,
          ));
        } else {
          // Mevcut günlük istatistiği güncelle
          final existing = monthly.dailyStats[dailyStatIndex];
          monthly.dailyStats[dailyStatIndex] = DailyStatistics(
            date: dayKey,
            advanceAmount: existing.advanceAmount + transaction.amount,
            workHours: existing.workHours,
            startTime: existing.startTime,
            endTime: existing.endTime,
            salary: existing.salary,
          );
        }

        // Aylık toplamı güncelle
        final updatedMonthly = monthlyMap[key]!;
        monthlyMap[key] = MonthlyStatistics(
          year: updatedMonthly.year,
          month: updatedMonthly.month,
          totalAdvances: updatedMonthly.totalAdvances + transaction.amount,
          monthlySalary: updatedMonthly.monthlySalary,
          totalBonus: updatedMonthly.totalBonus,
          totalHours: updatedMonthly.totalHours,
          workDays: updatedMonthly.workDays,
          dailyStats: updatedMonthly.dailyStats,
        );
      }
    }

    // Primleri işle
    for (var bonus in bonuses) {
      final key = '${bonus.month.year}-${bonus.month.month.toString().padLeft(2, '0')}';
      if (monthlyMap.containsKey(key)) {
        final monthly = monthlyMap[key]!;
        monthlyMap[key] = MonthlyStatistics(
          year: monthly.year,
          month: monthly.month,
          totalAdvances: monthly.totalAdvances,
          monthlySalary: monthly.monthlySalary + bonus.amount, // Prim maaşa eklenir
          totalBonus: monthly.totalBonus + bonus.amount,
          totalHours: monthly.totalHours,
          workDays: monthly.workDays,
          dailyStats: monthly.dailyStats,
        );
      }
    }

    // Günlük istatistikleri tarihe göre sırala
    for (var key in monthlyMap.keys) {
      monthlyMap[key]!.dailyStats.sort((a, b) => a.date.compareTo(b.date));
    }

    return monthlyMap.values.toList();
  }
}
