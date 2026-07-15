import 'package:flutter/material.dart';
import 'package:elefit_app/theme/app_theme.dart';
import 'package:elefit_app/features/challenge/data/models/challenge.dart';
import 'package:elefit_app/features/challenge/data/constants/firestore_collections.dart';

class ChallengeStatusView {
  final String label;
  final Color color;
  const ChallengeStatusView(this.label, this.color);
}

/// Derives a human, DATE-AWARE status for a challenge.
///
/// The stored `status` enum doesn't automatically advance as time passes (it
/// stays `registrationOpen` until an admin closes it), so a challenge whose
/// dates have already passed would wrongly show "Registration Open". Here we
/// compute the true state from the dates for anything past draft/cancelled.
ChallengeStatusView challengeStatusView(Challenge c, [DateTime? nowOverride]) {
  final now = nowOverride ?? DateTime.now();

  // Explicit lifecycle states first.
  if (c.status == ChallengeStatus.draft) {
    return const ChallengeStatusView('Draft', Colors.grey);
  }
  if (c.status == ChallengeStatus.cancelled) {
    return ChallengeStatusView('Cancelled', AppTheme.error);
  }

  // Ended: admin closed it, or the end date has passed.
  if (c.status == ChallengeStatus.completed || now.isAfter(c.endDate)) {
    return const ChallengeStatusView('Challenge Ended', Colors.grey);
  }

  // Running: we're between the start and end date.
  if (now.isAfter(c.startDate)) {
    return const ChallengeStatusView('Challenge Running', Color(0xFF4FC3F7));
  }

  // Before the start date → the registration window.
  if (now.isAfter(c.registrationDeadline)) {
    return const ChallengeStatusView('Registration Closed', Color(0xFFFFB74D));
  }
  return ChallengeStatusView('Registration Open', AppTheme.lime);
}
