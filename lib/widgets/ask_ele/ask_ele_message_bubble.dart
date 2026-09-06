import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AskEleMessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const AskEleMessageBubble({
    super.key,
    required this.text,
    required this.isUser,
  });

  String _cleanFormattedText(String raw) {
    if (isUser) return raw;
    var cleaned = raw;
    cleaned = cleaned.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'__([^_]+)__'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'_([^_]+)_'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '');
    cleaned = cleaned.replaceAll('`', '');
    return cleaned.trim();
  }

  @override
  Widget build(BuildContext context) {
    final displayText = _cleanFormattedText(text);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.purple,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.lime.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppTheme.lime,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? AppTheme.lime.withValues(alpha: 0.18)
                    : AppTheme.surface1,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppTheme.radiusLg),
                  topRight: const Radius.circular(AppTheme.radiusLg),
                  bottomLeft: Radius.circular(
                    isUser ? AppTheme.radiusLg : AppTheme.radiusSm,
                  ),
                  bottomRight: Radius.circular(
                    isUser ? AppTheme.radiusSm : AppTheme.radiusLg,
                  ),
                ),
                border: Border.all(
                  color: isUser
                      ? AppTheme.lime.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Text(
                displayText,
                style: AppTheme.bodyMD.copyWith(
                  color: AppTheme.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
