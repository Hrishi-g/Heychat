import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../models/message_model.dart';
import '../providers/chat_provider.dart';
import 'cached_avatar.dart';

/// ForwardMessageSheet renders a modern glassmorphic sheet for selecting multiple recipients
/// to forward selected chat messages to. Features search, recipient chips, and floating send dock.
class ForwardMessageSheet extends StatefulWidget {
  final List<MessageModel> selectedMessages;
  final String currentMblNo;

  const ForwardMessageSheet({
    super.key,
    required this.selectedMessages,
    required this.currentMblNo,
  });

  @override
  State<ForwardMessageSheet> createState() => _ForwardMessageSheetState();
}

class _ForwardMessageSheetState extends State<ForwardMessageSheet> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedRecipients = {}; // Selected phone numbers
  final Map<String, String> _recipientNames = {}; // Phone number -> Name map
  String _searchQuery = '';
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleRecipient(String phone, String name) {
    setState(() {
      if (_selectedRecipients.contains(phone)) {
        _selectedRecipients.remove(phone);
      } else {
        _selectedRecipients.add(phone);
        _recipientNames[phone] = name;
      }
    });
  }

  Future<void> _handleSendForward() async {
    if (_selectedRecipients.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    await chatProvider.forwardMessages(
      messages: widget.selectedMessages,
      recipientMblNos: _selectedRecipients.toList(),
      senderMblNo: widget.currentMblNo,
    );

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final homeChats = chatProvider.homeChats;

    // Filter chat users based on search query
    final filteredChats = homeChats.where((chat) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = (chat.chatUserName ?? '').toLowerCase();
      final phone = chat.chatUser.toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();

    return Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    // 1. Drag Handle
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppConfig.brandLimeLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shortcut_rounded,
                              color: AppConfig.brandDark,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Forward ${widget.selectedMessages.length} ${widget.selectedMessages.length == 1 ? 'Message' : 'Messages'}',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: AppConfig.brandDark,
                                  ),
                                ),
                                const Text(
                                  'Select one or multiple contacts',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: AppConfig.brandDark),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 3. Glassmorphic Search Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search contact or enter phone number...',
                            hintStyle: TextStyle(
                                fontSize: 13.5, color: Colors.grey.shade500),
                            prefixIcon: const Icon(Icons.search_rounded,
                                color: AppConfig.brandDark, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded,
                                        size: 18, color: Colors.grey),
                                    onPressed: () => _searchController.clear(),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 4. Contact List
                    Expanded(
                      child: filteredChats.isEmpty
                          ? ListView(
                              padding: const EdgeInsets.all(20),
                              children: [
                                if (_searchQuery.trim().isNotEmpty) ...[
                                  // Allow forwarding to a searched phone number directly
                                  ListTile(
                                    leading: Container(
                                      width: 42,
                                      height: 42,
                                      decoration: const BoxDecoration(
                                        color: AppConfig.brandLime,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.send_rounded,
                                          color: AppConfig.brandDark, size: 20),
                                    ),
                                    title: Text(
                                      'Send to "${_searchQuery.trim()}"',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    subtitle:
                                        const Text('Tap to add recipient'),
                                    onTap: () => _toggleRecipient(
                                        _searchQuery.trim(),
                                        _searchQuery.trim()),
                                  ),
                                ] else
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(30),
                                      child: Text(
                                        'No contacts found.\nSearch by phone number above.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          : ListView.builder(
                              itemCount: filteredChats.length,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              itemBuilder: (context, index) {
                                final chat = filteredChats[index];
                                final isSelected =
                                    _selectedRecipients.contains(chat.chatUser);
                                final displayName =
                                    chat.chatUserName ?? chat.chatUser;

                                return ListTile(
                                  leading: Stack(
                                    children: [
                                      CachedAvatar(
                                        imgUrl: chat.imgUrl,
                                        name: displayName,
                                        radius: 22,
                                      ),
                                      if (isSelected)
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF22C55E),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.check_rounded,
                                              color: Colors.white,
                                              size: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  title: Text(
                                    displayName,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: AppConfig.brandDark,
                                    ),
                                  ),
                                  subtitle: Text(
                                    chat.chatUser,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600),
                                  ),
                                  trailing: Checkbox(
                                    value: isSelected,
                                    activeColor: AppConfig.brandLimeDark,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    onChanged: (_) => _toggleRecipient(
                                        chat.chatUser, displayName),
                                  ),
                                  onTap: () => _toggleRecipient(
                                      chat.chatUser, displayName),
                                );
                              },
                            ),
                    ),

                    // 5. Selected Recipients Chips + Floating Send Dock
                    if (_selectedRecipients.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(
                                color: Colors.grey.shade200, width: 1.0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 10,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Recipient Chips List
                            SizedBox(
                              height: 36,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: _selectedRecipients.map((phone) {
                                  final name = _recipientNames[phone] ?? phone;
                                  return Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppConfig.brandLimeLight,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                          color: AppConfig.brandLimeDark
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppConfig.brandDark,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        GestureDetector(
                                          onTap: () =>
                                              _toggleRecipient(phone, name),
                                          child: const Icon(
                                            Icons.cancel_rounded,
                                            size: 15,
                                            color: AppConfig.brandDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Send Button
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppConfig.brandLime,
                                  foregroundColor: AppConfig.brandDark,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed:
                                    _isSending ? null : _handleSendForward,
                                child: _isSending
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: AppConfig.brandDark),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.send_rounded,
                                              size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Forward to ${_selectedRecipients.length} ${_selectedRecipients.length == 1 ? 'Contact' : 'Contacts'}',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ));
  }
}
