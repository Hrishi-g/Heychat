import 'dart:io';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/avatar_cache_service.dart';

/// CachedAvatar renders a circular profile avatar that pulls from local disk cache
/// first for zero-latency loading, falling back to network and caching locally,
/// or displaying a capitalized initial badge.
class CachedAvatar extends StatefulWidget {
  final String? imgUrl;
  final String name;
  final Color backgroundColor;
  final double radius;
  final double fontSize;
  final VoidCallback? onTap;

  const CachedAvatar({
    super.key,
    required this.imgUrl,
    required this.name,
    this.backgroundColor = AppConfig.brandDark,
    this.radius = 24,
    this.fontSize = 18,
    this.onTap,
  });

  @override
  State<CachedAvatar> createState() => _CachedAvatarState();
}

class _CachedAvatarState extends State<CachedAvatar> {
  File? _cachedFile;

  @override
  void initState() {
    super.initState();
    _resolveAvatar();
  }

  @override
  void didUpdateWidget(covariant CachedAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imgUrl != widget.imgUrl) {
      _resolveAvatar();
    }
  }

  Future<void> _resolveAvatar() async {
    final url = widget.imgUrl?.trim();
    if (url == null || url.isEmpty) {
      if (mounted) setState(() => _cachedFile = null);
      return;
    }

    // 1. Check local file cache
    final local = await AvatarCacheService.instance.getCachedFile(url);
    if (mounted && local != null) {
      setState(() => _cachedFile = local);
      return;
    }

    // 2. Download and save to cache in background
    final downloaded = await AvatarCacheService.instance.cacheUrl(url);
    if (mounted && downloaded != null) {
      setState(() => _cachedFile = downloaded);
    }
  }

  Widget _buildInitial() {
    final cleanName = widget.name.trim();
    final initial = cleanName.isNotEmpty ? cleanName[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.backgroundColor,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: widget.fontSize,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget avatarWidget;
    final cleanUrl = widget.imgUrl?.trim();

    if (cleanUrl != null && cleanUrl.isNotEmpty) {
      if (_cachedFile != null) {
        avatarWidget = SizedBox(
          width: widget.radius * 2,
          height: widget.radius * 2,
          child: ClipOval(
            child: Image.file(
              _cachedFile!,
              width: widget.radius * 2,
              height: widget.radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildInitial(),
            ),
          ),
        );
      } else {
        avatarWidget = SizedBox(
          width: widget.radius * 2,
          height: widget.radius * 2,
          child: ClipOval(
            child: Image.network(
              cleanUrl,
              width: widget.radius * 2,
              height: widget.radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildInitial(),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return _buildInitial();
              },
            ),
          ),
        );
      }
    } else {
      avatarWidget = _buildInitial();
    }

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: widget.onTap,
        child: avatarWidget,
      );
    }

    return avatarWidget;
  }
}
