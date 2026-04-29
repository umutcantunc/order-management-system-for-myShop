import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import '../../constants/app_colors.dart';

class AddUserScreen extends StatefulWidget {
  const AddUserScreen({Key? key}) : super(key: key);

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _monthlySalaryController = TextEditingController();
  final _salaryDayController = TextEditingController(text: '1');
  
  String _selectedRole = 'worker';
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _monthlySalaryController.dispose();
    _salaryDayController.dispose();
    super.dispose();
  }

  Future<void> _handleAddUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final currentUser = Provider.of<AuthProvider>(context, listen: false).user;
        
        // Admin kontrolü (opsiyonel - güvenlik için)
        if (currentUser?.role != 'admin') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sadece admin kullanıcılar yeni kullanıcı ekleyebilir'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        // Kullanıcı oluştur
        double? monthlySalary = _selectedRole == 'worker' && _monthlySalaryController.text.isNotEmpty
            ? double.tryParse(_monthlySalaryController.text)
            : null;
        int? salaryDay = _selectedRole == 'worker' && _salaryDayController.text.isNotEmpty
            ? int.tryParse(_salaryDayController.text)
            : 1;

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        
        // Firebase Auth'tan admin'in email'ini al
        final authService = AuthService();
        String? adminEmailFromAuth = authService.currentUser?.email;
        
        // Admin'in password'unu iste (oturumunu korumak için)
        String? adminPassword = await _showAdminPasswordDialog();
        if (adminPassword == null) {
          // Kullanıcı dialog'u iptal etti
          if (mounted) {
            setState(() => _isLoading = false);
          }
          return;
        }
        
        // Kullanıcı oluştur ve admin'i tekrar giriş yaptır
        await authProvider.createUser(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
          role: _selectedRole,
          monthlySalary: monthlySalary,
          salaryDay: salaryDay,
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          adminEmail: adminEmailFromAuth, // Admin email'ini geçir
          adminPassword: adminPassword, // Admin password'unu geçir
        );

        // Kullanıcı listesini yenile
        await userProvider.loadUsers();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kullanıcı başarıyla eklendi'),
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
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<String?> _showAdminPasswordDialog() async {
    final passwordController = TextEditingController();
    bool obscurePassword = true;
    
    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.mediumGray,
          title: Text(
            'Admin Şifresi',
            style: TextStyle(color: AppColors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Yeni kullanıcı oluşturduktan sonra admin oturumunuzu korumak için şifrenizi girin.',
                style: TextStyle(color: AppColors.textGray),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Admin Şifresi',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.textGray),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primaryOrange),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility : Icons.visibility_off,
                      color: AppColors.textGray,
                    ),
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(
                'İptal',
                style: TextStyle(color: AppColors.textGray),
              ),
            ),
            TextButton(
              onPressed: () {
                if (passwordController.text.isNotEmpty) {
                  Navigator.pop(context, passwordController.text);
                }
              },
              child: Text(
                'Devam',
                style: TextStyle(color: AppColors.primaryOrange),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        title: const Text('Yeni Kullanıcı Ekle'),
        backgroundColor: AppColors.mediumGray,
        foregroundColor: AppColors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ad Soyad
              TextFormField(
                controller: _nameController,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Ad Soyad',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  prefixIcon: Icon(Icons.person, color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ad soyad gerekli';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // E-posta
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'E-posta',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  prefixIcon: Icon(Icons.email, color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'E-posta gerekli';
                  }
                  if (!value.contains('@')) {
                    return 'Geçerli bir e-posta girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Şifre
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  prefixIcon: Icon(Icons.lock, color: AppColors.textGray),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      color: AppColors.textGray,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Şifre gerekli';
                  }
                  if (value.length < 6) {
                    return 'Şifre en az 6 karakter olmalıdır';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Rol
              DropdownButtonFormField<String>(
                value: _selectedRole,
                dropdownColor: AppColors.mediumGray,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Rol',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  prefixIcon: Icon(Icons.work, color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'worker',
                    child: Text('İşçi'),
                  ),
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text('Admin'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Telefon (Opsiyonel)
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: 'Telefon (Opsiyonel)',
                  labelStyle: TextStyle(color: AppColors.textGray),
                  prefixIcon: Icon(Icons.phone, color: AppColors.textGray),
                  filled: true,
                  fillColor: AppColors.mediumGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Aylık Maaş (Sadece işçi için)
              if (_selectedRole == 'worker')
                TextFormField(
                  controller: _monthlySalaryController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: AppColors.white),
                  decoration: InputDecoration(
                    labelText: 'Aylık Maaş (₺)',
                    labelStyle: TextStyle(color: AppColors.textGray),
                    prefixIcon: Icon(Icons.attach_money, color: AppColors.textGray),
                    filled: true,
                    fillColor: AppColors.mediumGray,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      if (double.tryParse(value) == null) {
                        return 'Geçerli bir sayı girin';
                      }
                    }
                    return null;
                  },
                ),
              if (_selectedRole == 'worker') const SizedBox(height: 16),

              // Maaş Günü (Sadece işçi için)
              if (_selectedRole == 'worker')
                TextFormField(
                  controller: _salaryDayController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppColors.white),
                  decoration: InputDecoration(
                    labelText: 'Maaş Günü (1-31)',
                    labelStyle: TextStyle(color: AppColors.textGray),
                    prefixIcon: Icon(Icons.calendar_today, color: AppColors.textGray),
                    filled: true,
                    fillColor: AppColors.mediumGray,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    helperText: 'Her ay bu gün maaş yenilenir',
                    helperStyle: TextStyle(color: AppColors.textGray, fontSize: 11),
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final day = int.tryParse(value);
                      if (day == null || day < 1 || day > 31) {
                        return '1-31 arası bir sayı girin';
                      }
                    }
                    return null;
                  },
                ),
              if (_selectedRole == 'worker') const SizedBox(height: 16),

              const SizedBox(height: 32),

              // Kaydet Butonu
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleAddUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: AppColors.white)
                      : Text(
                          'KULLANICI EKLE',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
