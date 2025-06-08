import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Import halaman-halaman
import 'home.dart';
import 'identitas.dart';
import 'laporan.dart';
import 'profile.dart';
import 'login.dart';
import 'forgot_password.dart';
import 'reset_password.dart';
import './admin/admin.dart'; // Pastikan kamu punya halaman ini

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _storage = const FlutterSecureStorage();
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _userRole; // Simpan role user

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final token = await _storage.read(key: 'token');
    final role = await _storage.read(key: 'role');
    print('token: $token');
    print('role: $role'); // Pastikan role terbaca di sini

    setState(() {
      _isLoggedIn = token != null;
      _userRole = role;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Presensi JTV',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        primaryColor: const Color(0xFF003F87),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF003F87),
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF003F87),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: const Color(0xFF003F87), width: 1.5),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home:
          _isLoading
              ? const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFF003F87)),
                ),
              )
              : !_isLoggedIn
              ? const LoginPage()
              : (_userRole == 'admin' ? const Admin() : const Admin()),
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const PresensiPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/admin': (context) => const Admin(),
      },
      onGenerateRoute: (settings) {
        if (settings.name != null &&
            settings.name!.startsWith('/reset-password/')) {
          final token = settings.name!.split('/reset-password/')[1];
          return MaterialPageRoute(
            builder: (context) => ResetPasswordPage(token: token),
          );
        }

        return MaterialPageRoute(
          builder:
              (context) => const Scaffold(
                body: Center(child: Text('Halaman tidak ditemukan')),
              ),
        );
      },
    );
  }
}

class PresensiPage extends StatefulWidget {
  const PresensiPage({Key? key}) : super(key: key);

  @override
  State<PresensiPage> createState() => _PresensiPageState();
}

class _PresensiPageState extends State<PresensiPage>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _animationController;

  final List<Widget> _pages = [
    const Home(),
    const Identitas(),
    const Laporan(),
    const Profil(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;

    setState(() {
      _currentIndex = index;
    });

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    _animationController.reset();
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: PageView(
        controller: _pageController,
        children: _pages,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        physics: const NeverScrollableScrollPhysics(),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: const Color(0xFFF8F9FD)),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home, "Home"),
                _buildNavItem(1, Icons.qr_code, "Identitas"),
                _buildNavItem(2, Icons.history, "Laporan"),
                _buildNavItem(3, Icons.person, "Profil"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _currentIndex == index;

    return InkWell(
      onTap: () => _onTabTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? const Color(0xFF003F87).withOpacity(0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF003F87) : Colors.grey,
              size: isSelected ? 28 : 24,
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isSelected ? const Color(0xFF003F87) : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: isSelected ? 12 : 11,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
