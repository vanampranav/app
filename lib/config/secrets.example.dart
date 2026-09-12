// Copy this file to secrets.dart and fill in your actual credentials.
// secrets.dart is gitignored — never commit real credentials.
class Secrets {
  // Production Firebase API keys
  static const String firebaseApiKey = 'your-firebase-prod-android-api-key';
  static const String prodIosFirebaseApiKey = 'your-firebase-prod-ios-api-key';

  // DEV Firebase API keys
  static const String devFirebaseApiKey = 'your-firebase-dev-android-api-key';
  static const String devIosFirebaseApiKey = 'your-firebase-dev-ios-api-key';

  // FatSecret Platform API — OAuth 1.0a credentials
  static const String fatSecretConsumerKey = 'your-fatsecret-consumer-key';
  static const String fatSecretConsumerSecret = 'your-fatsecret-consumer-secret';

  // OneSignal push notifications app ID
  static const String oneSignalAppId = 'your-onesignal-app-id';

  // Must match the coach web app's SHOPIFY_BRIDGE_SALT exactly.
  static const String shopifyBridgeSalt = 'your-shopify-bridge-salt';
}
