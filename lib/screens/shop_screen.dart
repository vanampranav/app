import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../services/shopify_service.dart';
import '../utils/constants.dart';
import 'package:provider/provider.dart';
import '../models/cart_model.dart';
import '../models/wishlist_model.dart';
import '../providers/location_provider.dart';
import 'cart_screen.dart';

class ShopScreen extends StatefulWidget {
  final String? categoryName;
  final String? collectionHandle;
  final String? tag;
  
  const ShopScreen({
    Key? key,
    this.categoryName,
    this.collectionHandle,
    this.tag,
  }) : super(key: key);

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late final ShopifyService _shopifyService;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _productsData;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _shopifyService = Provider.of<ShopifyService>(context, listen: false);
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    // Serve cached data immediately so the screen is never blank on return visits
    final cached = _shopifyService.getCachedProducts(
      collectionHandle: widget.collectionHandle,
      tag: widget.tag,
    );
    if (cached != null) {
      setState(() {
        _productsData = cached;
        _isLoading = false;
        _error = null;
      });
      // Silently refresh in the background
      _refreshInBackground();
      return;
    }

    // First ever load — show spinner
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      var products = await _shopifyService.getProducts(
        collectionHandle: widget.collectionHandle,
      );
      final isEmpty = products == null ||
          (products['products']?['edges'] as List?)?.isEmpty == true;
      if (isEmpty && widget.tag != null) {
        products = await _shopifyService.getProducts(tag: widget.tag);
      }
      if (mounted) {
        setState(() {
          _productsData = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshInBackground() async {
    var fresh = await _shopifyService.getProducts(
      collectionHandle: widget.collectionHandle,
    );
    final isEmpty = fresh == null ||
        (fresh['products']?['edges'] as List?)?.isEmpty == true;
    if (isEmpty && widget.tag != null) {
      fresh = await _shopifyService.getProducts(tag: widget.tag);
    }
    if (mounted && fresh != null) {
      setState(() => _productsData = fresh);
    }
  }

  List<Map<String, dynamic>> _getFilteredProducts() {
    if (_productsData == null || _productsData!['products'] == null) {
      return [];
    }

    final locationProvider = Provider.of<LocationProvider>(context, listen: false);

    final List<Map<String, dynamic>> products = (_productsData!['products']['edges'] as List)
        .map((edge) => edge['node'] as Map<String, dynamic>)
        .where((product) {
          final title = product['title'].toString().toLowerCase();
          final search = _searchQuery.toLowerCase();
          
          // Filter by search query and location
          return title.contains(search) && 
                 locationProvider.shouldShowProduct(product['title'] ?? '');
        })
        .toList();

    return products;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName ?? 'Shop'),
        actions: [
          Consumer<CartModel>(
            builder: (context, cart, _) => Badge(
              isLabelVisible: cart.itemCount > 0,
              label: Text('${cart.itemCount}', style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
              backgroundColor: AppTheme.accentColor,
              child: IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: AppTheme.textTertiary, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: const BorderSide(color: AppTheme.lime, width: 1.5),
                ),
                filled: true,
                fillColor: AppTheme.surface2,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadProducts,
        child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Error loading products: $_error',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadProducts,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _getFilteredProducts().length,
                itemBuilder: (context, index) {
                  final products = _getFilteredProducts();
                  if (index >= products.length) {
                    return null;
                  }
                  final product = products[index];
                  return Card(
                    child: InkWell(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/product-details',
                          arguments: {
                            'product': {
                              'id': product['id'],
                              'name': product['title'],
                              'price': double.tryParse(product['priceRange']['minVariantPrice']['amount'].toString()) ?? 0.0,
                              'image': product['images']['edges'].isNotEmpty 
                                  ? product['images']['edges'][0]['node']['url'] 
                                  : AppConstants.productPlaceholder,
                              'images': (product['images']['edges'] as List)
                                  .map((edge) => edge['node']['url'] as String)
                                  .toList(),
                              'description': product['descriptionHtml'] ?? product['description'] ?? '',
                              'variants': product['variants'],  // Add this line to include variants
                            },
                          },
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: product['images']['edges'].isNotEmpty
                                        ? product['images']['edges'][0]['node']['url']
                                        : AppConstants.productPlaceholder,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      color: Colors.grey.shade200,
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: Colors.grey.shade200,
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Consumer<WishlistModel>(
                                      builder: (context, wishlist, child) {
                                        final isInWishlist = wishlist.isInWishlist(product['id']);
                                        return IconButton(
                                          icon: Icon(
                                            isInWishlist ? Icons.favorite : Icons.favorite_border,
                                            color: isInWishlist ? Colors.red : null,
                                          ),
                                          onPressed: () {
                                            // Extract variant information for proper cart integration
                                            String? variantId;
                                            List<Map<String, dynamic>>? variants;
                                            
                                            if (product['variants'] != null && 
                                                product['variants']['edges'] != null &&
                                                product['variants']['edges'].isNotEmpty) {
                                              variants = (product['variants']['edges'] as List)
                                                  .map((edge) => edge['node'] as Map<String, dynamic>)
                                                  .toList();
                                              variantId = variants.first['id'];
                                            }
                                            
                                            wishlist.toggleWishlist({
                                              'id': product['id'],
                                              'title': product['title'],
                                              'price': double.tryParse(product['priceRange']['minVariantPrice']['amount'].toString()) ?? 0.0,
                                              'imageUrl': product['images']['edges'].isNotEmpty 
                                                  ? product['images']['edges'][0]['node']['url'] 
                                                  : AppConstants.productPlaceholder,
                                              'description': product['descriptionHtml'] ?? product['description'] ?? '',
                                              'variantId': variantId,
                                              'variants': variants,
                                            });
                                          },
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            padding: const EdgeInsets.all(8),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product['title'] ?? '',
                                  style: TextStyle(fontFamily: "Helvetica", 
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      context.read<LocationProvider>().formatPrice(
                                        double.tryParse(product['priceRange']['minVariantPrice']['amount'].toString()) ?? 0.0,
                                        fromCurrencyCode: (product['priceRange']['minVariantPrice']['currencyCode'] as String?) ?? 'USD',
                                      ),
                                      style: TextStyle(fontFamily: "Helvetica", 
                                        color: AppTheme.accentColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_shopping_cart),
                                      onPressed: () {
                                        final variants = product['variants']['edges'];
                                        if (variants != null && variants.isNotEmpty) {
                                          // Extract just the numeric ID from the variant ID
                                          final variantId = variants[0]['node']['id'].toString();
                                          final numericId = variantId.split('/').last;
                                          context.read<CartModel>().addToCart(
                                            {
                                              'id': product['id'],
                                              'title': product['title'],
                                              'price': double.tryParse(product['priceRange']['minVariantPrice']['amount'].toString()) ?? 0.0,
                                              'imageUrl': product['images']['edges'].isNotEmpty 
                                                  ? product['images']['edges'][0]['node']['url'] 
                                                  : AppConstants.productPlaceholder,
                                              'description': product['descriptionHtml'] ?? product['description'] ?? '',
                                            },
                                            numericId,
                                            1,
                                          );
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Added to cart',
                                                style: TextStyle(fontFamily: "Helvetica", ),
                                              ),
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Product variant not available'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                      style: IconButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.all(8),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        ),
    );
  }
} 