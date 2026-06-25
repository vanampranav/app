import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/features/challenge/presentation/providers/notification_provider.dart';
import 'package:elefit_app/features/challenge/presentation/screens/participant/notification_center_screen.dart';

class NotificationBellIcon extends StatelessWidget {
  const NotificationBellIcon({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        final count = provider.unreadCount;
        final hasUnread = count > 0;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.surface1,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Badge(
              isLabelVisible: hasUnread,
              label: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                ),
              ),
              backgroundColor: AppTheme.lime,
              child: const Icon(
                Icons.notifications_outlined,
                color: AppTheme.textPrimary,
                size: 20,
              ),
            ),
          ),
        );
      },
    );
  }
}
