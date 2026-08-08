import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/widgets/ef_error_components.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_package.dart';
import 'package:elefit_app/features/challenge/domain/services/challenge_package_service.dart';
import 'package:elefit_app/features/challenge/presentation/providers/challenge_package_provider.dart';
import 'package:elefit_app/services/analytics_service.dart';
import 'package:elefit_app/features/challenge/domain/services/auth_service.dart';

class ChallengePackageSelectionScreen extends StatelessWidget {
  final String challengeId;
  final Function(ChallengePackage) onPackageSelected;

  const ChallengePackageSelectionScreen({
    Key? key,
    required this.challengeId,
    required this.onPackageSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => ChallengePackageProvider(
        challengeId: challengeId,
        packageService: ctx.read<ChallengePackageService>(),
      ),
      child: _ChallengePackageSelectionContent(onPackageSelected: onPackageSelected),
    );
  }
}

class _ChallengePackageSelectionContent extends StatefulWidget {
  final Function(ChallengePackage) onPackageSelected;

  const _ChallengePackageSelectionContent({
    Key? key,
    required this.onPackageSelected,
  }) : super(key: key);

  @override
  State<_ChallengePackageSelectionContent> createState() => _ChallengePackageSelectionContentState();
}

class _ChallengePackageSelectionContentState extends State<_ChallengePackageSelectionContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsService.logEvent('challenge_package_screen_viewed', {'challenge_id': context.read<ChallengePackageProvider>().challengeId});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChallengePackageProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppTheme.bg,
          appBar: AppBar(
            title: const Text('Select Package', style: AppTheme.headingMD),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: const BackButton(color: AppTheme.textPrimary),
          ),
          body: provider.isLoading
              ? const EFLoadingStateView(message: 'Loading packages...')
              : provider.errorMessage != null
                  ? _buildErrorState(context, provider)
                  : provider.packages.isEmpty
                      ? const EFEmptyStateView(
                          title: 'No Packages',
                          message: 'No active packages available for this challenge.',
                          icon: Icons.inventory_2_outlined,
                        )
                      : _buildPackageList(context, provider),
          bottomNavigationBar: _buildBottomAction(context, provider),
        );
      },
    );
  }

  Widget _buildPackageList(BuildContext context, ChallengePackageProvider provider) {
    return Column(
      children: [
        _buildInstructionBanner(),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            itemCount: provider.packages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (ctx, i) {
              final package = provider.packages[i];
              final isSelected = provider.selectedPackage?.id == package.id;

              return _PackageCard(
                package: package,
                isSelected: isSelected,
                onTap: () => provider.selectPackage(package),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lime.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.lime.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppTheme.lime, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Select one package for this challenge — tap it and a check mark '
              'appears on the right. Then tap Continue at the bottom to join.',
              style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context, ChallengePackageProvider provider) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: EFButton(
          label: 'Continue',
          onTap: provider.selectedPackage == null
              ? null
              : () {
                  final pkg = provider.selectedPackage!;
                  AnalyticsService.logPackageSelected(
                    challengeId: provider.challengeId,
                    packageType: pkg.id,
                    price: pkg.packagePrice,
                    currency: pkg.currency,
                  );
                  widget.onPackageSelected(pkg);
                },
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, ChallengePackageProvider provider) {
    final userId = context.read<AuthService>().currentUser?.id;

    return EFErrorView.map(
      provider.errorMessage!,
      screenName: 'ChallengePackageSelectionScreen',
      featureName: 'ChallengeEnrollment',
      userId: userId,
      onRetry: () => provider.retry(),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final ChallengePackage package;
  final bool isSelected;
  final VoidCallback onTap;

  const _PackageCard({
    Key? key,
    required this.package,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return EFCard(
      onTap: onTap,
      color: isSelected ? AppTheme.lime.withValues(alpha: 0.05) : AppTheme.surface1,
      hasBorder: true,
      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  package.name,
                  style: AppTheme.headingSM.copyWith(color: isSelected ? AppTheme.lime : AppTheme.textPrimary),
                ),
              ),
              const SizedBox(width: 12),
              // Always-visible selection checkbox: empty circle when unselected,
              // filled check when selected, so it's clear the card is selectable.
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                color: isSelected ? AppTheme.lime : AppTheme.textTertiary,
                size: 26,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            package.description,
            style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          if (package.shopifyVariants.isNotEmpty) ...[
            Text(
              'INCLUDES:',
              style: AppTheme.labelSM.copyWith(color: AppTheme.textTertiary, letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            ...package.shopifyVariants.map((v) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_bag_outlined, size: 12, color: AppTheme.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        'Item ${v.variantId} (Qty: ${v.quantity})', // TODO: Fetch real names from Shopify
                        style: AppTheme.bodySM,
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${package.packagePrice.toStringAsFixed(0)} ${package.currency}',
                style: AppTheme.numericMD.copyWith(color: AppTheme.lime, fontSize: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
