import 'firestore_parsing.dart';

/// A declared winner / award recipient on a completed challenge.
///
/// `place` is 1/2/3 for podium finishers, or 0 for a named special award
/// (e.g. "Most Consistent"). Stored inline on the challenge doc's `winners[]`.
class ChallengeWinner {
  final String userId;
  final String displayName;
  final int place; // 1,2,3 for podium; 0 for a special award
  final String awardLabel; // "1st Place" / "Most Consistent" / ...
  final String metric; // bodyFatLossPoints | weightLossPercent | special
  final double? score;
  final String? prizeNote;

  ChallengeWinner({
    required this.userId,
    required this.displayName,
    required this.place,
    required this.awardLabel,
    this.metric = 'bodyFatLossPoints',
    this.score,
    this.prizeNote,
  });

  bool get isSpecialAward => place <= 0;

  ChallengeWinner copyWith({
    String? userId,
    String? displayName,
    int? place,
    String? awardLabel,
    String? metric,
    double? score,
    String? prizeNote,
  }) {
    return ChallengeWinner(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      place: place ?? this.place,
      awardLabel: awardLabel ?? this.awardLabel,
      metric: metric ?? this.metric,
      score: score ?? this.score,
      prizeNote: prizeNote ?? this.prizeNote,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'displayName': displayName,
      'place': place,
      'awardLabel': awardLabel,
      'metric': metric,
      'score': score,
      'prizeNote': prizeNote,
    };
  }

  factory ChallengeWinner.fromMap(Map<String, dynamic> map) {
    return ChallengeWinner(
      userId: (map['userId'] ?? '').toString(),
      displayName: (map['displayName'] ?? 'Participant').toString(),
      place: parseIntOr(map['place'], 0),
      awardLabel: (map['awardLabel'] ?? '').toString(),
      metric: (map['metric'] ?? 'bodyFatLossPoints').toString(),
      score: map['score'] == null ? null : parseDoubleOr(map['score'], 0),
      prizeNote: map['prizeNote']?.toString(),
    );
  }
}
