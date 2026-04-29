import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../models/scheduled_notification_model.dart';
import '../../services/scheduled_notification_service.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({Key? key}) : super(key: key);

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> with SingleTickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _titleController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  
  late TabController _tabController;
  
  // Anlık bildirim için
  String _instantRecipientType = 'all';
  String? _instantSelectedUserId;
  List<UserModel> _workers = [];
  
  // Zamanlanmış bildirim için
  String _scheduledRecipientType = 'all';
  List<String> _scheduledSelectedUserIds = [];
  List<int> _selectedDays = []; // 1=Pazartesi, 7=Pazar
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  bool _scheduledIsActive = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _titleController.text = 'Tunç Nur Branda';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _titleController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<List<UserModel>> _getWorkersList() async {
    if (_workers.isNotEmpty) return _workers;
    
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'worker')
        .get();
    
    _workers = snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .toList();
    
    return _workers;
  }

  Future<void> _sendInstantNotification() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen mesaj giriniz'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_instantRecipientType == 'selected' && _instantSelectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir personel seçiniz'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      final message = _messageController.text.trim();
      final title = _titleController.text.trim().isEmpty ? 'Tunç Nur Branda' : _titleController.text.trim();
      final timestamp = DateTime.now();

      if (_instantRecipientType == 'all') {
        final usersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .get();

        for (var userDoc in usersSnapshot.docs) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'user_id': userDoc.id,
            'title': title,
            'message': message,
            'created_at': Timestamp.fromDate(timestamp),
            'read': false,
          });
        }

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final adminUserId = authProvider.user?.uid;
        if (adminUserId != null) {
          try {
            final notificationService = NotificationService();
            await notificationService.showNotification(
              title: title,
              body: message,
              notificationId: DateTime.now().millisecondsSinceEpoch % 100000,
            );
          } catch (e) {
            debugPrint('Anında bildirim gösterilirken hata: $e');
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bildirim tüm kullanıcılara gönderildi'),
              backgroundColor: AppColors.statusCompleted,
            ),
          );
        }
      } else {
        await FirebaseFirestore.instance.collection('notifications').add({
          'user_id': _instantSelectedUserId!,
          'title': title,
          'message': message,
          'created_at': Timestamp.fromDate(timestamp),
          'read': false,
        });

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final adminUserId = authProvider.user?.uid;
        if (adminUserId != null && _instantSelectedUserId == adminUserId) {
          try {
            final notificationService = NotificationService();
            await notificationService.showNotification(
              title: title,
              body: message,
              notificationId: DateTime.now().millisecondsSinceEpoch % 100000,
            );
          } catch (e) {
            debugPrint('Anında bildirim gösterilirken hata: $e');
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bildirim gönderildi'),
              backgroundColor: AppColors.statusCompleted,
            ),
          );
        }
      }

      _messageController.clear();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveScheduledNotification() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen mesaj giriniz'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen en az bir gün seçiniz'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_scheduledRecipientType == 'selected' && _scheduledSelectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen en az bir personel seçiniz'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final adminUserId = authProvider.user?.uid ?? '';

      final notification = ScheduledNotificationModel(
        id: '',
        title: _titleController.text.trim().isEmpty ? 'Tunç Nur Branda' : _titleController.text.trim(),
        message: _messageController.text.trim(),
        selectedDays: _selectedDays,
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
        recipientType: _scheduledRecipientType,
        selectedUserIds: _scheduledRecipientType == 'selected' ? _scheduledSelectedUserIds : null,
        isActive: _scheduledIsActive,
        createdBy: adminUserId,
        createdAt: DateTime.now(),
      );

      final notificationId = await _firestoreService.createScheduledNotification(notification);
      
      // Bildirimi cihazın bildirim sistemine kaydet
      if (_scheduledIsActive) {
        final scheduledNotificationService = ScheduledNotificationService();
        final notificationWithId = notification.copyWith(id: notificationId);
        await scheduledNotificationService.scheduleDeviceNotification(notificationWithId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Zamanlanmış bildirim kaydedildi'),
            backgroundColor: AppColors.statusCompleted,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primaryOrange,
              onPrimary: AppColors.white,
              surface: AppColors.mediumGray,
              onSurface: AppColors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _toggleDay(int day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
      _selectedDays.sort();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        title: const Text('Bildirim Gönder'),
        backgroundColor: AppColors.mediumGray,
        foregroundColor: AppColors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryOrange,
          unselectedLabelColor: AppColors.textGray,
          indicatorColor: AppColors.primaryOrange,
          tabs: const [
            Tab(text: 'Anlık Bildirim'),
            Tab(text: 'Zamanlanmış Bildirim'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInstantNotificationTab(),
          _buildScheduledNotificationTab(),
        ],
      ),
    );
  }

  Widget _buildInstantNotificationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Başlık
          TextFormField(
            controller: _titleController,
            style: TextStyle(color: AppColors.white),
            decoration: InputDecoration(
              labelText: 'Başlık',
              labelStyle: TextStyle(color: AppColors.textGray),
              filled: true,
              fillColor: AppColors.mediumGray,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Alıcı seçimi
          Text(
            'Alıcı Seçimi',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          RadioListTile<String>(
            title: const Text('Tüm Kullanıcılar'),
            value: 'all',
            groupValue: _instantRecipientType,
            onChanged: (value) {
              setState(() {
                _instantRecipientType = value!;
                _instantSelectedUserId = null;
              });
            },
            activeColor: AppColors.primaryOrange,
          ),
          RadioListTile<String>(
            title: const Text('Seçilen Personel'),
            value: 'selected',
            groupValue: _instantRecipientType,
            onChanged: (value) {
              setState(() {
                _instantRecipientType = value!;
              });
            },
            activeColor: AppColors.primaryOrange,
          ),
          
          if (_instantRecipientType == 'selected') ...[
            const SizedBox(height: 16),
            FutureBuilder<List<UserModel>>(
              future: _getWorkersList(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Text(
                    'Personel bulunamadı',
                    style: TextStyle(color: AppColors.textGray),
                  );
                }
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.mediumGray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _instantSelectedUserId,
                      hint: Text(
                        'Personel Seçin',
                        style: TextStyle(color: AppColors.textGray),
                      ),
                      isExpanded: true,
                      dropdownColor: AppColors.mediumGray,
                      style: TextStyle(color: AppColors.white),
                      items: snapshot.data!.map((user) {
                        return DropdownMenuItem<String>(
                          value: user.uid,
                          child: Text(user.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _instantSelectedUserId = value;
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 24),
          
          // Mesaj alanı
          Text(
            'Mesaj',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            maxLines: 6,
            style: TextStyle(color: AppColors.white),
            decoration: InputDecoration(
              hintText: 'Bildirim mesajını buraya yazın...',
              hintStyle: TextStyle(color: AppColors.textGray),
              filled: true,
              fillColor: AppColors.mediumGray,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Gönder butonu
          ElevatedButton(
            onPressed: _sendInstantNotification,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'BİLDİRİM GÖNDER',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduledNotificationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Başlık
          TextFormField(
            controller: _titleController,
            style: TextStyle(color: AppColors.white),
            decoration: InputDecoration(
              labelText: 'Başlık',
              labelStyle: TextStyle(color: AppColors.textGray),
              filled: true,
              fillColor: AppColors.mediumGray,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Mesaj alanı
          Text(
            'Mesaj',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            maxLines: 6,
            style: TextStyle(color: AppColors.white),
            decoration: InputDecoration(
              hintText: 'Bildirim mesajını buraya yazın...',
              hintStyle: TextStyle(color: AppColors.textGray),
              filled: true,
              fillColor: AppColors.mediumGray,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Gün seçimi
          Text(
            'Günler',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildDayChip(1, 'Pzt'),
              _buildDayChip(2, 'Sal'),
              _buildDayChip(3, 'Çar'),
              _buildDayChip(4, 'Per'),
              _buildDayChip(5, 'Cum'),
              _buildDayChip(6, 'Cmt'),
              _buildDayChip(7, 'Paz'),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Saat seçimi
          Text(
            'Saat',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _selectTime,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.mediumGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedTime.format(context),
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.access_time, color: AppColors.primaryOrange),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Alıcı seçimi
          Text(
            'Alıcı Seçimi',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          RadioListTile<String>(
            title: const Text('Tüm Kullanıcılar'),
            value: 'all',
            groupValue: _scheduledRecipientType,
            onChanged: (value) {
              setState(() {
                _scheduledRecipientType = value!;
                _scheduledSelectedUserIds.clear();
              });
            },
            activeColor: AppColors.primaryOrange,
          ),
          RadioListTile<String>(
            title: const Text('Seçilen Personeller'),
            value: 'selected',
            groupValue: _scheduledRecipientType,
            onChanged: (value) {
              setState(() {
                _scheduledRecipientType = value!;
              });
            },
            activeColor: AppColors.primaryOrange,
          ),
          
          if (_scheduledRecipientType == 'selected') ...[
            const SizedBox(height: 16),
            FutureBuilder<List<UserModel>>(
              future: _getWorkersList(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Text(
                    'Personel bulunamadı',
                    style: TextStyle(color: AppColors.textGray),
                  );
                }
                return Column(
                  children: snapshot.data!.map((user) {
                    final isSelected = _scheduledSelectedUserIds.contains(user.uid);
                    return CheckboxListTile(
                      title: Text(user.name),
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _scheduledSelectedUserIds.add(user.uid);
                          } else {
                            _scheduledSelectedUserIds.remove(user.uid);
                          }
                        });
                      },
                      activeColor: AppColors.primaryOrange,
                    );
                  }).toList(),
                );
              },
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Aktif/Pasif
          SwitchListTile(
            title: const Text('Aktif'),
            subtitle: const Text('Bildirim aktif olsun mu?'),
            value: _scheduledIsActive,
            onChanged: (value) {
              setState(() {
                _scheduledIsActive = value;
              });
            },
            activeColor: AppColors.primaryOrange,
          ),
          
          const SizedBox(height: 24),
          
          // Kaydet butonu
          ElevatedButton(
            onPressed: _saveScheduledNotification,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'ZAMANLANMIŞ BİLDİRİM KAYDET',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayChip(int day, String label) {
    final isSelected = _selectedDays.contains(day);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) => _toggleDay(day),
      selectedColor: AppColors.primaryOrange,
      checkmarkColor: AppColors.white,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.white : AppColors.textGray,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
