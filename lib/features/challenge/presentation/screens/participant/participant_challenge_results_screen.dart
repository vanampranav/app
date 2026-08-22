import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/widgets/ef_components.dart';
import 'package:elefit_app/widgets/ef_error_components.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/data/models/leaderboard_standing.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/leaderboard_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/auth_service.dart';

/// Dedicated post-challenge results screen: an animated podium for the top 3 and
/// the current user's own rank / standing. Works off the published leaderboard
/// standings, enriched with award labels when the admin has declared winners.
class ParticipantChallengeResultsScreen extends StatelessWidget {
  final String challengeId;

  const ParticipantChallengeResultsScreen({Key? key, required this.challengeId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final challengeRepo = context.read<ChallengeRepository>();
    final leaderboardRepo = context.read<LeaderboardRepository>();
    final myUserId = context.read<AuthService>().currentUser?.id ?? '';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Results', style: AppTheme.headingMD),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppTheme.textPrimary),
      ),
      body: StreamBuilder<Challenge?>(
        stream: challengeRepo.streamChallengeById(challengeId),
        builder: (context, challengeSnap) {
          final challenge = challengeSnap.data;
          return StreamBuilder<List<LeaderboardStanding>>(
            stream: leaderboardRepo.streamStandings(challengeId),
            builder: (context, standingsSnap) {
              if (challengeSnap.connectionState == ConnectionState.waiting ||
                  standingsSnap.connectionState == ConnectionState.waiting) {
                return const EFLoadingStateView(message: 'Loading results...');
              }
              final standings =
                  List<LeaderboardStanding>.from(standingsSnap.data ?? const [])
                    ..sort((a, b) =>
                        b.motivationalScore.compareTo(a.motivationalScore));

              if (standings.isEmpty) {
                return const EFEmptyStateView(
                  title: 'No Results Yet',
                  message:
                      'Final standings aren’t available yet. Check back once the organizer publishes results.',
                  icon: Icons.emoji_events_outlined,
                );
              }
              return _ResultsView(
                challenge: challenge,
                standings: standings,
                myUserId: myUserId,
              );
            },
          );
        },
      ),
    );
  }
}

class _ResultsView extends StatefulWidget {
  final Challenge? challenge;
  final List<LeaderboardStanding> standings;
  final String myUserId;

  const _ResultsView({
    Key? key,
    required this.challenge,
    required this.standings,
    required this.myUserId,
  }) : super(key: key);

