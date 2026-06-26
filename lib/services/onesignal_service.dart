import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter/foundation.dart';
import '../config/secrets.dart';
import 'navigation_service.dart';

class OneSignalService {
  static const String appId = Secrets.oneSignalAppId;

  static Future<void> initialize() async {
    try {
      OneSignal.initialize(appId);
      // Set up listeners immediately so we never miss an event.
      _setupNotificationListeners();
      _setupInAppMessageListeners();
      // Request notification permission WITHOUT awaiting — the OS dialog must
      // not block app startup. It now appears over the running UI instead of a
      // blank splash.
      OneSignal.Notifications.requestPermission(true);
    } catch (e) {
      debugPrint('OneSignal init error: $e');
    }
  }

  /// Call this once the first screen is visible (e.g. HomeScreen.initState).
  /// In-app messages need the Flutter UI to be fully rendered before they can show.
  static void triggerAppOpened() {
    try {
      OneSignal.InAppMessages.paused(false);
      OneSignal.InAppMessages.addTrigger('app_opened', 'true');
    } catch (e) {
      debugPrint('OneSignal triggerAppOpened error: $e');
    }
  }

  // ─── Triggers ──────────────────────────────────────────────────────────────

  /// Call when user views a specific screen, e.g. setTrigger('screen', 'shop')
  static void setTrigger(String key, String value) {
    OneSignal.InAppMessages.addTrigger(key, value);
  }

  /// Call when user adds to cart
  static void triggerCartAdded() =>
      OneSignal.InAppMessages.addTrigger('cart_added', 'true');

  /// Call after user completes checkout
  static void triggerPurchaseComplete() =>
      OneSignal.InAppMessages.addTrigger('purchase_complete', 'true');

  /// Tag the logged-in user so you can target by user ID in OneSignal dashboard
  static void setUser(String userId, String email) {
    OneSignal.login(userId);
    OneSignal.User.addEmail(email);
    OneSignal.User.addTags({'platform': 'flutter', 'app': 'elefit'});
  }

  static void clearUser() {
    OneSignal.logout();
  }

  // ─── Push notification listeners ───────────────────────────────────────────

  static void _setupNotificationListeners() {
    // Show notification banner even while app is in foreground
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      event.notification.display();
    });

    // Handle tap on push notification
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      if (data == null) return;

      final action = data['action'] as String?;
      final productId = data['product_id'] as String?;

      if (productId != null) {
        NavigationService.navigateToProductById(productId);
      } else if (action != null) {
        NavigationService.handleAction(action);
      }
    });
  }

  // ─── In-app message listeners ──────────────────────────────────────────────

  static void _setupInAppMessageListeners() {
    OneSignal.InAppMessages.addClickListener((event) {
      // In OneSignal v5, actionId is set per-button in the dashboard
      final actionId = event.result.actionId;
      final url = event.result.url;

      if (actionId != null && actionId.isNotEmpty) {
        _handleActionId(actionId);
      } else if (url != null && url.isNotEmpty) {
        _handleUrl(url);
      }
    });
  }

  /// Routes the actionId string you configure in the OneSignal dashboard.
  ///
  /// Convention:
  ///   "shop"              → Shop screen
  ///   "cart"              → Cart screen
  ///   "home"              → Home screen
  ///   "product_<id>"      → Product details for that numeric Shopify ID
  ///   Any Shopify product URL → Product details
  static void _handleActionId(String actionId) {
    // product_8101770789083
    if (actionId.startsWith('product_')) {
      final id = actionId.substring(8);
      if (RegExp(r'^\d+$').hasMatch(id)) {
        NavigationService.navigateToProductById(id);
        return;
      }
    }

    // Plain numeric ID
    if (RegExp(r'^\d+$').hasMatch(actionId)) {
      NavigationService.navigateToProductById(actionId);
      return;
    }

    // URL format
    if (actionId.contains('://') || actionId.startsWith('/')) {
      _handleUrl(actionId);
      return;
    }

    NavigationService.handleAction(actionId);
  }

  static void _handleUrl(String url) {
    final productId = _extractProductId(url);
    if (productId != null) {
      NavigationService.navigateToProductById(productId);
    } else {
      NavigationService.handleAction('shop');
    }
  }

  static String? _extractProductId(String url) {
    // /product/8101770789083 or ?id=8101770789083
    final byPath = RegExp(r'/product/(\d+)').firstMatch(url);
    if (byPath != null) return byPath.group(1);

    final byQuery = RegExp(r'[?&]id=(\d+)').firstMatch(url);
    if (byQuery != null) return byQuery.group(1);

    return null;
  }
}
