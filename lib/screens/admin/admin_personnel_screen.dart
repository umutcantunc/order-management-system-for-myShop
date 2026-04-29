import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/user_provider.dart';
import '../../constants/app_colors.dart';
import 'personnel_detail_screen.dart';
import 'add_user_screen.dart';
import '../../models/user_model.dart';

class AdminPersonnelScreen extends StatefulWidget {
  const AdminPersonnelScreen({Key? key}) : super(key: key);

  @override
  State<AdminPersonnelScreen> createState() => _AdminPersonnelScreenState();
}

class _AdminPersonnelScreenState extends State<AdminPersonnelScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UserProvider>(context, listen: false).loadUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddUserScreen(),
            ),
          );
        },
        backgroundColor: AppColors.primaryOrange,
        child: const Icon(Icons.person_add, color: AppColors.white),
      ),
      body: Consumer<UserProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = provider.users.where((u) => u.role == 'worker').toList();

          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: AppColors.textGray,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz personel eklenmemiş',
                    style: TextStyle(
                      color: AppColors.textGray,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sağ alttaki + butonuna tıklayarak\npersonel ekleyebilirsiniz',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textGray,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              // Staggered fade-in animasyonu
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 300 + (index * 50)),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: _buildPersonnelCard(context, users[index], index),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPersonnelCard(BuildContext context, UserModel user, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: AppColors.mediumGray,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: Text(
          user.name,
          style: GoogleFonts.poppins(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user.phone != null)
              Text(
                user.phone!,
                style: GoogleFonts.poppins(
                  color: AppColors.textGray,
                  fontSize: 13,
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (user.monthlySalary != null)
                        Text(
                          'Aylık Maaş: ${user.monthlySalary!.toStringAsFixed(2)} ₺',
                          style: GoogleFonts.poppins(
                            color: AppColors.textGray,
                            fontSize: 13,
                          ),
                        ),
                      if (user.monthlySalary == null)
                        Text(
                          'Aylık Maaş: Belirtilmemiş',
                          style: GoogleFonts.poppins(
                            color: AppColors.textGray,
                            fontSize: 13,
                          ),
                        ),
                      if (user.salaryDay != null)
                        Text(
                          'Maaş Günü: ${user.salaryDay}. Gün',
                          style: GoogleFonts.poppins(
                            color: AppColors.textGray,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit, size: 18, color: AppColors.primaryOrange),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  onPressed: () => _showEditSalaryDialog(context, user),
                  tooltip: 'Maaşı Düzenle',
                ),
              ],
            ),
          ],
        ),
        trailing: Icon(Icons.chevron_right, color: AppColors.primaryOrange),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PersonnelDetailScreen(user: user),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showEditSalaryDialog(BuildContext context, UserModel user) async {
    final TextEditingController salaryController = TextEditingController(
      text: user.monthlySalary?.toStringAsFixed(2) ?? '0.00',
    );
    final TextEditingController salaryDayController = TextEditingController(
      text: user.salaryDay?.toString() ?? '1',
    );

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.mediumGray,
          title: Text(
            'Maaş Bilgilerini Düzenle',
            style: TextStyle(color: AppColors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Personel: ${user.name}',
                  style: TextStyle(
                    color: AppColors.textGray,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: salaryController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: AppColors.white),
                  decoration: InputDecoration(
                    labelText: 'Aylık Maaş (₺)',
                    labelStyle: TextStyle(color: AppColors.textGray),
                    prefixIcon: Icon(Icons.attach_money, color: AppColors.primaryOrange),
                    filled: true,
                    fillColor: AppColors.darkGray,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primaryOrange, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: salaryDayController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppColors.white),
                  decoration: InputDecoration(
                    labelText: 'Maaş Günü (1-31)',
                    labelStyle: TextStyle(color: AppColors.textGray),
                    prefixIcon: Icon(Icons.calendar_today, color: AppColors.primaryOrange),
                    filled: true,
                    fillColor: AppColors.darkGray,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primaryOrange, width: 2),
                    ),
                    helperText: 'Her ay bu gün maaş yenilenir',
                    helperStyle: TextStyle(color: AppColors.textGray, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'İptal',
                style: TextStyle(color: AppColors.textGray),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final newSalary = double.tryParse(salaryController.text);
                if (newSalary == null || newSalary < 0) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Geçerli bir tutar giriniz'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                  return;
                }

                final newSalaryDay = int.tryParse(salaryDayController.text);
                if (newSalaryDay == null || newSalaryDay < 1 || newSalaryDay > 31) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Maaş günü 1-31 arasında olmalıdır'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                  return;
                }

                try {
                  final userProvider = Provider.of<UserProvider>(context, listen: false);
                  await userProvider.updateUser(user.uid, {
                    'monthly_salary': newSalary,
                    'salary_day': newSalaryDay,
                  });

                  if (context.mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${user.name} için maaş bilgileri güncellendi: ${newSalary.toStringAsFixed(2)} ₺, Maaş Günü: $newSalaryDay'),
                        backgroundColor: AppColors.statusCompleted,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Hata: ${e.toString()}'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
              ),
              child: Text(
                'Kaydet',
                style: TextStyle(color: AppColors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
