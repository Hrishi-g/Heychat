import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_config.dart';
import '../models/message_model.dart';
import '../providers/chat_provider.dart';
import 'chat_image_widget.dart';
import 'reply_photo_thumbnail.dart';

/// ChatBubble renders a modern glassmorphic message bubble in app-brand yellow/lime/green shades.
/// Features tight content-hugging width/height and custom geometric dot status indicators.
class ChatBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final String? contactName;
  final String? contactMblNo;
  final String? currentMblNo;
  final bool isHighlighted;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onReplyTap;
  final VoidCallback? onTap;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.contactName,
    this.contactMblNo,
    this.currentMblNo,
    this.isHighlighted = false,
    this.isSelected = false,
    this.onLongPress,
    this.onReplyTap,
    this.onTap,
  });

  static bool _isImageText(String text) {
    final t = text.trim();
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

  /// Modern custom geometric dot status indicator (0% WhatsApp tick marks)
  /// - READ: Dual glowing neon cyan dots
  /// - DELIVERED: Dual solid charcoal dots
  /// - SENT: Single solid charcoal dot
  /// - UPLOADING: Single outline ring dot
  Widget _buildStatusIcon() {
    if (!isMe || message.isDeletedForEveryone) return const SizedBox.shrink();

    switch (message.status) {
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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(width: 2.5),
            Container(
              width: 4.5,
              height: 4.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
          ],
        );
      case 'SENT':
        return Container(
          width: 4.5,
          height: 4.5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.45),
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
              color: Colors.black.withValues(alpha: 0.45),
              width: 1.0,
            ),
          ),
        );
    }
  }

  Widget _buildReplyQuote(BuildContext context) {
    final isRepliedMe = currentMblNo != null &&
        message.replyToSender != null &&
        ChatProvider.isSameUser(message.replyToSender!, currentMblNo!);
    final senderTitle = isRepliedMe
        ? 'You'
        : (contactName ?? message.replyToSender ?? 'Message');

    final rawReply = message.replyToText ?? '';
    final isReplyImg = _isImageText(rawReply);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onReplyTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.fromLTRB(9, 5, 9, 5),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.black.withValues(alpha: 0.07)
              : AppConfig.brandLimeDark.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMe
                ? Colors.black.withValues(alpha: 0.09)
                : AppConfig.brandLimeDark.withValues(alpha: 0.12),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(3.5),
              decoration: BoxDecoration(
                color: AppConfig.brandLimeDark.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.reply_rounded,
                size: 12,
                color: AppConfig.brandLimeDark,
              ),
            ),
            const SizedBox(width: 7),
            Flexible(
              fit: FlexFit.loose,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    senderTitle,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppConfig.brandLimeDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  if (isReplyImg)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.camera_alt_rounded,
                          size: 11,
                          color: Colors.black54,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'Photo',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      rawReply,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.black.withValues(alpha: 0.80),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (isReplyImg) ...[
              const SizedBox(width: 6),
              ReplyPhotoThumbnail(
                imageUrl: rawReply,
                size: 30,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('hh:mm a').format(
      DateTime.fromMillisecondsSinceEpoch(message.timeStamp),
    );

    final isDeleted = message.isDeletedForEveryone;
    final isImage = !isDeleted &&
        (message.type == 'IMAGE' ||
            message.message.startsWith('local_img_') ||
            (message.message.startsWith('http') &&
                (message.message.contains('/uploads/') ||
                    message.message.contains('.r2.dev') ||
                    message.message.endsWith('.jpg') ||
                    message.message.endsWith('.jpeg') ||
                    message.message.endsWith('.png') ||
                    message.message.endsWith('.webp') ||
                    message.message.endsWith('.gif'))));

    final hasReply = !isDeleted &&
        message.replyToText != null &&
        message.replyToText!.trim().isNotEmpty;

    final bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
      bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            borderRadius: bubbleRadius,
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? const Color(0xFF536B00).withValues(alpha: 0.45)
                    : (isHighlighted
                        ? AppConfig.brandLime.withValues(alpha: 0.60)
                        : (isMe
                            ? const Color(0xFF536B00).withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.06))),
                blurRadius: isSelected || isHighlighted ? 14 : 10,
                spreadRadius: isSelected ? 2 : 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: bubbleRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: isImage && !hasReply
                    ? const EdgeInsets.all(3.5)
                    : const EdgeInsets.fromLTRB(12, 9, 12, 7),
                decoration: BoxDecoration(
                  gradient: isHighlighted
                      ? const LinearGradient(
                          colors: [
                            Color(0xFFBEF264),
                            Color(0xFF84CC16),
                          ],
                        )
                      : (isDeleted
                          ? null
                          : (isMe
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFFD4F933), // Vibrant Brand Lime
                                    Color(0xFFA3E635), // Fresh Green Lime
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null)),
                  color: isHighlighted
                      ? null
                      : (isDeleted
                          ? (isMe
                              ? AppConfig.sentBubbleGreen.withValues(alpha: 0.6)
                              : Colors.grey.shade200)
                          : (isMe
                              ? null
                              : Colors.white.withValues(alpha: 0.85))),
                  borderRadius: bubbleRadius,
                  border: Border.all(
                    color: isSelected
                        ? AppConfig.brandLimeDark
                        : (isMe
                            ? Colors.white.withValues(alpha: 0.60)
                            : Colors.white.withValues(alpha: 0.90)),
                    width: isSelected ? 2.2 : 1.0,
                  ),
                ),
                child: IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasReply) _buildReplyQuote(context),
                      if (isImage)
                        ChatImageWidget(
                          message: message,
                          isMe: isMe,
                          contactName: contactName ?? '',
                          contactMblNo: contactMblNo ?? '',
                        )
                      else ...[
                        if (isDeleted)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.do_not_disturb_alt_rounded,
                                size: 15,
                                color: Colors.black45,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'This message was deleted',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          )
                        else ...[
                          Text(
                            message.message,
                            style: const TextStyle(
                              fontSize: 14.5,
                              height: 1.35,
                              color: Color(0xFF1A1D20),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (message.isEdited) ...[
                                  const Text(
                                    'edited',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.black45,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                ],
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: isMe
                                        ? Colors.black54
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 4),
                                  _buildStatusIcon(),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
