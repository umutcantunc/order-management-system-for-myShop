import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
    _checkAutoLogin();
  }

  // Otomatik giriş kontrolü - Firebase Auth'ta oturum açık kullanıcı varsa direkt giriş yap
  Future<void> _checkAutoLogin() async {
    // Kısa bir gecikme ile kontrol et (AuthProvider'ın yüklenmesi için)
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (!mounted) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Eğer kullanıcı zaten giriş yapmışsa, hiçbir şey yapma (AuthWrapper zaten yönlendirecek)
    if (authProvider.isAuthenticated) {
      return;
    }
    
    // Firebase Auth'ta oturum açık kullanıcı var mı kontrol et
    // AuthProvider'ın _checkCurrentUser metodu zaten bunu yapıyor
    // Burada sadece loading durumunu kontrol ediyoruz
  }

  Future<void> _loadSavedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('remembered_email');
      final shouldRemember = prefs.getBool('remember_me') ?? false;
      
      if (shouldRemember && savedEmail != null) {
        setState(() {
          _emailController.text = savedEmail;
          _rememberMe = true;
        });
      }
    } catch (e) {
      print('Email yükleme hatası: $e');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final email = _emailController.text.trim();
      
      bool success = await authProvider.signIn(
        email,
        _passwordController.text,
      );

      if (success && mounted) {
        // "Beni Hatırla" seçeneği işaretliyse email'i kaydet
        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          await prefs.setString('remembered_email', email);
          await prefs.setBool('remember_me', true);
        } else {
          // İşaretli değilse kaydedilmiş bilgileri temizle
          await prefs.remove('remembered_email');
          await prefs.setBool('remember_me', false);
        }
      } else if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.error ?? 'Giriş başarısız'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo/Başlık
                  Image.asset(
                    'assets/images/logo.png',
                    height: 120,
                    width: 120,
                    errorBuilder: (context, error, stackTrace) {
                      // Logo yüklenemezse fallback icon göster
                      return Icon(
                        Icons.construction,
                        size: 80,
                        color: AppColors.primaryOrange,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tunç Nur Branda',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Yönetim Sistemi',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: AppColors.textGray,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.poppins(color: AppColors.white),
                    decoration: InputDecoration(
                      labelText: 'E-posta',
                      labelStyle: GoogleFonts.poppins(color: AppColors.textGray),
                      prefixIcon: Icon(Icons.email, color: AppColors.textGray),
                      filled: true,
                      fillColor: AppColors.mediumGray,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.primaryOrange, width: 2),
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
                    style: GoogleFonts.poppins(color: AppColors.white),
                    decoration: InputDecoration(
                      labelText: 'Şifre',
                      labelStyle: GoogleFonts.poppins(color: AppColors.textGray),
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
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.primaryOrange, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Şifre gerekli';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // Beni Hatırla
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                        activeColor: AppColors.primaryOrange,
                      ),
                      Text(
                        'Beni Hatırla',
                        style: GoogleFonts.poppins(color: AppColors.textGray),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Giriş Butonu
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      return SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: authProvider.isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryOrange,
                            elevation: 4,
                            shadowColor: AppColors.primaryOrange.withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: authProvider.isLoading
                              ? CircularProgressIndicator(color: AppColors.white)
                              : Text(
                                  'GİRİŞ YAP',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.white,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
