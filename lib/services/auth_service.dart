import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/user_model.dart';
import 'db_service.dart';
import 'log_service.dart';
import 'secure_storage_service.dart';

/// AuthService handles REST API communication with chatApp_App.
/// Attaches Authorization: Bearer <token> headers to requests (no cookies required).
class AuthService {
  static final _secureStorage = SecureStorageService.instance;

  // Store JWT token in hardware-backed Secure Storage (Android Keystore / iOS Keychain)
  static Future<void> saveToken(String token) async {
    await _secureStorage.saveToken(token);
  }

  static Future<String?> getToken() async {
    return await _secureStorage.getToken();
  }

  static Future<void> clearToken() async {
    await _secureStorage.clearToken();
  }

  static Future<void> saveUserMblNo(String mblNo) async {
    await _secureStorage.saveUserMblNo(mblNo);
  }

  static Future<String?> getUserMblNo() async {
    return await _secureStorage.getUserMblNo();
  }

  // Header helper: Includes Authorization Bearer header
  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'X-Client-Type': 'mobile',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // POST /auth/login
  Future<http.Response> login(String mblNo, String password) async {
    final url = Uri.parse('${AppConfig.baseUrl}/auth/login');
    LogService.http('POST /auth/login', 'mblNo: $mblNo');
    try {
      final response = await http.post(
        url,
        headers: await _headers(),
        body: jsonEncode({'mblNo': mblNo, 'pass': password}),
      );
      LogService.http(
        'POST /auth/login Response [${response.statusCode}]',
        response.body,
      );
      return response;
    } catch (e, st) {
      LogService.error('POST /auth/login Failed', e, st);
      rethrow;
    }
  }

  // POST /auth/verify-otp
  Future<http.Response> verifyOtp(String mblNo, String otp,
      {String? verificationToken}) async {
    final url = Uri.parse('${AppConfig.baseUrl}/auth/verify-otp');
    LogService.http('POST /auth/verify-otp', 'mblNo: $mblNo');
    try {
      final response = await http.post(
        url,
        headers: await _headers(),
        body: jsonEncode({
          'mblNo': mblNo,
          'otp': otp,
          if (verificationToken != null) 'verificationToken': verificationToken,
        }),
      );
      LogService.http(
        'POST /auth/verify-otp Response [${response.statusCode}]',
        response.body,
      );

      if (response.statusCode == 200) {
        final body = response.body;
        if (body.startsWith('Token: ')) {
          final token = body.replaceFirst('Token: ', '').trim();
          await saveToken(token);
          await saveUserMblNo(mblNo);
        }
      }
      return response;
    } catch (e, st) {
      LogService.error('POST /auth/verify-otp Failed', e, st);
      rethrow;
    }
  }

  Future<String?> verifyOtpAndLogin(String mblNo, String otp,
      {String? verificationToken}) async {
    try {
      final res =
          await verifyOtp(mblNo, otp, verificationToken: verificationToken);
      if (res.statusCode == 200 && res.body.startsWith('Token: ')) {
        return res.body.replaceFirst('Token: ', '').trim();
      }
    } catch (_) {}
    return null;
  }

