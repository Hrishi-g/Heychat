import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/message_model.dart';
import '../models/chat_home_model.dart';
import '../models/user_model.dart';
import 'log_service.dart';
import 'secure_storage_service.dart';

/// DatabaseService manages encrypted local SQLite storage on Android & iOS using SQLCipher.
/// Provides 256-bit AES page-level encryption at rest with keys protected by Keystore/Keychain.
class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      try {
        await _database!.rawQuery('SELECT 1');
        return _database!;
      } catch (_) {
        try {
          await _database!.close();
        } catch (_) {}
        _database = null;
      }
    }
    _database = await _initDB('heychat_encrypted.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final encryptedPath = join(dbPath, filePath);
    final legacyWhatsappEncryptedPath = join(dbPath, 'whatsapp_encrypted.db');
    final legacyPath = join(dbPath, 'whatsapp_local.db');

    // Retrieve or generate 256-bit AES encryption master key from Keystore/Keychain
    final dbPassword =
        await SecureStorageService.instance.getOrCreateDatabaseKey();

    // Migrate from legacy whatsapp_encrypted.db if present
    if (await File(legacyWhatsappEncryptedPath).exists() &&
        !await File(encryptedPath).exists()) {
      try {
        await File(legacyWhatsappEncryptedPath).rename(encryptedPath);
        LogService.info(
            'DatabaseService: Successfully renamed legacy whatsapp_encrypted.db to heychat_encrypted.db');
      } catch (e) {
        LogService.error(
            'DatabaseService: Failed to rename legacy whatsapp_encrypted.db',
            e);
      }
    }

    // Check if legacy unencrypted database exists and migrate records
    if (await File(legacyPath).exists() &&
        !await File(encryptedPath).exists()) {
      try {
        final legacyDb = await openDatabase(legacyPath);
        final encryptedDb = await openDatabase(
          encryptedPath,
          password: dbPassword,
          version: 5,
          onCreate: _createDB,
        );

        final legacyMessages = await legacyDb.query('messages');
        for (final msg in legacyMessages) {
          await encryptedDb.insert('messages', msg,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }

        final legacyChats = await legacyDb.query('chats');
        for (final chat in legacyChats) {
          await encryptedDb.insert('chats', chat,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }

        await legacyDb.close();
        await File(legacyPath).delete();
        LogService.info(
            'DatabaseService: Successfully migrated legacy unencrypted database to encrypted SQLCipher');
        return encryptedDb;
      } catch (e) {
        LogService.error(
            'DatabaseService: Failed to migrate legacy database, opening fresh encrypted DB',
            e);
      }
    }

    try {
      final db = await openDatabase(
        encryptedPath,
        password: dbPassword,
        version: 5,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );

      // Validate SQLCipher decryption key by running a test query on sqlite_master
      await db.rawQuery('SELECT count(*) FROM sqlite_master;');
      return db;
    } catch (e) {
      LogService.error(
          'DatabaseService: Failed to validate encrypted DB (key mismatch or corruption), re-creating clean DB',
          e);
      final dbFile = File(encryptedPath);
      if (await dbFile.exists()) {
        try {
          await dbFile.delete();
        } catch (_) {}
      }
      final freshDb = await openDatabase(
        encryptedPath,
        password: dbPassword,
        version: 5,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );
      await freshDb.rawQuery('SELECT count(*) FROM sqlite_master;');
      return freshDb;
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // Table for storing conversation messages
    await db.execute('''
      CREATE TABLE messages (
        msgId TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        sender TEXT NOT NULL,
        receiver TEXT NOT NULL,
        message TEXT NOT NULL,
        status TEXT NOT NULL,
        timeStamp INTEGER NOT NULL,
        isEdited INTEGER NOT NULL DEFAULT 0,
        isDeletedForEveryone INTEGER NOT NULL DEFAULT 0,
        isForwarded INTEGER NOT NULL DEFAULT 0,
        replyToMsgId TEXT,
        replyToSender TEXT,
        replyToText TEXT,
        localImageUrl TEXT,
        cloudImageUrl TEXT
      )
    ''');

    // Table for storing home chat preview items
    await db.execute('''
      CREATE TABLE chats (
        chatUser TEXT PRIMARY KEY,
        chatUserName TEXT,
        lastMsg TEXT NOT NULL,
        status TEXT NOT NULL,
        lastMessageTime TEXT,
        imgUrl TEXT
      )
    ''');

    // Table for caching user profile locally
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profile (
        mblNo TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT,
        gender TEXT,
        dob TEXT,
        imgUrl TEXT
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE messages ADD COLUMN replyToMsgId TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE messages ADD COLUMN replyToSender TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE messages ADD COLUMN replyToText TEXT');
      } catch (_) {}
    }
    if (oldVersion < 3) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS user_profile (
            mblNo TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT,
            gender TEXT,
            dob TEXT,
            imgUrl TEXT
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE messages ADD COLUMN localImageUrl TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE messages ADD COLUMN cloudImageUrl TEXT');
      } catch (_) {}
    }
    if (oldVersion < 5) {
      try {
        await db.execute(
            'ALTER TABLE messages ADD COLUMN isForwarded INTEGER NOT NULL DEFAULT 0');
      } catch (_) {}
    }
  }

  // Insert or update a message in local SQLite
  Future<void> saveMessage(MessageModel message) async {
    try {
      final db = await instance.database;
      await db.insert(
        'messages',
        message.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      LogService.error('DatabaseService: saveMessage error', e);
    }
  }

  // Delete a message locally from SQLite
  Future<void> deleteMessage(String msgId) async {
    try {
      final db = await instance.database;
      await db.delete(
        'messages',
        where: 'msgId = ?',
        whereArgs: [msgId],
      );
    } catch (e) {
      LogService.error('DatabaseService: deleteMessage error', e);
    }
  }

  // Get conversation history with a specific user
  Future<List<MessageModel>> getMessagesBetween(
      String currentUser, String otherUser) async {
    try {
      final db = await instance.database;
      final maps = await db.query(
        'messages',
        where: '(sender = ? AND receiver = ?) OR (sender = ? AND receiver = ?)',
        whereArgs: [currentUser, otherUser, otherUser, currentUser],
        orderBy: 'timeStamp ASC',
      );

      return maps.map((map) => MessageModel.fromDbMap(map)).toList();
    } catch (e) {
      LogService.error('DatabaseService: getMessagesBetween error', e);
      return [];
    }
  }

  // Insert or update home chat preview item
  Future<void> saveChatHome(ChatHomeModel chat) async {
    try {
      final db = await instance.database;
      await db.insert(
        'chats',
        chat.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      LogService.error('DatabaseService: saveChatHome error', e);
    }
  }

  // Get all cached home chat previews
  Future<List<ChatHomeModel>> getAllHomeChats() async {
    try {
      final db = await instance.database;
      final maps = await db.query(
        'chats',
        orderBy: 'lastMessageTime DESC',
      );
      return maps.map((map) => ChatHomeModel.fromDbMap(map)).toList();
    } catch (e) {
      LogService.error('DatabaseService: getAllHomeChats error', e);
      return [];
    }
  }

  // Get all pending offline messages for a specific recipient, sorted chronologically
  Future<List<MessageModel>> getPendingMessagesFor(String receiver) async {
    try {
      final db = await instance.database;
      final maps = await db.query(
        'messages',
        where: 'receiver = ? AND status = ?',
        whereArgs: [receiver, 'PENDING'],
        orderBy: 'timeStamp ASC',
      );
      return maps.map((map) => MessageModel.fromDbMap(map)).toList();
    } catch (e) {
      LogService.error('DatabaseService: getPendingMessagesFor error', e);
      return [];
    }
  }

  // Get all pending offline messages across all recipients, sorted chronologically
  Future<List<MessageModel>> getAllPendingMessages() async {
    try {
      final db = await instance.database;
      final maps = await db.query(
        'messages',
        where: 'status = ?',
        whereArgs: ['PENDING'],
        orderBy: 'timeStamp ASC',
      );
      return maps.map((map) => MessageModel.fromDbMap(map)).toList();
    } catch (e) {
      LogService.error('DatabaseService: getAllPendingMessages error', e);
      return [];
    }
  }

  // Delete a home chat entry from SQLite
  Future<void> deleteHomeChat(String chatUser) async {
    try {
      final db = await instance.database;
      await db.delete(
        'chats',
        where: 'chatUser = ?',
        whereArgs: [chatUser],
      );
    } catch (e) {
      LogService.error('DatabaseService: deleteHomeChat error', e);
    }
  }

  // Delete all conversation messages with a specific user from SQLite
  Future<void> deleteMessagesBetween(
      String currentUser, String otherUser) async {
    try {
      final db = await instance.database;
      await db.delete(
        'messages',
        where: '(sender = ? AND receiver = ?) OR (sender = ? AND receiver = ?)',
        whereArgs: [currentUser, otherUser, otherUser, currentUser],
      );
    } catch (e) {
      LogService.error('DatabaseService: deleteMessagesBetween error', e);
    }
  }

  // Bulk update message status between sender and receiver (e.g. DELIVERED or READ)
  Future<void> updateMessageStatus({
    required String sender,
    required String receiver,
    required String newStatus,
  }) async {
    final db = await instance.database;
    if (newStatus == 'DELIVERED') {
      await db.update(
        'messages',
        {'status': newStatus},
        where: 'sender = ? AND receiver = ? AND status = ?',
        whereArgs: [sender, receiver, 'SENT'],
      );
    } else {
      await db.update(
        'messages',
        {'status': newStatus},
        where: 'sender = ? AND receiver = ?',
        whereArgs: [sender, receiver],
      );
    }
  }

  // Update home chat preview status
  Future<void> updateHomeChatStatus({
    required String chatUser,
    required String newStatus,
  }) async {
    final db = await instance.database;
    if (newStatus == 'DELIVERED') {
      await db.update(
        'chats',
        {'status': newStatus},
        where: 'chatUser = ? AND status = ?',
        whereArgs: [chatUser, 'SENT'],
      );
    } else {
      await db.update(
        'chats',
        {'status': newStatus},
        where: 'chatUser = ?',
        whereArgs: [chatUser],
      );
    }
  }

  // Insert or replace cached user profile in local SQLite
  Future<void> saveUserProfile(UserModel user) async {
    try {
      final db = await instance.database;
      await db.insert(
        'user_profile',
        user.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      LogService.info(
          'DatabaseService: Saved user profile for ${user.mblNo} to local SQLite');
    } catch (e) {
      LogService.error('DatabaseService: saveUserProfile error', e);
    }
  }

  // Get cached user profile from local SQLite
  Future<UserModel?> getUserProfile(String mblNo) async {
    try {
      final db = await instance.database;
      final maps = await db.query(
        'user_profile',
        where: 'mblNo = ?',
        whereArgs: [mblNo],
      );
      if (maps.isNotEmpty) {
        return UserModel.fromJson(maps.first);
      }
    } catch (e) {
      LogService.error('DatabaseService: getUserProfile error', e);
    }
    return null;
  }

  // Update localImageUrl path for a message in local SQLite
  Future<void> updateMessageLocalPath(String msgId, String localPath) async {
    try {
      final db = await instance.database;
      await db.update(
        'messages',
        {'localImageUrl': localPath},
        where: 'msgId = ?',
        whereArgs: [msgId],
      );
      LogService.info(
          'DatabaseService: Updated localImageUrl for $msgId to $localPath');
    } catch (e) {
      LogService.error('DatabaseService: updateMessageLocalPath error', e);
    }
  }

  // Clear cached messages, chats, and profile on user logout
  Future<void> clearDatabase() async {
    try {
      final db = await instance.database;
      await db.delete('messages');
      await db.delete('chats');
      await db.delete('user_profile');
      LogService.info(
          'DatabaseService: Cleared messages, chats, and user_profile on logout');
    } catch (e) {
      LogService.error(
          'DatabaseService: Failed to clear database tables on logout', e);
    }
  }

  // Close database instance
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // Return the absolute filesystem path to local SQLite database file
  Future<String> getDatabaseFilePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'heychat_encrypted.db');
  }

  // Force close and reload database instance (used after cloud restore)
  Future<Database> reloadDatabase() async {
    await close();
    return await database;
  }
}
