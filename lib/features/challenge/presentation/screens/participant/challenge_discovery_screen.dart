import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/features/challenge/domain/services/challenge_service.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/presentation/screens/participant/challenge_detail_screen.dart';
import 'package:elefit_app/features/challenge/presentation/providers/participant_challenge_discovery_provider.dart';

class ChallengeDiscoveryScreen extends StatelessWidget {
  const ChallengeDiscoveryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => ParticipantChallengeDiscoveryProvider(
        challengeService: ctx.read<ChallengeService>(),
      ),
      child: const _ChallengeDiscoveryContent(),
    );
  }
}

class _ChallengeDiscoveryContent extends StatelessWidget {
  const _ChallengeDiscoveryContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Discover Challenges', style: AppTheme.headingMD),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppTheme.textPrimary),
      ),
      body: Consumer<ParticipantChallengeDiscoveryProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.lime));
          }

          if (provider.errorMessage != null) {
            return _buildErrorState(provider.errorMessage!);
          }

          if (provider.challenges.isEmpty) {
            return const Center(
              child: Text(
                'No active challenges available right now.',
                style: AppTheme.bodyLG,
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: provider.challenges.length,
            separatorBuilder: (_, __) => const SizedBox(height: 20),
            itemBuilder: (ctx, i) {
              final challenge = provider.challenges[i];
              return _ChallengeDiscoveryCard(challenge: challenge);
            },
          );
        },
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: AppTheme.bodyMD),
          ],
        ),
      ),
    );
  }
}

class _ChallengeDiscoveryCard extends StatelessWidget {
  final Challenge challenge;

  const _ChallengeDiscoveryCard({Key? key, required this.challenge}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd');
    final registrationFormat = DateFormat('MMM dd, yyyy');

    return EFCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  challenge.title,
                  style: AppTheme.headingSM.copyWith(fontSize: 18),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _StatusBadge(status: challenge.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            challenge.description,
            style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          _InfoRow(
            icon: Icons.calendar_today_rounded,
            label: '${dateFormat.format(challenge.startDate)} - ${dateFormat.format(challenge.endDate)}',
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.timer_outlined,
            label: 'Register by: ${registrationFormat.format(challenge.registrationDeadline)}',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _InfoRow(
                  icon: Icons.attach_money_rounded,
                  label: challenge.registrationFee == 0 
                    ? 'Free Entry' 
                    : '\$${challenge.registrationFee.toStringAsFixed(0)} Registration',
                ),
              ),
              Expanded(
                child: _InfoRow(
                  icon: Icons.people_outline_rounded,
                  label: '${challenge.maxParticipants} Spots Total',
                ),
              ),
            ],
          ),
          const Divider(height: 32, color: Colors.white10),
          Text(
            'PRIZE',
            style: AppTheme.labelSM.copyWith(color: AppTheme.textTertiary, letterSpacing: 1.2),
          ),
          const SizedBox(height: 4),
          Text(
            challenge.prizeDescription,
            style: AppTheme.bodyMD.copyWith(color: AppTheme.lime, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),
          EFButton(
            label: 'View Details',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChallengeDetailScreen(challengeId: challenge.id)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({Key? key, required this.icon, required this.label}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textTertiary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({Key? key, required this.status}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color color = AppTheme.lime;
    String label = 'OPEN';
    
    if (status == 'active') {
      color = Colors.blue;
      label = 'IN PROGRESS';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }
}
