import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../models/chat_home_model.dart';
import '../models/message_model.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/cached_avatar.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/glitter_border_wrapper.dart';
import '../widgets/reply_photo_thumbnail.dart';
import '../widgets/swipe_to_reply_wrapper.dart';
import 'full_screen_image_screen.dart';

class ChatDetailScreen extends StatefulWidget {
  final String contactMblNo;
  final String? contactName;
  final String? contactImgUrl;

  const ChatDetailScreen({
    super.key,
    required this.contactMblNo,
    this.contactName,
    this.contactImgUrl,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  static const _imageChannel =
      MethodChannel('com.example.my_first_app/image_picker');

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  MessageModel? _editingMessage;
  MessageModel? _replyingMessage;
  String? _highlightedMsgId;
  final Map<String, GlobalKey> _messageKeys = {};
  final Set<String> _selectedMsgKeys = {};
  int _lastMessageCount = 0;
  double _lastBottomInset = 0.0;
  bool _isActionActive = false;
  ChatProvider? _chatProvider;
  bool _isInputEmpty = true;

  bool _isMsgSelected(MessageModel msg) {
    final mKey = msg.msgId ?? '${msg.sender}_${msg.receiver}_${msg.timeStamp}';
    return _selectedMsgKeys.contains(mKey);
  }

  void _toggleMessageSelection(MessageModel msg) {
    final mKey = msg.msgId ?? '${msg.sender}_${msg.receiver}_${msg.timeStamp}';
    setState(() {
      if (_selectedMsgKeys.contains(mKey)) {
        _selectedMsgKeys.remove(mKey);
      } else {
        _selectedMsgKeys.add(mKey);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedMsgKeys.clear();
    });
  }

  Future<void> _confirmBatchDelete() async {
    if (_selectedMsgKeys.isEmpty) return;

    _focusNode.canRequestFocus = false;
    _focusNode.unfocus();
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    final count = _selectedMsgKeys.length;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Delete for me?',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppConfig.brandDark),
          ),
          content: Text(
            count == 1
                ? 'Selected message will be deleted from me.'
                : 'Selected $count messages will be deleted from me.',
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx, false);
              },
              child: const Text('Cancel',
                  style: TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx, true);
              },
              child: const Text('Confirm',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.currentMblNo != null) {
        final messages = chatProvider.getMessagesFor(widget.contactMblNo);
        final targets = messages.where((m) {
          final mKey = m.msgId ?? '${m.sender}_${m.receiver}_${m.timeStamp}';
          return _selectedMsgKeys.contains(mKey);
        }).toList();

        for (final msg in targets) {
          chatProvider.deleteMessageForMe(
            message: msg,
            currentUserMblNo: authProvider.currentMblNo!,
          );
        }
      }

      _clearSelection();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count == 1
              ? 'Message deleted for me'
              : '$count messages deleted for me'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    _isActionActive = false;
    await Future.delayed(const Duration(milliseconds: 140));
    if (mounted) {
      _focusNode.canRequestFocus = true;
    }
  }

  void _onTextChanged() {
    final nowEmpty = _messageController.text.trim().isEmpty;
    if (nowEmpty != _isInputEmpty) {
      if (mounted) {
        setState(() {
          _isInputEmpty = nowEmpty;
        });
      }
    }
  }

  static bool _isImageMessage(MessageModel msg) {
    if (msg.isDeletedForEveryone) return false;
    if (msg.type == 'IMAGE') return true;
    final text = msg.message.trim();
    if (text.startsWith('local_img_')) return true;
    if (text.startsWith('http') &&
        (text.contains('/uploads/') ||
            text.contains('.r2.dev') ||
            text.endsWith('.jpg') ||
            text.endsWith('.jpeg') ||
            text.endsWith('.png') ||
            text.endsWith('.webp') ||
            text.endsWith('.gif'))) {
      return true;
    }
    return false;
  }

  static bool _isDifferentDay(int ts1, int ts2) {
    final d1 = DateTime.fromMillisecondsSinceEpoch(ts1);
    final d2 = DateTime.fromMillisecondsSinceEpoch(ts2);
    return d1.year != d2.year || d1.month != d2.month || d1.day != d2.day;
  }

