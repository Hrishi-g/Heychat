import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/message_model.dart';
import '../providers/chat_provider.dart';
import '../screens/full_screen_image_screen.dart';
import '../services/avatar_cache_service.dart';
import '../services/media_storage_service.dart';

/// ChatImageWidget renders a square-shaped chat image bubble with:
/// - Immediate local file rendering if available in device storage (Pictures/HeyChat)
/// - Download overlay button if deleted from gallery or not downloaded yet
/// - Auto-redownload from Cloudflare R2 on button tap and rewrite local path to SQLite
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
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant ChatImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.localImageUrl != widget.message.localImageUrl ||
        oldWidget.message.cloudImageUrl != widget.message.cloudImageUrl ||
        oldWidget.message.message != widget.message.message ||
        oldWidget.message.status != widget.message.status) {
      _resolveImage();
    }
  }

  Future<void> _resolveImage() async {
    final localPath = widget.message.localImageUrl;
    if (MediaStorageService.instance.isFileAvailable(localPath)) {
      if (mounted) {
        setState(() {
          _localFile = File(localPath!);
          _isDownloading = false;
        });
      }
      return;
    }

    // Check disk avatar cache fallback
    final cloudUrl = widget.message.cloudImageUrl ?? widget.message.message;
    if (cloudUrl.trim().startsWith('http')) {
      final cached = await AvatarCacheService.instance.getCachedFile(cloudUrl);
      if (mounted && cached != null && cached.existsSync()) {
        setState(() {
          _localFile = cached;
          _isDownloading = false;
        });
        return;
      }
    }

    if (mounted) {
      setState(() {
        _localFile = null;
        _isDownloading = false;
      });
    }
  }

  Future<void> _handleDownload() async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
    });

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final success =
        await chatProvider.downloadAndSaveImageMessage(widget.message);

    if (mounted) {
      setState(() {
        _isDownloading = false;
      });
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download image from cloud')),
        );
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
    final isLocalAvailable = _localFile != null;
    final targetUrl = widget.message.cloudImageUrl ?? widget.message.message;

    final timeStr = DateFormat('hh:mm a').format(
      DateTime.fromMillisecondsSinceEpoch(widget.message.timeStamp),
    );

    const double squareSize = 230.0;

    return GestureDetector(
      onTap: () {
        if (isLocalAvailable && !isUploading && !isFailed) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FullScreenImageScreen(
                imageUrl: targetUrl,
                userName: widget.isMe ? 'You' : widget.contactName,
                phoneNumber: widget.contactMblNo,
                showChatButton: false,
              ),
            ),
          );
        } else if (!isLocalAvailable && !isUploading && !isFailed) {
          _handleDownload();
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
              // 1. Image Content (File if available, blurred placeholder if missing)
              if (isLocalAvailable)
                Image.file(
                  _localFile!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => _buildFallback(),
                )
              else if (targetUrl.startsWith('http'))
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Image.network(
                    targetUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) => _buildFallback(),
                  ),
                )
              else
                _buildFallback(),

              // 2. Uploading Overlay
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
                          color: Color(0xFFD4F933),
                        ),
                      ),
                    ),
                  ),
                ),

              // 3. Download Button Overlay (when image file is missing locally or deleted from gallery)
              if (!isLocalAvailable && !isUploading && !isFailed)
                Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  child: Center(
                    child: _isDownloading
                        ? Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.70),
                              shape: BoxShape.circle,
                            ),
                            child: const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.8,
                                color: Color(0xFFD4F933),
                              ),
                            ),
                          )
                        : GestureDetector(
                            onTap: _handleDownload,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.70),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.download_for_offline_rounded,
                                    color: Color(0xFFD4F933),
                                    size: 22,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Download',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),

              // 4. Retry Overlay when Upload Failed
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

              // 5. Timestamp & Status Badge Overlay on Bottom Right
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
