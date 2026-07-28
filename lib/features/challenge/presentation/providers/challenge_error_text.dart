/// Turns an exception into a clean, user-facing message for the challenge flows.
///
/// - Business-rule exceptions thrown as `Exception('...')` (e.g. "Participant
///   must be approved before submitting") are shown WITHOUT the "Exception:"
///   prefix, because their message is meaningful to the user.
/// - Technical Firebase errors (storage/auth/network) map to friendly text.
String friendlyChallengeError(Object e) {
  final s = e.toString();
  final lower = s.toLowerCase();

  if (lower.contains('storage/unauthorized') || lower.contains('unauthorized')) {
    return "We couldn't upload your photo right now. Please make sure you're signed in and try again.";
  }
  if (lower.contains('permission-denied') || lower.contains('permission_denied')) {
    return 'You don\'t have permission to do this right now. Please sign in again and retry.';
  }
  if (lower.contains('unauthenticated')) {
    return 'Your session has expired. Please sign in again to continue.';
  }
  if (lower.contains('network') || lower.contains('unavailable') || lower.contains('socketexception')) {
    return 'Connection issue. Please check your internet and try again.';
  }
  if (lower.contains('object-not-found') || lower.contains('not-found') || lower.contains('not_found')) {
    return "We couldn't find that. Please try again.";
  }
  if (lower.contains('failed-precondition') && lower.contains('requires an index')) {
    return 'This section is still being set up. Please try again shortly or contact EleFit support.';
  }
  if (lower.contains('deadline-exceeded') || lower.contains('timeout') || lower.contains('timed out')) {
    return 'This is taking longer than expected. Please try again.';
  }
  if (lower.contains('already-exists') || lower.contains('already_exists')) {
    return 'That already exists.';
  }
  if (lower.contains('resource-exhausted') || lower.contains('quota')) {
    return "The server is busy right now. Please try again in a moment.";
  }

  // Business-rule message — drop the "Exception:" prefix so it reads cleanly.
  return s.replaceFirst(RegExp(r'^Exception:\s*'), '');
}
