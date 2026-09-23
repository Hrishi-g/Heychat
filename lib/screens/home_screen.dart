import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../services/auth_service.dart';
import '../utils/dummy_data.dart';
import 'chat_detail_screen.dart';
import 'full_screen_image_screen.dart';
import 'login_screen.dart';
import 'logs_screen.dart';
import 'profile_screen.dart';
import '../widgets/cached_avatar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;
  final _newChatController = TextEditingController();
  bool _isSearchingExistingChats = false;
  final _searchExistingChatsController = TextEditingController();
  String _searchExistingChatsQuery = '';
  final Set<String> _selectedChatUsers = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      if (authProvider.currentMblNo != null) {
        chatProvider.init(authProvider.currentMblNo!);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _newChatController.dispose();
    _searchExistingChatsController.dispose();
    super.dispose();
  }

  static bool _isImageMsg(String msg) {
    final t = msg.trim();
    return t.startsWith('local_img_') ||
        t.contains('📷 Photo') ||
        (t.startsWith('http') &&
            (t.contains('/uploads/') ||
                t.contains('.r2.dev') ||
                t.endsWith('.jpg') ||
                t.endsWith('.jpeg') ||
                t.endsWith('.png') ||
                t.endsWith('.webp') ||
                t.endsWith('.gif')));
  }

  Widget _buildAvatar({
    required String? imgUrl,
    required String name,
    required Color backgroundColor,
    double radius = 24,
    double fontSize = 18,
    VoidCallback? onTap,
  }) {
    return CachedAvatar(
      imgUrl: imgUrl,
      name: name,
      backgroundColor: backgroundColor,
      radius: radius,
      fontSize: fontSize,
      onTap: onTap,
    );
  }

  void _showNewChatDialog() {
    _newChatController.clear();
    bool isSearching = false;
    String? errorMessage;
    Map<String, dynamic>? foundUser;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final authProvider =
                Provider.of<AuthProvider>(context, listen: false);
            final chatProvider =
                Provider.of<ChatProvider>(context, listen: false);

            Future<void> performSearch() async {
              final targetMblNo = _newChatController.text.trim();
              if (targetMblNo.isEmpty) {
                setDialogState(() {
                  errorMessage = 'Please enter a mobile number';
                });
                return;
              }

              setDialogState(() {
                isSearching = true;
                errorMessage = null;
                foundUser = null;
              });

              try {
                final user = await AuthService().getNewUser(targetMblNo);
                setDialogState(() {
                  isSearching = false;
                  if (user != null) {
                    foundUser = user;
                    errorMessage = null;
                  } else {
                    foundUser = null;
                    errorMessage = 'User not found with this mobile number';
                  }
                });
              } catch (e) {
                setDialogState(() {
                  isSearching = false;
                  errorMessage = 'Search failed. Please check connection.';
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              title: const Text(
                'New Chat',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppConfig.brandDark,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _newChatController,
                      keyboardType: TextInputType.phone,
                      autofocus: true,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppConfig.brandDark,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Enter contact mobile',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.normal,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppConfig.brandDark, width: 1.5),
                        ),
                        suffixIcon: isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppConfig.brandDark,
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.search, size: 20),
                                tooltip: 'Search',
                                onPressed: isSearching ? null : performSearch,
                              ),
                      ),
                      onSubmitted: (_) => performSearch(),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (foundUser != null) ...[
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final isSelf = foundUser!['mblNo']?.toString() ==
                              authProvider.currentMblNo;
                          final rawName =
                              foundUser!['name']?.toString() ?? 'User';
                          final displayName =
                              isSelf ? '$rawName (self)' : rawName;
                          final targetMblNo = foundUser!['mblNo']?.toString() ??
                              _newChatController.text.trim();
                          final targetImg = foundUser!['imgUrl']?.toString();

                          Future<void> startChatWithFoundUser() async {
                            await chatProvider.addNewChatUser(
                              targetMblNo,
                              displayName,
                              imgUrl: targetImg,
                            );

                            if (mounted) {
                              setState(() {
                                _isSearchingExistingChats = false;
                                _searchExistingChatsController.clear();
                                _searchExistingChatsQuery = '';
                              });
                            }

                            Navigator.pop(dialogCtx);
                            _newChatController.clear();

                            if (mounted) {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatDetailScreen(
                                      contactMblNo: targetMblNo,
                                      contactName: displayName,
                                      contactImgUrl: targetImg,
                                    ),
                                  ));
                            }
                          }

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: startChatWithFoundUser,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    AppConfig.brandLime.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppConfig.brandLime,
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  _buildAvatar(
                                    imgUrl: targetImg,
                                    name: rawName,
                                    backgroundColor: AppConfig.brandDark,
                                    radius: 20,
                                    fontSize: 14,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: AppConfig.brandDark,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          targetMblNo,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppConfig.brandLime,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.chat_bubble_rounded,
                                            size: 11, color: Colors.black),
                                        SizedBox(width: 4),
                                        Text(
                                          'Chat',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(
                    'CANCEL',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (foundUser == null)
                  ElevatedButton(
                    onPressed: isSearching ? null : performSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConfig.brandLime,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                    ),
                    child: isSearching
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            'SEARCH',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                  )
                else
                  ElevatedButton(
                    onPressed: () async {
                      final targetMblNo = foundUser!['mblNo']?.toString() ??
                          _newChatController.text.trim();
                      final isSelf = targetMblNo == authProvider.currentMblNo;
                      final rawName = foundUser!['name']?.toString() ?? 'User';
                      final targetName = isSelf ? '$rawName (self)' : rawName;
                      final targetImg = foundUser!['imgUrl']?.toString();

                      await chatProvider.addNewChatUser(
                        targetMblNo,
                        targetName,
                        imgUrl: targetImg,
                      );

                      if (mounted) {
                        setState(() {
                          _isSearchingExistingChats = false;
                          _searchExistingChatsController.clear();
                          _searchExistingChatsQuery = '';
                        });
                      }

                      Navigator.pop(dialogCtx);
                      _newChatController.clear();

                      if (mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatDetailScreen(
                              contactMblNo: targetMblNo,
                              contactName: targetName,
                              contactImgUrl: targetImg,
                            ),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConfig.brandLime,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    child: const Text(
                      'CHAT',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteSelectedChats() {
    if (_selectedChatUsers.isEmpty) return;

    bool deleteHistory = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final authProvider =
                Provider.of<AuthProvider>(context, listen: false);
            final chatProvider =
                Provider.of<ChatProvider>(context, listen: false);
            final currentUser = authProvider.currentMblNo ?? '';

            final count = _selectedChatUsers.length;
            final titleText =
                count == 1 ? 'Delete Chat?' : 'Delete $count Chats?';

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                titleText,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppConfig.brandDark,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count == 1
                        ? 'Are you sure you want to delete this chat from your chat list?'
                        : 'Are you sure you want to delete $count selected chats from your chat list?',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () {
                      setDialogState(() {
                        deleteHistory = !deleteHistory;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: deleteHistory,
                              activeColor: AppConfig.brandDark,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (val) {
                                setDialogState(() {
                                  deleteHistory = val ?? false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Also delete chat history and media from device',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(
                    'CANCEL',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final usersToDelete = List<String>.from(_selectedChatUsers);
                    Navigator.pop(dialogCtx);

                    for (final user in usersToDelete) {
                      await chatProvider.deleteChatUser(
                        chatUser: user,
                        currentUser: currentUser,
                        deleteMessagesHistory: deleteHistory,
                      );
                    }

                    if (mounted) {
                      setState(() {
                        _selectedChatUsers.clear();
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'DELETE',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFloatingDock() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          children: [
            // 1. MAIN NAVIGATION PILL (Chats, Status, Calls)
            Expanded(
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, _) {
                        double page = _currentIndex.toDouble();
                        if (_pageController.hasClients &&
                            _pageController.position.haveDimensions) {
                          page =
                              _pageController.page ?? _currentIndex.toDouble();
                        }
                        // Map page (0.0 to 2.0) to Alignment (-1.0 to 1.0)
                        final alignX = (page - 1.0).clamp(-1.0, 1.0);

                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // A. Smooth Sliding Brand Lime Capsule Indicator
                            Align(
                              alignment: Alignment(alignX, 0.0),
                              child: FractionallySizedBox(
                                widthFactor: 1 / 3,
                                heightFactor: 1.0,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 5),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppConfig.brandLime,
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppConfig.brandLime
                                              .withValues(alpha: 0.45),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // B. Fixed Tab Slots (Each occupying exactly 1/3 width)
                            Row(
                              children: [
                                _buildNavPillItem(
                                  index: 0,
                                  label: 'Chats',
                                  icon: Icons.chat_bubble_outline_rounded,
                                  activeIcon: Icons.chat_bubble_rounded,
                                  page: page,
                                ),
                                _buildNavPillItem(
                                  index: 1,
                                  label: 'Status',
                                  icon: Icons.donut_large_rounded,
                                  activeIcon: Icons.donut_large_rounded,
                                  page: page,
                                ),
                                _buildNavPillItem(
                                  index: 2,
                                  label: 'Calls',
                                  icon: Icons.call_outlined,
                                  activeIcon: Icons.call_rounded,
                                  page: page,
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // 2. SEPARATE PILL FOR "SEARCH MOBILE" / START CHAT
            _BouncyEffect(
              onTap: _showNewChatDialog,
              pressedScale: 0.88,
              child: Container(
                height: 58,
                width: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppConfig.brandLime.withValues(alpha: 0.85),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppConfig.brandLime.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      color: AppConfig.brandLime.withValues(alpha: 0.22),
                      child: const Center(
                        child: Icon(
                          Icons.person_search_rounded,
                          color: AppConfig.brandDark,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavPillItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    required double page,
  }) {
    final isSelected = _currentIndex == index;
    final indicatorDistance = (page - index).abs();
    final indicatorCloseness = (1.0 - indicatorDistance).clamp(0.0, 1.0);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_currentIndex == index) return;
          setState(() {
            _currentIndex = index;
          });
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
        },
        child: Container(
          height: double.infinity,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  key: ValueKey<bool>(isSelected),
                  size: 20,
                  color: Color.lerp(
                        Colors.grey.shade600,
                        Colors.black,
                        indicatorCloseness,
                      ) ??
                      Colors.black,
                ),
              ),
              ClipRect(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: isSelected
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 5),
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: isSelected ? 1.0 : 0.0,
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final tabTitles = ['Chats', 'Status', 'Calls'];

    // Real chats managed by backend WebSocket and local SQLite database
    final allChats = chatProvider.homeChats;
    final displayChats = (_isSearchingExistingChats &&
            _searchExistingChatsQuery.trim().isNotEmpty)
        ? allChats.where((c) {
            final query = _searchExistingChatsQuery.trim().toLowerCase();
            final phoneDigits = c.chatUser.replaceAll(RegExp(r'[^0-9]'), '');
            final queryDigits = query.replaceAll(RegExp(r'[^0-9]'), '');
            final name = (c.chatUserName ?? '').toLowerCase();

            // Match phone digits if query contains digits, or raw phone string, or name
            final phoneMatch =
                queryDigits.isNotEmpty && phoneDigits.contains(queryDigits);
            final rawPhoneMatch = c.chatUser.toLowerCase().contains(query);
            final nameMatch = name.contains(query);
            return phoneMatch || rawPhoneMatch || nameMatch;
          }).toList()
        : allChats;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppConfig.brandDark,
        elevation: 0.5,
        leading: _selectedChatUsers.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppConfig.brandDark),
                onPressed: () {
                  setState(() {
                    _selectedChatUsers.clear();
                  });
                },
              )
            : (_isSearchingExistingChats
                ? IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: AppConfig.brandDark),
                    onPressed: () {
                      setState(() {
                        _isSearchingExistingChats = false;
                        _searchExistingChatsController.clear();
                        _searchExistingChatsQuery = '';
                      });
                    },
                  )
                : null),
        title: _selectedChatUsers.isNotEmpty
            ? Text(
                '${_selectedChatUsers.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: AppConfig.brandDark,
                ),
              )
            : (_isSearchingExistingChats
                ? TextField(
                    controller: _searchExistingChatsController,
                    autofocus: true,
                    style: const TextStyle(
                      color: AppConfig.brandDark,
                      fontSize: 16.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search chats by phone number...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchExistingChatsQuery = val;
                      });
                    },
                  )
                : Text(
                    tabTitles[_currentIndex],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  )),
        actions: [
          if (_selectedChatUsers.isNotEmpty) ...[
            IconButton(
              icon:
                  const Icon(Icons.delete_outline, color: Colors.red, size: 24),
              tooltip: 'Delete selected chats',
              onPressed: _confirmDeleteSelectedChats,
            ),
          ] else if (_isSearchingExistingChats) ...[
            if (_searchExistingChatsQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, color: AppConfig.brandDark),
                onPressed: () {
                  setState(() {
                    _searchExistingChatsController.clear();
                    _searchExistingChatsQuery = '';
                  });
                },
              ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.search, color: AppConfig.brandDark),
              tooltip: 'Search chats',
              onPressed: () {
                setState(() {
                  _isSearchingExistingChats = true;
                  if (_currentIndex != 0) {
                    _currentIndex = 0;
                    _pageController.jumpToPage(0);
                  }
                });
              },
            ),
            PopupMenuButton<String>(
              iconColor: AppConfig.brandDark,
              offset: const Offset(0, 48),
              elevation: 8,
              shadowColor: Colors.black.withValues(alpha: 0.16),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              onSelected: (val) async {
                if (val == 'profile') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ProfileScreen()),
                  );
                } else if (val == 'logs') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LogsScreen()),
                  );
                } else if (val == 'logout') {
                  await authProvider.logout();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'profile',
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        _buildAvatar(
                          imgUrl: authProvider.currentImgUrl,
                          name: authProvider.currentUserName ??
                              authProvider.currentMblNo ??
                              'U',
                          backgroundColor: AppConfig.brandDark,
                          radius: 17,
                          fontSize: 14,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Profile & Account',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppConfig.brandDark,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                authProvider.currentMblNo ?? 'View profile',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios,
                            size: 11, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const PopupMenuDivider(height: 8),
                PopupMenuItem(
                  value: 'logs',
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.terminal_rounded,
                            size: 16, color: AppConfig.brandDark),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'App Device Logs',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: AppConfig.brandDark,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'logout',
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.logout_rounded,
                            size: 16, color: Colors.red),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: PopScope(
        canPop: !_isSearchingExistingChats && _selectedChatUsers.isEmpty,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            if (_selectedChatUsers.isNotEmpty) {
              setState(() {
                _selectedChatUsers.clear();
              });
            } else if (_isSearchingExistingChats) {
              setState(() {
                _isSearchingExistingChats = false;
                _searchExistingChatsController.clear();
                _searchExistingChatsQuery = '';
              });
            }
          }
        },
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
              if (_currentIndex != 0 && _isSearchingExistingChats) {
                _isSearchingExistingChats = false;
                _searchExistingChatsController.clear();
                _searchExistingChatsQuery = '';
              }
            });
          },
          children: [
            // 1. CHATS TAB
            displayChats.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isSearchingExistingChats
                              ? Icons.search_off_rounded
                              : Icons.chat_bubble_outline_rounded,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isSearchingExistingChats
                              ? 'No conversations found'
                              : 'No conversations yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isSearchingExistingChats
                              ? 'No matching phone number in your chats'
                              : 'Tap the chat icon below to message someone',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    padding: const EdgeInsets.only(top: 6, bottom: 95),
                    itemCount: displayChats.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 74,
                      endIndent: 16,
                      color: Colors.grey.shade200,
                    ),
                    itemBuilder: (context, index) {
                      final chat = displayChats[index];
                      final isOnline = chatProvider.isUserOnline(chat.chatUser,
                          currentUser: authProvider.currentMblNo);
                      final unreadCount =
                          chatProvider.getUnreadCount(chat.chatUser);
                      final isUnread = unreadCount > 0;

                      const avatarColors = [
                        Color(0xFF00796B),
                        Color(0xFF3F51B5),
                        Color(0xFF673AB7),
                        Color(0xFF0097A7),
                        Color(0xFF2E7D32),
                        Color(0xFFD81B60),
                        Color(0xFFE65100),
                        Color(0xFF455A64),
                      ];
                      final avatarColor =
                          avatarColors[index % avatarColors.length];
                      final nameToDisplay = (chat.chatUserName != null &&
                              chat.chatUserName!.trim().isNotEmpty)
                          ? chat.chatUserName!.trim()
                          : (chat.chatUser.trim().isNotEmpty
                              ? chat.chatUser.trim()
                              : 'User');
                      final initial = nameToDisplay.isNotEmpty
                          ? nameToDisplay[0].toUpperCase()
                          : '?';

                      final isSelectedChat =
                          _selectedChatUsers.contains(chat.chatUser);

                      return ListTile(
                        selected: isSelectedChat,
                        selectedTileColor:
                            AppConfig.brandLime.withValues(alpha: 0.18),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 3),
                        leading: Stack(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (_selectedChatUsers.isNotEmpty) {
                                  setState(() {
                                    if (_selectedChatUsers
                                        .contains(chat.chatUser)) {
                                      _selectedChatUsers.remove(chat.chatUser);
                                    } else {
                                      _selectedChatUsers.add(chat.chatUser);
                                    }
                                  });
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          FullScreenImageScreen(
                                        imageUrl: chat.imgUrl,
                                        userName: nameToDisplay,
                                        phoneNumber: chat.chatUser,
                                        heroTag: 'avatar_${chat.chatUser}',
                                      ),
                                    ),
                                  );
                                }
                              },
                              onLongPress: () {
                                setState(() {
                                  if (_selectedChatUsers
                                      .contains(chat.chatUser)) {
                                    _selectedChatUsers.remove(chat.chatUser);
                                  } else {
                                    _selectedChatUsers.add(chat.chatUser);
                                  }
                                });
                              },
                              child: Hero(
                                tag: 'avatar_${chat.chatUser}',
                                child: _buildAvatar(
                                  imgUrl: chat.imgUrl,
                                  name: nameToDisplay,
                                  backgroundColor: avatarColor,
                                  radius: 24,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            if (isOnline)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 13,
                                  height: 13,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF25D366),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2.2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          chat.chatUserName ?? chat.chatUser,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: AppConfig.brandDark,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Row(
                            children: [
                              if (!isUnread) ...[
                                if (chat.status == 'READ')
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(Icons.done_all_rounded,
                                        size: 16, color: Color(0xFF34B7F1)),
                                  )
                                else if (chat.status == 'DELIVERED')
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(Icons.done_all_rounded,
                                        size: 16, color: Colors.grey),
                                  )
                                else if (chat.status == 'SENT')
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(Icons.check_rounded,
                                        size: 16, color: Colors.grey),
                                  ),
                              ],
                              Expanded(
                                child: _isImageMsg(chat.lastMsg)
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.camera_alt_rounded,
                                            size: 14,
                                            color: isUnread
                                                ? Colors.black87
                                                : Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Photo',
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: isUnread
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                              color: isUnread
                                                  ? Colors.black87
                                                  : Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        chat.lastMsg,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: isUnread
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: isUnread
                                              ? Colors.black87
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              DummyData.formatTimestamp(chat.lastMessageTime),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isUnread
                                    ? const Color(0xFF25D366)
                                    : Colors.grey.shade500,
                                fontWeight: isUnread
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(height: 5),
                            if (isUnread)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6.5, vertical: 2),
                                constraints: const BoxConstraints(minWidth: 20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF25D366),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$unreadCount',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            else
                              const SizedBox(height: 18),
                          ],
                        ),
                        onLongPress: () {
                          setState(() {
                            if (_selectedChatUsers.contains(chat.chatUser)) {
                              _selectedChatUsers.remove(chat.chatUser);
                            } else {
                              _selectedChatUsers.add(chat.chatUser);
                            }
                          });
                        },
                        onTap: () {
                          if (_selectedChatUsers.isNotEmpty) {
                            setState(() {
                              if (_selectedChatUsers.contains(chat.chatUser)) {
                                _selectedChatUsers.remove(chat.chatUser);
                              } else {
                                _selectedChatUsers.add(chat.chatUser);
                              }
                            });
                          } else {
                            chatProvider.clearUnreadCount(chat.chatUser);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatDetailScreen(
                                  contactMblNo: chat.chatUser,
                                  contactName: chat.chatUserName,
                                  contactImgUrl: chat.imgUrl,
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
            // 2. STATUS TAB
            const Center(child: Text('My Status & Updates')),
            // 3. CALLS TAB
            const Center(child: Text('Recent Calls')),
          ],
        ),
      ),
      bottomNavigationBar: _buildFloatingDock(),
    );
  }
}

class _BouncyEffect extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const _BouncyEffect({
    required this.child,
    this.onTap,
    this.pressedScale = 0.90,
  });

  @override
  State<_BouncyEffect> createState() => _BouncyEffectState();
}

class _BouncyEffectState extends State<_BouncyEffect> {
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
