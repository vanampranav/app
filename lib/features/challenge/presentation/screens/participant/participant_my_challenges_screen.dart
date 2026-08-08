import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/widgets/ef_error_components.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_participant.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/auth_service.dart';
import 'package:elefit_app/features/challenge/presentation/challenge_status_label.dart';
import 'package:elefit_app/features/challenge/presentation/screens/participant/participant_challenge_results_screen.dart';
import 'package:elefit_app/features/challenge/presentation/screens/participant/participant_challenge_dashboard_screen.dart';

/// The challenges the current user has joined / participated in. A finished
/// challenge opens the results screen (rank + podium) so they can view or show
/// it off; an ongoing one opens their challenge dashboard.
class ParticipantMyChallengesScreen extends StatefulWidget {
  const ParticipantMyChallengesScreen({Key? key}) : super(key: key);

  @override
  State<ParticipantMyChallengesScreen> createState() =>
      _ParticipantMyChallengesScreenState();
}

class _ParticipantMyChallengesScreenState
    extends State<ParticipantMyChallengesScreen> {
  StreamSubscription? _sub;
  bool _loading = true;
  String? _error;
  List<_JoinedChallenge> _items = const [];

  @override
  void initState() {
    super.initState();
    final userId = context.read<AuthService>().currentUser?.id;
    final participantRepo = context.read<ChallengeParticipantRepository>();
    final challengeRepo = context.read<ChallengeRepository>();

    if (userId == null || userId.isEmpty) {
      _loading = false;
      _error = 'Please sign in to view your challenges.';
      return;
    }

    _sub = participantRepo.streamParticipantsByUser(userId).listen(
      (participations) async {
        try {
          // Skip withdrawn; fetch each participation's challenge.
          final active = participations
              .where((p) => p.status != ParticipantStatus.withdrawn)
              .toList();
          final challenges = await Future.wait(
              active.map((p) => challengeRepo.getChallengeById(p.challengeId)));

          final items = <_JoinedChallenge>[];
          for (var i = 0; i < active.length; i++) {
            final c = challenges[i];
            if (c != null) items.add(_JoinedChallenge(c, active[i]));
          }
          // Finished challenges first, then most recent start date.
          items.sort((a, b) {
            if (a.isEnded != b.isEnded) return a.isEnded ? -1 : 1;
            return b.challenge.startDate.compareTo(a.challenge.startDate);
          });

          if (mounted) {
            setState(() {
              _items = items;
              _loading = false;
              _error = null;
            });
          }
        } catch (e) {
          if (mounted) setState(() { _loading = false; _error = e.toString(); });
        }
      },
      onError: (e) {
        if (mounted) setState(() { _loading = false; _error = e.toString(); });
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('My Challenges', style: AppTheme.headingMD),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppTheme.textPrimary),
      ),
      body: _loading
          ? const EFLoadingStateView(message: 'Loading your challenges...')
          : _error != null
              ? EFEmptyStateView(
                  title: 'Something went wrong',
                  message: _error!,
                  icon: Icons.error_outline_rounded,
                )
              : _items.isEmpty
                  ? const EFEmptyStateView(
                      title: 'No Challenges Yet',
                      message:
                          "You haven't joined any challenges yet. Find one to get started!",
                      icon: Icons.emoji_events_outlined,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) => _buildRow(context, _items[i]),
                    ),
    );
  }

  Widget _buildRow(BuildContext context, _JoinedChallenge item) {
    final c = item.challenge;
    final view = challengeStatusView(c);
    final ended = item.isEnded;
    final placement = item.participant.finalPlacement;

    return EFCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ended
              ? ParticipantChallengeResultsScreen(challengeId: c.id)
              : ParticipantChallengeDashboardScreen(challengeId: c.id),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (ended ? const Color(0xFFFFD700) : AppTheme.lime)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              ended ? Icons.emoji_events_rounded : Icons.fitness_center_rounded,
              color: ended ? const Color(0xFFFFD700) : AppTheme.lime,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.title,
                    style: AppTheme.bodyLG.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: view.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(view.label,
                          style: AppTheme.labelSM.copyWith(color: view.color)),
                    ),
                    if (ended && placement != null && placement >= 1) ...[
                      const SizedBox(width: 8),
                      Text('You placed #$placement',
                          style: AppTheme.bodySM.copyWith(color: AppTheme.lime)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Icon(
            ended ? Icons.emoji_events_outlined : Icons.chevron_right_rounded,
            color: ended ? const Color(0xFFFFD700) : AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _JoinedChallenge {
  final Challenge challenge;
  final ChallengeParticipant participant;
  _JoinedChallenge(this.challenge, this.participant);

  /// The challenge is over — admin marked it completed OR its end date passed.
  bool get isEnded =>
      challenge.status == ChallengeStatus.completed ||
      DateTime.now().isAfter(challenge.endDate);
}
