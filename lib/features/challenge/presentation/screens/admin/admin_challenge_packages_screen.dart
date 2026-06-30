import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/widgets/ef_error_components.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_package.dart';
import 'package:elefit_app/features/challenge/domain/services/challenge_package_service.dart';
import 'package:elefit_app/features/challenge/domain/services/admin_audit_service.dart';
import 'package:elefit_app/features/challenge/domain/services/auth_service.dart';
import 'package:elefit_app/features/challenge/presentation/providers/admin_challenge_packages_provider.dart';
import 'package:elefit_app/features/challenge/presentation/screens/admin/admin_create_edit_package_screen.dart';
import 'package:elefit_app/features/challenge/presentation/widgets/admin/admin_guard.dart';

class AdminChallengePackagesScreen extends StatelessWidget {
  final String challengeId;

  const AdminChallengePackagesScreen({Key? key, required this.challengeId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      child: ChangeNotifierProvider(
        create: (ctx) => AdminChallengePackagesProvider(
          challengeId: challengeId,
          packageService: ctx.read<ChallengePackageService>(),
          auditService: ctx.read<AdminAuditService>(),
        ),
        child: const _AdminChallengePackagesContent(),
      ),
    );
  }
}

class _AdminChallengePackagesContent extends StatelessWidget {
  const _AdminChallengePackagesContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminChallengePackagesProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppTheme.bg,
          appBar: AppBar(
            title: const Text('Challenge Packages', style: AppTheme.headingMD),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: const BackButton(color: AppTheme.textPrimary),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminCreateEditPackageScreen(
                  challengeId: provider.challengeId,
                ),
              ),
            ).then((_) => provider.fetchPackages()),
            backgroundColor: AppTheme.lime,
            child: const Icon(Icons.add, color: Colors.black),
          ),
          body: provider.isLoading
              ? const EFLoadingStateView(message: 'Loading packages...')
              : provider.errorMessage != null
                  ? _buildErrorState(context, provider)
                  : provider.packages.isEmpty
                      ? const EFEmptyStateView(
                          title: 'No Packages',
                          message: 'No packages configured for this challenge.',
                          icon: Icons.inventory_2_outlined,
                        )
                      : _buildPackageList(context, provider),
        );
      },
    );
  }

  Widget _buildPackageList(BuildContext context, AdminChallengePackagesProvider provider) {
    final adminId = context.read<AuthService>().currentUser?.id ?? '';

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: provider.packages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (ctx, i) {
        final package = provider.packages[i];
        return _PackageAdminCard(
          package: package,
          onEdit: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminCreateEditPackageScreen(
                challengeId: provider.challengeId,
                existingPackage: package,
              ),
            ),
          ).then((_) => provider.fetchPackages()),
          onToggleStatus: () => provider.togglePackageStatus(package, adminId),
          isActionInProgress: provider.isActionInProgress,
        );
      },
    );
  }

  Widget _buildErrorState(BuildContext context, AdminChallengePackagesProvider provider) {
    return EFErrorView.map(
      provider.errorMessage!,
      screenName: 'AdminChallengePackagesScreen',
      featureName: 'ChallengePackageManagement',
      onRetry: () => provider.fetchPackages(),
    );
  }
}

class _PackageAdminCard extends StatelessWidget {
  final ChallengePackage package;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final bool isActionInProgress;

  const _PackageAdminCard({
    required this.package,
    required this.onEdit,
    required this.onToggleStatus,
    required this.isActionInProgress,
  });

  @override
  Widget build(BuildContext context) {
    return EFCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(package.name, style: AppTheme.headingSM),
              ),
              _StatusBadge(isActive: package.isActive),
            ],
          ),
          const SizedBox(height: 8),
          Text(package.description, style: AppTheme.bodySM, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Order: ${package.displayOrder}', style: AppTheme.labelMD.copyWith(color: AppTheme.textTertiary)),
              const Spacer(),
              Text('${package.packagePrice.toStringAsFixed(0)} ${package.currency}', 
                  style: AppTheme.numericMD.copyWith(color: AppTheme.lime, fontSize: 18)),
            ],
          ),
          const Divider(height: 24, color: Colors.white10),
          Row(
            children: [
              EFButton(
                label: 'Edit',
                onTap: onEdit,
                variant: EFButtonVariant.secondary,
                height: 36,
                fullWidth: false,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              const SizedBox(width: 8),
              EFButton(
                label: package.isActive ? 'Deactivate' : 'Activate',
                onTap: isActionInProgress ? null : onToggleStatus,
                variant: package.isActive ? EFButtonVariant.danger : EFButtonVariant.primary,
                height: 36,
                fullWidth: false,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isActive ? AppTheme.lime : Colors.grey).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: (isActive ? AppTheme.lime : Colors.grey).withValues(alpha: 0.3)),
      ),
      child: Text(
        isActive ? 'ACTIVE' : 'INACTIVE',
        style: TextStyle(color: isActive ? AppTheme.lime : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
