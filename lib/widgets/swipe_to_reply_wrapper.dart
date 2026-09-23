import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_config.dart';

/// SwipeToReplyWrapper provides WhatsApp-style horizontal swipe gesture
/// to reply (right swipe) or select multiple messages (left swipe).
class SwipeToReplyWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final VoidCallback? onSelect;

  const SwipeToReplyWrapper({
    super.key,
    required this.child,
    required this.onReply,
    this.onSelect,
  });

  @override
  State<SwipeToReplyWrapper> createState() => _SwipeToReplyWrapperState();
}

class _SwipeToReplyWrapperState extends State<SwipeToReplyWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _dragOffset = 0.0;
  bool _thresholdReached = false;
  bool _isLeftSwipe = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _animation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0.0;
    if (_dragOffset > 0 || (_dragOffset == 0 && delta > 0)) {
      setState(() {
        _dragOffset = (_dragOffset + delta).clamp(0.0, 72.0);
        if (_dragOffset >= 46.0 && !_thresholdReached) {
          _thresholdReached = true;
          _isLeftSwipe = false;
          HapticFeedback.lightImpact();
        }
      });
    } else if (widget.onSelect != null &&
        (_dragOffset < 0 || (_dragOffset == 0 && delta < 0))) {
      setState(() {
        _dragOffset = (_dragOffset + delta).clamp(-72.0, 0.0);
        if (_dragOffset <= -46.0 && !_thresholdReached) {
          _thresholdReached = true;
          _isLeftSwipe = true;
          HapticFeedback.lightImpact();
        }
      });
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_thresholdReached) {
      if (_isLeftSwipe) {
        widget.onSelect?.call();
      } else {
        widget.onReply();
      }
    }
    _thresholdReached = false;
    _isLeftSwipe = false;
    _animation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _dragOffset = 0.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final rightProgress = (_dragOffset / 46.0).clamp(0.0, 1.0);
    final leftProgress = (-_dragOffset / 46.0).clamp(0.0, 1.0);

    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Right swipe (Reply) indicator on left
          if (_dragOffset > 0)
            Positioned(
              left: 12,
              child: Opacity(
                opacity: rightProgress,
                child: Transform.scale(
                  scale: 0.65 + (0.35 * rightProgress),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppConfig.brandLimeDark.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              AppConfig.brandLimeDark.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.reply_rounded,
                          color: AppConfig.brandDark,
                          size: 16,
                        ),
                        if (_thresholdReached && !_isLeftSwipe) ...[
                          const SizedBox(width: 4),
                          const Text(
                            'Reply',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: AppConfig.brandDark,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Left swipe (Multi-Select) indicator on right
          if (_dragOffset < 0)
            Positioned(
              right: 12,
              child: Opacity(
                opacity: leftProgress,
                child: Transform.scale(
                  scale: 0.65 + (0.35 * leftProgress),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppConfig.brandLime,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppConfig.brandLimeDark.withValues(alpha: 0.50),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              AppConfig.brandLimeDark.withValues(alpha: 0.20),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppConfig.brandDark,
                          size: 16,
                        ),
                        if (_thresholdReached && _isLeftSwipe) ...[
                          const SizedBox(width: 4),
                          const Text(
                            'Select',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: AppConfig.brandDark,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Child message bubble that translates horizontally and springs back
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final currentOffset =
                  _controller.isAnimating ? _animation.value : _dragOffset;
              return Transform.translate(
                offset: Offset(currentOffset, 0),
                child: child,
              );
            },
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
