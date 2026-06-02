import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/shop_screen.dart';
import '../screens/product_details_screen.dart';
import '../screens/cart_screen.dart';
import '../screens/wishlist_screen.dart';
import '../screens/profile_screen.dart';
import '../services/shopify_service.dart';
import '../widgets/main_layout.dart';
import 'package:provider/provider.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static BuildContext? get context => navigatorKey.currentContext;

  // ─── Tab navigation ────────────────────────────────────────────────────────

  static void navigateToTab(int index) {
    if (context == null) return;
    Widget page;
    switch (index) {
      case 1:  page = const ShopScreen(); break;
      case 2:  page = const WishlistScreen(); break;
      case 3:  page = const CartScreen(); break;
      case 4:  page = const ProfileScreen(); break;
      default: page = const HomeScreen();
    }
    Navigator.of(context!).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MainLayout(currentIndex: index, child: page),
      ),
      (route) => false,
    );
  }

  static void navigateToHome()     => navigateToTab(0);
  static void navigateToShop()     => navigateToTab(1);
  static void navigateToWishlist() => navigateToTab(2);
  static void navigateToCart()     => navigateToTab(3);
  static void navigateToProfile()  => navigateToTab(4);

  // ─── Product navigation ────────────────────────────────────────────────────

  static void navigateToProductDetails(Map<String, dynamic> product) {
    if (context == null) return;
    Navigator.of(context!).push(MaterialPageRoute(
      builder: (_) => MainLayout(
        currentIndex: 1,
        child: ProductDetailsScreen(product: product),
      ),
    ));
  }

  static Future<void> navigateToProductById(String productId) async {
    if (context == null) return;
    try {
      final shopify = Provider.of<ShopifyService>(context!, listen: false);
      final raw = await shopify.getProductById(productId);

      if (raw != null && raw['id'] != null) {
        final product = _transform(raw);
        Navigator.of(context!).push(MaterialPageRoute(
          builder: (_) => MainLayout(
            currentIndex: 1,
            child: ProductDetailsScreen(product: product),
          ),
        ));
      } else {
        navigateToShop();
      }
    } catch (_) {
      navigateToShop();
    }
  }

  // ─── Action router (used by OneSignal) ────────────────────────────────────

  /// Routes a plain action string from a notification or in-app message button.
  static void handleAction(String action) {
    switch (action.toLowerCase()) {
      case 'shop':
      case 'browse':
      case 'explore':
        navigateToShop();
        break;
      case 'cart':
      case 'checkout':
        navigateToCart();
        break;
      case 'wishlist':
      case 'favorites':
        navigateToWishlist();
        break;
      case 'profile':
      case 'account':
        navigateToProfile();
        break;
      case 'home':
      default:
        navigateToHome();
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  static Map<String, dynamic> _transform(Map<String, dynamic> raw) {
    final images = raw['images'] != null
        ? (raw['images']['edges'] as List)
            .map((e) => (e['node']['url'] as String?) ?? '')
            .where((u) => u.isNotEmpty)
            .toList()
        : <String>[];

    final price = double.tryParse(
            raw['priceRange']?['minVariantPrice']?['amount']?.toString() ??
                '0') ??
        0.0;

    return {
      'id': raw['id']?.toString() ?? '',
      'name': raw['title']?.toString() ?? '',
      'title': raw['title']?.toString() ?? '',
      'handle': raw['handle']?.toString() ?? '',
      'description': raw['description']?.toString() ?? '',
      'images': images,
      'image': images.isNotEmpty ? images.first : '',
      'price': price,
      'priceRange': raw['priceRange'] ?? {
        'minVariantPrice': {'amount': '$price', 'currencyCode': 'USD'}
      },
      'variants': raw['variants'] ?? {'edges': []},
    };
  }
}
