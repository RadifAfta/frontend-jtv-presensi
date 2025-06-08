import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Tambahkan import ini
import './services/api_services.dart';

class Laporan extends StatefulWidget {
  const Laporan({Key? key}) : super(key: key);

  @override
  State<Laporan> createState() => _LaporanState();
}

class _LaporanState extends State<Laporan> {
  List<Map<String, dynamic>> riwayatPresensi = [];
  bool isLoading = true;
  String errorMessage = '';
  DateTime currentMonth = DateTime.now();
  Map<String, int> statistics = {
    'hadir': 0,
    'terlambat': 0,
    'izin': 0,
  };
  List<Map<String, dynamic>> allAttendanceData = [];
  bool _localeInitialized = false; // Track locale initialization

  @override
  void initState() {
    super.initState();
    _initializeLocaleAndLoadData();
  }

  // Inisialisasi locale terlebih dahulu, baru load data
  Future<void> _initializeLocaleAndLoadData() async {
    try {
      // Inisialisasi locale Indonesia
      await initializeDateFormatting('id_ID', null);
      setState(() {
        _localeInitialized = true;
      });
      
      // Setelah locale berhasil diinisialisasi, load data
      await _loadAttendanceData();
    } catch (e) {
      print('Error initializing locale: $e');
      // Jika gagal inisialisasi locale, coba tanpa locale
      setState(() {
        _localeInitialized = false;
      });
      await _loadAttendanceData();
    }
  }

  Future<void> _loadAttendanceData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      final List<dynamic> attendanceData = await UserApiService.getUserAttendance();
      
      // Process the API response based on the actual structure
      final List<Map<String, dynamic>> processedData = attendanceData.map((item) {
        // Parse scan_time from the API response
        DateTime date;
        if (item['scan_time'] != null) {
          date = DateTime.parse(item['scan_time']);
        } else if (item['created_at'] != null) {
          date = DateTime.parse(item['created_at']);
        } else {
          date = DateTime.now();
        }

        // Determine check-in/check-out times based on category
        String masuk = '-';
        String pulang = '-';
        
        // Ambil status langsung dari kategori API
        String status = item['category'] ?? 'Tidak Hadir';

        if (item['category'] == 'Masuk') {
          masuk = DateFormat('HH:mm').format(date);
        } else if (item['category'] == 'Pulang') {
          pulang = DateFormat('HH:mm').format(date);
        }

        return {
          'tanggal': DateFormat('yyyy-MM-dd').format(date),
          'masuk': masuk,
          'pulang': pulang,
          'status': status, // Langsung ambil dari kategori API
          'lokasi': 'Kantor Pusat', // Default location since not provided in API
          'rawDate': date,
        };
      }).toList();

      // Group by date and merge check-in/check-out times
      Map<String, Map<String, dynamic>> groupedData = {};
      
      for (var item in processedData) {
        String dateKey = item['tanggal'];
        
        if (groupedData.containsKey(dateKey)) {
          // Merge check-in and check-out times
          if (item['masuk'] != '-') {
            groupedData[dateKey]!['masuk'] = item['masuk'];
          }
          if (item['pulang'] != '-') {
            groupedData[dateKey]!['pulang'] = item['pulang'];
          }
          
          // Update status - ambil status yang bukan 'Masuk' atau 'Pulang'
          // Jika ada status selain Masuk/Pulang, gunakan itu
          if (item['status'] != 'Masuk' && item['status'] != 'Pulang') {
            groupedData[dateKey]!['status'] = item['status'];
          } else if (groupedData[dateKey]!['status'] == 'Masuk' || groupedData[dateKey]!['status'] == 'Pulang') {
            // Jika status sebelumnya juga Masuk/Pulang, set ke Hadir
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

      // Convert back to list and sort by date
      final List<Map<String, dynamic>> finalData = groupedData.values.toList();
      finalData.sort((a, b) => b['rawDate'].compareTo(a['rawDate']));

      setState(() {
        allAttendanceData = finalData;
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

  void _filterDataByMonth() {
    final filteredData = allAttendanceData.where((item) {
      final DateTime itemDate = item['rawDate'];
      return itemDate.year == currentMonth.year && itemDate.month == currentMonth.month;
    }).toList();

    Map<String, int> stats = {
      'hadir': 0,
      'terlambat': 0,
      'izin': 0,
    };

    for (var item in filteredData) {
      String status = item['status'].toLowerCase();
      
      // Mapping status berdasarkan kategori API
      if (status == 'hadir') {
        stats['hadir'] = (stats['hadir'] ?? 0) + 1;
      } else if (status == 'terlambat') {
        stats['terlambat'] = (stats['terlambat'] ?? 0) + 1;
      } else if (status == 'izin' || status == 'sakit' || status == 'cuti' || status == 'tidak hadir') {
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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message.contains('Authentication') 
              ? 'Sesi Anda telah berakhir. Silakan login kembali.'
              : 'Gagal memuat data presensi: $message'),
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
                _loadAttendanceData();
              },
              child: const Text('Coba Lagi'),
            ),
          ],
        );
      },
    );
  }

  // Safe date formatting dengan fallback
  String _formatDate(DateTime date, String pattern, {String? locale}) {
    try {
      if (_localeInitialized && locale != null) {
        return DateFormat(pattern, locale).format(date);
      } else {
        return DateFormat(pattern).format(date);
      }
    } catch (e) {
      // Fallback to basic formatting if locale fails
      return DateFormat(pattern).format(date);
    }
  }

  String _formatDayName(DateTime date) {
    try {
      if (_localeInitialized) {
        return DateFormat('EEEE', 'id_ID').format(date);
      } else {
        // Fallback to English day names
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
        title: const Text(
          "Laporan Presensi Saya",
          style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E3A8A)),
        ),
        backgroundColor: Color(0xFFF8F9FD),
      ),
      body: Column(
        children: [
          // Statistics Card
          Container(
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
          ),

          // Month selector
          Padding(
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
          ),

          // Riwayat Presensi Title
          Padding(
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
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red[300],
                            ),
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
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadAttendanceData,
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
                                Icon(
                                  Icons.event_busy,
                                  size: 64,
                                  color: Colors.grey[300],
                                ),
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
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: riwayatPresensi.length,
                            itemBuilder: (context, index) {
                              final presensi = riwayatPresensi[index];
                              final DateTime date = presensi['rawDate'];

                              // Determine status color and icon berdasarkan kategori API
                              Color statusColor;
                              IconData statusIcon;
                              String displayStatus = presensi['status'];
                              
                              switch (presensi['status'].toLowerCase()) {
                                case 'hadir':
                                  statusColor = Colors.green;
                                  statusIcon = Icons.check_circle;
                                  break;
                                case 'terlambat':
                                  statusColor = Colors.orange;
                                  statusIcon = Icons.access_time;
                                  break;
                                case 'izin':
                                case 'sakit':
                                case 'cuti':
                                  statusColor = Colors.blue;
                                  statusIcon = Icons.event_note;
                                  break;
                                default:
                                  statusColor = Colors.red;
                                  statusIcon = Icons.cancel;
                              }

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 6,
                                  horizontal: 8,
                                ),
                                elevation: 0.5,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
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
                                            // Day name
                                            Text(
                                              _formatDayName(date),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                              ),
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
                                                  presensi['masuk'] == '-'
                                                      ? 'Tidak ada catatan waktu'
                                                      : '${presensi['masuk']} - ${presensi['pulang']}',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[700],
                                                  ),
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
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Status
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
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
                            },
                          ),
          ),
        ],
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