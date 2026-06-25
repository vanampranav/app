import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elefit_app/features/challenge/domain/services/auth_service.dart';
import '../../screens/admin/admin_access_denied_screen.dart';

class AdminGuard extends StatelessWidget {
  final Widget child;

  const AdminGuard({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        if (authService.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (authService.isUserAdmin) {
          return child;
        }

        return const AdminAccessDeniedScreen();
      },
    );
  }
}
