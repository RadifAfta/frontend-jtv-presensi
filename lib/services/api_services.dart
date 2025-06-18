import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import '../models/attendance_model.dart';
import '../utils/constants.dart';

class UserApiService {
  static const String baseUrl =
      'http://localhost:3000/api'; // Ganti dengan IP server Anda
      // 'http://192.168.1.182:3000/api'; // Ganti dengan IP server Anda
  static const _storage =
      FlutterSecureStorage(); // Gunakan FlutterSecureStorage

  // PENTING: Gunakan key yang konsisten untuk semua operasi token
  static const String _tokenKey =
      'token'; // atau 'auth_token', pilih salah satu

  // Get token from secure storage (sama seperti di main.dart)
  static Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey); // Gunakan key yang konsisten
    } catch (e) {
      print('Error getting token: $e');
      return null;
    }
  }

  // Get headers with authentication
  static Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Clear token when authentication fails
  static Future<void> clearToken() async {
    try {
      await _storage.delete(key: _tokenKey); // Gunakan key yang konsisten
    } catch (e) {
      print('Error clearing token: $e');
    }
  }

  static Future<User?> getCurrentUser() async {
    try {
      final headers = await _getHeaders();

      // Check if token exists
      if (!headers.containsKey('Authorization')) {
        throw Exception('No authentication token found');
      }

      final response = await http
          .get(Uri.parse('$baseUrl/me'), headers: headers)
          .timeout(const Duration(seconds: 10));

      print('getCurrentUser Response status: ${response.statusCode}');
      print('getCurrentUser Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Handle different response structures
        if (data['success'] == true && data['data'] != null) {
          return User.fromJson(data['data']);
        } else if (data['user'] != null) {
          return User.fromJson(data['user']);
        } else {
          return User.fromJson(data);
        }
      } else if (response.statusCode == 401) {
        // Token expired atau invalid - hapus token
        await clearToken();
        throw Exception('Authentication failed. Please login again.');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          '${response.statusCode} - ${errorData['message'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      print('Error getting current user: $e');
      rethrow; // Re-throw untuk handling di UI
    }
  }

  // NEW METHOD: Generate QR Token untuk attendance
  static Future<String> generateQRToken() async {
    try {
      final headers = await _getHeaders();

      // Check if token exists
      if (!headers.containsKey('Authorization')) {
        throw Exception('No authentication token found');
      }

      final response = await http
          .post(Uri.parse('$baseUrl/qrcode/generate-qr'), headers: headers)
          .timeout(const Duration(seconds: 10));

      print('generateQRToken Response status: ${response.statusCode}');
      print('generateQRToken Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);

        // Handle different response structures
        if (data['success'] == true && data['token'] != null) {
          return data['token'] as String;
        } else if (data['qr_token'] != null) {
          return data['qr_token'] as String;
        } else if (data['data'] != null && data['data']['token'] != null) {
          return data['data']['token'] as String;
        } else if (data['qrUrl'] != null) {
          // PERBAIKAN: Extract token from qrUrl
          String qrUrl = data['qrUrl'] as String;
          Uri uri = Uri.parse(qrUrl);
          String? token = uri.queryParameters['token'];

          if (token != null && token.isNotEmpty) {
            return token;
          } else {
            throw Exception('Token not found in qrUrl');
          }
        } else {
          throw Exception('Invalid response format: QR token not found');
        }
      } else if (response.statusCode == 401) {
        // Token expired atau invalid - hapus token
        await clearToken();
        throw Exception('Authentication failed. Please login again.');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          '${response.statusCode} - ${errorData['message'] ?? 'Failed to generate QR token'}',
        );
      }
    } catch (e) {
      print('Error generating QR token: $e');
      rethrow; // Re-throw untuk handling di UI
    }
  }

  // Method untuk login (jika belum ada)
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        // Save token if login successful - gunakan key yang konsisten
        if (data['token'] != null) {
          await _storage.write(key: _tokenKey, value: data['token']);
        }
        return data;
      } else {
        throw Exception(data['message'] ?? 'Login failed');
      }
    } catch (e) {
      print('Error during login: $e');
      rethrow;
    }
  }

  // Method untuk logout
  static Future<void> logout() async {
    try {
      final headers = await _getHeaders();

      // Panggil API logout jika ada
      if (headers.containsKey('Authorization')) {
        try {
          await http
              .post(Uri.parse('$baseUrl/logout'), headers: headers)
              .timeout(const Duration(seconds: 5));
        } catch (e) {
          print('Error calling logout API: $e');
        }
      }

      // Hapus token dari storage
      await clearToken();
    } catch (e) {
      print('Error during logout: $e');
    }
  }

  static Future<List<dynamic>> getAllUserAttendance() async {
    try {
      print('Checking authentication for getAllUserAttendance');

      // PERBAIKAN: Gunakan method getToken() yang sudah ada untuk konsistensi
      final token = await getToken();
      print(
        'Token found: ${token != null ? 'Yes (${token?.length} chars)' : 'No'}',
      );

      if (token == null || token.isEmpty) {
        print('No valid authentication token found');
        throw Exception('Authentication required');
      }

      // Gunakan baseUrl yang sama dengan method lain untuk konsistensi
      final url = '$baseUrl${ApiConstants.allAttendanceUserEndpoint}';
      print('Making request to: $url');

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10)); // Tambahkan timeout

      print('Get All User Attendance Response: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['success'] == true && responseData['data'] != null) {
          print(
            'Successfully got ${(responseData['data'] as List).length} attendance records',
          );
          return responseData['data'] as List<dynamic>;
        } else {
          print('Invalid response format: $responseData');
          throw Exception('Invalid response format');
        }
      } else if (response.statusCode == 401) {
        print('Authentication failed - token might be expired');
        // Clear token jika authentication failed
        await clearToken();
        throw Exception('Authentication failed');
      } else {
        print('HTTP Error: ${response.statusCode}, Body: ${response.body}');

        // Try to parse error message
        try {
          final errorData = json.decode(response.body);
          throw Exception(
            errorData['message'] ?? 'Server error: ${response.statusCode}',
          );
        } catch (e) {
          throw Exception('Server error: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error getting all user attendance: $e');
      rethrow;
    }
  }

  // OPTIONAL: Method untuk mendapatkan attendance history berdasarkan QR scan
  static Future<List<dynamic>> getAttendanceHistory({int? limit}) async {
    try {
      final headers = await _getHeaders();

      if (!headers.containsKey('Authorization')) {
        throw Exception('No authentication token found');
      }

      String url = '$baseUrl/attendance/history';
      if (limit != null) {
        url += '?limit=$limit';
      }

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 10));

      print('getAttendanceHistory Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['success'] == true && responseData['data'] != null) {
          return responseData['data'] as List<dynamic>;
        } else {
          throw Exception('Invalid response format');
        }
      } else if (response.statusCode == 401) {
        await clearToken();
        throw Exception('Authentication failed');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['message'] ?? 'Failed to get attendance history',
        );
      }
    } catch (e) {
      print('Error getting attendance history: $e');
      rethrow;
    }
  }

  static Future<List<dynamic>> getUserAttendance() async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Token tidak ditemukan. Silakan login kembali.');
      }

      final response = await http.get(
        Uri.parse(
          '$baseUrl/attendance',
        ), // Sesuai dengan route yang Anda berikan
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Get User Attendance Response Status: ${response.statusCode}');
      print('Get User Attendance Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Asumsikan response structure seperti:
        // { "success": true, "data": [...], "message": "..." }
        if (data['success'] == true && data['data'] != null) {
          return List<dynamic>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Gagal mengambil data presensi');
        }
      } else if (response.statusCode == 401) {
        await logout();
        throw Exception('Authentication failed. Please login again.');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['message'] ?? 'Server error: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error in getUserAttendance: $e');
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        throw Exception('Koneksi internet bermasalah. Periksa koneksi Anda.');
      }
      rethrow;
    }
  }

  static Future<List<dynamic>> getAllAttendance() async {
    try {
      print('Checking authentication for getAllUserAttendance');

      final token = await getToken();
      print(
        'Token found: ${token != null ? 'Yes (${token?.length} chars)' : 'No'}',
      );

      if (token == null || token.isEmpty) {
        print('No valid authentication token found');
        throw Exception('Authentication required');
      }

      // PERBAIKAN: Gunakan endpoint admin yang benar
      final url = '$baseUrl/attendance/all'; // Endpoint khusus admin
      print('Making request to: $url');

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      print('Get All User Attendance Response: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['success'] == true && responseData['data'] != null) {
          print(
            'Successfully got ${(responseData['data'] as List).length} attendance records',
          );
          return responseData['data'] as List<dynamic>;
        } else {
          print('Invalid response format: $responseData');
          throw Exception('Invalid response format');
        }
      } else if (response.statusCode == 401) {
        print('Authentication failed - token might be expired');
        await clearToken();
        throw Exception('Authentication failed');
      } else if (response.statusCode == 403) {
        print('Access forbidden - admin privileges required');
        throw Exception('Access denied. Admin privileges required.');
      } else {
        print('HTTP Error: ${response.statusCode}, Body: ${response.body}');

        try {
          final errorData = json.decode(response.body);
          throw Exception(
            errorData['message'] ?? 'Server error: ${response.statusCode}',
          );
        } catch (e) {
          throw Exception('Server error: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error getting all user attendance: $e');
      rethrow;
    }
  }
}
