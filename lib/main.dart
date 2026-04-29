import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/order_provider.dart';
import 'providers/shift_provider.dart';
import 'providers/user_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/transaction_provider.dart';
import 'services/notification_service.dart';
import 'services/scheduled_notification_service.dart';
import 'services/version_service.dart';
import 'widgets/update_dialog.dart';
import 'screens/auth/login_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/worker/worker_home_screen.dart';
import 'constants/app_colors.dart';

bool _notificationServiceInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Flutter hatalarını yakala ve logla
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };
  
  // Platform hatalarını yakala
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Platform Error: $error');
    debugPrint('Stack trace: $stack');
    return true;
  };
  
  // Sistem UI'yi ayarla - Navigation bar ve status bar görünür ama engel olmayacak şekilde
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge, // Edge-to-edge modunda çalışır, çubuklar görünür ama içerik altına girer
  );
  
  // Sistem UI overlay stilini ayarla
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Status bar şeffaf
      statusBarIconBrightness: Brightness.light, // Status bar ikonları açık renk
      systemNavigationBarColor: Colors.transparent, // Navigation bar şeffaf
      systemNavigationBarIconBrightness: Brightness.light, // Navigation bar ikonları açık renk
      systemNavigationBarDividerColor: Colors.transparent, // Navigation bar divider şeffaf
    ),
  );
  
  // Firebase'i başlat - timeout ile
  try {
    // Web platformu için Firebase config
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyA4FbmQOmWY8TlmwmvXJEwe7tFOsDukBgw",
          appId: "1:590959884913:web:c7a984a8b2389947a139d0",
          messagingSenderId: "590959884913",
          projectId: "tuncnurbranda-a93a5",
          authDomain: "tuncnurbranda-a93a5.firebaseapp.com",
          // Must match the bucket shown in Firebase Console → Storage (gs://...)
          storageBucket: "tuncnurbranda-a93a5.firebasestorage.app",
          measurementId: "G-VDHDS02E74",
        ),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('Firebase initialization timeout');
          throw TimeoutException('Firebase initialization timeout');
        },
      );
    } else {
      // Mobile platformlar için default initialize
      await Firebase.initializeApp().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('Firebase initialization timeout');
          throw TimeoutException('Firebase initialization timeout');
        },
      );
    }
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    // Hata olsa bile uygulama çalışmaya devam etsin
  }
  
  runApp(const MyApp());
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => message;
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(), lazy: false),
        ChangeNotifierProvider(create: (_) => OrderProvider(), lazy: true),
        ChangeNotifierProvider(create: (_) => ShiftProvider(), lazy: true),
        ChangeNotifierProvider(create: (_) => UserProvider(), lazy: true),
        ChangeNotifierProvider(create: (_) => DashboardProvider(), lazy: true),
        ChangeNotifierProvider(create: (_) => TransactionProvider(), lazy: true),
      ],
      child: MaterialApp(
        title: 'Tunç Nur Branda',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('tr', 'TR'),
          Locale('en', 'US'),
        ],
        locale: const Locale('tr', 'TR'),
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          primaryColor: AppColors.primaryOrange,
          scaffoldBackgroundColor: AppColors.darkGray,
          
          // Google Fonts - Poppins
          textTheme: GoogleFonts.poppinsTextTheme(
            ThemeData.dark().textTheme,
          ).apply(
            bodyColor: AppColors.white,
            displayColor: AppColors.white,
          ),
          
          colorScheme: ColorScheme.dark(
            primary: AppColors.primaryOrange,
            secondary: AppColors.primaryOrange,
            surface: AppColors.mediumGray,
            background: AppColors.darkGray,
          ),
          
          // Page Transitions
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: ZoomPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
              TargetPlatform.windows: ZoomPageTransitionsBuilder(),
              TargetPlatform.linux: ZoomPageTransitionsBuilder(),
            },
          ),
          
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.mediumGray,
            foregroundColor: AppColors.white,
            elevation: 0,
            centerTitle: false,
            titleTextStyle: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
          
          cardTheme: CardThemeData(
            color: AppColors.mediumGray,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            shadowColor: Colors.black.withOpacity(0.3),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColors.mediumGray,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.error, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppColors.error, width: 2),
            ),
            labelStyle: GoogleFonts.poppins(
              color: AppColors.textGray,
              fontSize: 14,
            ),
            hintStyle: GoogleFonts.poppins(
              color: AppColors.textGray.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
          
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: AppColors.white,
              elevation: 4,
              shadowColor: AppColors.primaryOrange.withOpacity(0.4),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryOrange,
              textStyle: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: AppColors.primaryOrange,
            foregroundColor: AppColors.white,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Kısa bir bekleme sonrası ana ekrana geç (Firebase Auth kontrolü için)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Image.asset(
              'assets/images/logo.png',
              height: 150,
              width: 150,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.construction,
                  size: 120,
                  color: AppColors.primaryOrange,
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Tunç Nur Branda',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Yönetim Sistemi',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textGray,
              ),
            ),
            const SizedBox(height: 48),
            CircularProgressIndicator(
              color: AppColors.primaryOrange,
            ),
          ],
        ),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final VersionService _versionService = VersionService();
  bool _updateChecked = false;

  @override
  void initState() {
    super.initState();
    // Bildirim servisini ilk girişte başlat
    _initializeNotificationService();
    // Versiyon kontrolü yap
    _checkForUpdate();
  }

  Future<void> _initializeNotificationService() async {
    if (_notificationServiceInitialized) return;
    
    try {
      debugPrint('=== Bildirim servisi başlatılıyor ===');
      final notificationService = NotificationService();
      await notificationService.initialize();
      debugPrint('Bildirim servisi başlatıldı');
      
      // Firebase'in hazır olmasını bekle
      await Future.delayed(const Duration(seconds: 3));
      
      // Zamanlanmış bildirim kontrolünü başlat
      final scheduledNotificationService = ScheduledNotificationService();
      // Tüm aktif bildirimleri cihaza yükle
      await scheduledNotificationService.reloadAllScheduledNotifications();
      debugPrint('Zamanlanmış bildirim kontrolü başlatıldı');
      
      _notificationServiceInitialized = true;
    } catch (e, stackTrace) {
      debugPrint('Bildirim servisi hatası: $e');
      debugPrint('Stack trace: $stackTrace');
      // Hata olsa bile uygulama çalışmaya devam etsin
    }
  }

  Future<void> _checkForUpdate() async {
    if (_updateChecked) return;
    
    try {
      // Kısa bir gecikme ile kontrol et (uygulama açılışını engellemesin)
      await Future.delayed(const Duration(seconds: 3));
      
      if (!mounted) return;
      
      final updateInfo = await _versionService.checkForUpdate();
      _updateChecked = true;

      if (updateInfo['needsUpdate'] == true && mounted) {
        // Dialog'u göster - WidgetsBinding kullanarak context'in hazır olduğundan emin ol
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: !(updateInfo['forceUpdate'] == true),
              builder: (context) => UpdateDialog(
                message: updateInfo['message'] ?? 'Yeni bir güncelleme mevcut.',
                updateUrl: updateInfo['updateUrl'],
                storagePath: updateInfo['storagePath'],
                forceUpdate: updateInfo['forceUpdate'] == true,
                currentVersion: updateInfo['currentVersion'] ?? '1.0.0',
                latestVersion: updateInfo['latestVersion'] ?? '1.0.0',
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Güncelleme kontrolü hatası: $e');
      // Hata olsa bile uygulama çalışmaya devam etsin
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Kullanıcı durumunu kontrol et
        // Firebase Auth otomatik olarak oturum açık kullanıcıyı yükler
        if (authProvider.isAuthenticated) {
          // Kullanıcı giriş yapmış - rolüne göre yönlendir
          if (authProvider.isAdmin) {
            return const AdminDashboardScreen();
          } else {
            return const WorkerHomeScreen();
          }
        } else {
          // Kullanıcı giriş yapmamış veya yükleniyor
          // Loading durumunda splash ekranı göster
          if (authProvider.isLoading) {
            return const SplashScreen();
          }
          // Kullanıcı giriş yapmamış
          return const LoginScreen();
        }
      },
    );
  }
}
