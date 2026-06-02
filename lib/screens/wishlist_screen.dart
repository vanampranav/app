import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/wishlist_model.dart';
import '../models/cart_model.dart';
import '../providers/location_provider.dart'; // Add this import
import 'shop_screen.dart'; // Add import for ShopScreen
import 'cart_screen.dart'; // Add import for CartScreen
import '../widgets/main_layout.dart'; // Fixed import path for MainLayout

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wishlist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {},
          ),
        ],
      ),
      body: Consumer<WishlistModel>(
        builder: (context, wishlist, child) {
          if (wishlist.items.isEmpty) {
            return _buildEmptyWishlist(context);
          }
          return _buildWishlistItems(context, wishlist);
        },
      ),
    );
  }

  Widget _buildEmptyWishlist(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 64,
            color: AppTheme.primaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Your wishlist is empty',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Save items you love to your wishlist',
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

  Widget _buildWishlistItems(BuildContext context, WishlistModel wishlist) {
    final locationProvider = context.watch<LocationProvider>();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: wishlist.items.length,
      itemBuilder: (context, index) {
        final item = wishlist.items[index];
        return Dismissible(
          key: Key(item.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.delete_outline,
              color: Colors.red.shade700,
              size: 28,
            ),
          ),
          onDismissed: (direction) {
            wishlist.removeFromWishlist(item.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Item removed from wishlist'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () {
                    wishlist.toggleWishlist({
                      'id': item.id,
                      'title': item.title,
                      'price': item.price,
                      'imageUrl': item.imageUrl,
                      'description': item.description,
                    });
                  },
                ),
              ),
            );
          },
          child: Hero(
            tag: 'wishlist_${item.id}',
            child: Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/product-details',
                    arguments: {
                      'product': {
                        'id': item.id,
                        'name': item.title,
                        'price': item.price,
                        'image': item.imageUrl,
                        'description': item.description,
                      },
                    },
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item.imageUrl,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.image_not_supported,
                                size: 40,
                                color: Colors.grey,
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
                              style: Theme.of(context).textTheme.titleLarge,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.description,
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  locationProvider.formatPrice(item.price),
                                  style: TextStyle(
                                    color: AppTheme.accentColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    _showAddToCartDialog(context, item);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: const Text('Add to Cart'),
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
            ),
          ),
        );
      },
    );
  }

  void _showAddToCartDialog(BuildContext context, WishlistItem item) {
    // If item has variants, show size selection dialog
    if (item.variants != null && item.variants!.isNotEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Select Size for ${item.title}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: item.variants!.map((variant) {
                return ListTile(
                  title: Text(variant['title'] ?? 'Default'),
                  subtitle: Text('Price: ${variant['price']?['amount'] ?? item.price}'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _addToCart(context, item, variant['id'], variant['title'] ?? 'M');
                  },
                );
              }).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
    } else {
      // If no variants, use empty string like product details screen does
      // This handles combo packs and other products without variants
      String variantId = item.variantId ?? '';
      _addToCart(context, item, variantId, 'M');
    }
  }

  void _addToCart(BuildContext context, WishlistItem item, String variantId, String size) {
    final cartModel = context.read<CartModel>();
    cartModel.addToCart(
      {
        'id': item.id,
        'title': item.title,
        'price': item.price,
        'imageUrl': item.imageUrl,
      },
      variantId,
      1,
      size: size,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.title} added to cart'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'VIEW CART',
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => MainLayout(
                  currentIndex: 2, // Cart tab
                  child: const CartScreen(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
} 