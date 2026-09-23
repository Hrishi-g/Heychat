import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

/// AvatarCacheService stores and retrieves compressed avatar images locally
/// so profile pictures never reload repeatedly across app sessions.
class AvatarCacheService {
  AvatarCacheService._();
  static final AvatarCacheService instance = AvatarCacheService._();

  Directory? _cacheDir;
  final Map<String, File> _fileCache = {};

  Future<Directory> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final dbPath = await getDatabasesPath();
    final parent = p.dirname(dbPath);
    final cacheFolder = Directory(p.join(parent, 'avatar_cache'));
    if (!await cacheFolder.exists()) {
      await cacheFolder.create(recursive: true);
    }
    _cacheDir = cacheFolder;
    return cacheFolder;
  }

  String _fileNameForUrl(String url) {
    // Generate clean alphanumeric filename based on URL hash
    final hash = url.hashCode.abs().toRadixString(16);
    final ext = url.toLowerCase().contains('.png') ? 'png' : 'jpg';
    return 'avatar_$hash.$ext';
  }

  /// Returns cached local file if it exists, otherwise null
  Future<File?> getCachedFile(String? url) async {
    if (url == null || url.trim().isEmpty) return null;
    final cleanUrl = url.trim();

    if (_fileCache.containsKey(cleanUrl)) {
      final file = _fileCache[cleanUrl]!;
      if (await file.exists() && await file.length() > 0) {
        return file;
      }
    }

    try {
      final dir = await _getCacheDir();
      final file = File(p.join(dir.path, _fileNameForUrl(cleanUrl)));
      if (await file.exists() && await file.length() > 0) {
        _fileCache[cleanUrl] = file;
        return file;
      }
    } catch (_) {}
    return null;
  }

  /// Downloads image if not already cached, saves to local disk, and returns the File
  Future<File?> cacheUrl(String? url) async {
    if (url == null || url.trim().isEmpty) return null;
    final cleanUrl = url.trim();

    final existing = await getCachedFile(cleanUrl);
    if (existing != null) return existing;

    try {
      final resp = await http.get(Uri.parse(cleanUrl));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        final dir = await _getCacheDir();
        final file = File(p.join(dir.path, _fileNameForUrl(cleanUrl)));
        await file.writeAsBytes(resp.bodyBytes);
        _fileCache[cleanUrl] = file;
        return file;
      }
    } catch (_) {}
    return null;
  }

  /// Directly saves raw bytes to disk for a given URL (e.g. after upload)
  Future<void> saveBytesToCache(String url, List<int> bytes) async {
    if (url.trim().isEmpty || bytes.isEmpty) return;
    try {
      final dir = await _getCacheDir();
      final file = File(p.join(dir.path, _fileNameForUrl(url.trim())));
      await file.writeAsBytes(bytes);
      _fileCache[url.trim()] = file;
    } catch (_) {}
  }
}
