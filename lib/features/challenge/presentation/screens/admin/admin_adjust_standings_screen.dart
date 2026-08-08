import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/widgets/ef_error_components.dart';
import 'package:elefit_app/features/challenge/data/models/leaderboard_standing.dart';
import 'package:elefit_app/features/challenge/data/repositories/leaderboard_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/leaderboard_service.dart';
import 'package:elefit_app/features/challenge/domain/services/auth_service.dart';

/// Admin-only: shows every challenger's standing and lets the organizer apply a
/// manual bonus / penalty to a participant's score to nudge the ranking (and so
/// decide the winner). It adjusts EXISTING participants only — there is no way
/// to add a new person or fabricate a winner here.
class AdminAdjustStandingsScreen extends StatelessWidget {
  final String challengeId;

  const AdminAdjustStandingsScreen({Key? key, required this.challengeId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final repo = context.read<LeaderboardRepository>();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Adjust Standings', style: AppTheme.headingMD),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppTheme.textPrimary),
      ),
      body: StreamBuilder<List<LeaderboardStanding>>(
        stream: repo.streamStandings(challengeId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const EFLoadingStateView(message: 'Loading standings...');
          }
          final standings =
              List<LeaderboardStanding>.from(snapshot.data ?? const [])
                ..sort((a, b) => b.motivationalScore.compareTo(a.motivationalScore));

          if (standings.isEmpty) {
            return const EFEmptyStateView(
              title: 'No Standings Yet',
              message:
                  'No participants to rank yet. Tap "Refresh Leaderboard" on the challenge screen once people have joined.',
              icon: Icons.leaderboard_outlined,
            );
          }

          return Column(
            children: [
              _buildInfoBanner(),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: standings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) => _buildRow(context, standings[i], i + 1),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
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
              'Add or remove bonus points to change a participant’s rank. Points '
              'apply to existing challengers only — you can’t add a new person here.',
              style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, LeaderboardStanding s, int rank) {
    final total = s.motivationalScore;
    final bonus = s.bonusPoints;
    final base = total - bonus;
    final bool isTop = rank <= 3;

    return EFCard(
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isTop ? AppTheme.lime.withValues(alpha: 0.15) : AppTheme.surface2,
              shape: BoxShape.circle,
            ),
            child: Text('$rank',
                style: AppTheme.numericMD.copyWith(
                    fontSize: 14,
                    color: isTop ? AppTheme.lime : AppTheme.textSecondary)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.displayName,
                    style: AppTheme.bodyLG, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  'Base ${base.toStringAsFixed(1)}   •   Bonus ${bonus >= 0 ? '+' : ''}${bonus.toStringAsFixed(1)}',
                  style: AppTheme.bodySM.copyWith(
                      color: bonus != 0 ? AppTheme.lime : AppTheme.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(total.toStringAsFixed(1),
                  style: AppTheme.numericMD.copyWith(fontSize: 18, color: AppTheme.lime)),
              Text('total', style: AppTheme.labelSM.copyWith(color: AppTheme.textTertiary)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppTheme.textSecondary),
            tooltip: 'Adjust bonus',
            onPressed: () => _showAdjustDialog(context, s),
          ),
        ],
      ),
    );
  }

  Future<void> _showAdjustDialog(BuildContext context, LeaderboardStanding s) async {
    final controller = TextEditingController(
      text: s.bonusPoints == 0 ? '' : _trim(s.bonusPoints),
    );
    final messenger = ScaffoldMessenger.of(context);
    final service = context.read<LeaderboardService>();
    final adminId = context.read<AuthService>().currentUser?.id;

    final value = await showDialog<double>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface1,
          title: Text('Bonus points — ${s.displayName}',
              style: AppTheme.headingSM),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the total bonus (or a negative penalty) to add to this participant’s score. This replaces any existing bonus.',
                style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                    signed: true, decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
                ],
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. 10  or  -5',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: AppTheme.surface2,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                final parsed = double.tryParse(controller.text.trim());
                Navigator.pop(dialogCtx, parsed ?? 0.0);
              },
              child: const Text('Save', style: TextStyle(color: AppTheme.lime)),
            ),
          ],
        );
      },
    );

    if (value == null) return;
    try {
      await service.setBonusPoints(challengeId, s.userId, value, adminId: adminId);
      messenger.showSnackBar(SnackBar(
        content: Text('Bonus for ${s.displayName} set to ${_trim(value)}.'),
        backgroundColor: AppTheme.lime,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Could not update: $e'),
        backgroundColor: AppTheme.error,
      ));
    }
  }

  String _trim(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
