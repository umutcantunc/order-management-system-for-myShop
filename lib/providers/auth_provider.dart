import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  bool _isInitializing = false; // İlk yükleme devam ediyor mu?
  bool _hasCheckedCurrentUser = false; // Mevcut kullanıcı kontrol edildi mi?

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get isAdmin => _user?.role == 'admin';

  AuthProvider() {
    _init();
  }

  bool _isCreatingUser = false; // Kullanıcı oluşturma işlemi devam ediyor mu?
  UserModel? _pendingAdminUser; // Admin'in user bilgisi (kullanıcı oluşturma sonrası geri yüklemek için)

  void _init() {
    // İlk açılışta mevcut kullanıcıyı kontrol et
    _checkCurrentUser();
    
    // Auth state değişikliklerini dinle
    _authService.authStateChanges.listen((firebaseUser) async {
      // Eğer kullanıcı oluşturma işlemi devam ediyorsa, listener'ı görmezden gel
      if (_isCreatingUser) {
        return;
      }
      
      // İlk yükleme sırasında authStateChanges'i görmezden gel
      // Çünkü _checkCurrentUser zaten kullanıcıyı yükleyecek
      if (!_hasCheckedCurrentUser) {
        return;
      }
      
      if (firebaseUser != null) {
        // Sadece kullanıcı değiştiyse yükle
        if (_user == null || _user!.uid != firebaseUser.uid) {
          await loadUserData(firebaseUser.uid);
        }
      } else {
        // Kullanıcı çıkış yaptı
        if (_user != null) {
          _user = null;
          notifyListeners();
        }
      }
    });
  }

  // Mevcut kullanıcıyı kontrol et (uygulama açıldığında)
  Future<void> _checkCurrentUser() async {
    if (_isInitializing) return; // Zaten kontrol ediliyor
    
    _isInitializing = true;
    try {
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        // Kullanıcı zaten giriş yapmış, verilerini yükle
        await loadUserData(currentUser.uid);
      }
    } catch (e) {
      debugPrint('Mevcut kullanıcı kontrolü hatası: $e');
    } finally {
      _hasCheckedCurrentUser = true;
      _isInitializing = false;
    }
  }

  Future<void> loadUserData(String uid) async {
    // Aynı kullanıcı zaten yüklüyse tekrar yükleme
    if (_user != null && _user!.uid == uid && !_isLoading) {
      return;
    }
    
    try {
      _isLoading = true;
      notifyListeners();
      
      _user = await _authService.getUserData(uid);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      debugPrint('Kullanıcı verisi yükleme hatası: $e');
      notifyListeners();
    }
  }

  Future<bool> signIn(String email, String password) async {
    // Zaten giriş yapılmışsa tekrar giriş yapma
    if (_isLoading) {
      return false;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.signInWithEmailAndPassword(email, password);
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    
    // Çıkış yapıldığında "Beni Hatırla" bilgisini temizle
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', false);
      await prefs.remove('remembered_email');
    } catch (e) {
      debugPrint('Çıkış yaparken SharedPreferences temizleme hatası: $e');
    }
    
    notifyListeners();
  }

  // Yeni kullanıcı oluştur (Admin için)
  // Admin'in oturumunu korumak için admin email/password saklanır
  Future<void> createUser({
    required String email,
    required String password,
    required String name,
    required String role,
    double? monthlySalary,
    int? salaryDay,
    String? phone,
    String? adminEmail,
    String? adminPassword,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Admin'in mevcut bilgilerini sakla (eğer admin ise)
      UserModel? savedAdminUser;
      
      if (_user != null && _user!.role == 'admin') {
        // Admin'in mevcut user bilgisini sakla
        savedAdminUser = _user;
        _pendingAdminUser = _user;
      }

      // Kullanıcı oluşturma işlemini başlat
      _isCreatingUser = true;
      
      // Kullanıcı oluştur (bu işlem otomatik olarak yeni kullanıcıya giriş yapar)
      await _authService.createUserWithEmailAndPassword(
        email,
        password,
        name,
        role,
        monthlySalary: monthlySalary,
        salaryDay: salaryDay,
        phone: phone,
        adminUser: _authService.currentUser,
      );

      // Kullanıcı oluşturulduktan sonra admin'i tekrar yükle
      // Firebase Auth'ta yeni kullanıcıya giriş yapıldı, ama biz admin'i geri yüklemeliyiz
      if (savedAdminUser != null) {
        // Firebase Auth'tan çıkış yap (yeni kullanıcı oturumunu kapat)
        await _authService.signOut();
        
        // Admin'i tekrar giriş yaptır (password varsa)
        if (adminEmail != null && adminPassword != null) {
          await signIn(adminEmail, adminPassword);
        } else {
          // Password yoksa, admin'in user bilgisini manuel olarak geri yükle
          // Ancak bu Firebase Auth'ta oturum açmaz, sadece UI'da admin olarak görünür
          // Bu durumda kullanıcıdan tekrar giriş yapması istenmeli
          _user = savedAdminUser;
          _pendingAdminUser = null;
          notifyListeners();
        }
      }
      
      _isCreatingUser = false;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow; // Hata tekrar fırlatılıyor ki UI'da gösterilebilsin
    }
  }
}
