import 'package:flutter/material.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';

class ChallengeStatusView {
  final String label;
  final Color color;
  const ChallengeStatusView(this.label, this.color);
}

/// Derives a human, DATE-AWARE status for a challenge — the SINGLE source of
/// truth used by both the admin list and the admin detail so they can't disagree.
///
/// Rule (per product): registration stays **Open until the end date OR until the
/// maximum number of participants is reached** — whichever comes first. The
/// stored `status` enum doesn't advance on its own, so we compute the real state
/// here. Pass [participantCount] to enable the "full" (max-participants) check;
/// without it, the status is purely date-based.
ChallengeStatusView challengeStatusView(
  Challenge c, {
  int? participantCount,
  DateTime? nowOverride,
}) {
  final now = nowOverride ?? DateTime.now();

  // Explicit lifecycle states first.
  if (c.status == ChallengeStatus.draft) {
    return const ChallengeStatusView('Draft', Colors.grey);
  }
  if (c.status == ChallengeStatus.cancelled) {
    return ChallengeStatusView('Cancelled', AppTheme.error);
  }

  // Ended: admin marked it completed, or the end date has passed.
  if (c.status == ChallengeStatus.completed || now.isAfter(c.endDate)) {
    return const ChallengeStatusView('Challenge Ended', Colors.grey);
  }

  // Full: the maximum number of participants has been reached.
  if (participantCount != null &&
      c.maxParticipants > 0 &&
      participantCount >= c.maxParticipants) {
    return const ChallengeStatusView('Registration Closed', Color(0xFFFFB74D));
  }

  // Otherwise registration is OPEN — up to the end date (or until it fills up).
  return ChallengeStatusView('Registration Open', AppTheme.lime);
}