  @override
  State<_ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<_ResultsView>
    with TickerProviderStateMixin {
  late final AnimationController _podium;
  AnimationController? _confetti;
  bool _confettiDone = false;

  int get _myRank {
    final i = widget.standings.indexWhere((s) => s.userId == widget.myUserId);
    return i < 0 ? -1 : i + 1;
  }

  bool get _iAmTop3 => _myRank >= 1 && _myRank <= 3;

  @override
  void initState() {
    super.initState();
    _podium = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..forward();
    if (_iAmTop3) {
      _confetti = AnimationController(
          vsync: this, duration: const Duration(seconds: 4))
        // Remove the confetti overlay entirely once it has fallen off-screen.
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed && mounted) {
            setState(() => _confettiDone = true);
          }
        })
        ..forward();
    }
  }

  @override
  void dispose() {
    _podium.dispose();
    _confetti?.dispose();
    super.dispose();
  }

  /// Award label from declared winners, if any (e.g. "Most Consistent").
  String? _awardLabel(String userId) {
    for (final w in widget.challenge?.winners ?? const []) {
      if (w.userId == userId) return w.awardLabel;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final standings = widget.standings;
    final top3 = standings.take(3).toList();

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            _buildHeader(),
            const SizedBox(height: 8),
            if (top3.isNotEmpty) _buildPodium(top3),
            const SizedBox(height: 28),
            _buildMyResult(),
            const SizedBox(height: 28),
            Text('FULL STANDINGS',
                style: AppTheme.labelMD.copyWith(letterSpacing: 2.0)),
            const SizedBox(height: 12),
            ...List.generate(standings.length,
                (i) => _buildRow(standings[i], i + 1)),
          ],
        ),
        // Celebration only if the current user finished on the podium — removed
        // once the confetti has fallen off-screen.
        if (_confetti != null && !_confettiDone)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _confetti!,
                builder: (_, __) =>
                    CustomPaint(painter: _ConfettiPainter(_confetti!.value)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const SizedBox(height: 8),
        const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 48),
        const SizedBox(height: 8),
        Text('Challenge Complete!',
            style: AppTheme.headingMD, textAlign: TextAlign.center),
        if (widget.challenge?.title != null) ...[
          const SizedBox(height: 4),
          Text(widget.challenge!.title,
              style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
        ],
      ],
    );
  }

  // ---- Animated podium (2nd | 1st | 3rd) ----
  Widget _buildPodium(List<LeaderboardStanding> top3) {
    LeaderboardStanding? at(int place) =>
        top3.length >= place ? top3[place - 1] : null;

    return SizedBox(
      height: 300,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _podiumColumn(at(2), 2, 140, const Interval(0.15, 0.8))),
          Expanded(child: _podiumColumn(at(1), 1, 185, const Interval(0.0, 0.9))),
          Expanded(child: _podiumColumn(at(3), 3, 110, const Interval(0.3, 1.0))),
        ],
      ),
    );
  }

  Color _medal(int place) => place == 1
      ? const Color(0xFFFFD700)
      : place == 2
          ? const Color(0xFFC0C0C0)
          : const Color(0xFFCD7F32);

  Widget _podiumColumn(
      LeaderboardStanding? s, int place, double maxHeight, Interval curve) {
    if (s == null) return const SizedBox.shrink();
    final anim = CurvedAnimation(parent: _podium, curve: curve);
    final isMe = s.userId == widget.myUserId;
    final medal = _medal(place);

    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        final t = anim.value;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Transform.scale(
                scale: Curves.elasticOut.transform(t.clamp(0, 1)),
                child: Icon(
                  place == 1 ? Icons.workspace_premium : Icons.emoji_events,
                  color: medal,
                  size: place == 1 ? 34 : 28,
                ),
              ),
              const SizedBox(height: 4),
              Opacity(
                opacity: t,
                child: Column(
                  children: [
                    Text(
                      s.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTheme.bodyMD.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isMe ? AppTheme.lime : AppTheme.textPrimary),
                    ),
                    Text(s.motivationalScore.toStringAsFixed(1),
                        style: AppTheme.numericMD
                            .copyWith(fontSize: 14, color: medal)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // The rising podium block.
              Container(
                height: (maxHeight * t).clamp(0, maxHeight),
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [medal.withValues(alpha: 0.45), medal.withValues(alpha: 0.12)],
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(10)),
                  border: Border.all(color: medal.withValues(alpha: 0.6)),
                ),
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.only(top: 8),
                child: Text('$place',
                    style: AppTheme.numericLG
                        .copyWith(fontSize: 22, color: medal)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---- The current user's own result ----
  Widget _buildMyResult() {
    final rank = _myRank;
    if (rank < 0) {
      return EFCard(
        color: AppTheme.surface2,
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You’re not ranked in this challenge.',
              style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary),
            ),
          ),
        ]),
      );
    }

    final me = widget.standings[rank - 1];
    final total = widget.standings.length;
    final award = _awardLabel(me.userId);
    final celebrate = _iAmTop3;

    return EFCard(
      color: celebrate
          ? AppTheme.lime.withValues(alpha: 0.08)
          : AppTheme.surface2,
      hasBorder: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(celebrate ? '🏆' : '📊', style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      celebrate
                          ? 'You finished on the podium!'
                          : 'Your Result',
                      style: AppTheme.labelSM.copyWith(
                          color: celebrate ? AppTheme.lime : AppTheme.textSecondary,
                          letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 4),
                    Text('Rank #$rank of $total',
                        style: AppTheme.headingSM.copyWith(
                            color: celebrate ? AppTheme.lime : AppTheme.textPrimary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(me.motivationalScore.toStringAsFixed(1),
                      style: AppTheme.numericLG
                          .copyWith(fontSize: 22, color: AppTheme.lime)),
                  Text('points',
                      style: AppTheme.labelSM
                          .copyWith(color: AppTheme.textTertiary)),
                ],
              ),
            ],
          ),
          if (award != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.workspace_premium_outlined,
                  color: AppTheme.lime, size: 16),
              const SizedBox(width: 8),
              Text(award,
                  style: AppTheme.bodyMD.copyWith(
                      color: AppTheme.lime, fontWeight: FontWeight.bold)),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(LeaderboardStanding s, int rank) {
    final isMe = s.userId == widget.myUserId;
    final isTop3 = rank <= 3;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? AppTheme.lime.withValues(alpha: 0.08) : AppTheme.surface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: isMe
            ? Border.all(color: AppTheme.lime.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('$rank',
                style: AppTheme.numericMD.copyWith(
                    fontSize: 15,
                    color: isTop3 ? _medal(rank) : AppTheme.textSecondary)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(isMe ? '${s.displayName}  (You)' : s.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.bodyMD.copyWith(
                    fontWeight: isMe ? FontWeight.bold : FontWeight.normal)),
          ),
          Text(
            s.latestSubmissionLabel == 'Not started'
                ? '—'
                : s.motivationalScore.toStringAsFixed(1),
            style: AppTheme.numericMD
                .copyWith(fontSize: 15, color: AppTheme.lime),
          ),
        ],
      ),
    );
  }
}

