import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/shopify_service.dart';
import '../utils/constants.dart';
import 'package:provider/provider.dart';
import '../models/cart_model.dart';
import '../models/wishlist_model.dart';
import '../providers/location_provider.dart';

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
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Try collection first
      var products = await _shopifyService.getProducts(
        collectionHandle: widget.collectionHandle,
      );
      
      // If collection returns null or empty, try tag-based query
      if (products == null && widget.tag != null) {
        print('Collection not found, trying tag: ${widget.tag}');
        products = await _shopifyService.getProducts(
          tag: widget.tag,
        );
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
      print('Error loading products: $e');
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
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
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
                                  Image.network(
                                    product['images']['edges'].isNotEmpty 
                                        ? product['images']['edges'][0]['node']['url'] 
                                        : AppConstants.productPlaceholder,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(
                                          Icons.image_not_supported,
                                          size: 50,
                                          color: Colors.grey,
                                        ),
                                      );
                                    },
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
                                            backgroundColor: Colors.white,
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
                                        double.tryParse(product['priceRange']['minVariantPrice']['amount'].toString()) ?? 0.0
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