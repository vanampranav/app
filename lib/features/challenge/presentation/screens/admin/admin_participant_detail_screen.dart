import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/user_repository.dart';
import 'package:elefit_app/features/challenge/presentation/providers/admin_participant_detail_provider.dart';
import 'package:elefit_app/features/challenge/presentation/widgets/admin/admin_guard.dart';

class AdminParticipantDetailScreen extends StatelessWidget {
  final String userId;
  final String? challengeId;

  const AdminParticipantDetailScreen({
    Key? key, 
    required this.userId,
    this.challengeId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      child: ChangeNotifierProvider(
        create: (ctx) => AdminParticipantDetailProvider(
          userId: userId,
          challengeId: challengeId,
          userRepository: ctx.read<UserRepository>(),
          participantRepository: ctx.read<ChallengeParticipantRepository>(),
        ),
        child: const _AdminParticipantDetailContent(),
      ),
    );
  }
}

class _AdminParticipantDetailContent extends StatelessWidget {
  const _AdminParticipantDetailContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminParticipantDetailProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppTheme.bg,
          appBar: AppBar(
            title: Text(provider.isLoading ? 'Loading...' : provider.displayName),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: const BackButton(color: AppTheme.textPrimary),
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.lime))
              : provider.errorMessage != null
                  ? Center(child: Text(provider.errorMessage!, style: const TextStyle(color: AppTheme.error)))
                  : Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('User Name', provider.displayName),
                          _buildDetailRow('Email', provider.user?.email ?? 'N/A'),
                          _buildDetailRow('Firebase UID', provider.userId, isTechnical: true),
                        ],
                      ),
                    ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTechnical = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTheme.labelSM.copyWith(color: isTechnical ? AppTheme.textTertiary : AppTheme.textSecondary, fontSize: 9)),
          const SizedBox(height: 4),
          Text(value, style: AppTheme.bodyLG.copyWith(color: isTechnical ? AppTheme.textTertiary : AppTheme.textPrimary, fontSize: isTechnical ? 12 : 16)),
        ],
      ),
    );
  }
}
