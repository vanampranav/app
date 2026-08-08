import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/widgets/ef_error_components.dart';
import 'package:elefit_app/features/challenge/data/models/leaderboard_standing.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/auth_service.dart';
import 'package:elefit_app/features/challenge/domain/services/winner_selection_service.dart';
import 'package:elefit_app/features/challenge/presentation/providers/admin_winner_selection_provider.dart';

class AdminWinnerSelectionScreen extends StatelessWidget {
  final String challengeId;
  const AdminWinnerSelectionScreen({Key? key, required this.challengeId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final adminId = context.read<AuthService>().currentUser?.id ?? '';
    return ChangeNotifierProvider(
      create: (ctx) => AdminWinnerSelectionProvider(
        challengeId: challengeId,
        adminId: adminId,
        service: ctx.read<WinnerSelectionService>(),
        challengeRepository: ctx.read<ChallengeRepository>(),
      ),
      child: const _WinnerSelectionContent(),
    );
  }
}

class _WinnerSelectionContent extends StatelessWidget {
  const _WinnerSelectionContent();

  static String _metricLabel(String metric) {
    switch (metric) {
      case 'compositeScore':
        return 'Participant Score';
      case 'bodyFatLossPoints':
        return 'Body-fat loss';
      case 'weightLossPercent':
        return 'Weight loss %';
      default:
        return metric;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppTheme.textPrimary),
        title: Text('Select Winners', style: AppTheme.headingMD),
      ),
      body: Consumer<AdminWinnerSelectionProvider>(
        builder: (context, p, _) {
          if (p.isLoading) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.lime));
          }
          if (!p.isCompleted) {
            return const EFEmptyStateView(
              title: 'Challenge not finished',
              message:
                  'Close the challenge first (mark it completed) before selecting winners.',
              icon: Icons.flag_outlined,
            );
          }
          if (p.error != null && p.ranked.isEmpty) {
            return EFEmptyStateView(
              title: 'Could not load',
              message: p.error!,
              icon: Icons.error_outline_rounded,
            );
          }
          if (p.ranked.isEmpty) {
            return const EFEmptyStateView(
              title: 'No eligible finalists',
              message:
                  'No participant has an approved final result yet, so there is no one to rank.',
              icon: Icons.emoji_events_outlined,
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                  children: [
                    if (p.resultsPublished)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: EFCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            const Icon(Icons.check_circle,
                                color: AppTheme.lime, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Results already published. You can adjust and re-publish.',
                                style: AppTheme.bodyMD
                                    .copyWith(color: AppTheme.textSecondary),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    Text('ELIGIBLE FINALISTS',
                        style: AppTheme.labelSM
                            .copyWith(color: AppTheme.textTertiary)),
                    const SizedBox(height: 4),
                    Text(
                      'Ranked automatically — body-fat loss first, then weight loss. Assign podium places or a special award.',
                      style: AppTheme.bodySM,
                    ),
                    const SizedBox(height: 12),
                    ...p.ranked.asMap().entries.map((e) =>
                        _candidateCard(context, p, e.value, e.key + 1)),
                    if (p.ineligible.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('NOT ELIGIBLE',
                          style: AppTheme.labelSM
                              .copyWith(color: AppTheme.textTertiary)),
                      const SizedBox(height: 8),
                      ...p.ineligible.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: EFCard(
                              padding: const EdgeInsets.all(14),
                              child: Row(children: [
                                Expanded(
                                    child: Text(s.displayName,
                                        style: AppTheme.bodyMD)),
                                Flexible(
                                  child: Text(
                                    s.officialIneligibilityReason ??
                                        'No final result',
                                    textAlign: TextAlign.right,
                                    style: AppTheme.bodySM.copyWith(
                                        color: AppTheme.textTertiary),
                                  ),
                                ),
                              ]),
                            ),
                          )),
                    ],
                  ],
                ),
              ),
              _publishBar(context, p),
            ],
          );
        },
      ),
    );
  }

  Widget _candidateCard(BuildContext context, AdminWinnerSelectionProvider p,
      LeaderboardStanding s, int autoRank) {
    final draft = p.draftFor(s.userId);
    final scoreText = s.officialScore == null
        ? '—'
        : (s.officialMetric == 'weightLossPercent'
            ? '${s.officialScore!.toStringAsFixed(1)}%'
            : s.officialScore!.toStringAsFixed(1));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: EFCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.surface2,
                  child: Text('$autoRank',
                      style: AppTheme.labelSM
                          .copyWith(color: AppTheme.textSecondary)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.displayName, style: AppTheme.bodyLG),
                      Text('${_metricLabel(s.officialMetric)} · $scoreText',
                          style: AppTheme.bodySM
                              .copyWith(color: AppTheme.textTertiary)),
                    ],
                  ),
                ),
                _placeDropdown(p, s.userId, draft.place),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: TextEditingController(text: draft.specialAward)
                ..selection = TextSelection.collapsed(
                    offset: draft.specialAward.length),
              onChanged: (v) => p.setSpecialAward(s.userId, v),
              style: AppTheme.bodyMD.copyWith(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Special award (optional, e.g. Most Consistent)',
                hintStyle:
                    AppTheme.bodySM.copyWith(color: AppTheme.textTertiary),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeDropdown(
      AdminWinnerSelectionProvider p, String userId, int place) {
    return DropdownButton<int>(
      value: place,
      dropdownColor: AppTheme.surface1,
      underline: const SizedBox.shrink(),
      items: const [
        DropdownMenuItem(value: 0, child: Text('—')),
        DropdownMenuItem(value: 1, child: Text('1st')),
        DropdownMenuItem(value: 2, child: Text('2nd')),
        DropdownMenuItem(value: 3, child: Text('3rd')),
      ],
      onChanged: (v) => p.setPlace(userId, v ?? 0),
    );
  }

  Widget _publishBar(BuildContext context, AdminWinnerSelectionProvider p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: AppTheme.surface1,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.lime,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26)),
          ),
          onPressed: (p.isPublishing || p.selectedCount == 0)
              ? null
              : () => _confirmPublish(context, p),
          child: p.isPublishing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black))
              : Text(
                  p.selectedCount == 0
                      ? 'Select at least one winner'
                      : 'Publish Results (${p.selectedCount})',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }

  Future<void> _confirmPublish(
      BuildContext context, AdminWinnerSelectionProvider p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface1,
        title: Text('Publish results?', style: AppTheme.headingMD),
        content: Text(
          'This announces ${p.selectedCount} winner(s) to all participants and cannot be undone silently (you can re-publish to correct it).',
          style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.lime, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final success = await p.publish();
    if (success) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Results published 🏆'),
          backgroundColor: AppTheme.lime));
      navigator.pop();
    } else {
      messenger.showSnackBar(SnackBar(
          content: Text(p.error ?? 'Could not publish results.'),
          backgroundColor: AppTheme.error));
    }
  }
}
