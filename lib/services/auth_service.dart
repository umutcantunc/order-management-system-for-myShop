import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Giriş yap
  Future<UserModel?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        return await getUserData(userCredential.user!.uid);
      }
      return null;
    } catch (e) {
      throw Exception('Giriş hatası: ${e.toString()}');
    }
  }

  // Çıkış yap
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Kullanıcı bilgilerini getir
  Future<UserModel?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        // Debug: Role değerini kontrol et
        print('DEBUG: Firestore user data for $uid: $data');
        print('DEBUG: Role value: ${data['role']}');
        return UserModel.fromMap(data, uid);
      }
      print('DEBUG: User document does not exist for $uid');
      return null;
    } catch (e) {
      print('DEBUG: Error getting user data: $e');
      throw Exception('Kullanıcı bilgisi alınamadı: ${e.toString()}');
    }
  }

  // Yeni kullanıcı oluştur (Admin tarafından)
  // Admin'in oturumunu korumak için adminUser parametresi alır
  Future<UserModel?> createUserWithEmailAndPassword(
    String email,
    String password,
    String name,
    String role,
    {double? monthlySalary, int? salaryDay, String? phone, User? adminUser}
  ) async {
    try {
      // Admin'in mevcut oturumunu sakla
      User? previousUser = adminUser ?? _auth.currentUser;
      
      // Firebase Authentication'da kullanıcı oluştur
      // Bu işlem otomatik olarak yeni kullanıcıya giriş yapar
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        String uid = userCredential.user!.uid;
        
        // Firestore'da kullanıcı bilgilerini kaydet
        UserModel newUser = UserModel(
          uid: uid,
          name: name,
          role: role,
          monthlySalary: monthlySalary,
          salaryDay: salaryDay,
          phone: phone,
        );

        await _firestore.collection('users').doc(uid).set(newUser.toMap());
        
        // Admin'in oturumunu geri yükle (eğer admin varsa)
        if (previousUser != null && previousUser.uid != uid) {
          // Admin'i tekrar giriş yaptır
          // Not: Bu işlem için admin'in email/password'una ihtiyacımız var
          // Alternatif: Admin'in token'ını kullanarak oturumu geri yükleyebiliriz
          // Şimdilik admin'in oturumunu korumak için signOut yapıp tekrar giriş yapması gerekecek
          // Ama daha iyi bir çözüm için admin'in email'ini saklayıp tekrar giriş yaptırabiliriz
        }
        
        return newUser;
      }
      return null;
    } catch (e) {
      throw Exception('Kullanıcı oluşturma hatası: ${e.toString()}');
    }
  }

  // Mevcut kullanıcı
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
