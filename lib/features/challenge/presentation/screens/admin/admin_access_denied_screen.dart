import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/features/challenge/domain/services/auth_service.dart';

class AdminAccessDeniedScreen extends StatefulWidget {
  const AdminAccessDeniedScreen({Key? key}) : super(key: key);

  @override
  State<AdminAccessDeniedScreen> createState() => _AdminAccessDeniedScreenState();
}

class _AdminAccessDeniedScreenState extends State<AdminAccessDeniedScreen> {
  bool _isRefreshing = false;

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppTheme.textPrimary),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_person_rounded,
              size: 80,
              color: AppTheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Access Denied',
              style: AppTheme.headingLG,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'You do not have the required permissions to access this administrative area. If you recently gained admin access, try logging out and logging back in to sync your credentials.',
              style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (user == null)
              Text(
                'Status: Not signed into Firebase SDK.',
                style: AppTheme.bodySM.copyWith(color: AppTheme.error),
                textAlign: TextAlign.center,
              )
            else
              Text(
                'Signed in as: ${user.email}\nUID: ${user.id}\nAdmin: ${user.isAdmin}, Role: ${user.role}',
                style: AppTheme.bodySM.copyWith(color: AppTheme.textTertiary),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 40),
            EFButton(
              label: _isRefreshing ? 'Refreshing...' : 'Refresh Permissions',
              loading: _isRefreshing,
              onTap: () async {
                setState(() => _isRefreshing = true);
                await context.read<AuthService>().refreshProfile();
                if (mounted) {
                  setState(() => _isRefreshing = false);
                  // If they are now admin, the AdminGuard will automatically rebuild and show the content
                }
              },
            ),
            const SizedBox(height: 12),
            EFButton(
              label: 'Go Home',
              variant: EFButtonVariant.ghost,
              onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
            ),
          ],
        ),
      ),
    );
  }
}
