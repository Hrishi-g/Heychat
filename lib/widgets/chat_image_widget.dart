import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/message_model.dart';
import '../screens/full_screen_image_screen.dart';
import '../services/avatar_cache_service.dart';

/// ChatImageWidget renders a square-shaped chat image bubble with:
/// - Immediate blurred placeholder + loading spinner during async upload
/// - Crisp high-res image once uploaded / received
/// - On tap opens full-screen photo viewer with pinch-to-zoom
class ChatImageWidget extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  final String contactName;
  final String contactMblNo;

  const ChatImageWidget({
    super.key,
    required this.message,
    required this.isMe,
    required this.contactName,
    required this.contactMblNo,
  });

  @override
  State<ChatImageWidget> createState() => _ChatImageWidgetState();
}

class _ChatImageWidgetState extends State<ChatImageWidget> {
  File? _localFile;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant ChatImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.message != widget.message.message ||
        oldWidget.message.status != widget.message.status) {
      _resolveImage();
    }
  }

  Future<void> _resolveImage() async {
    final key = widget.message.message.trim();
    if (key.isEmpty) return;

    // 1. Check local cache
    final local = await AvatarCacheService.instance.getCachedFile(key);
    if (mounted && local != null) {
      setState(() => _localFile = local);
      return;
    }

    // 2. If it's a remote URL, download and cache in background
    if (key.startsWith('http')) {
      final downloaded = await AvatarCacheService.instance.cacheUrl(key);
      if (mounted && downloaded != null) {
        setState(() => _localFile = downloaded);
      }
    }
  }

  Widget _buildStatusIcon() {
    if (!widget.isMe) return const SizedBox.shrink();

    switch (widget.message.status) {
      case 'READ':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF06B6D4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.90),
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 2.5),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF06B6D4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.90),
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ],
        );
      case 'DELIVERED':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 4.5,
              height: 4.5,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white70,
              ),
            ),
            const SizedBox(width: 2.5),
            Container(
              width: 4.5,
              height: 4.5,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white70,
              ),
            ),
          ],
        );
      case 'FAILED':
        return const Icon(Icons.error_outline_rounded,
            size: 14, color: Colors.redAccent);
      case 'SENT':
        return Container(
          width: 4.5,
          height: 4.5,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white70,
          ),
        );
      case 'UPLOADING':
      default:
        return Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white70,
              width: 1.0,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUploading = widget.message.status == 'UPLOADING';
    final isFailed = widget.message.status == 'FAILED';
    final timeStr = DateFormat('hh:mm a').format(
      DateTime.fromMillisecondsSinceEpoch(widget.message.timeStamp),
    );

    const double squareSize = 230.0;

    return GestureDetector(
      onTap: () {
        if (!isUploading && !isFailed) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FullScreenImageScreen(
                imageUrl: widget.message.message,
                userName: widget.isMe ? 'You' : widget.contactName,
                phoneNumber: widget.contactMblNo,
                showChatButton: false,
              ),
            ),
          );
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: squareSize,
          height: squareSize,
          color: Colors.grey.shade900,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Image Content (blurred if uploading, crisp when ready)
              if (isUploading || isFailed)
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: _buildRawImage(),
                )
              else
                _buildRawImage(),

              // 2. Loading Spinner Overlay when Uploading
              if (isUploading)
                Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.8,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
                  ),
                ),

              // 3. Retry Overlay when Upload Failed
              if (isFailed)
                Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.refresh_rounded,
                            color: Colors.white, size: 32),
                        SizedBox(height: 4),
                        Text(
                          'Upload failed',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 4. Timestamp & Status Badge Overlay on Bottom Right
              Positioned(
                bottom: 6,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (widget.isMe) ...[
                        const SizedBox(width: 4),
                        _buildStatusIcon(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRawImage() {
    if (_localFile != null) {
      return Image.file(
        _localFile!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    }

    final url = widget.message.message.trim();
    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _buildFallback(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _buildFallback();
        },
      );
    }

    return _buildFallback();
  }

  Widget _buildFallback() {
    return Container(
      color: Colors.grey.shade800,
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: Colors.white38,
          size: 44,
        ),
      ),
    );
  }
}
