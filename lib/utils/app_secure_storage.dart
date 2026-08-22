import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Shared, correctly-configured secure storage for the whole app.
///
/// Why this exists — the default `FlutterSecureStorage()` uses iOS keychain
/// accessibility `whenUnlocked` (`kSecAttrAccessibleWhenUnlocked`). That makes
/// every stored token UNREADABLE while the device is locked. This app is
/// push-enabled, so a notification can cold-launch it while the device is
/// still locked (or freshly rebooted); the token reads then return `null` and
/// the user looks "logged out" even though they never signed out — the classic
/// "reopened the app later and it asked me to log in again" report.
///
/// `first_unlock` (`kSecAttrAccessibleAfterFirstUnlock`) keeps the tokens
/// readable after the first unlock following a boot, which is the right
/// trade-off for a background/push-launchable app and still survives a
/// restore-from-backup. Existing items written with the old accessibility keep
/// working and are upgraded on the next write (login / token refresh).
///
/// Always use this instance instead of `const FlutterSecureStorage()`.
const appSecureStorage = FlutterSecureStorage(
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);
