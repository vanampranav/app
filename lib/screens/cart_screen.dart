import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cart_model.dart';
import '../models/address_model.dart';
import '../theme/app_theme.dart';
import 'webview_checkout_screen.dart';
import '../services/shopify_service.dart';
import '../providers/location_provider.dart'; 
import 'shop_screen.dart'; 
import '../widgets/main_layout.dart'; 
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  // Shopify checkout URL with proper encoding
  static const String shopifyCheckoutUrl = 'https://theelefit.com/checkouts/cn/Z2NwLXVzLWVhc3QxOjAxSldZMTlUWVlSQjc4VldKTktGN01ZTjQ3';

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isLoading = false; // Added state variable for loading

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
        actions: [
          TextButton.icon(
            onPressed: () {
              context.read<CartModel>().clearCart();
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Clear'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
      body: Consumer<CartModel>(
        builder: (context, cart, child) {
          if (cart.items.isEmpty) {
            return _buildEmptyCart(context);
          }
          return Column(
            children: [
              Expanded(
                child: _buildCartItems(context, cart),
              ),
              _buildCartSummary(context, cart),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: AppTheme.primaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add items to start shopping',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.secondaryTextColor,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => MainLayout(
                    currentIndex: 1, // Shop tab
                    child: const ShopScreen(),
                  ),
                ),
              );
            },
            child: const Text('Start Shopping'),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItems(BuildContext context, CartModel cart) {
    final locationProvider = context.watch<LocationProvider>();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cart.items.length,
      itemBuilder: (context, index) {
        final item = cart.items[index];
        return Dismissible(
          key: Key('${item.variantId}_${item.size}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: AppTheme.error.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: AppTheme.error,
              size: 28,
            ),
          ),
          onDismissed: (direction) {
            cart.removeFromCart(item.variantId, item.size);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Item removed from cart'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () {
                    cart.addToCart(
                      {
                        'id': item.id,
                        'title': item.title,
                        'price': item.price,
                        'imageUrl': item.imageUrl,
                      },
                      item.variantId,
                      item.quantity,
                      size: item.size,
                    );
                  },
                ),
              ),
            );
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item.imageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppTheme.surface2,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            size: 40,
                            color: AppTheme.textTertiary,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Size: ${item.size}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              locationProvider.formatPrice(item.price * item.quantity, fromCurrencyCode: locationProvider.isInIndia ? 'INR' : 'USD'),
                              style: TextStyle(
                                color: AppTheme.accentColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: () {
                                    cart.updateQuantity(
                                      item.variantId,
                                      item.size,
                                      item.quantity - 1,
                                    );
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    item.quantity.toString(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () {
                                    cart.updateQuantity(
                                      item.variantId,
                                      item.size,
                                      item.quantity + 1,
                                    );
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCartSummary(BuildContext context, CartModel cart) {
    final locationProvider = context.watch<LocationProvider>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface1,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal'),
                Text(
                  locationProvider.formatPrice(cart.subtotal, fromCurrencyCode: locationProvider.isInIndia ? 'INR' : 'USD'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Shipping'),
                Text(
                  locationProvider.formatPrice(cart.shipping, fromCurrencyCode: locationProvider.isInIndia ? 'INR' : 'USD'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tax'),
                Text(
                  locationProvider.formatPrice(cart.tax, fromCurrencyCode: locationProvider.isInIndia ? 'INR' : 'USD'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  locationProvider.formatPrice(cart.total, fromCurrencyCode: locationProvider.isInIndia ? 'INR' : 'USD'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.lime,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                elevation: 0,
              ),
              onPressed: () async {
                setState(() {
                  _isLoading = true;
                });
                try {
                  final shopifyService = context.read<ShopifyService>();
                  final addressModel = context.read<AddressModel>();
                  
                  // Get user authentication token
                  const _secureStorage = FlutterSecureStorage();
                  final customerAccessToken = await _secureStorage.read(key: 'auth_token');
                  
                  // Get default shipping address
                  await addressModel.loadAddresses();
                  final defaultAddress = addressModel.defaultAddress;
                  
                  final cartItems = cart.items.map((item) => {
                    'variantId': item.variantId,
                    'quantity': item.quantity,
                  }).toList();

                  debugPrint('Sending cart items to checkout: $cartItems');
                  debugPrint('Customer access token: ${customerAccessToken != null ? 'available' : 'not available'}');
                  debugPrint('Default address: ${defaultAddress != null ? 'available' : 'not available'}');
                  
                  // Prepare shipping address for Shopify
                  Map<String, dynamic>? shippingAddress;
                  if (defaultAddress != null) {
                    shippingAddress = {
                      'firstName': defaultAddress.firstName,
                      'lastName': defaultAddress.lastName,
                      'company': defaultAddress.company,
                      'address1': defaultAddress.address1,
                      'address2': defaultAddress.address2,
                      'city': defaultAddress.city,
                      'province': defaultAddress.province,
                      'country': defaultAddress.country,
                      'zip': defaultAddress.zip,
                      'phone': defaultAddress.phone,
                    };
                  }
                  
                  final checkoutUrl = await shopifyService.createCheckout(
                    cartItems,
                    customerAccessToken: customerAccessToken,
                    shippingAddress: shippingAddress,
                  );
                  
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                    });

                    if (checkoutUrl != null) {
                      debugPrint('Received checkout URL: $checkoutUrl');
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WebViewCheckoutScreen(
                            checkoutUrl: checkoutUrl,
                          ),
                        ),
                      );

                      if (result == true) {
                        // Order completed successfully, cart was already cleared
                        Navigator.of(context).pop(); // Return to previous screen
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to create checkout. Please try again.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  debugPrint('Error during checkout: $e');
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Proceed to Checkout'),
            ),
          ],
        ),
      ),
    );
  }
} 