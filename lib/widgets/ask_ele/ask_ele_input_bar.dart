import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AskEleInputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onMicTap;
  final bool isLoading;
  final bool isListening;

  const AskEleInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.onMicTap,
    this.isLoading = false,
    this.isListening = false,
  });

  @override
  State<AskEleInputBar> createState() => _AskEleInputBarState();
}

class _AskEleInputBarState extends State<AskEleInputBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );

    if (widget.isListening) {
      _animCtrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AskEleInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !_animCtrl.isAnimating) {
      _animCtrl.repeat(reverse: true);
    } else if (!widget.isListening && _animCtrl.isAnimating) {
      _animCtrl.stop();
      _animCtrl.reset();
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.md,
        vertical: AppTheme.sm,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isListening) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.lime,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Listening...',
                      style: AppTheme.bodySM.copyWith(
                        color: AppTheme.lime,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Microphone Action Button
                if (widget.onMicTap != null) ...[
                  GestureDetector(
                    onTap: widget.isLoading ? null : widget.onMicTap,
                    child: ScaleTransition(
                      scale: widget.isListening
                          ? _pulseScale
                          : const AlwaysStoppedAnimation(1.0),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: widget.isListening
                              ? AppTheme.lime
                              : AppTheme.surface2,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.isListening
                                ? AppTheme.lime
                                : Colors.white.withValues(alpha: 0.15),
                          ),
                          boxShadow: widget.isListening
                              ? AppTheme.shadowLime
                              : null,
                        ),
                        child: Icon(
                          widget.isListening
                              ? Icons.mic_rounded
                              : Icons.mic_none_rounded,
                          color: widget.isListening
                              ? Colors.black
                              : AppTheme.lime,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.sm),
                ],

                // Input Text Field
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface2,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusXl),
                      border: Border.all(
                        color: widget.isListening
                            ? AppTheme.lime.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: TextField(
                      controller: widget.controller,
                      minLines: 1,
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      style: AppTheme.bodyMD
                          .copyWith(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: widget.isListening
                            ? 'Listening...'
                            : 'Ask Ele anything...',
                        hintStyle: AppTheme.bodyMD.copyWith(
                          color: widget.isListening
                              ? AppTheme.lime
                              : AppTheme.textSecondary,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.md,
                          vertical: 10,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.sm),

                // Send Action Button
                GestureDetector(
                  onTap: widget.isLoading ? null : widget.onSend,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.lime,
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.shadowLime,
                    ),
                    child: Center(
                      child: widget.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(
                              Icons.auto_awesome_rounded,
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
    );
  }
}
