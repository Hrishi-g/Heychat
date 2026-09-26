import 'dart:convert';
import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'db_service.dart';
import 'log_service.dart';

class GoogleDriveBackupInfo {
  final String fileId;
  final DateTime modifiedTime;
  final int sizeInBytes;

  GoogleDriveBackupInfo({
    required this.fileId,
    required this.modifiedTime,
    required this.sizeInBytes,
  });
}

/// GoogleDriveService manages cloud backups of heychat_encrypted.db
/// to the user's private, hidden Google Drive appDataFolder.
class GoogleDriveService {
  static final GoogleDriveService instance = GoogleDriveService._init();
  GoogleDriveService._init();

  static const String _backupFileName = 'heychat_backup.db';
  static const String _appDataScope =
      'https://www.googleapis.com/auth/drive.appdata';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [_appDataScope],
  );

  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;

  Future<GoogleSignInAccount?> signIn() async {
    try {
      // 1. Try silent sign-in first (no UI popups if already authorized)
      _currentUser = await _googleSignIn.signInSilently();
      if (_currentUser != null) {
        LogService.info(
            'GoogleDriveService: Silently signed in as ${_currentUser?.email}');
        return _currentUser;
      }

      // 2. If silent sign-in returns null (first time), prompt account picker
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser != null) {
        LogService.info(
            'GoogleDriveService: Signed in as ${_currentUser?.email}');
      }
      return _currentUser;
    } catch (e, st) {
      LogService.error('GoogleDriveService: Sign in failed', e, st);
      final errStr = e.toString();
      if (errStr.contains('sign_in_failed') || errStr.contains('10:')) {
        throw Exception(
            'Google Sign-In failed (ApiException 10). Please ensure Google Drive API is enabled and restart the app after modifying build.gradle.kts.');
      }
      rethrow;
    }
  }

  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      return _currentUser;
    } catch (e) {
      LogService.error('GoogleDriveService: Silent sign in failed', e);
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _currentUser = null;
      LogService.info('GoogleDriveService: Signed out successfully');
    } catch (e) {
      LogService.error('GoogleDriveService: Sign out failed', e);
    }
  }

  Future<Map<String, String>> _authHeaders() async {
    _currentUser ??= await signInSilently();
    _currentUser ??= await signIn();
    if (_currentUser == null) {
      throw Exception(
          'Google Sign-In failed or was cancelled. Please ensure your Google Account is selected.');
    }

    try {
      final headers = await _currentUser!.authHeaders;
      if (headers.containsKey('Authorization') &&
          headers['Authorization'] != null &&
          headers['Authorization']!.isNotEmpty) {
        return headers;
      }
    } catch (e) {
      LogService.error('GoogleDriveService: authHeaders retrieval failed', e);
    }

    try {
      final auth = await _currentUser!.authentication;
      final token = auth.accessToken;
      if (token != null && token.isNotEmpty) {
        return {
          'Authorization': 'Bearer $token',
        };
      }
    } catch (e) {
      LogService.error(
          'GoogleDriveService: authentication token retrieval failed', e);
    }

    throw Exception(
        'Could not obtain Google Drive OAuth access token. On Android, please ensure Google Drive API is enabled and your App SHA-1 fingerprint is registered in Google Cloud Console.');
  }

  /// Search appDataFolder for an existing heychat_backup.db file
  Future<GoogleDriveBackupInfo?> getBackupMetadata() async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse(
          'https://www.googleapis.com/drive/v3/files?spaces=appDataFolder&q=name%3D%27$_backupFileName%27+and+trashed%3Dfalse&fields=files(id%2Cname%2CmodifiedTime%2Csize)');

      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List files = decoded['files'] ?? [];
        if (files.isNotEmpty) {
          final first = files.first;
          final fileId = first['id']?.toString() ?? '';
          final modTimeStr = first['modifiedTime']?.toString();
          final sizeStr = first['size']?.toString() ?? '0';

          final modTime = modTimeStr != null
              ? DateTime.parse(modTimeStr).toLocal()
              : DateTime.now();
          final size = int.tryParse(sizeStr) ?? 0;

          return GoogleDriveBackupInfo(
            fileId: fileId,
            modifiedTime: modTime,
            sizeInBytes: size,
          );
        }
      }
      return null;
    } catch (e) {
      LogService.error('GoogleDriveService: Error fetching backup metadata', e);
      return null;
    }
  }

  /// Upload/Overwrite local heychat_encrypted.db to Google Drive appDataFolder
  Future<bool> uploadBackup() async {
    try {
      final dbPath = await DatabaseService.instance.getDatabaseFilePath();
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) {
        throw Exception('Local database file does not exist at $dbPath');
      }

      // Safely copy DB file to temporary directory before reading bytes to avoid SQLite file-lock conflicts
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/heychat_backup_temp.db');
      await dbFile.copy(tempFile.path);

      final bytes = await tempFile.readAsBytes();
      try {
        await tempFile.delete();
      } catch (_) {}

      final headers = await _authHeaders();
      final existingBackup = await getBackupMetadata();

      if (existingBackup != null) {
        // Update existing backup file via PATCH media upload
        final patchUrl = Uri.parse(
            'https://www.googleapis.com/upload/drive/v3/files/${existingBackup.fileId}?uploadType=media');
        final response = await http.patch(
          patchUrl,
          headers: {
            ...headers,
            'Content-Type': 'application/octet-stream',
          },
          body: bytes,
        );

        if (response.statusCode == 200) {
          LogService.info(
              'GoogleDriveService: Successfully updated cloud backup (${bytes.length} bytes)');
          return true;
        } else {
          final errBody = response.body;
          LogService.error(
              'GoogleDriveService: PATCH upload failed [HTTP ${response.statusCode}]: $errBody');
          throw Exception(
              'Google Drive API HTTP ${response.statusCode}: $errBody');
        }
      } else {
        // Create new backup file via multipart upload
        final createUrl = Uri.parse(
            'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart');
        const boundary = 'heychat_backup_boundary_xyz123';

        final metadataJson = jsonEncode({
          'name': _backupFileName,
          'parents': ['appDataFolder'],
        });

        List<int> body = [];
        body.addAll(utf8.encode('--$boundary\r\n'));
        body.addAll(utf8
            .encode('Content-Type: application/json; charset=UTF-8\r\n\r\n'));
        body.addAll(utf8.encode('$metadataJson\r\n'));
        body.addAll(utf8.encode('--$boundary\r\n'));
        body.addAll(
            utf8.encode('Content-Type: application/octet-stream\r\n\r\n'));
        body.addAll(bytes);
        body.addAll(utf8.encode('\r\n--$boundary--\r\n'));

        final response = await http.post(
          createUrl,
          headers: {
            ...headers,
            'Content-Type': 'multipart/related; boundary=$boundary',
          },
          body: body,
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          LogService.info(
              'GoogleDriveService: Successfully created new cloud backup (${bytes.length} bytes)');
          return true;
        } else {
          final errBody = response.body;
          LogService.error(
              'GoogleDriveService: POST upload failed [HTTP ${response.statusCode}]: $errBody');
          throw Exception(
              'Google Drive API HTTP ${response.statusCode}: $errBody');
        }
      }
    } catch (e, st) {
      LogService.error('GoogleDriveService: uploadBackup error', e, st);
      rethrow;
    }
  }

  /// Download backup file from Google Drive appDataFolder and restore local database
  Future<bool> restoreBackup() async {
    try {
      final existingBackup = await getBackupMetadata();
      if (existingBackup == null) {
        throw Exception('No existing cloud backup found on Google Drive.');
      }

      final headers = await _authHeaders();
      final downloadUrl = Uri.parse(
          'https://www.googleapis.com/drive/v3/files/${existingBackup.fileId}?alt=media');

      final response = await http.get(downloadUrl, headers: headers);
      if (response.statusCode != 200) {
        throw Exception(
            'Failed to download backup file (HTTP ${response.statusCode})');
      }

      final backupBytes = response.bodyBytes;
      if (backupBytes.isEmpty) {
        throw Exception('Downloaded backup file is empty');
      }

      final dbPath = await DatabaseService.instance.getDatabaseFilePath();

      // Close active database connection before replacing the file
      await DatabaseService.instance.close();

      // Write downloaded bytes to database path
      final dbFile = File(dbPath);
      await dbFile.writeAsBytes(backupBytes, flush: true);

      // Reload database connection
      await DatabaseService.instance.reloadDatabase();
      LogService.info(
          'GoogleDriveService: Successfully restored cloud backup (${backupBytes.length} bytes)');
      return true;
    } catch (e) {
      LogService.error('GoogleDriveService: restoreBackup error', e);
      rethrow;
    }
  }
}
