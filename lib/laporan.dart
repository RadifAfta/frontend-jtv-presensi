import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import './services/api_services.dart';

class Laporan extends StatefulWidget {
  const Laporan({Key? key}) : super(key: key);

  @override
  State<Laporan> createState() => _LaporanState();
}

class _LaporanState extends State<Laporan> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> riwayatPresensi = [];
  bool isLoading = true;
  String errorMessage = '';
  DateTime currentMonth = DateTime.now();
  Map<String, int> statistics = {'hadir': 0, 'terlambat': 0, 'izin': 0};
  List<Map<String, dynamic>> allAttendanceData = [];
  bool _localeInitialized = false;

  // Admin-related variables
  bool isAdmin = false;
  late TabController _tabController;
  String selectedEmployee = 'all'; // 'all' untuk semua karyawan
  List<Map<String, dynamic>> employees = [];
  Map<String, List<Map<String, dynamic>>> employeeAttendanceMap = {};

  @override
  void initState() {
    super.initState();
    // _tabController = TabController(length: 2, vsync: this);
    _initializeLocaleAndLoadData();
  }

  @override
  void dispose() {
    // _tabController.dispose();
    super.dispose();
  }

  // Check if current user is admin
  Future<void> _checkUserRole() async {
    try {
      final user = await UserApiService.getCurrentUser();
      setState(() {
        isAdmin =
            user?.role?.toLowerCase() == 'admin' ||
            user?.role?.toLowerCase() == 'administrator';
      });
    } catch (e) {
      print('Error checking user role: $e');
      setState(() {
        isAdmin = false;
      });
    }
  }

  Future<void> _initializeLocaleAndLoadData() async {
    try {
      await initializeDateFormatting('id_ID', null);
      setState(() {
        _localeInitialized = true;
      });

      // Check user role first
      await _checkUserRole();

      // Load appropriate data based on role
      if (isAdmin) {
        await _loadAllAttendanceData();
      } else {
        await _loadUserAttendanceData();
      }
    } catch (e) {
      print('Error initializing locale: $e');
      setState(() {
        _localeInitialized = false;
      });
      await _loadUserAttendanceData();
    }
  }

  // Load user's own attendance data
  Future<void> _loadUserAttendanceData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      final List<dynamic> attendanceData =
          await UserApiService.getUserAttendance();
      final processedData = _processAttendanceData(attendanceData);

      setState(() {
        allAttendanceData = processedData;
        isLoading = false;
      });

      _filterDataByMonth();
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });

      if (mounted) {
        _showErrorDialog(e.toString());
      }
    }
  }

  // Load all attendance data for admin
  Future<void> _loadAllAttendanceData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      final List<dynamic> attendanceData =
          await UserApiService.getAllAttendance();

      if (attendanceData.isNotEmpty) {
        print('=== STRUKTUR DATA ATTENDANCE ===');
        print('Keys available: ${attendanceData[0].keys.toList()}');
        print('Sample data: ${attendanceData[0]}');
        print('===============================');
      }

      final processedData = _processAllAttendanceData(attendanceData);

      // Group by employee
      Map<String, List<Map<String, dynamic>>> employeeMap = {};
      Set<String> employeeSet = {};

      for (var item in processedData) {
        String employeeId = item['user_id']?.toString() ?? 'unknown';
        String employeeName = item['user_name'] ?? 'Unknown User';

        employeeSet.add('$employeeId|$employeeName');

        if (!employeeMap.containsKey(employeeId)) {
          employeeMap[employeeId] = [];
        }
        employeeMap[employeeId]!.add(item);
      }

      // Create employee list for dropdown
      List<Map<String, dynamic>> empList = [
        {'id': 'all', 'name': 'Semua Karyawan'},
      ];

      for (String emp in employeeSet) {
        List<String> parts = emp.split('|');
        empList.add({'id': parts[0], 'name': parts[1]});
      }

      setState(() {
        employeeAttendanceMap = employeeMap;
        employees = empList;
        allAttendanceData = processedData;
        isLoading = false;
      });

      _filterDataByMonth();
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });

      if (mounted) {
        _showErrorDialog(e.toString());
      }
    }
  }

  // Process attendance data for single user
  List<Map<String, dynamic>> _processAttendanceData(
    List<dynamic> attendanceData,
  ) {
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

          String masuk = '-';
          String pulang = '-';
          String jamLembur = '-';
          String status = item['category'] ?? 'Tidak Hadir';
          String jamTerlambat = '-';

          if (item['category'] == 'Masuk') {
            masuk = DateFormat('HH:mm').format(date);
          } else if (item['category'] == 'Pulang') {
            pulang = DateFormat('HH:mm').format(date);
          } else if (item['category'] == 'Terlambat') {
            jamTerlambat = DateFormat('HH:mm').format(date);
            status = 'Terlambat';
          } else if (item['category'] == 'Lembur') {
            jamLembur = DateFormat('HH:mm').format(date);
            status = 'Lembur';
          }

          return {
            'tanggal': DateFormat('yyyy-MM-dd').format(date),
            'masuk': masuk,
            'pulang': pulang,
            'jamTerlambat': jamTerlambat,
            'jamLembur': jamLembur,
            'status': status,
            'lokasi': 'Kantor Pusat',
            'rawDate': date,
            'originalCategory': item['category'], // simpan kategori asli
          };
        }).toList();

    return _groupAttendanceByDate(processedData);
  }

  // Process attendance data for all users (admin view)
  List<Map<String, dynamic>> _processAllAttendanceData(
    List<dynamic> attendanceData,
  ) {
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

          String masuk = '-';
          String pulang = '-';
          String jamLembur = '-';
          String status = item['category'] ?? 'Tidak Hadir';
          String jamTerlambat = '-';

          if (item['category'] == 'Masuk') {
            masuk = DateFormat('HH:mm').format(date);
          } else if (item['category'] == 'Pulang') {
            pulang = DateFormat('HH:mm').format(date);
          } else if (item['category'] == 'Terlambat') {
            jamTerlambat = DateFormat('HH:mm').format(date);
            status = 'Terlambat';
          } else if (item['category'] == 'Lembur') {
            jamLembur = DateFormat('HH:mm').format(date);
            status = 'Lembur';
          }

          // PERBAIKAN: Akses data user dari objek nested 'User'
          String userName = 'Unknown User';
          String userEmail = '';

          if (item['User'] != null) {
            // Data user ada di dalam objek 'User'
            Map<String, dynamic> userObj = item['User'];

            if (userObj['nama'] != null &&
                userObj['nama'].toString().isNotEmpty) {
              userName = userObj['nama'].toString();
            }

            if (userObj['email'] != null &&
                userObj['email'].toString().isNotEmpty) {
              userEmail = userObj['email'].toString();
            }
          }

          return {
            'tanggal': DateFormat('yyyy-MM-dd').format(date),
            'masuk': masuk,
            'pulang': pulang,
            'jamTerlambat': jamTerlambat,
            'jamLembur': jamLembur,
            'status': status,
            'lokasi': 'Kantor Pusat',
            'rawDate': date,
            'user_id': item['user_id'],
            'user_name': userName, // Menggunakan userName yang sudah diperbaiki
            'user_email':
                userEmail, // Menggunakan userEmail yang sudah diperbaiki
            'originalCategory': item['category'],
          };
        }).toList();

    // Group by user and date
    Map<String, Map<String, Map<String, dynamic>>> userDateMap = {};

    for (var item in processedData) {
      String userId = item['user_id']?.toString() ?? 'unknown';
      String dateKey = item['tanggal'];

      if (!userDateMap.containsKey(userId)) {
        userDateMap[userId] = {};
      }

      if (userDateMap[userId]!.containsKey(dateKey)) {
        // Merge check-in and check-out times
        if (item['masuk'] != '-') {
          userDateMap[userId]![dateKey]!['masuk'] = item['masuk'];
        }
        if (item['pulang'] != '-') {
          userDateMap[userId]![dateKey]!['pulang'] = item['pulang'];
        }
        if (item['jamTerlambat'] != '-') {
          userDateMap[userId]![dateKey]!['jamTerlambat'] = item['jamTerlambat'];
        }
        if (item['jamLembur'] != '-') {
          userDateMap[userId]![dateKey]!['jamLembur'] = item['jamLembur'];
        }

        // PERBAIKAN: Logika status yang lebih tepat
        String finalStatus = _combineStatuses(
          userDateMap[userId]![dateKey]!,
          item,
        );
        userDateMap[userId]![dateKey]!['status'] = finalStatus;
      } else {
        if (item['status'] == 'Masuk' || item['status'] == 'Pulang') {
          item['status'] = 'Hadir';
        }
        userDateMap[userId]![dateKey] = item;
      }
    }

    // Convert back to flat list
    List<Map<String, dynamic>> finalData = [];
    userDateMap.forEach((userId, dateMap) {
      finalData.addAll(dateMap.values);
    });

    finalData.sort((a, b) => b['rawDate'].compareTo(a['rawDate']));
    return finalData;
  }

  // Group attendance data by date (for single user)
  List<Map<String, dynamic>> _groupAttendanceByDate(
    List<Map<String, dynamic>> data,
  ) {
    Map<String, Map<String, dynamic>> groupedData = {};

    for (var item in data) {
      String dateKey = item['tanggal'];

      if (groupedData.containsKey(dateKey)) {
        if (item['masuk'] != '-') {
          groupedData[dateKey]!['masuk'] = item['masuk'];
        }
        if (item['pulang'] != '-') {
          groupedData[dateKey]!['pulang'] = item['pulang'];
        }
        if (item['jamTerlambat'] != '-') {
          groupedData[dateKey]!['jamTerlambat'] = item['jamTerlambat'];
        }
        if (item['jamLembur'] != '-') {
          groupedData[dateKey]!['jamLembur'] = item['jamLembur'];
        }

        // PERBAIKAN: Logika status yang lebih tepat
        String finalStatus = _combineStatuses(groupedData[dateKey]!, item);
        groupedData[dateKey]!['status'] = finalStatus;
      } else {
        if (item['status'] == 'Masuk' || item['status'] == 'Pulang') {
          item['status'] = 'Hadir';
        }
        groupedData[dateKey] = item;
      }
    }

    final List<Map<String, dynamic>> finalData = groupedData.values.toList();
    finalData.sort((a, b) => b['rawDate'].compareTo(a['rawDate']));
    return finalData;
  }

  String _combineStatuses(
    Map<String, dynamic> existingItem,
    Map<String, dynamic> newItem,
  ) {
    Set<String> statusSet = <String>{};

    // Ambil status dari data yang sudah ada
    String currentStatus = existingItem['status'];
    if (currentStatus != 'Masuk' && currentStatus != 'Pulang') {
      statusSet.add(currentStatus);
    }

    // Ambil status dari data baru
    String newStatus = newItem['status'];
    if (newStatus != 'Masuk' && newStatus != 'Pulang') {
      statusSet.add(newStatus);
    }

    // Logika prioritas status
    bool hasTerlambat = statusSet.contains('Terlambat');
    bool hasLembur = statusSet.contains('Lembur');
    bool hasHadir = statusSet.contains('Hadir');

    // Jika ada jam masuk atau pulang, berarti hadir
    if (existingItem['masuk'] != '-' ||
        existingItem['pulang'] != '-' ||
        newItem['masuk'] != '-' ||
        newItem['pulang'] != '-') {
      hasHadir = true;
    }

    List<String> finalStatuses = [];

    // Prioritas: Terlambat + Lembur
    if (hasTerlambat && hasLembur) {
      finalStatuses.add('Terlambat');
      finalStatuses.add('Lembur');
    } else if (hasTerlambat) {
      finalStatuses.add('Terlambat');
    } else if (hasLembur) {
      finalStatuses.add('Lembur');
    } else if (hasHadir) {
      finalStatuses.add('Hadir');
    }

    // Tambahkan status lainnya yang tidak termasuk dalam kategori di atas
    for (String status in statusSet) {
      if (![
        'Terlambat',
        'Lembur',
        'Hadir',
        'Masuk',
        'Pulang',
      ].contains(status)) {
        finalStatuses.add(status);
      }
    }

    // Jika tidak ada status sama sekali, default ke Hadir
    if (finalStatuses.isEmpty) {
      finalStatuses.add('Hadir');
    }

    return finalStatuses.join(', ');
  }

  void _filterDataByMonth() {
    List<Map<String, dynamic>> dataToFilter;

    if (isAdmin && selectedEmployee != 'all') {
      // Filter by specific employee
      dataToFilter =
          allAttendanceData.where((item) {
            return item['user_id']?.toString() == selectedEmployee;
          }).toList();
    } else {
      // All data or user's own data
      dataToFilter = allAttendanceData;
    }

    final filteredData =
        dataToFilter.where((item) {
          final DateTime itemDate = item['rawDate'];
          return itemDate.year == currentMonth.year &&
              itemDate.month == currentMonth.month;
        }).toList();

    Map<String, int> stats = {'hadir': 0, 'terlambat': 0, 'izin': 0};

    for (var item in filteredData) {
      String status = item['status'].toLowerCase();

      if (status == 'hadir') {
        stats['hadir'] = (stats['hadir'] ?? 0) + 1;
      } else if (status == 'terlambat') {
        stats['terlambat'] = (stats['terlambat'] ?? 0) + 1;
      } else if (status == 'izin' ||
          status == 'sakit' ||
          status == 'cuti' ||
          status == 'tidak hadir') {
        stats['izin'] = (stats['izin'] ?? 0) + 1;
      }
    }

    setState(() {
      riwayatPresensi = filteredData;
      statistics = stats;
    });
  }

  void _changeMonth(bool isNext) {
    setState(() {
      if (isNext) {
        currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
      } else {
        currentMonth = DateTime(currentMonth.year, currentMonth.month - 1);
      }
    });
    _filterDataByMonth();
  }

  void _onEmployeeChanged(String? employeeId) {
    if (employeeId != null) {
      setState(() {
        selectedEmployee = employeeId;
      });
      _filterDataByMonth();
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(
            message.contains('Authentication')
                ? 'Sesi Anda telah berakhir. Silakan login kembali.'
                : 'Gagal memuat data presensi: $message',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (message.contains('Authentication')) {
                  UserApiService.logout();
                }
              },
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (isAdmin) {
                  _loadAllAttendanceData();
                } else {
                  _loadUserAttendanceData();
                }
              },
              child: const Text('Coba Lagi'),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date, String pattern, {String? locale}) {
    try {
      if (_localeInitialized && locale != null) {
        return DateFormat(pattern, locale).format(date);
      } else {
        return DateFormat(pattern).format(date);
      }
    } catch (e) {
      return DateFormat(pattern).format(date);
    }
  }

  String _formatDayName(DateTime date) {
    try {
      if (_localeInitialized) {
        return DateFormat('EEEE', 'id_ID').format(date);
      } else {
        return DateFormat('EEEE').format(date);
      }
    } catch (e) {
      return DateFormat('EEEE').format(date);
    }
  }

  String _formatMonthYear(DateTime date) {
    try {
      if (_localeInitialized) {
        return DateFormat('MMMM yyyy', 'id_ID').format(date);
      } else {
        return DateFormat('MMMM yyyy').format(date);
      }
    } catch (e) {
      return DateFormat('MMMM yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FD),
      appBar: AppBar(
        elevation: 0,
        title: Text(
          "Laporan Presensi",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E3A8A),
          ),
        ),
        backgroundColor: Color(0xFFF8F9FD),
        // HAPUS: bottom: TabBar dan kondisi isAdmin
      ),
      body: _buildMainView(), // UBAH: langsung panggil method baru
    );
  }

  Widget _buildMainView() {
    return Column(
      children: [
        // Employee selector untuk admin
        if (isAdmin && employees.isNotEmpty)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedEmployee,
                isExpanded: true,
                hint: const Text('Pilih Karyawan'),
                items:
                    employees.map((employee) {
                      return DropdownMenuItem<String>(
                        value: employee['id'],
                        child: Text(employee['name']),
                      );
                    }).toList(),
                onChanged: _onEmployeeChanged,
              ),
            ),
          ),
        _buildStatisticsCard(),
        _buildMonthSelector(),
        _buildAttendanceTitle(),
        _buildAttendanceList(),
      ],
    );
  }

  Widget _buildUserView() {
    return Column(
      children: [
        _buildStatisticsCard(),
        _buildMonthSelector(),
        _buildAttendanceTitle(),
        _buildAttendanceList(),
      ],
    );
  }

  Widget _buildAdminView() {
    return Column(
      children: [
        // Employee selector
        if (employees.isNotEmpty)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedEmployee,
                isExpanded: true,
                hint: const Text('Pilih Karyawan'),
                items:
                    employees.map((employee) {
                      return DropdownMenuItem<String>(
                        value: employee['id'],
                        child: Text(employee['name']),
                      );
                    }).toList(),
                onChanged: _onEmployeeChanged,
              ),
            ),
          ),
        _buildStatisticsCard(),
        _buildMonthSelector(),
        _buildAttendanceTitle(),
        _buildAttendanceList(),
      ],
    );
  }

  Widget _buildStatisticsCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              context,
              Icons.check_circle_outline,
              Colors.green,
              '${statistics['hadir']}',
              'Hadir',
            ),
            _buildDivider(),
            _buildStatItem(
              context,
              Icons.warning_amber_outlined,
              Colors.orange,
              '${statistics['terlambat']}',
              'Terlambat',
            ),
            _buildDivider(),
            _buildStatItem(
              context,
              Icons.event_busy,
              Colors.blue,
              '${statistics['izin']}',
              'Izin',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _formatMonthYear(currentMonth),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 28),
                onPressed: () => _changeMonth(false),
                color: Colors.grey[700],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 28),
                onPressed: () => _changeMonth(true),
                color: Colors.grey[700],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          const Text(
            'Riwayat Presensi',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
              color: Color(0xFF666666),
            ),
          ),
          const Spacer(),
          Text(
            '${riwayatPresensi.length} hari',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceList() {
    return Expanded(
      child:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage.isNotEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Gagal memuat data',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      errorMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed:
                          isAdmin
                              ? _loadAllAttendanceData
                              : _loadUserAttendanceData,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              )
              : riwayatPresensi.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_busy, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada data presensi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'untuk bulan ${_formatMonthYear(currentMonth)}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: riwayatPresensi.length,
                itemBuilder:
                    (context, index) =>
                        _buildAttendanceCard(riwayatPresensi[index]),
              ),
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> presensi) {
    final DateTime date = presensi['rawDate'];

    Color statusColor;
    IconData statusIcon;
    String displayStatus = presensi['status'];

    // Handle multiple status
    String lowerStatus = presensi['status'].toLowerCase();
    if (lowerStatus.contains('terlambat')) {
      statusColor = Colors.orange;
      statusIcon = Icons.access_time;
    } else if (lowerStatus.contains('lembur')) {
      statusColor = Colors.purple;
      statusIcon = Icons.work_history;
    } else if (lowerStatus.contains('hadir')) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (lowerStatus.contains('izin') ||
        lowerStatus.contains('sakit') ||
        lowerStatus.contains('cuti')) {
      statusColor = Colors.blue;
      statusIcon = Icons.event_note;
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    }

    // Tentukan waktu yang akan ditampilkan
    String waktuPresensi;
    if (presensi['jamTerlambat'] != '-') {
      if (presensi['jamLembur'] != '-') {
        waktuPresensi =
            '${presensi['jamTerlambat']} - ${presensi['jamLembur']}';
      } else if (presensi['pulang'] != '-') {
        waktuPresensi = '${presensi['jamTerlambat']} - ${presensi['pulang']}';
      } else {
        waktuPresensi = presensi['jamTerlambat'];
      }
    } else if (presensi['masuk'] != '-') {
      if (presensi['jamLembur'] != '-') {
        waktuPresensi = '${presensi['masuk']} - ${presensi['jamLembur']}';
      } else if (presensi['pulang'] != '-') {
        waktuPresensi = '${presensi['masuk']} - ${presensi['pulang']}';
      } else {
        waktuPresensi = presensi['masuk'];
      }
    } else {
      waktuPresensi = 'Tidak ada catatan waktu';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Date column
            Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                color: const Color(0xFF003F87).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _formatDate(date, 'dd'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Color(0xFF003F87),
                    ),
                  ),
                  Text(
                    _formatDate(date, 'MMM'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF003F87),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 14),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day name and user name (untuk admin)
                  Row(
                    children: [
                      Text(
                        _formatDayName(date),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      // PERBAIKAN: Tampilkan nama user hanya untuk admin dan ketika "Semua Karyawan"
                      if (isAdmin &&
                          selectedEmployee == 'all' &&
                          presensi['user_name'] != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            presensi['user_name'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Check-in/Check-out times
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        waktuPresensi,
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),

                  const SizedBox(height: 2),

                  // Location
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        presensi['lokasi'],
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 14, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    displayStatus,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    Color color,
    String count,
    String label,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          count,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(height: 40, width: 1, color: Colors.grey.withOpacity(0.3));
  }
}
