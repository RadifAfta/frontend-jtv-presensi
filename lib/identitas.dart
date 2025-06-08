import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import './services/api_services.dart';
import '../models/user_model.dart';

class Identitas extends StatefulWidget {
  const Identitas({Key? key}) : super(key: key);

  @override
  State<Identitas> createState() => _IdentitasState();
}

class _IdentitasState extends State<Identitas> {
  User? currentUser;
  bool isLoadingUser = true;
  bool isLoadingQR = false;
  String errorMessage = '';
  String? qrToken; // Token untuk QR code
  DateTime? tokenGeneratedAt; // Waktu generate token

  @override
  void initState() {
    super.initState();
    _checkAuthenticationAndLoadUser();
  }

  Future<void> _checkAuthenticationAndLoadUser() async {
    try {
      final isAuth = await UserApiService.isAuthenticated();
      if (!isAuth) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
          return;
        }
      } else {
        await _loadUserData();
        await _generateQRToken(); // Generate QR token setelah load user
      }
    } catch (e) {
      print('Error checking authentication: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

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

          if (e.toString().contains('Authentication failed') ||
              e.toString().contains('401') ||
              e.toString().contains('No authentication token found')) {
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

  Future<void> _generateQRToken() async {
    if (currentUser == null) return;

    setState(() {
      isLoadingQR = true;
      errorMessage = '';
    });

    try {
      final token = await UserApiService.generateQRToken();

      if (mounted) {
        setState(() {
          qrToken = token;
          tokenGeneratedAt = DateTime.now();
          isLoadingQR = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingQR = false;
          errorMessage = 'Gagal generate QR token: $e';
        });
      }
    }
  }

  Future<void> _refreshUserData() async {
    await _loadUserData();
    await _generateQRToken(); // Refresh QR token juga
  }

  // Check if token needs refresh (misalnya setiap 5 menit)
  bool _shouldRefreshToken() {
    if (tokenGeneratedAt == null) return true;

    final difference = DateTime.now().difference(tokenGeneratedAt!);
    return difference.inMinutes >= 5; // Refresh setiap 5 menit
  }

  String _generateQRData() {
    if (qrToken == null || currentUser == null) {
      return 'QR Token not available';
    }

    // Format QR data untuk IoT device scanning
    // Format: token,user_id,timestamp
    // IoT akan scan ini dan mengirim ke backend untuk record attendance
    return '$qrToken,${currentUser!.id},${DateTime.now().millisecondsSinceEpoch}';
  }

  Widget _buildQRCodeSection() {
    if (isLoadingUser || isLoadingQR) {
      return Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
        ),
      );
    }

    if (currentUser == null || qrToken == null) {
      return Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.grey, size: 48),
              const SizedBox(height: 8),
              const Text(
                'QR Code tidak tersedia',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _generateQRToken,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Generate QR'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        QrImageView(
          data: _generateQRData(),
          version: QrVersions.auto,
          size: 200,
          backgroundColor: Colors.white,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.circle,
            color: Color(0xFF1E3A8A),
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.circle,
            color: Color(0xFF1E3A8A),
          ),
          embeddedImage: const AssetImage('assets/images/jtv.png'),
          embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(40, 40)),
        ),

        // Token info dan refresh button
        const SizedBox(height: 16),

        if (tokenGeneratedAt != null) ...[
          Text(
            'Token: ${qrToken?.substring(0, 8)}...',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Generated: ${_formatTime(tokenGeneratedAt!)}',
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),

          const SizedBox(height: 12),

          // Refresh button dengan indikator jika perlu refresh
          ElevatedButton.icon(
            onPressed: isLoadingQR ? null : _generateQRToken,
            icon: Icon(
              _shouldRefreshToken() ? Icons.refresh : Icons.qr_code,
              size: 16,
            ),
            label: Text(
              _shouldRefreshToken() ? 'Refresh QR' : 'QR Active',
              style: const TextStyle(fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _shouldRefreshToken() ? Colors.orange : Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Color(0xFFF8F9FD),
        iconTheme: const IconThemeData(color: Color.fromARGB(255, 0, 0, 0)),
        title: const Text(
          "Identitas",
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Profile Avatar and Name Section with modern design
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Modern gradient border avatar
                  Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0061CF), Color(0xFF1E3A8A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      padding: const EdgeInsets.all(5),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F7FF),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child:
                            isLoadingUser
                                ? const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF1E3A8A),
                                  ),
                                )
                                : const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Color(0xFF1E3A8A),
                                ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Name with modern typography
              isLoadingUser
                  ? Container(
                    width: 200,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  )
                  : Text(
                    currentUser?.nama ?? "Nama tidak tersedia",
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: 0.5,
                    ),
                  ),

              const SizedBox(height: 8),

              // Email with subtle container
              isLoadingUser
                  ? Container(
                    width: 150,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(20),
                    ),
                  )
                  : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F7FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          size: 16,
                          color: Color(0xFF1E3A8A),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currentUser?.email ?? "Email tidak tersedia",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),

              // Show error message if any
              if (errorMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorMessage,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 50),

              // Modern QR Code Card with subtle shadow and rounded corners
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0061CF).withOpacity(0.1),
                      blurRadius: 40,
                      offset: const Offset(0, 10),
                      spreadRadius: 0,
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                ),
                child: Column(
                  children: [
                    // Modern styled QR code with gradient container
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF0061CF).withOpacity(0.05),
                            const Color(0xFF1E3A8A).withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: _buildQRCodeSection(),
                    ),

                    const SizedBox(height: 24),

                    // Scan instruction with modern design
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F7FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A8A).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.qr_code_scanner,
                              size: 18,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "Scan untuk absensi",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Security tip with modern design
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFE0B2), width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE0B2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.security,
                        size: 22,
                        color: Color(0xFFFF9800),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Keamanan",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "QR code akan otomatis diperbarui secara berkala untuk keamanan.",
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
