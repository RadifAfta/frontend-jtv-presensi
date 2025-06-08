// home.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// import 'package:flutter_svg/flutter_svg.dart';

import './services/api_services.dart';
import '../models/user_model.dart';
import '../models/attendance_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  // User data dari API
  static const _storage = FlutterSecureStorage();
  User? currentUser;
  bool isLoadingUser = true;
  String errorMessage = '';

  Map<String, int> userStats = {'hadir': 0, 'terlambat': 0, 'izin': 0};

  bool isLoadingStats = true;
  String statsErrorMessage = '';
  // Data aktivitas tim (sementara masih dummy, nanti akan diganti)
  List<Map<String, dynamic>> timActivities = [];
  bool isLoadingActivities = true;
  String activitiesErrorMessage = '';

  String _timeString = '';
  late DateTime _currentTime;

  @override
  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _updateTime();
    _checkAuthenticationStatus(); // Cek auth dulu
  }

  void _updateTime() {
    if (mounted) {
      setState(() {
        _timeString = DateFormat('HH:mm:ss').format(DateTime.now());
        _currentTime = DateTime.now();
      });
      Future.delayed(const Duration(seconds: 1), _updateTime);
    }
  }

  Future<void> _checkAuthenticationStatus() async {
    try {
      final isAuth = await UserApiService.isAuthenticated();
      if (!isAuth) {
        if (mounted) {
          // Redirect ke login page
          Navigator.pushReplacementNamed(context, '/login');
          return;
        }
      } else {
        // Jika sudah authenticated, load user data
        _loadUserData();
        _loadTeamActivities();
        _loadUserStats();
      }
    } catch (e) {
      print('Error checking authentication: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Future<void> _loadTeamActivities() async {
    setState(() {
      isLoadingActivities = true;
      activitiesErrorMessage = '';
    });

    try {
      final response = await UserApiService.getAllUserAttendance();

      if (mounted) {
        setState(() {
          timActivities =
              response
                  .map<Map<String, dynamic>>(
                    (item) => {
                      'nama': item['nama'] ?? '',
                      'divisi': item['divisi'] ?? '',
                      'masuk': item['masuk'] ?? '-',
                      'pulang': item['pulang'] ?? '-',
                      'status': item['status'] ?? '',
                    },
                  )
                  .toList();
          isLoadingActivities = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingActivities = false;
          activitiesErrorMessage = 'Gagal memuat aktivitas tim: $e';
          // Gunakan data dummy sebagai fallback
          timActivities = [
            {
              'nama': 'Data tidak tersedia',
              'divisi': '-',
              'masuk': '-',
              'pulang': '-',
              'status': 'Error',
            },
          ];
        });
      }
    }
  }

  Future<void> _loadUserStats() async {
    setState(() {
      isLoadingStats = true;
      statsErrorMessage = '';
    });

    try {
      final attendanceData = await UserApiService.getUserAttendance();

      print('DEBUG: Total attendance records: ${attendanceData.length}');

      // Process data sama seperti di laporan page
      final List<Map<String, dynamic>> processedData =
          attendanceData.map((item) {
            DateTime date;
            if (item['scan_time'] != null) {
              date = DateTime.parse(item['scan_time']);
            } else if (item['created_at'] != null) {
              date = DateTime.parse(item['created_at']);
            } else {
              date = DateTime.now();
            }

            String status = item['category'] ?? 'Tidak Hadir';

            return {
              'tanggal': DateFormat('yyyy-MM-dd').format(date),
              'status': status,
              'rawDate': date,
            };
          }).toList();

      // Group by date dan merge seperti di laporan page
      Map<String, Map<String, dynamic>> groupedData = {};

      for (var item in processedData) {
        String dateKey = item['tanggal'];

        if (groupedData.containsKey(dateKey)) {
          // Update status - ambil status yang bukan 'Masuk' atau 'Pulang'
          if (item['status'] != 'Masuk' && item['status'] != 'Pulang') {
            groupedData[dateKey]!['status'] = item['status'];
          } else if (groupedData[dateKey]!['status'] == 'Masuk' ||
              groupedData[dateKey]!['status'] == 'Pulang') {
            groupedData[dateKey]!['status'] = 'Hadir';
          }
        } else {
          // Jika kategori adalah Masuk atau Pulang, ubah status ke Hadir
          if (item['status'] == 'Masuk' || item['status'] == 'Pulang') {
            item['status'] = 'Hadir';
          }
          groupedData[dateKey] = item;
        }
      }

      // Hitung statistik dari data yang sudah diproses
      int hadirCount = 0;
      int terlambatCount = 0;
      int izinCount = 0;

      for (var entry in groupedData.values) {
        String status = entry['status']?.toString() ?? '';
        print('DEBUG: Final status: "$status"');

        if (status == 'Hadir') {
          hadirCount++;
        } else if (status == 'Terlambat') {
          terlambatCount++;
        } else if (status == 'Izin' || status == 'Sakit') {
          izinCount++;
        }
      }

      print(
        'DEBUG: Final counts - Hadir: $hadirCount, Terlambat: $terlambatCount, Izin: $izinCount',
      );

      if (mounted) {
        setState(() {
          userStats = {
            'hadir': hadirCount,
            'terlambat': terlambatCount,
            'izin': izinCount,
          };
          isLoadingStats = false;
        });
      }
    } catch (e) {
      print('ERROR in _loadUserStats: $e');
    }
  }

  // Load data user dari API
  Future<void> _loadUserData() async {
    setState(() {
      isLoadingUser = true;
      errorMessage = '';
    });

    try {
      final user = await UserApiService.getCurrentUser();

      if (mounted) {
        setState(() {
          currentUser = user;
          isLoadingUser = false;
          if (user == null) {
            errorMessage = 'Gagal memuat data user';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingUser = false;

          // Handle specific authentication errors
          if (e.toString().contains('Authentication failed') ||
              e.toString().contains('401') ||
              e.toString().contains('No authentication token found')) {
            // Redirect to login
            Future.delayed(Duration.zero, () {
              Navigator.pushReplacementNamed(context, '/login');
            });
            errorMessage = 'Sesi telah berakhir. Silakan login kembali.';
          } else {
            errorMessage = 'Error: $e';
          }
        });
      }
    }
  }

  // Refresh data user
  Future<void> _refreshUserData() async {
    await _loadUserData();
    await _loadTeamActivities();
    await _loadUserStats();
  }

  Future<void> _logout() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const Center(
              child: CircularProgressIndicator(color: Color(0xFF003F87)),
            ),
      );

      await UserApiService.logout();

      if (mounted) {
        // Close loading dialog
        Navigator.pop(context);
        // Redirect to login
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (mounted) {
        // Close loading dialog
        Navigator.pop(context);

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during logout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showLogoutDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Konfirmasi Logout'),
            content: const Text(
              'Apakah Anda yakin ingin keluar dari aplikasi?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Logout'),
              ),
            ],
          ),
    );

    if (result == true) {
      _logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Format current date
    final formattedDate = DateFormat('EEEE, d MMMM yyyy').format(_currentTime);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header dengan logo dan profil
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 72,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Image.asset('assets/images/jtv_plus.png'),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "JTV PLUS",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF1E3A8A),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              "Presensi",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Welcome message & date
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLoadingUser
                          ? "Selamat Datang!"
                          : "Selamat Datang, ${currentUser?.nama ?? 'User'}!",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // Tampilkan error jika ada
                    if (errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        errorMessage,
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Profile Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        spreadRadius: 1,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Header with profile picture
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child:
                            isLoadingUser
                                ? _buildLoadingProfile()
                                : _buildProfileContent(),
                      ),

                      // Stats section
                      Container(
                        margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildModernStat(
                                  iconData: Icons.check_circle_outline,
                                  title:
                                      isLoadingStats
                                          ? "..."
                                          : "${userStats['hadir']}",
                                  subtitle: "Hadir",
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                              _buildVerticalDivider(),
                              Expanded(
                                child: _buildModernStat(
                                  iconData: Icons.access_time,
                                  title:
                                      isLoadingStats
                                          ? "..."
                                          : "${userStats['terlambat']}",
                                  subtitle: "Terlambat",
                                  color: const Color(0xFFF97316),
                                ),
                              ),
                              _buildVerticalDivider(),
                              Expanded(
                                child: _buildModernStat(
                                  iconData: Icons.calendar_today_outlined,
                                  title:
                                      isLoadingStats
                                          ? "..."
                                          : "${userStats['izin']}",
                                  subtitle: "Izin",
                                  color: const Color(0xFF6366F1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Team Activity header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Aktivitas Hari Ini",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Team Activity Table
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Table Header
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              flex: 3,
                              child: Text(
                                "Nama",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Container(
                                alignment: Alignment.center,
                                child: const Text(
                                  "Masuk",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Container(
                                alignment: Alignment.center,
                                child: const Text(
                                  "Pulang",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Container(
                                alignment: Alignment.center,
                                child: const Text(
                                  "Status",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFEEF2F6),
                      ),

                      // Loading atau Table Rows
                      isLoadingActivities
                          ? Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                const CircularProgressIndicator(
                                  color: Color(0xFF003F87),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Memuat aktivitas tim...',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                          : activitiesErrorMessage.isNotEmpty
                          ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  activitiesErrorMessage,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: _loadTeamActivities,
                                  child: const Text('Coba Lagi'),
                                ),
                              ],
                            ),
                          )
                          : timActivities.isEmpty
                          ? const Padding(
                            padding: EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  color: Color(0xFF64748B),
                                  size: 32,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Belum ada aktivitas hari ini',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                          : ListView.separated(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: timActivities.length,
                            separatorBuilder:
                                (context, index) => const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Color(0xFFEEF2F6),
                                ),
                            itemBuilder: (context, index) {
                              final activity = timActivities[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    // Nama dan Divisi
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  activity['nama'],
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                    color: Color(0xFF1E293B),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  activity['divisi'],
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Jam Masuk
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        alignment: Alignment.center,
                                        child: Text(
                                          activity['masuk'],
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Jam Pulang
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        alignment: Alignment.center,
                                        child: Text(
                                          activity['pulang'],
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Status
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        alignment: Alignment.center,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(
                                              activity['status'],
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            activity['status'],
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: _getStatusColor(
                                                activity['status'],
                                              ),
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 30)),
          ],
        ),
      ),
    );
  }

  // Widget untuk loading profile
  Widget _buildLoadingProfile() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Loading profile picture
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Loading text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 150,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 120,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: 100,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Widget untuk profile content
  Widget _buildProfileContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile picture dengan border effect
        Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow/gradient
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E3A8A), Color(0xFF1E3A8A)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            // Profile container
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF2F7FF), Color(0xFFF2F7FF)],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.person,
                size: 40,
                color: Color(0xFF1E3A8A),
              ),
            ),
            // Status indicator
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        // Profile info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      currentUser?.nama ?? "Nama tidak tersedia",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(
                    Icons.badge_outlined,
                    size: 14,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "ID: ${currentUser?.id ?? 'N/A'}",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.email_outlined,
                    size: 14,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      currentUser?.email ?? 'Email tidak tersedia',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Tags
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildModernTag(
                    label: currentUser?.divisi ?? "Divisi tidak tersedia",
                    iconData: Icons.computer,
                    color: const Color(0xFF1E3A8A),
                    bgColor: const Color(0xFFDBEAFE),
                  ),
                  _buildModernTag(
                    label: currentUser?.role ?? "Role tidak tersedia",
                    iconData: Icons.admin_panel_settings,
                    color: const Color(0xFF059669),
                    bgColor: const Color(0xFFD1FAE5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernTag({
    required String label,
    required IconData iconData,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernStat({
    required IconData iconData,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(iconData, size: 18, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(width: 1, color: const Color(0xFFE2E8F0)),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Hadir':
        return const Color(0xFF10B981);
      case 'Terlambat':
        return const Color(0xFFF97316);
      case 'Izin':
        return const Color(0xFF6366F1);
      default:
        return const Color(0xFF64748B);
    }
  }
}