  static String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(date.year, date.month, date.day);

    if (msgDate == today) {
      return 'Today';
    } else if (msgDate == yesterday) {
      return 'Yesterday';
    } else if (msgDate.year == now.year) {
      return DateFormat('d MMMM').format(date);
    } else {
      return DateFormat('d MMMM yyyy').format(date);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chatProvider = Provider.of<ChatProvider>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      if (authProvider.currentMblNo != null) {
        chatProvider.setActiveChatUser(widget.contactMblNo);
        chatProvider.loadConversation(
            authProvider.currentMblNo!, widget.contactMblNo,
            contactName: widget.contactName);
        chatProvider.markConversationAsRead(
          currentUserMblNo: authProvider.currentMblNo!,
          contactMblNo: widget.contactMblNo,
        );
        _scrollToBottom(animated: false);
      }
    });
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _chatProvider?.setActiveChatUser(null);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing(MessageModel msg) {
    _focusNode.canRequestFocus = true;
    setState(() {
      _editingMessage = msg;
      _replyingMessage = null;
      _messageController.text = msg.message;
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: _messageController.text.length),
      );
    });
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingMessage = null;
      _messageController.clear();
    });
  }

  void _startReply(MessageModel msg) {
    setState(() {
      _replyingMessage = msg;
      _editingMessage = null;
    });
    _focusNode.canRequestFocus = true;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingMessage = null;
    });
  }

  void _scrollToRepliedMessage(String? targetMsgId) {
    if (targetMsgId == null || targetMsgId.isEmpty) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final messages = chatProvider.getMessagesFor(widget.contactMblNo);

    final targetIndex = messages.indexWhere((m) {
      final mKey = m.msgId ?? '${m.sender}_${m.receiver}_${m.timeStamp}';
      return mKey == targetMsgId || m.msgId == targetMsgId;
    });

    if (targetIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Original message not found'),
          duration: Duration(milliseconds: 1200),
        ),
      );
      return;
    }

    final targetMsg = messages[targetIndex];
    final targetKeyId = (targetMsg.msgId != null && targetMsg.msgId!.isNotEmpty)
        ? '${targetMsg.msgId}_$targetIndex'
        : '${targetMsg.sender}_${targetMsg.receiver}_${targetMsg.timeStamp}_$targetIndex';
    final globalKey = _messageKeys[targetKeyId];

    void triggerHighlight() {
      if (mounted) {
        setState(() {
          _highlightedMsgId = targetKeyId;
        });
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted && _highlightedMsgId == targetKeyId) {
            setState(() {
              _highlightedMsgId = null;
            });
          }
        });
      }
    }

    if (globalKey?.currentContext != null) {
      Scrollable.ensureVisible(
        globalKey!.currentContext!,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
        alignment: 0.35,
      ).then((_) => triggerHighlight());
    } else if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final targetOffset = (targetIndex / messages.length) * maxScroll;
      _scrollController
          .animateTo(
        targetOffset.clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
      )
          .then((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (globalKey?.currentContext != null) {
            Scrollable.ensureVisible(
              globalKey!.currentContext!,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutQuad,
              alignment: 0.35,
            );
          }
          triggerHighlight();
        });
      });
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    final replyMsg = _replyingMessage;
    if (_replyingMessage != null) {
      setState(() {
        _replyingMessage = null;
      });
    }

    if (authProvider.currentMblNo != null) {
      if (_editingMessage != null) {
        if (text != _editingMessage!.message) {
          chatProvider.editChatMessage(
            originalMessage: _editingMessage!,
            newText: text,
          );
        }
        setState(() {
          _editingMessage = null;
        });
        _messageController.clear();
      } else {
        _messageController.clear();
        chatProvider.sendChatMessage(
          sender: authProvider.currentMblNo!,
          receiver: widget.contactMblNo,
          text: text,
          replyToMsgId: replyMsg?.msgId ??
              (replyMsg != null
                  ? '${replyMsg.sender}_${replyMsg.receiver}_${replyMsg.timeStamp}'
                  : null),
          replyToSender: replyMsg?.sender,
          replyToText: replyMsg?.message,
        );
        _scrollToBottom(animated: true);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final dynamic result =
          await _imageChannel.invokeMethod('pickMultipleImages');
      if (result != null) {
        List<dynamic> items = [];
        if (result is List) {
          items = result;
        } else if (result is Map) {
          items = [result];
        }

        for (final item in items) {
          if (item is Map) {
            final Uint8List? bytes = item['bytes'] as Uint8List?;
            final String ext = (item['ext'] as String?) ?? 'jpg';
            if (bytes != null && bytes.isNotEmpty) {
              _sendImageBytes(bytes, ext);
            }
          }
        }
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open image picker: ${e.message}')),
        );
      }
    } on MissingPluginException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Gallery picker requires running on an Android device.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: $e')),
        );
      }
    }
  }

  void _sendImageBytes(Uint8List bytes, String ext) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    final replyMsg = _replyingMessage;
    if (_replyingMessage != null) {
      setState(() {
        _replyingMessage = null;
      });
    }

    if (authProvider.currentMblNo != null) {
      chatProvider.sendImageMessage(
        sender: authProvider.currentMblNo!,
        receiver: widget.contactMblNo,
        imageBytes: bytes,
        fileExtension: ext,
        replyToMsgId: replyMsg?.msgId ??
            (replyMsg != null
                ? '${replyMsg.sender}_${replyMsg.receiver}_${replyMsg.timeStamp}'
                : null),
        replyToSender: replyMsg?.sender,
        replyToText: replyMsg?.message,
      );
      _scrollToBottom(animated: true);
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      void performScroll() {
        if (_scrollController.hasClients) {
          final target = _scrollController.position.maxScrollExtent;
          if (animated) {
            _scrollController.animateTo(
              target,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutQuad,
            );
          } else {
            _scrollController.jumpTo(target);
          }
        }
      }

      performScroll();
      Future.delayed(const Duration(milliseconds: 60), performScroll);
      Future.delayed(const Duration(milliseconds: 180), performScroll);
    });
  }

  void _showMessageOptions(MessageModel msg, bool isMe) {
    _isActionActive = true;
    _focusNode.canRequestFocus = false;
    _focusNode.unfocus();
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    final isImage = _isImageMessage(msg);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                if (!msg.isDeletedForEveryone) ...[
                  ListTile(
                    leading: const Icon(Icons.reply_rounded,
                        color: AppConfig.brandDark),
                    title: const Text('Reply',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    onTap: () {
                      _isActionActive = false;
                      _focusNode.canRequestFocus = true;
                      Navigator.pop(ctx);
                      _startReply(msg);
                    },
                  ),
                  if (!isImage)
                    ListTile(
                      leading: const Icon(Icons.content_copy_rounded,
                          color: AppConfig.brandDark),
                      title: const Text('Copy',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      onTap: () {
                        _isActionActive = false;
                        _focusNode.canRequestFocus = true;
                        Navigator.pop(ctx);
                        Clipboard.setData(ClipboardData(text: msg.message));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied to clipboard'),
                            duration: Duration(milliseconds: 1200),
                          ),
                        );
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.check_circle_outline_rounded,
                        color: AppConfig.brandDark),
                    title: const Text('Select',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    onTap: () {
                      _isActionActive = false;
                      _focusNode.canRequestFocus = true;
                      Navigator.pop(ctx);
                      _toggleMessageSelection(msg);
                    },
                  ),
                ],
                if (isMe && !msg.isDeletedForEveryone) ...[
                  if (!isImage)
                    ListTile(
                      leading: const Icon(Icons.edit_rounded,
                          color: AppConfig.brandDark),
                      title: const Text('Edit message',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      onTap: () {
                        _isActionActive = false;
                        Navigator.pop(ctx);
                        _startEditing(msg);
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.delete_forever_rounded,
                        color: Colors.redAccent),
                    title: const Text('Delete for everyone',
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w500)),
                    onTap: () async {
                      _focusNode.canRequestFocus = false;
                      _focusNode.unfocus();
                      FocusScope.of(context).unfocus();
                      FocusManager.instance.primaryFocus?.unfocus();
                      SystemChannels.textInput.invokeMethod('TextInput.hide');

                      Navigator.pop(ctx);
                      await Future.delayed(const Duration(milliseconds: 100));
                      if (mounted) {
                        await _confirmDelete(msg, forEveryone: true);
                      }
                    },
                  ),
                ],
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: Colors.redAccent),
                  title: const Text('Delete for me',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w500)),
                  onTap: () async {
                    _focusNode.canRequestFocus = false;
                    _focusNode.unfocus();
                    FocusScope.of(context).unfocus();
                    FocusManager.instance.primaryFocus?.unfocus();
                    SystemChannels.textInput.invokeMethod('TextInput.hide');

                    Navigator.pop(ctx);
                    await Future.delayed(const Duration(milliseconds: 100));
                    if (mounted) {
                      await _confirmDelete(msg, forEveryone: false);
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      if (mounted && !_isActionActive) {
        _focusNode.canRequestFocus = true;
      }
    });
  }

  Future<void> _confirmDelete(MessageModel msg,
      {required bool forEveryone}) async {
    _focusNode.canRequestFocus = false;
    _focusNode.unfocus();
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            forEveryone ? 'Delete for everyone?' : 'Delete for me?',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppConfig.brandDark),
          ),
          content: Text(
            forEveryone
                ? 'This message will be deleted for everyone in this chat.'
                : 'This message will be removed from your chat history.',
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx, false);
              },
              child: const Text('Cancel',
                  style: TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx, true);
              },
              child: const Text('Delete',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      if (forEveryone) {
        chatProvider.deleteMessageForEveryone(message: msg);
      } else {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.currentMblNo != null) {
          chatProvider.deleteMessageForMe(
            message: msg,
            currentUserMblNo: authProvider.currentMblNo!,
          );
        }
      }
    }

    _isActionActive = false;
    // After the entire popup flow is completely done, bring keyboard back smoothly
    await Future.delayed(const Duration(milliseconds: 140));
    if (mounted) {
      _focusNode.canRequestFocus = true;
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);

    final messages = chatProvider.getMessagesFor(
      widget.contactMblNo,
      currentUser: authProvider.currentMblNo,
      contactName: widget.contactName,
    );
    final isOnline = chatProvider.isUserOnline(widget.contactMblNo,
        currentUser: authProvider.currentMblNo);

    // Auto-scroll when new message is added or received
    if (messages.length != _lastMessageCount) {
      _lastMessageCount = messages.length;
      _scrollToBottom(animated: true);
    }

    // Auto-scroll when keyboard opens to keep latest messages visible
    final currentBottomInset = MediaQuery.of(context).viewInsets.bottom;
    if (currentBottomInset > _lastBottomInset) {
      _lastBottomInset = currentBottomInset;
      _scrollToBottom(animated: true);
    } else {
      _lastBottomInset = currentBottomInset;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.80),
        foregroundColor: AppConfig.brandDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.black.withValues(alpha: 0.05),
                    width: 0.8,
                  ),
                ),
              ),
            ),
          ),
        ),
        leading: _selectedMsgKeys.isNotEmpty
            ? IconButton(
                icon:
                    const Icon(Icons.close_rounded, color: AppConfig.brandDark),
                onPressed: _clearSelection,
              )
            : null,
        titleSpacing: _selectedMsgKeys.isNotEmpty ? 8 : 0,
        title: _selectedMsgKeys.isNotEmpty
            ? Text(
                '${_selectedMsgKeys.length} Selected',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppConfig.brandDark,
                ),
              )
            : Row(
                children: [
                  Builder(
                    builder: (context) {
                      final chatProvider =
                          Provider.of<ChatProvider>(context, listen: false);
                      final homeChat = chatProvider.homeChats.firstWhere(
                        (c) => ChatProvider.isSameUser(
                            c.chatUser, widget.contactMblNo),
                        orElse: () => ChatHomeModel(
                          chatUser: widget.contactMblNo,
                          chatUserName: widget.contactName,
                          lastMsg: '',
                          status: 'SENT',
                          imgUrl: widget.contactImgUrl,
                        ),
                      );
                      final effectiveImg =
                          widget.contactImgUrl ?? homeChat.imgUrl;
                      final displayName =
                          widget.contactName ?? widget.contactMblNo;

                      return CachedAvatar(
                        imgUrl: effectiveImg,
                        name: displayName,
                        backgroundColor: AppConfig.brandDark,
                        radius: 19,
                        fontSize: 15,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FullScreenImageScreen(
                                imageUrl: effectiveImg,
                                userName: displayName,
                                phoneNumber: widget.contactMblNo,
                                showChatButton: false,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.contactName ?? widget.contactMblNo,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppConfig.brandDark),
                      ),
                      Row(
                        children: [
                          if (isOnline) ...[
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF22C55E)
                                        .withValues(alpha: 0.55),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isOnline
                                  ? const Color(0xFF16A34A)
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
        actions: [
          if (_selectedMsgKeys.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent, size: 24),
              onPressed: _confirmBatchDelete,
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient soft mesh gradient background
          Container(
            color: const Color(0xFFF7F8FC),
          ),
          // Ambient blurred glow sphere 1 (Top right lime glow)
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppConfig.brandLime.withValues(alpha: 0.35),
                    AppConfig.brandLime.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Ambient blurred glow sphere 2 (Center-left soft sky glow)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.32,
            left: -80,
            child: Container(
              width: 270,
              height: 270,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFD6E9FE).withValues(alpha: 0.45),
                    const Color(0xFFD6E9FE).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Ambient blurred glow sphere 3 (Bottom right lime tint)
          Positioned(
            bottom: 90,
            right: -60,
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppConfig.brandLimeLight.withValues(alpha: 0.50),
                    AppConfig.brandLimeLight.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 10, bottom: 20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = ChatProvider.isSameUser(
                        msg.sender, authProvider.currentMblNo ?? '');
                    final msgKeyId = (msg.msgId != null &&
                            msg.msgId!.isNotEmpty)
                        ? '${msg.msgId}_$index'
                        : '${msg.sender}_${msg.receiver}_${msg.timeStamp}_$index';
                    final itemKey =
                        _messageKeys.putIfAbsent(msgKeyId, () => GlobalKey());

                    final showDateHeader = index == 0 ||
                        _isDifferentDay(
                            messages[index - 1].timeStamp, msg.timeStamp);

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showDateHeader)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    width: 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _formatDateHeader(
                                    DateTime.fromMillisecondsSinceEpoch(
                                        msg.timeStamp),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppConfig.brandDark,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        TweenAnimationBuilder<double>(
                          key:
                              ValueKey('${msg.timeStamp}_${msg.sender}_$index'),
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(
                                  isMe
                                      ? (1.0 - value) * 16
                                      : -(1.0 - value) * 16,
                                  (1.0 - value) * 8,
                                ),
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            key: itemKey,
                            child: SwipeToReplyWrapper(
                              onReply: () => _startReply(msg),
                              onSelect: () => _toggleMessageSelection(msg),
                              child: ChatBubble(
                                message: msg,
                                isMe: isMe,
                                contactName: widget.contactName,
                                contactMblNo: widget.contactMblNo,
                                currentMblNo: authProvider.currentMblNo,
                                isHighlighted: _highlightedMsgId == msgKeyId,
                                isSelected: _isMsgSelected(msg),
                                onTap: _selectedMsgKeys.isNotEmpty
                                    ? () => _toggleMessageSelection(msg)
                                    : null,
                                onLongPress: () =>
                                    _showMessageOptions(msg, isMe),
                                onReplyTap: () =>
                                    _scrollToRepliedMessage(msg.replyToMsgId),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              // Floating Pill Input Bar & Separate Send Pill
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_editingMessage != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppConfig.brandLimeDark
                                  .withValues(alpha: 0.5),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.edit_rounded,
                                size: 16,
                                color: AppConfig.brandDark,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Editing message',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppConfig.brandDark,
                                      ),
                                    ),
                                    Text(
                                      _editingMessage!.message,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: _cancelEditing,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_replyingMessage != null) ...[
                        Builder(builder: (context) {
                          final isReplyImg = _isImageMessage(_replyingMessage!);
                          final replyAuthor = ChatProvider.isSameUser(
                                  _replyingMessage!.sender,
                                  authProvider.currentMblNo ?? '')
                              ? 'You'
                              : (widget.contactName ?? widget.contactMblNo);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppConfig.brandLimeDark
                                    .withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppConfig.brandLimeDark
                                      .withValues(alpha: 0.10),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    // Sleek modern curved reply badge
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: AppConfig.brandLime
                                            .withValues(alpha: 0.50),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.reply_rounded,
                                        size: 16,
                                        color: AppConfig.brandDark,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                'Replying to ',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              Text(
                                                replyAuthor,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      AppConfig.brandLimeDark,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          if (isReplyImg)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                Icon(
                                                  Icons.camera_alt_rounded,
                                                  size: 13,
                                                  color: Colors.black54,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Photo',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.black87,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            )
                                          else
                                            Text(
                                              _replyingMessage!.message,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.black
                                                    .withValues(alpha: 0.75),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (isReplyImg) ...[
                                      const SizedBox(width: 8),
                                      ReplyPhotoThumbnail(
                                        imageUrl: _replyingMessage!.message,
                                        size: 42,
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    GestureDetector(
                                      onTap: _cancelReply,
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.06),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Main Message Input Pill (auto-expanding)
                          Expanded(
                            child: Builder(builder: (context) {
                              final isGlitterActive =
                                  _isInputEmpty && _editingMessage == null;

                              return GlitterBorderWrapper(
                                isEnabled: isGlitterActive,
                                borderRadius: 26,
                                strokeWidth: 1.1,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minHeight: 52,
                                    maxHeight: 130,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.90),
                                    borderRadius: BorderRadius.circular(26),
                                    border: Border.all(
                                      color: isGlitterActive
                                          ? Colors.transparent
                                          : ((_editingMessage != null ||
                                                  _replyingMessage != null)
                                              ? AppConfig.brandLimeDark
                                                  .withValues(alpha: 0.6)
                                              : Colors.white
                                                  .withValues(alpha: 0.95)),
                                      width: 1.1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.05),
                                        blurRadius: 14,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(26),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                          sigmaX: 14, sigmaY: 14),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 4),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 2),
                                              child: Icon(
                                                _editingMessage != null
                                                    ? Icons.edit_note_rounded
                                                    : (_replyingMessage != null
                                                        ? Icons.reply_rounded
                                                        : Icons
                                                            .chat_bubble_outline_rounded),
                                                color:
                                                    (_editingMessage != null ||
                                                            _replyingMessage !=
                                                                null)
                                                        ? AppConfig.brandDark
                                                        : Colors.grey,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: TextField(
                                                controller: _messageController,
                                                focusNode: _focusNode,
                                                onTap: () => _focusNode
                                                    .canRequestFocus = true,
                                                keyboardType:
                                                    TextInputType.multiline,
                                                minLines: 1,
                                                maxLines: 5,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: AppConfig.brandDark,
                                                ),
                                                decoration: InputDecoration(
                                                  hintText: _editingMessage !=
                                                          null
                                                      ? 'Edit your message...'
                                                      : (_replyingMessage !=
                                                              null
                                                          ? 'Type a reply...'
                                                          : 'Type a message...'),
                                                  hintStyle: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey,
                                                  ),
                                                  border: InputBorder.none,
                                                  isDense: true,
                                                  contentPadding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                          vertical: 10),
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 4),
                                              child: _BouncyScaleButton(
                                                onTap: _pickFromGallery,
                                                child: Container(
                                                  width: 36,
                                                  height: 36,
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade100,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.image_outlined,
                                                    size: 20,
                                                    color: AppConfig.brandDark,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(width: 8),
                          // Separate Send Action Pill
                          _BouncyScaleButton(
                            onTap: _sendMessage,
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppConfig.brandLime,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppConfig.brandLime
                                        .withValues(alpha: 0.45),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  _editingMessage != null
                                      ? Icons.check_rounded
                                      : Icons.send_rounded,
                                  color: Colors.black,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BouncyScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const _BouncyScaleButton({
    required this.child,
    this.onTap,
  }) : pressedScale = 0.88;

  @override
  State<_BouncyScaleButton> createState() => _BouncyScaleButtonState();
}

class _BouncyScaleButtonState extends State<_BouncyScaleButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
