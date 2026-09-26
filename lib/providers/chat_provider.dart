import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:my_first_app/services/log_service.dart';
import '../models/chat_home_model.dart';
import '../models/message_model.dart';
import '../services/auth_service.dart';
import '../services/avatar_cache_service.dart';
import '../services/db_service.dart';
import '../services/media_storage_service.dart';
import '../services/websocket_service.dart';

class ChatProvider extends ChangeNotifier {
  final WebSocketService _wsService = WebSocketService();
  final DatabaseService _dbService = DatabaseService.instance;

  List<ChatHomeModel> _homeChats = [];
  final Map<String, List<MessageModel>> _conversationMap = {};
  Set<String> _onlineUsers = {};
  StreamSubscription? _wsSubscription;
  String? _activeChatUser;

  final Map<String, int> _unreadCounts = {};
  int _lastGeneratedTimestamp = 0;

  int _nextUniqueTimestamp() {
    int now = DateTime.now().millisecondsSinceEpoch;
    if (now <= _lastGeneratedTimestamp) {
      now = _lastGeneratedTimestamp + 1;
    }
    _lastGeneratedTimestamp = now;
    return now;
  }

  List<ChatHomeModel> get homeChats => _homeChats;
  Set<String> get onlineUsers => _onlineUsers;
  String? get activeChatUser => _activeChatUser;

  void setActiveChatUser(String? user) {
    _activeChatUser = user;
  }