/// Lightweight confetti — colored bits fall + spin over the screen for a few
/// seconds. Pure Flutter, no package.
class _ConfettiPainter extends CustomPainter {
  final double progress; // 0..1
  static final List<_Bit> _bits = _make();

  _ConfettiPainter(this.progress);

  static List<_Bit> _make() {
    final rnd = math.Random(7);
    const colors = [
      Color(0xFFFFD700),
      Color(0xFFC8DA2B),
      Color(0xFF4FC3F7),
      Color(0xFFFF6B6B),
      Color(0xFFC0C0C0),
    ];
    return List.generate(90, (i) {
      return _Bit(
        x: rnd.nextDouble(),
        // Delay + speed are bounded so EVERY piece reaches the bottom (t = 1)
        // before the animation ends — nothing freezes mid-screen.
        // Slowest piece: (1 - 0.25) * 1.4 ≈ 1.05 ≥ 1.
        delay: rnd.nextDouble() * 0.25,
        speed: 1.4 + rnd.nextDouble() * 0.8,
        drift: (rnd.nextDouble() - 0.5) * 0.3,
        color: colors[i % colors.length],
        size: 5 + rnd.nextDouble() * 6,
        rot: rnd.nextDouble() * math.pi,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final b in _bits) {
      final t = ((progress - b.delay) * b.speed).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final y = t * (size.height + 40) - 20;
      final x = (b.x + b.drift * t) * size.width;
      // Stay solid while falling, then fade out over the last stretch so it
      // reads as "falls down and disappears" rather than fading the whole way.
      final double fade = t < 0.8 ? 1.0 : ((1 - t) / 0.2).clamp(0.0, 1.0);
      paint.color = b.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(b.rot + t * 8);
      canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: b.size, height: b.size * 0.5),
          paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

class _Bit {
  final double x, delay, speed, drift, size, rot;
  final Color color;
  _Bit({
    required this.x,
    required this.delay,
    required this.speed,
    required this.drift,
    required this.color,
    required this.size,
    required this.rot,
  });
}
