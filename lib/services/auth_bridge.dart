import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:elefit_app/services/firebase_rest_service.dart';
import 'package:elefit_app/services/shopify_service.dart';
import '../config/app_environment.dart';

/// The deployed `mintFirebaseToken` Cloud Function.
String get _mintTokenUrl => AppEnvironment.mintTokenUrl;

/// Signs a user into Firebase, bridging Shopify/AI-coach accounts WITHOUT ever
/// changing their password:
///
///   1. Try Firebase directly with the entered password.
///   2. If that fails, authenticate against Shopify (their store password).
///   3. Ask the `mintFirebaseToken` Cloud Function for a Firebase CUSTOM TOKEN
///      (it re-validates the Shopify token server-side, then mints a token for
///      that user's uid — no password touched).
///   4. Sign the REST session in with that custom token.
///
/// Returns the custom token if the bridge path was used (so the caller can also
/// sign the Firebase Auth SDK session in with it), or null if the direct login
/// worked (caller signs the SDK in with the password as normal). Throws with a
/// user-friendly message if the credentials are genuinely invalid.
Future<String?> bridgeSignIn({
  required String email,
  required String password,
  required FirebaseRestService fb,
  required ShopifyService shopify,
}) async {
  // 1. Direct Firebase login (normal users, and Shopify users whose Firebase
  //    password already equals their Shopify password).
  if (await fb.trySignIn(email, password)) return null;

  // 2. Fall back to Shopify — validates the real store password + issues a token.
  final customer = await shopify.customerLogin(email, password);
  if (customer == null) {
    throw Exception('Invalid email or password.');
  }

  // 3. Mint a Firebase custom token for this user (server-side, no password change).
  final token = await _mintFirebaseToken(
    email: email,
    shopifyAccessToken: customer['accessToken']!,
  );
  if (token == null) {
    throw Exception(
        'We couldn\'t finish signing you in. Please try again in a moment.');
  }

  // 4. Establish the REST session from the custom token.
  await fb.signInWithCustomToken(token, email: email.trim());
  return token;
}

Future<String?> _mintFirebaseToken({
  required String email,
  required String shopifyAccessToken,
}) async {
  try {
    final res = await http.post(
      Uri.parse(_mintTokenUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'shopifyAccessToken': shopifyAccessToken,
      }),
    );
    if (res.statusCode != 200) return null;
    return jsonDecode(res.body)['token'] as String?;
  } catch (_) {
    return null;
  }
}
