import 'dart:io';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/avatar_cache_service.dart';
import 'chat_detail_screen.dart';

/// FullScreenImageScreen displays a user's profile photo in full-screen
/// with pinch-to-zoom, dark immersive background, and hero animation.
class FullScreenImageScreen extends StatefulWidget {
  final String? imageUrl;
  final String userName;
  final String phoneNumber;
  final String? heroTag;
  final bool showChatButton;

  const FullScreenImageScreen({
    super.key,
    this.imageUrl,
    required this.userName,
    required this.phoneNumber,
    this.heroTag,
    this.showChatButton = true,
  });

  @override
  State<FullScreenImageScreen> createState() => _FullScreenImageScreenState();
}

class _FullScreenImageScreenState extends State<FullScreenImageScreen> {
  File? _cachedFile;
  bool _isLoadingCache = true;

  @override
  void initState() {
    super.initState();
    _checkLocalCache();
  }

  Future<void> _checkLocalCache() async {
    if (widget.imageUrl != null && widget.imageUrl!.trim().isNotEmpty) {
      final file =
          await AvatarCacheService.instance.getCachedFile(widget.imageUrl);
      if (mounted) {
        setState(() {
          _cachedFile = file;
          _isLoadingCache = false;
        });
      }
      // If not yet cached, fetch and cache in background
      if (file == null) {
        final downloaded =
            await AvatarCacheService.instance.cacheUrl(widget.imageUrl);
        if (mounted && downloaded != null) {
          setState(() {
            _cachedFile = downloaded;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() => _isLoadingCache = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanName = widget.userName.trim();
    final initial = cleanName.isNotEmpty ? cleanName[0].toUpperCase() : '?';
    final hasImage =
        widget.imageUrl != null && widget.imageUrl!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.userName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (widget.phoneNumber.isNotEmpty &&
                widget.phoneNumber != widget.userName)
              Text(
                widget.phoneNumber,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          if (widget.showChatButton)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded,
                  color: AppConfig.brandLime),
              tooltip: 'Message ${widget.userName}',
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatDetailScreen(
                      contactMblNo: widget.phoneNumber,
                      contactName: widget.userName,
                      contactImgUrl: widget.imageUrl,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.0,
          clipBehavior: Clip.none,
          child: widget.heroTag != null
              ? Hero(
                  tag: widget.heroTag!,
                  child: _buildImageContent(hasImage, initial),
                )
              : _buildImageContent(hasImage, initial),
        ),
      ),
    );
  }

  Widget _buildImageContent(bool hasImage, String initial) {
    if (hasImage) {
      if (_cachedFile != null) {
        return Image.file(
          _cachedFile!,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
        );
      }

      return Image.network(
        widget.imageUrl!.trim(),
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(
              color: AppConfig.brandLime,
              strokeWidth: 2.5,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) =>
            _buildFallbackInitial(initial),
      );
    }

    return _buildFallbackInitial(initial);
  }

  Widget _buildFallbackInitial(String initial) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 80,
          backgroundColor: AppConfig.brandDark,
          child: Text(
            initial,
            style: const TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'No profile photo set',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
