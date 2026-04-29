import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/shift_model.dart';
import '../../models/transaction_model.dart';
import '../../constants/app_colors.dart';

class WorkerCalendarScreen extends StatefulWidget {
  const WorkerCalendarScreen({Key? key}) : super(key: key);

  @override
  State<WorkerCalendarScreen> createState() => _WorkerCalendarScreenState();
}

class _WorkerCalendarScreenState extends State<WorkerCalendarScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  
  Map<DateTime, List<dynamic>> _events = {};
  List<ShiftModel> _shifts = [];
  List<TransactionModel> _transactions = [];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR', null).then((_) {
      setState(() {});
    });
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;

    final userId = authProvider.user!.uid;

    // Shifts ve transactions'ı dinle
    _firestoreService.getUserShifts(userId).listen((shifts) {
      setState(() {
        _shifts = shifts;
        _updateEvents();
      });
    });

    _firestoreService.getUserTransactions(userId).listen((transactions) {
      setState(() {
        _transactions = transactions;
        _updateEvents();
      });
    });
  }

  void _updateEvents() {
    _events = {};
    
    // Shifts ekle
    for (var shift in _shifts) {
      final date = DateTime(shift.date.year, shift.date.month, shift.date.day);
      if (!_events.containsKey(date)) {
        _events[date] = [];
      }
      _events[date]!.add({'type': 'shift', 'data': shift});
    }

    // Transactions ekle
    for (var transaction in _transactions) {
      if (transaction.type == 'advance') {
        final date = DateTime(transaction.date.year, transaction.date.month, transaction.date.day);
        if (!_events.containsKey(date)) {
          _events[date] = [];
        }
        _events[date]!.add({'type': 'transaction', 'data': transaction});
      }
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return _events[date] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final dayEvents = _getEventsForDay(_selectedDay);
    final shifts = dayEvents.where((e) => e['type'] == 'shift').map((e) => e['data'] as ShiftModel).toList();
    final transactions = dayEvents.where((e) => e['type'] == 'transaction').map((e) => e['data'] as TransactionModel).toList();

    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        title: const Text('Takvim'),
        backgroundColor: AppColors.mediumGray,
        foregroundColor: AppColors.white,
      ),
      body: Column(
        children: [
          // Takvim
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.mediumGray,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: _calendarFormat,
              eventLoader: _getEventsForDay,
              startingDayOfWeek: StartingDayOfWeek.monday,
              locale: 'tr_TR',
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(color: AppColors.textGray),
                defaultTextStyle: TextStyle(color: AppColors.white),
                selectedDecoration: BoxDecoration(
                  color: AppColors.primaryOrange,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: AppColors.primaryOrange.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                // Marker kaldırıldı - çıkış saati okunabilirliğini engelliyordu
                markersMaxCount: 0,
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (BuildContext context, DateTime date, DateTime focusedDay) {
                  final events = _getEventsForDay(date);
                  return _buildDayCell(date, events);
                },
                todayBuilder: (BuildContext context, DateTime date, DateTime focusedDay) {
                  final events = _getEventsForDay(date);
                  return _buildDayCell(date, events, isToday: true);
                },
                selectedBuilder: (BuildContext context, DateTime date, DateTime focusedDay) {
                  final events = _getEventsForDay(date);
                  return _buildDayCell(date, events, isSelected: true);
                },
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonShowsNext: false,
                formatButtonDecoration: BoxDecoration(
                  color: AppColors.primaryOrange,
                  borderRadius: BorderRadius.circular(8),
                ),
                formatButtonTextStyle: TextStyle(color: AppColors.white),
                titleTextStyle: TextStyle(color: AppColors.white, fontSize: 16),
              ),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
            ),
          ),

          // Seçilen günün detayları
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.mediumGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('dd MMMM yyyy EEEE', 'tr_TR').format(_selectedDay),
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Mesai bilgileri
                    if (shifts.isNotEmpty) ...[
                      Text(
                        'Mesai Bilgileri',
                        style: TextStyle(
                          color: AppColors.primaryOrange,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...shifts.map((shift) => _buildShiftInfo(shift)),
                      const SizedBox(height: 16),
                    ] else ...[
                      Text(
                        'Bu gün için mesai kaydı bulunmamaktadır.',
                        style: TextStyle(color: AppColors.textGray),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Para çekme bilgileri
                    if (transactions.isNotEmpty) ...[
                      Text(
                        'Para Çekme İşlemleri',
                        style: TextStyle(
                          color: AppColors.statusWaiting,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...transactions.map((transaction) => _buildTransactionInfo(transaction)),
                    ] else ...[
                      Text(
                        'Bu gün için para çekme işlemi bulunmamaktadır.',
                        style: TextStyle(color: AppColors.textGray),
                      ),
                    ],
                    const SizedBox(height: 16), // Bottom padding
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftInfo(ShiftModel shift) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkGray,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, color: AppColors.primaryOrange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Giriş: ${DateFormat('HH:mm').format(shift.startTime)}',
                style: TextStyle(color: AppColors.white),
              ),
            ],
          ),
          if (shift.endTime != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.logout, color: AppColors.primaryOrange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Çıkış: ${DateFormat('HH:mm').format(shift.endTime!)}',
                  style: TextStyle(color: AppColors.white),
                ),
              ],
            ),
          ],
          if (shift.totalHours != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.timer, color: AppColors.primaryOrange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Toplam: ${shift.totalHours!.toStringAsFixed(2)} saat',
                  style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
          if (shift.note != null && shift.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.mediumGray,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note, color: AppColors.textGray, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      shift.note!,
                      style: TextStyle(
                        color: AppColors.textGray,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionInfo(TransactionModel transaction) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkGray,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet, color: AppColors.statusWaiting, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${transaction.amount.toStringAsFixed(2)} ₺',
                  style: TextStyle(
                    color: AppColors.statusWaiting,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (transaction.description.isNotEmpty)
                  Text(
                    transaction.description,
                    style: TextStyle(color: AppColors.textGray, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(DateTime date, List<dynamic> events, {bool isToday = false, bool isSelected = false}) {
    final dateKey = DateTime(date.year, date.month, date.day);
    final dayShifts = _shifts.where((shift) {
      final shiftDate = DateTime(shift.date.year, shift.date.month, shift.date.day);
      return shiftDate == dateKey;
    }).toList();

    // O gün için para çekimlerini bul
    final dayTransactions = _transactions.where((transaction) {
      if (transaction.type != 'advance') return false;
      final transactionDate = DateTime(transaction.date.year, transaction.date.month, transaction.date.day);
      return transactionDate == dateKey;
    }).toList();

    // O gün çekilen toplam para
    double totalAdvance = 0;
    for (var transaction in dayTransactions) {
      totalAdvance += transaction.amount;
    }

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primaryOrange
            : isToday
                ? AppColors.primaryOrange.withOpacity(0.5)
                : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                color: isSelected || isToday ? AppColors.white : AppColors.white,
                fontSize: 12,
                fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            // Giriş-çıkış saatlerini göster
            if (dayShifts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: dayShifts.take(1).map((shift) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('HH:mm').format(shift.startTime),
                          style: TextStyle(
                            color: isSelected || isToday ? AppColors.white : AppColors.primaryOrange,
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (shift.endTime != null)
                          Text(
                            DateFormat('HH:mm').format(shift.endTime!),
                            style: TextStyle(
                              color: isSelected || isToday ? AppColors.white : AppColors.statusCompleted,
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            // Para çekimi bilgisi
            if (totalAdvance > 0)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  '${totalAdvance.toStringAsFixed(0)}₺',
                  style: TextStyle(
                    color: isSelected || isToday ? AppColors.white : AppColors.statusWaiting,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            // Event marker kaldırıldı - shift varsa saatler zaten gösteriliyor
          ],
        ),
      ),
    );
  }
}
