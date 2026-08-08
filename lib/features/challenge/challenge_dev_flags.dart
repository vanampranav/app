/// DEV-ONLY feature flags for the challenge feature.
///
/// [kChallengeScaleSyncEnabled] shows a "Sync from EleFit Scale" button on the
/// baseline / weekly / final submission screens that auto-fills weight + body
/// fat from the connected EleFit body-fat scale (pinned to the account owner's
/// profile).
///
/// ▶ To DISABLE before publishing: set this to `false`. The button disappears
///   everywhere (each button already checks this flag), no other changes needed.
///   To remove entirely later, delete this file, the `ChallengeScaleSyncButton`
///   widget, and its three usages in the submission screens.
const bool kChallengeScaleSyncEnabled = false;
