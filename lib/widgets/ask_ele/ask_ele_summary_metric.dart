import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AskEleSummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const AskEleSummaryMetric({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.sm,
          vertical: AppTheme.sm,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 13, color: AppTheme.lime),
                const SizedBox(width: 4),
                Text(
                  label.toUpperCase(),
                  style: AppTheme.labelSM.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.0,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.headingSM.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