  static bool isSameUser(String a, String b) {
    final cleanA = a.replaceAll(RegExp(r'[^0-9]'), '');
    final cleanB = b.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanA.isEmpty || cleanB.isEmpty) return a.trim() == b.trim();
    if (cleanA == cleanB) return true;
    if (cleanA.length >= 10 && cleanB.length >= 10) {
      return cleanA.substring(cleanA.length - 10) ==
          cleanB.substring(cleanB.length - 10);
    }
    return false;
  }

  bool isUserOnline(String user, {String? currentUser}) {
    if (currentUser != null && isSameUser(user, currentUser)) {
      return true; // Self is always online when active
    }
    final clean = user.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return false;

    return _onlineUsers.any((u) => isSameUser(u, user));
  }

  int getUnreadCount(String chatUser) {
    for (final entry in _unreadCounts.entries) {
      if (isSameUser(entry.key, chatUser)) {
        return entry.value;
      }
    }
    return 0;
  }

  void clearUnreadCount(String chatUser) {
    for (final key in _unreadCounts.keys.toList()) {
      if (isSameUser(key, chatUser)) {
        _unreadCounts[key] = 0;
      }
    }
    _unreadCounts[chatUser] = 0;
    notifyListeners();
  }

  void setUnreadCount(String chatUser, int count) {
    String targetKey = chatUser;
    for (final key in _unreadCounts.keys) {
      if (isSameUser(key, chatUser)) {
        targetKey = key;
        break;
      }
    }
    _unreadCounts[targetKey] = count;
    notifyListeners();
  }

  List<MessageModel>? _getConversationList(String user) {
    for (final entry in _conversationMap.entries) {
      if (isSameUser(entry.key, user)) {
        return entry.value;
      }
    }
    return null;
  }

  List<MessageModel> getMessagesFor(String otherUser,
      {String? currentUser, String? contactName}) {
    final existing = _getConversationList(otherUser);
    if (existing != null) return existing;
    final list = <MessageModel>[];
    _conversationMap[otherUser] = list;
    return list;
  }

  List<MessageModel> getMessages(String otherUser) => getMessagesFor(otherUser);

  String? _initializedMblNo;

  Future<void> init(String currentUserMblNo) async {
    if (_initializedMblNo == currentUserMblNo && _wsService.isConnected) {
      return;
    }
    _initializedMblNo = currentUserMblNo;

    // 1. Load cached home chats from local SQLite database
    try {
      _homeChats = await _dbService.getAllHomeChats();
    } catch (e) {
      _homeChats = [];
    }
    _onlineUsers.clear();
    notifyListeners();

    // Sync profiles/avatars from backend for all contacts in background
    syncAllChatProfiles();

    // 2. ALWAYS subscribe to real-time WebSocket message stream
    _wsSubscription?.cancel();
    _wsSubscription = _wsService.messageStream.listen((data) {
      _handleIncomingWsMessage(data, currentUserMblNo);
    });

    // 3. Initiate WebSocket connection
    try {
      await _wsService.connect();
    } catch (_) {}
  }

  void _handleIncomingWsMessage(
      Map<String, dynamic> data, String currentUserMblNo) async {
    final type = data['type'];

    if (type == 'ONLINE_USERS_LIST') {
      final List<dynamic> users = data['users'] ?? [];
      _onlineUsers = users.map((u) => u.toString()).toSet();
      notifyListeners();
      _processAllPendingMessages(currentUserMblNo);
    } else if (type == 'USER_STATUS') {
      final user = data['user']?.toString();
      final status = data['status']?.toString();
      if (user != null) {
        if (status == 'ONLINE') {
          _onlineUsers.add(user);
          _processPendingMessagesForUser(user, currentUserMblNo);
        } else {
          _onlineUsers.removeWhere((u) => isSameUser(u, user));
        }
        notifyListeners();
      }
    } else if (type == 'CHAT') {
      final msg = MessageModel.fromJson(data);

      // Determine other participant
      final otherUser =
          isSameUser(msg.sender, currentUserMblNo) ? msg.receiver : msg.sender;

      // Save to local SQLite database
      await _dbService.saveMessage(msg);

      // Update in-memory conversation state
      List<MessageModel>? list = _getConversationList(otherUser);
      if (list == null) {
        list = [];
        _conversationMap[otherUser] = list;
      }

      int existingIdx = -1;
      if (msg.msgId != null && msg.msgId!.isNotEmpty) {
        existingIdx = list.indexWhere((m) => m.msgId == msg.msgId);
      }
      if (existingIdx == -1) {
        existingIdx = list.indexWhere((m) =>
            isSameUser(m.sender, msg.sender) && m.timeStamp == msg.timeStamp);
      }

      if (existingIdx != -1) {
        list[existingIdx] = msg;
      } else {
        list.add(msg);
      }

      // If active screen is currently this chat and message came from contact, mark as read
      if (!isSameUser(msg.sender, currentUserMblNo)) {
        if (_activeChatUser != null &&
            isSameUser(_activeChatUser!, otherUser)) {
          markConversationAsRead(
            currentUserMblNo: currentUserMblNo,
            contactMblNo: otherUser,
          );
        } else {
          setUnreadCount(otherUser, getUnreadCount(otherUser) + 1);
        }
      }

      // Update local SQLite home chat preview
      final existingChatIndex =
          _homeChats.indexWhere((c) => isSameUser(c.chatUser, otherUser));
      final existingChat =
          existingChatIndex != -1 ? _homeChats[existingChatIndex] : null;

      final isImage = msg.type == 'IMAGE' ||
          msg.message.startsWith('local_img_') ||
          (msg.message.startsWith('http') &&
              (msg.message.contains('/uploads/') ||
                  msg.message.contains('.r2.dev') ||
                  msg.message.endsWith('.jpg') ||
                  msg.message.endsWith('.jpeg') ||
                  msg.message.endsWith('.png') ||
                  msg.message.endsWith('.webp') ||
                  msg.message.endsWith('.gif')));

      final homeChat = ChatHomeModel(
        chatUser: otherUser,
        chatUserName: existingChat?.chatUserName,
        lastMsg: isImage ? '📷 Photo' : msg.message,
        status: msg.status,
        lastMessageTime: DateTime.fromMillisecondsSinceEpoch(msg.timeStamp)
            .toIso8601String(),
        imgUrl: existingChat?.imgUrl,
      );
      await _dbService.saveChatHome(homeChat);
      _homeChats = await _dbService.getAllHomeChats();

      notifyListeners();

      // If contact avatar or name is missing, fetch fresh profile from backend
      if (existingChat == null ||
          existingChat.imgUrl == null ||
          existingChat.chatUserName == null) {
        _fetchAndUpdateUserProfile(otherUser);
      }
    } else if (type == 'STATUS_UPDATE') {
      final sender = data['sender']?.toString();
      final receiver = data['receiver']?.toString();
      final newStatus = data['status']?.toString();

      if (newStatus != null) {
        final otherUser =
            isSameUser(sender ?? '', currentUserMblNo) ? receiver : sender;

        if (otherUser != null) {
          final msgSender = sender ?? currentUserMblNo;
          final msgReceiver = receiver ?? otherUser;

          // 1. Update SQLite DB
          await _dbService.updateMessageStatus(
            sender: msgSender,
            receiver: msgReceiver,
            newStatus: newStatus,
          );

          // 2. Update in-memory messages
          for (final entry in _conversationMap.entries) {
            if (isSameUser(entry.key, otherUser)) {
              final list = entry.value;
              for (int i = 0; i < list.length; i++) {
                if (isSameUser(list[i].sender, msgSender)) {
                  if (newStatus == 'READ' && list[i].status != 'READ') {
                    list[i] = list[i].copyWith(status: 'READ');
                  } else if (newStatus == 'DELIVERED' &&
                      list[i].status == 'SENT') {
                    list[i] = list[i].copyWith(status: 'DELIVERED');
                  }
                }
              }
            }
          }

          // 3. Update home chat preview status
          final chatIndex =
              _homeChats.indexWhere((c) => isSameUser(c.chatUser, otherUser));
          if (chatIndex != -1) {
            final currentChat = _homeChats[chatIndex];
            if (newStatus == 'READ' ||
                (newStatus == 'DELIVERED' && currentChat.status == 'SENT')) {
              _homeChats[chatIndex] = currentChat.copyWith(status: newStatus);
              await _dbService.updateHomeChatStatus(
                chatUser: currentChat.chatUser,
                newStatus: newStatus,
              );
            }
          }

          notifyListeners();
        }
      }
    } else if (type == 'EDIT') {
      final msgId = data['msgId']?.toString();
      final sender = data['sender']?.toString() ?? '';
      final receiver = data['receiver']?.toString() ?? '';
      final newMessage =
          data['message']?.toString() ?? data['msg']?.toString() ?? '';
      final otherUser = sender == currentUserMblNo ? receiver : sender;

      final list = _getConversationList(otherUser);
      if (list != null) {
        int idx = -1;
        if (msgId != null && msgId.isNotEmpty) {
          idx = list.indexWhere((m) => m.msgId == msgId);
        }
        if (idx == -1 && sender.isNotEmpty) {
          idx = list.lastIndexWhere((m) => isSameUser(m.sender, sender));
        }
        if (idx != -1) {
          final updated = list[idx].copyWith(
            message: newMessage,
            isEdited: true,
          );
          list[idx] = updated;
          await _dbService.saveMessage(updated);

          if (idx == list.length - 1) {
            final existingChat = _homeChats.firstWhere(
              (c) => isSameUser(c.chatUser, otherUser),
              orElse: () =>
                  ChatHomeModel(chatUser: otherUser, lastMsg: '', status: ''),
            );
            final homeChat = ChatHomeModel(
              chatUser: otherUser,
              chatUserName: existingChat.chatUserName,
              lastMsg: newMessage,
              status: existingChat.status,
              lastMessageTime: existingChat.lastMessageTime,
              imgUrl: existingChat.imgUrl,
            );
            await _dbService.saveChatHome(homeChat);
            _homeChats = await _dbService.getAllHomeChats();
          }
          notifyListeners();
        }
      }
    } else if (type == 'DELETE_EVERYONE') {
      final msgId = data['msgId']?.toString();
      final sender = data['sender']?.toString() ?? '';
      final receiver = data['receiver']?.toString() ?? '';
      final otherUser = sender == currentUserMblNo ? receiver : sender;

      final list = _getConversationList(otherUser);
      if (list != null) {
        int idx = -1;
        if (msgId != null && msgId.isNotEmpty) {
          idx = list.indexWhere((m) => m.msgId == msgId);
        }
        if (idx == -1 && sender.isNotEmpty) {
          idx = list.lastIndexWhere((m) => isSameUser(m.sender, sender));
        }
        if (idx != -1) {
          final updated = list[idx].copyWith(
            message: 'This message was deleted',
            isDeletedForEveryone: true,
          );
          list[idx] = updated;
          await _dbService.saveMessage(updated);

          if (idx == list.length - 1) {
            final existingChat = _homeChats.firstWhere(
              (c) => isSameUser(c.chatUser, otherUser),
              orElse: () =>
                  ChatHomeModel(chatUser: otherUser, lastMsg: '', status: ''),
            );
            final homeChat = ChatHomeModel(
              chatUser: otherUser,
              chatUserName: existingChat.chatUserName,
              lastMsg: 'This message was deleted',
              status: existingChat.status,
              lastMessageTime: existingChat.lastMessageTime,
              imgUrl: existingChat.imgUrl,
            );
            await _dbService.saveChatHome(homeChat);
            _homeChats = await _dbService.getAllHomeChats();
          }
          notifyListeners();
        }
      }
    }
  }

  Future<void> loadConversation(String currentUser, String otherUser,
      {String? contactName}) async {
    final cached = await _dbService.getMessagesBetween(currentUser, otherUser);
    for (final key in _conversationMap.keys.toList()) {
      if (isSameUser(key, otherUser)) {
        _conversationMap.remove(key);
      }
    }
    _conversationMap[otherUser] = cached;
    notifyListeners();
  }

  Future<void> addNewChatUser(String mblNo, String? name,
      {String? imgUrl}) async {
    final existingIndex =
        _homeChats.indexWhere((c) => isSameUser(c.chatUser, mblNo));
    if (existingIndex == -1) {
      final newChat = ChatHomeModel(
        chatUser: mblNo,
        chatUserName: name,
        lastMsg: 'Tap to start chatting',
        status: 'SENT',
        lastMessageTime: DateTime.now().toIso8601String(),
        imgUrl: imgUrl,
      );
      await _dbService.saveChatHome(newChat);
      _homeChats = await _dbService.getAllHomeChats();
      notifyListeners();
    } else {
      final existing = _homeChats[existingIndex];
      bool changed = false;
      String? newName = existing.chatUserName;
      String? newImg = existing.imgUrl;

      if (name != null &&
          name.trim().isNotEmpty &&
          name.trim() != existing.chatUserName) {
        newName = name.trim();
        changed = true;
      }
      if (imgUrl != null &&
          imgUrl.trim().isNotEmpty &&
          imgUrl.trim() != existing.imgUrl) {
        newImg = imgUrl.trim();
        changed = true;
      }

      if (changed) {
        final updatedChat = existing.copyWith(
          chatUserName: newName,
          imgUrl: newImg,
        );
        await _dbService.saveChatHome(updatedChat);
        _homeChats = await _dbService.getAllHomeChats();
        notifyListeners();
      }
    }
  }

  Future<void> updateChatUserInfo(String mblNo,
      {String? name, String? imgUrl}) async {
    final existingIndex =
        _homeChats.indexWhere((c) => isSameUser(c.chatUser, mblNo));
    if (existingIndex != -1) {
      final existing = _homeChats[existingIndex];
      bool changed = false;
      String? newName = existing.chatUserName;
      String? newImg = existing.imgUrl;

      if (name != null &&
          name.trim().isNotEmpty &&
          name.trim() != existing.chatUserName) {
        newName = name.trim();
        changed = true;
      }
      if (imgUrl != null &&
          imgUrl.trim().isNotEmpty &&
          imgUrl.trim() != existing.imgUrl) {
        newImg = imgUrl.trim();
        changed = true;
      }

      if (changed) {
        final updated = existing.copyWith(
          chatUserName: newName,
          imgUrl: newImg,
        );
        _homeChats[existingIndex] = updated;
        await _dbService.saveChatHome(updated);
        notifyListeners();
      }
    }
  }

  Future<void> deleteChatUser({
    required String chatUser,
    required String currentUser,
    required bool deleteMessagesHistory,
  }) async {
    // 1. Delete home chat preview item from local SQLite database
    await _dbService.deleteHomeChat(chatUser);

    // 2. Conditionally delete conversation message history from local SQLite database
    if (deleteMessagesHistory) {
      await _dbService.deleteMessagesBetween(currentUser, chatUser);

      // Remove from in-memory conversation map
      for (final key in _conversationMap.keys.toList()) {
        if (isSameUser(key, chatUser)) {
          _conversationMap.remove(key);
        }
      }
    }

    // 3. Remove chat preview from in-memory list
    _homeChats.removeWhere((c) => isSameUser(c.chatUser, chatUser));

    // Clear unread count for this user
    _unreadCounts.removeWhere((key, _) => isSameUser(key, chatUser));

    notifyListeners();
  }

  Future<void> syncAllChatProfiles() async {
    for (final chat in List<ChatHomeModel>.from(_homeChats)) {
      try {
        final user = await AuthService().getNewUser(chat.chatUser);
        if (user != null) {
          final name = user['name']?.toString();
          final imgUrl = user['imgUrl']?.toString();
          await updateChatUserInfo(chat.chatUser, name: name, imgUrl: imgUrl);
        }
      } catch (_) {}
    }
  }

  Future<void> _fetchAndUpdateUserProfile(String mblNo) async {
    try {
      final user = await AuthService().getNewUser(mblNo);
      if (user != null) {
        final name = user['name']?.toString();
        final imgUrl = user['imgUrl']?.toString();
        await updateChatUserInfo(mblNo, name: name, imgUrl: imgUrl);
      }
    } catch (_) {}
  }

  Future<void> _processPendingMessagesForUser(
      String targetUser, String currentUserMblNo) async {
    final pendingList = await _dbService.getPendingMessagesFor(targetUser);
    if (pendingList.isEmpty) return;

    LogService.ws(
        'Processing ${pendingList.length} pending offline messages for online user: $targetUser');

    for (final pendingMsg in pendingList) {
      // Re-verify recipient is still online and WebSocket connected before transmitting next message
      if (!isUserOnline(targetUser, currentUser: currentUserMblNo) ||
          !_wsService.isConnected) {
        LogService.ws(
            'Recipient $targetUser went offline mid-transmission. Pausing outbox queue.');
        break;
      }

      final updatedMsg = pendingMsg.copyWith(status: 'SENT');

      // 1. Push message over WebSocket
      final sent = await _wsService.sendMessage(updatedMsg);
      if (!sent) {
        LogService.ws(
            'WebSocket send failed mid-transmission for $targetUser. Pausing queue.');
        break;
      }

      // 2. Update in-memory conversation list only after successful send
      final list = _getConversationList(targetUser);
      if (list != null) {
        final idx = list.indexWhere((m) =>
            m.msgId == pendingMsg.msgId ||
            (isSameUser(m.sender, pendingMsg.sender) &&
                m.timeStamp == pendingMsg.timeStamp));
        if (idx != -1) {
          list[idx] = updatedMsg;
        }
      }

      // 3. Save updated SENT status to SQLite
      await _dbService.saveMessage(updatedMsg);

      // Brief sequence delay to preserve exact line-by-line order
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // 4. Update home chat preview status
    final chatIndex =
        _homeChats.indexWhere((c) => isSameUser(c.chatUser, targetUser));
    if (chatIndex != -1) {
      final updatedChat = _homeChats[chatIndex].copyWith(status: 'SENT');
      _homeChats[chatIndex] = updatedChat;
      await _dbService.saveChatHome(updatedChat);
    }
    _homeChats = await _dbService.getAllHomeChats();
    notifyListeners();
  }

  Future<void> _processAllPendingMessages(String currentUserMblNo) async {
    final pendingList = await _dbService.getAllPendingMessages();
    if (pendingList.isEmpty) return;

    final processedUsers = <String>{};
    for (final pendingMsg in pendingList) {
      final target = pendingMsg.receiver;
      if (!processedUsers.contains(target) &&
          isUserOnline(target, currentUser: currentUserMblNo)) {
        processedUsers.add(target);
        await _processPendingMessagesForUser(target, currentUserMblNo);
      }
    }
  }

  Future<void> sendChatMessage({
    required String sender,
    required String receiver,
    required String text,
    String? replyToMsgId,
    String? replyToSender,
    String? replyToText,
  }) async {
    final timeStamp = _nextUniqueTimestamp();
    final clientMsgId = '${sender}_${receiver}_$timeStamp';
    final isSelf = isSameUser(sender, receiver);
    final isOnline = isSelf || isUserOnline(receiver);

    // Initial status:
    // If messaging self -> READ
    // If recipient online & WS connected -> SENT
    // If recipient offline -> PENDING (queued locally in SQLite until recipient comes online)
    final initialStatus = isSelf ? 'READ' : (isOnline ? 'SENT' : 'PENDING');

    final msg = MessageModel(
      msgId: clientMsgId,
      type: 'CHAT',
      sender: sender,
      receiver: receiver,
      message: text,
      status: initialStatus,
      timeStamp: timeStamp,
      replyToMsgId: replyToMsgId,
      replyToSender: replyToSender,
      replyToText: replyToText,
    );

    // Update in-memory state & notify UI immediately (instant UI response)
    List<MessageModel>? list = _getConversationList(receiver);
    if (list == null) {
      list = [];
      _conversationMap[receiver] = list;
    }
    list.add(msg);
    clearUnreadCount(receiver);

    // Push via WebSocket if recipient is online
    if (isOnline) {
      _wsService.sendMessage(msg);
    }

    // Save locally to SQLite and update home chat
    await _dbService.saveMessage(msg);

    final existingIndex =
        _homeChats.indexWhere((c) => isSameUser(c.chatUser, receiver));
    final chatUserName =
        existingIndex != -1 ? _homeChats[existingIndex].chatUserName : null;
    final imgUrl =
        existingIndex != -1 ? _homeChats[existingIndex].imgUrl : null;

    final homeChat = ChatHomeModel(
      chatUser: receiver,
      chatUserName: chatUserName,
      lastMsg: text,
      status: initialStatus,
      lastMessageTime:
          DateTime.fromMillisecondsSinceEpoch(timeStamp).toIso8601String(),
      imgUrl: imgUrl,
    );
    await _dbService.saveChatHome(homeChat);
    _homeChats = await _dbService.getAllHomeChats();
    notifyListeners();
  }

  Future<void> sendImageMessage({
    required String sender,
    required String receiver,
    required List<int> imageBytes,
    required String fileExtension,
    String? replyToMsgId,
    String? replyToSender,
    String? replyToText,
  }) async {
    final timeStamp = _nextUniqueTimestamp();
    final clientMsgId = '${sender}_${receiver}_$timeStamp';
    final isSelf = isSameUser(sender, receiver);

    // Cache local image bytes immediately under a temp identifier so UI displays instant blurred placeholder
    final localTempKey = 'local_img_$clientMsgId';
    await AvatarCacheService.instance
        .saveBytesToCache(localTempKey, imageBytes);

    // 1. Create message with UPLOADING status and local preview key
    final pendingMsg = MessageModel(
      msgId: clientMsgId,
      type: 'IMAGE',
      sender: sender,
      receiver: receiver,
      message: localTempKey,
      status: 'UPLOADING',
      timeStamp: timeStamp,
      replyToMsgId: replyToMsgId,
      replyToSender: replyToSender,
      replyToText: replyToText,
    );

    // Add to in-memory conversation list immediately (so it renders at this initial timestamp)
    List<MessageModel>? list = _getConversationList(receiver);
    if (list == null) {
      list = [];
      _conversationMap[receiver] = list;
    }
    list.add(pendingMsg);
    list.sort((a, b) => a.timeStamp.compareTo(b.timeStamp));
    clearUnreadCount(receiver);

    // Save locally to SQLite so it persists
    await _dbService.saveMessage(pendingMsg);

    // Update Home Chat preview with '📷 Photo'
    final existingIndex =
        _homeChats.indexWhere((c) => isSameUser(c.chatUser, receiver));
    final chatUserName =
        existingIndex != -1 ? _homeChats[existingIndex].chatUserName : null;
    final imgUrl =
        existingIndex != -1 ? _homeChats[existingIndex].imgUrl : null;

    final homeChat = ChatHomeModel(
      chatUser: receiver,
      chatUserName: chatUserName,
      lastMsg: '📷 Photo',
      status: 'UPLOADING',
      lastMessageTime:
          DateTime.fromMillisecondsSinceEpoch(timeStamp).toIso8601String(),
      imgUrl: imgUrl,
    );
    await _dbService.saveChatHome(homeChat);
    _homeChats = await _dbService.getAllHomeChats();
    notifyListeners();

    // 2. Perform asynchronous upload in background WITHOUT blocking user input or text messages
    _performAsyncImageUpload(
      clientMsgId: clientMsgId,
      sender: sender,
      receiver: receiver,
      imageBytes: imageBytes,
      fileExtension: fileExtension,
      timeStamp: timeStamp,
      isSelf: isSelf,
      localTempKey: localTempKey,
      replyToMsgId: replyToMsgId,
      replyToSender: replyToSender,
      replyToText: replyToText,
    );
  }

  Future<void> _performAsyncImageUpload({
    required String clientMsgId,
    required String sender,
    required String receiver,
    required List<int> imageBytes,
    required String fileExtension,
    required int timeStamp,
    required bool isSelf,
    required String localTempKey,
    String? replyToMsgId,
    String? replyToSender,
    String? replyToText,
  }) async {
    try {
      final authService = AuthService();
      final presignInfo = await authService.getPresignedUrl(fileExtension);
      if (presignInfo == null) {
        throw Exception('Failed to get presigned URL from server');
      }

      final uploadUrl = presignInfo['uploadUrl']!;
      final filePublicUrl = presignInfo['filePublicUrl']!;

      final uploadResult = await authService.uploadImageToPresignedUrl(
        uploadUrl: uploadUrl,
        imageBytes: imageBytes,
        fileExtension: fileExtension,
      );

      if (uploadResult['success'] != true) {
        throw Exception('R2 upload failed: ${uploadResult['statusCode']}');
      }

      // Save raw image bytes locally to Pictures/HeyChat folder so sender can view in gallery
      final localSavedPath = await MediaStorageService.instance
          .saveImageBytes(imageBytes, fileExtension);

      // Cache the public URL with the image bytes locally
      await AvatarCacheService.instance
          .saveBytesToCache(filePublicUrl, imageBytes);

      final isOnline = isSelf || isUserOnline(receiver);
      final finalStatus = isSelf ? 'READ' : (isOnline ? 'SENT' : 'PENDING');

      final completedMsg = MessageModel(
        msgId: clientMsgId,
        type: 'IMAGE',
        sender: sender,
        receiver: receiver,
        message: filePublicUrl,
        status: finalStatus,
        timeStamp:
            timeStamp, // KEEP INITIAL TIMESTAMP SO POSITION DOES NOT JUMP
        replyToMsgId: replyToMsgId,
        replyToSender: replyToSender,
        replyToText: replyToText,
        localImageUrl: localSavedPath,
        cloudImageUrl: filePublicUrl,
      );

      // Update in-memory list
      List<MessageModel>? list = _getConversationList(receiver);
      if (list != null) {
        final idx = list.indexWhere((m) => m.msgId == clientMsgId);
        if (idx != -1) {
          list[idx] = completedMsg;
          list.sort((a, b) => a.timeStamp.compareTo(b.timeStamp));
        }
      }

      // Send via WebSocket to other participant
      _wsService.sendMessage(completedMsg);
      // Send via WebSocket to other participant if online
      if (isOnline) {
        _wsService.sendMessage(completedMsg);
      }

      // Save locally to SQLite
      await _dbService.saveMessage(completedMsg);

      // Update Home Chat preview
      final existingIndex =
          _homeChats.indexWhere((c) => isSameUser(c.chatUser, receiver));
      final chatUserName =
          existingIndex != -1 ? _homeChats[existingIndex].chatUserName : null;
      final imgUrl =
          existingIndex != -1 ? _homeChats[existingIndex].imgUrl : null;

      final homeChat = ChatHomeModel(
        chatUser: receiver,
        chatUserName: chatUserName,
        lastMsg: '📷 Photo',
        status: finalStatus,
        lastMessageTime:
            DateTime.fromMillisecondsSinceEpoch(timeStamp).toIso8601String(),
        imgUrl: imgUrl,
      );
      await _dbService.saveChatHome(homeChat);
      _homeChats = await _dbService.getAllHomeChats();

      notifyListeners();
    } catch (e) {
      // Mark message as FAILED so user sees retry option
      List<MessageModel>? list = _getConversationList(receiver);
      if (list != null) {
        final idx = list.indexWhere((m) => m.msgId == clientMsgId);
        if (idx != -1) {
          list[idx] = list[idx].copyWith(status: 'FAILED');
          notifyListeners();
        }
      }
    }
  }

  Future<void> markConversationAsRead({
    required String currentUserMblNo,
    required String contactMblNo,
  }) async {
    // 1. Clear unread count for this contact
    clearUnreadCount(contactMblNo);

    // 2. Send READ packet via WebSocket
    final readPacket = MessageModel(
      type: 'READ',
      sender: currentUserMblNo,
      receiver: contactMblNo,
      message: '',
      status: 'READ',
      timeStamp: DateTime.now().millisecondsSinceEpoch,
    );
    _wsService.sendMessage(readPacket);

    // 3. Mark any incoming messages from contactMblNo as READ in SQLite
    await _dbService.updateMessageStatus(
      sender: contactMblNo,
      receiver: currentUserMblNo,
      newStatus: 'READ',
    );

    // 4. Mark in-memory messages from contactMblNo as READ
    final list = _getConversationList(contactMblNo);
    if (list != null) {
      bool updated = false;
      for (int i = 0; i < list.length; i++) {
        if (isSameUser(list[i].sender, contactMblNo) &&
            list[i].status != 'READ') {
          list[i] = list[i].copyWith(status: 'READ');
          updated = true;
        }
      }
      if (updated) {
        notifyListeners();
      }
    }
  }

  Future<void> editChatMessage({
    required MessageModel originalMessage,
    required String newText,
  }) async {
    final updatedMsg = originalMessage.copyWith(
      type: 'EDIT',
      message: newText,
      isEdited: true,
    );

    final otherUser = originalMessage.receiver;

    // Update in local DB
    await _dbService.saveMessage(updatedMsg);

    // Update in memory
    final list = _getConversationList(otherUser);
    if (list != null) {
      final targetId = originalMessage.msgId ??
          '${originalMessage.sender}_${originalMessage.receiver}_${originalMessage.timeStamp}';
      final idx = list.indexWhere((m) =>
          m.msgId == targetId ||
          (m.timeStamp == originalMessage.timeStamp &&
              isSameUser(m.sender, originalMessage.sender)));
      if (idx != -1) {
        list[idx] = updatedMsg;
        if (idx == list.length - 1) {
          final existingChat = _homeChats.firstWhere(
            (c) => isSameUser(c.chatUser, otherUser),
            orElse: () =>
                ChatHomeModel(chatUser: otherUser, lastMsg: '', status: ''),
          );
          final homeChat = ChatHomeModel(
            chatUser: otherUser,
            chatUserName: existingChat.chatUserName,
            lastMsg: newText,
            status: existingChat.status,
            lastMessageTime: existingChat.lastMessageTime,
            imgUrl: existingChat.imgUrl,
          );
          await _dbService.saveChatHome(homeChat);
          _homeChats = await _dbService.getAllHomeChats();
        }
      }
    }

    // Push via WebSocket
    _wsService.sendMessage(updatedMsg);

    notifyListeners();
  }

  Future<void> deleteMessageForEveryone({
    required MessageModel message,
  }) async {
    final updatedMsg = message.copyWith(
      type: 'DELETE_EVERYONE',
      message: 'This message was deleted',
      isDeletedForEveryone: true,
    );

    final otherUser = message.receiver;

    // Update locally in SQLite
    await _dbService.saveMessage(updatedMsg);

    // Update in memory
    final list = _getConversationList(otherUser);
    if (list != null) {
      final targetId = message.msgId ??
          '${message.sender}_${message.receiver}_${message.timeStamp}';
      final idx = list.indexWhere((m) =>
          m.msgId == targetId ||
          (m.timeStamp == message.timeStamp &&
              isSameUser(m.sender, message.sender)));
      if (idx != -1) {
        list[idx] = updatedMsg;
        if (idx == list.length - 1) {
          final existingChat = _homeChats.firstWhere(
            (c) => isSameUser(c.chatUser, otherUser),
            orElse: () =>
                ChatHomeModel(chatUser: otherUser, lastMsg: '', status: ''),
          );
          final homeChat = ChatHomeModel(
            chatUser: otherUser,
            chatUserName: existingChat.chatUserName,
            lastMsg: 'This message was deleted',
            status: existingChat.status,
            lastMessageTime: existingChat.lastMessageTime,
            imgUrl: existingChat.imgUrl,
          );
          await _dbService.saveChatHome(homeChat);
          _homeChats = await _dbService.getAllHomeChats();
        }
      }
    }

    // Push via WebSocket
    _wsService.sendMessage(updatedMsg);

    notifyListeners();
  }

  Future<void> deleteMessageForMe({
    required MessageModel message,
    required String currentUserMblNo,
  }) async {
    final otherUser = isSameUser(message.sender, currentUserMblNo)
        ? message.receiver
        : message.sender;

    // Send DELETE_FOR_ME to backend so backend tracks deletedForUsers
    final delEvent = MessageModel(
      msgId: message.msgId,
      type: 'DELETE_FOR_ME',
      sender: currentUserMblNo,
      receiver: otherUser,
      message: message.message,
      status: message.status,
      timeStamp: DateTime.now().millisecondsSinceEpoch,
    );
    _wsService.sendMessage(delEvent);

    // Delete locally from SQLite
    final targetId = message.msgId ??
        '${message.sender}_${message.receiver}_${message.timeStamp}';
    await _dbService.deleteMessage(targetId);

    // Remove from in-memory conversation
    final list = _getConversationList(otherUser);
    if (list != null) {
      list.removeWhere((m) =>
          m.msgId == targetId ||
          (m.timeStamp == message.timeStamp &&
              isSameUser(m.sender, message.sender)));

      // Update home preview if list changed
      final existingIndex =
          _homeChats.indexWhere((c) => isSameUser(c.chatUser, otherUser));
      if (existingIndex != -1) {
        final newLast = list.isNotEmpty ? list.last : null;
        final homeChat = ChatHomeModel(
          chatUser: otherUser,
          chatUserName: _homeChats[existingIndex].chatUserName,
          lastMsg: newLast?.message ?? '',
          status: newLast?.status ?? '',
          lastMessageTime: newLast != null
              ? DateTime.fromMillisecondsSinceEpoch(newLast.timeStamp)
                  .toIso8601String()
              : _homeChats[existingIndex].lastMessageTime,
          imgUrl: _homeChats[existingIndex].imgUrl,
        );
        await _dbService.saveChatHome(homeChat);
        _homeChats = await _dbService.getAllHomeChats();
      }
    }

    notifyListeners();
  }

  /// Download image from Cloudflare R2 and save to device Pictures/HeyChat folder
  Future<bool> downloadAndSaveImageMessage(MessageModel message) async {
    final targetUrl = message.cloudImageUrl ?? message.message;
    if (targetUrl.trim().isEmpty) return false;

    try {
      final resp = await http.get(Uri.parse(targetUrl.trim()));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        final ext = targetUrl.toLowerCase().contains('.png') ? 'png' : 'jpg';
        final savedPath = await MediaStorageService.instance
            .saveImageBytes(resp.bodyBytes, ext);

        if (savedPath != null && savedPath.isNotEmpty) {
          final updatedMsg = message.copyWith(localImageUrl: savedPath);

          // Update SQLite DB
          final msgId = message.msgId ??
              '${message.sender}_${message.receiver}_${message.timeStamp}';
          await _dbService.updateMessageLocalPath(msgId, savedPath);

          // Update in-memory chat conversation list
          final otherUser = isSameUser(message.sender, activeChatUser ?? '')
              ? message.receiver
              : message.sender;
          final list = _conversationMap[otherUser];
          if (list != null) {
            final idx = list.indexWhere((m) =>
                m.msgId == message.msgId ||
                (m.timeStamp == message.timeStamp &&
                    isSameUser(m.sender, message.sender)));
            if (idx != -1) {
              list[idx] = updatedMsg;
              notifyListeners();
            }
          }
          return true;
        }
      }
    } catch (e) {
      LogService.error('ChatProvider: downloadAndSaveImageMessage error', e);
    }
    return false;
  }

  /// Forward selected messages to multiple recipient contacts
  Future<void> forwardMessages({
    required List<MessageModel> messages,
    required List<String> recipientMblNos,
    required String senderMblNo,
  }) async {
    for (final recipient in recipientMblNos) {
      for (final msg in messages) {
        final uniqueTs = _nextUniqueTimestamp();
        final clientMsgId = '${senderMblNo}_${recipient}_$uniqueTs';
        final isOnline = isUserOnline(recipient);
        final finalStatus = isOnline ? 'SENT' : 'PENDING';

        final fwdMsg = MessageModel(
          msgId: clientMsgId,
          type: msg.type,
          sender: senderMblNo,
          receiver: recipient,
          message: msg.message,
          status: finalStatus,
          timeStamp: uniqueTs,
          isForwarded: true,
          localImageUrl: msg.localImageUrl,
          cloudImageUrl:
              msg.cloudImageUrl ?? (msg.type == 'IMAGE' ? msg.message : null),
        );

        // Update in-memory conversation list if initialized
        List<MessageModel>? list = _getConversationList(recipient);
        if (list != null) {
          list.add(fwdMsg);
          list.sort((a, b) => a.timeStamp.compareTo(b.timeStamp));
        }

        // Send via WebSocket to recipient
        _wsService.sendMessage(fwdMsg);

        // Save locally to SQLite DB
        await _dbService.saveMessage(fwdMsg);

        // Update Home Chat preview item
        final homeChat = ChatHomeModel(
          chatUser: recipient,
          lastMsg: fwdMsg.type == 'IMAGE' ? '📷 Photo' : fwdMsg.message,
          status: finalStatus,
          lastMessageTime:
              DateTime.fromMillisecondsSinceEpoch(uniqueTs).toIso8601String(),
        );
        await _dbService.saveChatHome(homeChat);
      }
    }

    _homeChats = await _dbService.getAllHomeChats();
    notifyListeners();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _wsService.disconnect();
    super.dispose();
  }
}
