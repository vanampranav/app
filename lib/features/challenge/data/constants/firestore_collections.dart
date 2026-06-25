class FirestoreCollections {
  static const String users = 'users';
  static const String challenges = 'challenges';
  static const String challengeParticipants = 'challengeParticipants';
  static const String challengeSubmissions = 'challengeSubmissions';
  static const String paymentRecords = 'paymentRecords';
  static const String notifications = 'notifications';
  static const String adminAuditLogs = 'adminAuditLogs';
}

class ChallengeStatus {
  static const String draft = 'draft';
  static const String registrationOpen = 'registrationOpen';
  static const String active = 'active';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
}

class ParticipantStatus {
  static const String invited = 'invited';
  static const String joined = 'joined';
  static const String active = 'active';
  static const String withdrawn = 'withdrawn';
  static const String disqualified = 'disqualified';
  static const String completed = 'completed';
}

class PaymentStatus {
  static const String pending = 'pending';
  static const String paid = 'paid';
  static const String waived = 'waived';
  static const String refunded = 'refunded';
  static const String rejected = 'rejected';
}

class SubmissionType {
  static const String baseline = 'baseline';
  static const String weeklyCheckIn = 'weeklyCheckIn';
  static const String finalSubmission = 'finalSubmission';
}

class ReviewStatus {
  static const String submitted = 'submitted';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
  static const String needsClarification = 'needsClarification';
}

class PaymentMethod {
  static const String zelle = 'zelle';
  static const String venmo = 'venmo';
  static const String cashApp = 'cashApp';
  static const String cash = 'cash';
  static const String other = 'other';
}
