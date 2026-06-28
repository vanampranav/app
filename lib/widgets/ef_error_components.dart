import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'ef_components.dart';

class EFErrorView extends StatelessWidget {
  final String title;
  final String message;
  final String? technicalCode;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;
  final VoidCallback? onContactSupport;

  const EFErrorView({
    Key? key,
    required this.title,
    required this.message,
    this.technicalCode,
    this.onRetry,
    this.onBack,
    this.onContactSupport,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 48),
            ),
            const SizedBox(height: 24),
            Text(title, style: AppTheme.headingLG, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              message,
              style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (technicalCode != null) ...[
              const SizedBox(height: 16),
              Text(
                'Error Code: $technicalCode',
                style: AppTheme.labelSM.copyWith(color: AppTheme.textTertiary),
              ),
            ],
            const SizedBox(height: 40),
            if (onRetry != null)
              EFButton(
                label: 'Try Again',
                onTap: onRetry,
                fullWidth: true,
              ),
            if (onBack != null) ...[
              const SizedBox(height: 12),
              EFButton(
                label: 'Go Back',
                onTap: onBack,
                variant: EFButtonVariant.secondary,
                fullWidth: true,
              ),
            ],
            if (onContactSupport != null) ...[
              const SizedBox(height: 12),
              EFButton(
                label: 'Contact Support',
                onTap: onContactSupport,
                variant: EFButtonVariant.ghost,
                fullWidth: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EFEmptyStateView extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  const EFEmptyStateView({
    Key? key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.action,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.textTertiary, size: 64),
            const SizedBox(height: 24),
            Text(title, style: AppTheme.headingSM, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              message,
              style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 32),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class EFLoadingStateView extends StatelessWidget {
  final String? message;

  const EFLoadingStateView({Key? key, this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.lime),
          if (message != null) ...[
            const SizedBox(height: 24),
            Text(message!, style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary)),
          ],
        ],
      ),
    );
  }
}

class EFRetryButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const EFRetryButton({
    Key? key,
    required this.onTap,
    this.label = 'Retry',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return EFButton(
      label: label,
      onTap: onTap,
      variant: EFButtonVariant.secondary,
      height: 44,
      fullWidth: false,
      padding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
}
