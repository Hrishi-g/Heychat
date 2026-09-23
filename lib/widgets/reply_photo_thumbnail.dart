import 'dart:io';
import 'package:flutter/material.dart';
import '../services/avatar_cache_service.dart';

/// ReplyPhotoThumbnail renders a neat square thumbnail for replied photos
/// in the reply preview banner and inside chat bubbles.
class ReplyPhotoThumbnail extends StatefulWidget {
  final String imageUrl;
  final double size;

  const ReplyPhotoThumbnail({
    super.key,
    required this.imageUrl,
    this.size = 40.0,
  });

  @override
  State<ReplyPhotoThumbnail> createState() => _ReplyPhotoThumbnailState();
}

class _ReplyPhotoThumbnailState extends State<ReplyPhotoThumbnail> {
  File? _localFile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ReplyPhotoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _load();
    }
  }

  Future<void> _load() async {
    final key = widget.imageUrl.trim();
    if (key.isEmpty || key == '📷 Photo') return;

    final cached = await AvatarCacheService.instance.getCachedFile(key);
    if (mounted && cached != null) {
      setState(() => _localFile = cached);
      return;
    }

    if (key.startsWith('http')) {
      final downloaded = await AvatarCacheService.instance.cacheUrl(key);
      if (mounted && downloaded != null) {
        setState(() => _localFile = downloaded);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: widget.size,
        height: widget.size,
        color: Colors.grey.shade300,
        child: _localFile != null
            ? Image.file(
                _localFile!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(),
              )
            : (widget.imageUrl.startsWith('http')
                ? Image.network(
                    widget.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallback(),
                    loadingBuilder: (c, w, p) => p == null ? w : _fallback(),
                  )
                : _fallback()),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: Colors.grey.shade400,
      child: Center(
        child: Icon(
          Icons.image_rounded,
          size: widget.size * 0.55,
          color: Colors.white70,
        ),
      ),
    );
  }
}