  // POST /auth/signup
  Future<http.Response> signUp({
    required String name,
    required String mblNo,
    required String email,
    required String pass,
    required String confirmPass,
    required String gender,
    required String dob,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/auth/signup');
    LogService.http(
        'POST /auth/signup', 'mblNo: $mblNo, email: $email, gender: $gender');
    try {
      final response = await http.post(
        url,
        headers: await _headers(),
        body: jsonEncode({
          'name': name,
          'mblNo': mblNo,
          'email': email,
          'pass': pass,
          'confirmPass': confirmPass,
          'gender': gender,
          'dob': dob,
        }),
      );
      LogService.http(
        'POST /auth/signup Response [${response.statusCode}]',
        response.body,
      );
      return response;
    } catch (e, st) {
      LogService.error('POST /auth/signup Failed', e, st);
      rethrow;
    }
  }

  // POST /auth/verify-signup
  Future<http.Response> verifySignup(String mblNo, String otp,
      {String? verificationToken}) async {
    final url = Uri.parse('${AppConfig.baseUrl}/auth/verify-signup');
    LogService.http('POST /auth/verify-signup', 'mblNo: $mblNo');
    try {
      final response = await http.post(
        url,
        headers: await _headers(),
        body: jsonEncode({
          'mblNo': mblNo,
          'otp': otp,
          if (verificationToken != null) 'verificationToken': verificationToken,
        }),
      );
      LogService.http(
        'POST /auth/verify-signup Response [${response.statusCode}]',
        response.body,
      );
      return response;
    } catch (e, st) {
      LogService.error('POST /auth/verify-signup Failed', e, st);
      rethrow;
    }
  }

  // POST /secure/ws-ticket -> Gets single-use WebSocket ticket
  Future<String?> fetchWsTicket() async {
    final url = Uri.parse('${AppConfig.baseUrl}/secure/ws-ticket');
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        LogService.error(
            'POST /secure/ws-ticket Failed: JWT auth token is null or empty');
        return null;
      }
      LogService.http('POST /secure/ws-ticket');
      final response = await http.post(
        url,
        headers: await _headers(),
      );
      LogService.http(
        'POST /secure/ws-ticket Response [${response.statusCode}]',
        response.body,
      );

      if (response.statusCode == 200) {
        return response.body.trim();
      } else {
        LogService.error(
            'POST /secure/ws-ticket returned status ${response.statusCode}: ${response.body}');
      }
    } catch (e, st) {
      LogService.error('POST /secure/ws-ticket Failed with exception', e, st);
    }
    return null;
  }

  // POST /user/getNewUser -> Checks if user exists by mobile number
  Future<Map<String, dynamic>?> getNewUser(String mblNo) async {
    final url = Uri.parse('${AppConfig.baseUrl}/user/getNewUser');
    LogService.http('POST /user/getNewUser', 'receiver: $mblNo');
    try {
      final response = await http.post(
        url,
        headers: await _headers(),
        body: jsonEncode({'receiver': mblNo.trim()}),
      );
      LogService.http(
        'POST /user/getNewUser Response [${response.statusCode}]',
        response.body,
      );

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty || body == 'null') {
          return null;
        }
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (e, st) {
      LogService.error('POST /user/getNewUser Failed', e, st);
    }
    return null;
  }

  // GET /user/profile -> Retrieves user profile data from local encrypted SQLite cache (0 BE hits), or fetches from backend
  Future<UserModel?> getProfile({bool forceRefresh = false}) async {
    final currentMbl = await getUserMblNo();

    // 1. Check local encrypted SQLite database cache first (0 BE hits)
    if (!forceRefresh && currentMbl != null && currentMbl.isNotEmpty) {
      final cachedProfile =
          await DatabaseService.instance.getUserProfile(currentMbl);
      if (cachedProfile != null) {
        LogService.info(
            'AuthService: Profile retrieved from local SQLite cache (0 BE hits)');
        return cachedProfile;
      }
    }

    // 2. Fetch from backend API if not cached locally
    final url = Uri.parse('${AppConfig.baseUrl}/user/profile');
    LogService.http('GET /user/profile');
    try {
      final response = await http.get(
        url,
        headers: await _headers(),
      );
      LogService.http(
        'GET /user/profile Response [${response.statusCode}]',
        response.body,
      );

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isNotEmpty && body != 'null') {
          final decoded = jsonDecode(body);
          if (decoded is Map<String, dynamic>) {
            final user = UserModel.fromJson(decoded);
            // Save fresh profile to local encrypted SQLite cache
            await DatabaseService.instance.saveUserProfile(user);
            return user;
          }
        }
      }
    } catch (e, st) {
      LogService.error('GET /user/profile Failed', e, st);
    }
    return null;
  }

  // POST /user/profile/update -> Updates user profile data on backend & saves to local SQLite cache
  Future<UserModel?> updateProfile(UserModel updated) async {
    final url = Uri.parse('${AppConfig.baseUrl}/user/profile/update');
    LogService.http('POST /user/profile/update', jsonEncode(updated.toJson()));
    try {
      final response = await http.post(
        url,
        headers: await _headers(),
        body: jsonEncode(updated.toJson()),
      );
      LogService.http(
        'POST /user/profile/update Response [${response.statusCode}]',
        response.body,
      );

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isNotEmpty && body != 'null') {
          final decoded = jsonDecode(body);
          if (decoded is Map<String, dynamic>) {
            final user = UserModel.fromJson(decoded);
            // Save updated profile to local encrypted SQLite cache
            await DatabaseService.instance.saveUserProfile(user);
            return user;
          }
        }
        // Save to local cache even if server response body was empty
        await DatabaseService.instance.saveUserProfile(updated);
        return updated;
      }
    } catch (e, st) {
      LogService.error('POST /user/profile/update Failed', e, st);
    }
    return null;
  }

  // GET /user/presigned-url?fileExtension=<ext> -> Requests Cloudflare R2 presigned PUT URL
  Future<Map<String, String>?> getPresignedUrl(String fileExtension) async {
    final cleanExt = fileExtension.toLowerCase().replaceAll('.', '').trim();
    final url = Uri.parse(
        '${AppConfig.baseUrl}/user/presigned-url?fileExtension=$cleanExt');
    LogService.http('GET /user/presigned-url', 'ext: $cleanExt');
    try {
      final response = await http.get(
        url,
        headers: await _headers(),
      );
      LogService.http(
        'GET /user/presigned-url Response [${response.statusCode}]',
        response.body,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          final uploadUrl = decoded['uploadUrl']?.toString();
          final filePublicUrl = decoded['filePublicUrl']?.toString();
          if (uploadUrl != null && filePublicUrl != null) {
            return {
              'uploadUrl': uploadUrl,
              'filePublicUrl': filePublicUrl,
            };
          }
        }
      }
    } catch (e, st) {
      LogService.error('GET /user/presigned-url Failed', e, st);
    }
    return null;
  }

  // PUT uploadUrl with raw image bytes -> Uploads directly to Cloudflare R2
  Future<Map<String, dynamic>> uploadImageToPresignedUrl({
    required String uploadUrl,
    required List<int> imageBytes,
    required String fileExtension,
  }) async {
    final cleanExt = fileExtension.toLowerCase().replaceAll('.', '').trim();
    // Match the exact contentType that ImageUploadController signs ("image/" + fileExtension)
    final contentType = 'image/$cleanExt';
    LogService.http('PUT to Cloudflare Presigned URL',
        'Size: ${imageBytes.length} bytes, Type: $contentType, URL: $uploadUrl');
    try {
      final response = await http.put(
        Uri.parse(uploadUrl),
        headers: {
          'Content-Type': contentType,
        },
        body: imageBytes,
      );
      LogService.http(
        'PUT R2 Response [${response.statusCode}]',
        response.body,
      );
      final isSuccess =
          response.statusCode == 200 || response.statusCode == 204;
      return {
        'success': isSuccess,
        'statusCode': response.statusCode,
        'body': response.body,
      };
    } catch (e, st) {
      LogService.error('PUT to Cloudflare Presigned URL Failed', e, st);
      return {
        'success': false,
        'statusCode': -1,
        'body': e.toString(),
      };
    }
  }
}
