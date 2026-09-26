import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'log_service.dart';

/// MediaStorageService manages local storage of chat images on device file system.
/// Saves images into public Pictures/HeyChat directory (or internal media storage)
/// so images are visible in device Gallery/Photos app.
class MediaStorageService {
  MediaStorageService._();
  static final MediaStorageService instance = MediaStorageService._();

  Directory? _mediaDir;

  Future<Directory> getMediaDir() async {
    if (_mediaDir != null && await _mediaDir!.exists()) return _mediaDir!;

    try {
      if (Platform.isAndroid) {
        // Public Pictures/HeyChat folder so images appear in Android Gallery/Photos
        final publicPictures =
            Directory('/storage/emulated/0/Pictures/HeyChat');
        if (!await publicPictures.exists()) {
          await publicPictures.create(recursive: true);
        }
        _mediaDir = publicPictures;
        return publicPictures;
      }
    } catch (_) {}

    // Fallback: Internal app storage directory
    final dbPath = await getDatabasesPath();
    final parent = p.dirname(dbPath);
    final mediaFolder = Directory(p.join(parent, 'heychat_media'));
    if (!await mediaFolder.exists()) {
      await mediaFolder.create(recursive: true);
    }
    _mediaDir = mediaFolder;
    return mediaFolder;
  }

  /// Save raw image bytes to local HeyChat folder and return local file path
  Future<String?> saveImageBytes(List<int> bytes, String ext) async {
    try {
      final dir = await getMediaDir();
      final cleanExt = ext.replaceAll('.', '').toLowerCase();
      final fileName =
          'IMG_${DateTime.now().millisecondsSinceEpoch}_${bytes.length}.$cleanExt';
      final file = File(p.join(dir.path, fileName));
      await file.writeAsBytes(bytes, flush: true);
      LogService.info('MediaStorageService: Saved image to ${file.path}');
      return file.path;
    } catch (e) {
      LogService.error('MediaStorageService: saveImageBytes error', e);
      return null;
    }
  }

  /// Checks if a local file path exists on device storage and is non-empty
  bool isFileAvailable(String? path) {
    if (path == null || path.trim().isEmpty) return false;
    try {
      final file = File(path.trim());
      return file.existsSync() && file.lengthSync() > 0;
    } catch (_) {
      return false;
    }
  }
}
