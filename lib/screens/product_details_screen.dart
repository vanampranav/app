import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/cart_model.dart';
import '../theme/app_theme.dart';
import '../models/product_model.dart';
import 'cart_screen.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import '../widgets/main_layout.dart';
import '../models/wishlist_model.dart';
import '../providers/location_provider.dart';
import '../screens/home_screen.dart';
import '../screens/shop_screen.dart';
import '../screens/wishlist_screen.dart';
import '../screens/profile_screen.dart';
import '../widgets/bottom_nav_bar.dart';
import 'package:flutter_html/flutter_html.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailsScreen({
    Key? key,
    required this.product,
  }) : super(key: key);

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int _selectedSize = 0;
  int _quantity = 1;
  late String _selectedVariantId;
  int _currentImageIndex = 0;
  late List<String> _productImages;
  List<Map<String, dynamic>>? _variants;

  @override
  void initState() {
    super.initState();
    _initializeProductData();
  }

  void _initializeProductData() {
    try {
      _variants = [];
      if (widget.product['variants'] != null) {
        var variantsData = widget.product['variants'];
        if (variantsData is Map && variantsData['edges'] != null) {
          var edges = variantsData['edges'];
          if (edges is List) {
            _variants = edges
                .where((edge) => edge != null && edge['node'] != null)
                .map((edge) => Map<String, dynamic>.from(edge['node'] as Map))
                .toList();
          }
        }
      }

      _selectedVariantId = '';
      if (_variants?.isNotEmpty == true) {
        var firstVariant = _variants![0];
        if (firstVariant['id'] != null) {
          _selectedVariantId = firstVariant['id'].toString();
        }
      }

      _productImages = [];
      if (widget.product['images'] != null) {
        var imagesData = widget.product['images'];
        if (imagesData is List) {
          _productImages = imagesData
              .where((img) => img != null && img.toString().isNotEmpty)
              .map((img) => img.toString())
              .toList();
        }
      }
      if (_productImages.isEmpty && widget.product['image'] != null) {
        String singleImage = widget.product['image'].toString();
        if (singleImage.isNotEmpty) _productImages = [singleImage];
      }
      if (_productImages.isEmpty) {
        _productImages = ['https://via.placeholder.com/400x400?text=No+Image'];
      }
    } catch (e) {
      _variants = [];
      _selectedVariantId = '';
      _productImages = ['https://via.placeholder.com/400x400?text=Error'];
    }
  }

  void _updateSelectedVariant(int variantIndex) {
    if (_variants?.isNotEmpty == true && variantIndex < _variants!.length) {
      setState(() {
        _selectedSize = variantIndex;
        _selectedVariantId = _variants![variantIndex]['id']?.toString() ?? '';
      });
    }
  }

  void _navigateToCart() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MainLayout(
          currentIndex: 2,
          child: const CartScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 0,
            pinned: true,
            backgroundColor: AppTheme.bg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppTheme.textPrimary, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              Consumer<WishlistModel>(
                builder: (context, wishlist, child) {
                  final isInWishlist = wishlist.isInWishlist(widget.product['id']);
                  return IconButton(
                    icon: Icon(
                      isInWishlist ? Icons.favorite : Icons.favorite_border,
                      color: isInWishlist ? Colors.red : AppTheme.textSecondary,
                    ),
                    onPressed: () {
                      wishlist.toggleWishlist({
                        'id': widget.product['id'],
                        'title': widget.product['name'],
                        'price': widget.product['price'] ?? 0.0,
                        'imageUrl': widget.product['image'] ?? '',
                        'description': widget.product['description'] ?? '',
                        'variantId': _selectedVariantId,
                        'variants': _variants,
                      });
                    },
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined,
                    color: AppTheme.textSecondary),
                onPressed: () {},
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProductImage(),
                _buildProductInfo(),
                _buildSizeSelector(),
                _buildQuantitySelector(),
                _buildDescription(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      // ── Bottom bar ──────────────────────────────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        decoration: BoxDecoration(
          color: AppTheme.surface1,
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.07)),
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Price column
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Price', style: AppTheme.bodyMD),
                    Consumer<LocationProvider>(
                      builder: (context, lp, _) => Text(
                        lp.formatPrice(
                          widget.product['price'] ?? 0.0,
                          fromCurrencyCode: lp.isInIndia ? 'INR' : 'USD',
                        ),
                        style: AppTheme.numericMD.copyWith(
                            color: AppTheme.lime, fontSize: 22),
                      ),
                    ),
                  ],
                ),
              ),
              // Add to Cart button
              GestureDetector(
                onTap: () {
                  context.read<CartModel>().addToCart(
                    {
                      'id': widget.product['id'],
                      'title': widget.product['name'] ?? '',
                      'price': widget.product['price'] ?? 0.0,
                      'imageUrl': widget.product['image'] ?? '',
                      'description': widget.product['description'] ?? '',
                    },
                    _selectedVariantId,
                    _quantity,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Added to cart'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: AppTheme.surface2,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd)),
                      action: SnackBarAction(
                        label: 'VIEW CART',
                        textColor: AppTheme.lime,
                        onPressed: _navigateToCart,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.lime,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.lime.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Add to Cart',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Product image carousel ────────────────────────────────────────────────
  Widget _buildProductImage() {
    return Hero(
      tag: 'product_${widget.product['id']}',
      child: Container(
        height: 300,
        width: double.infinity,
        color: AppTheme.surface1,
        child: Stack(
          children: [
            FlutterCarousel(
              options: CarouselOptions(
                height: 300,
                showIndicator: true,
                viewportFraction: 1.0,
                enableInfiniteScroll: true,
                autoPlay: false,
                slideIndicator: CircularSlideIndicator(),
                initialPage: _currentImageIndex,
                onPageChanged: (index, reason) {
                  setState(() => _currentImageIndex = index);
                },
              ),
              items: _productImages.map((url) {
                return Builder(
                  builder: (_) => CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppTheme.surface2),
                    errorWidget: (_, __, ___) => Container(
                      color: AppTheme.surface2,
                      child: const Icon(Icons.image_not_supported,
                          size: 50, color: AppTheme.textTertiary),
                    ),
                  ),
                );
              }).toList(),
            ),
            // Image counter pill
            Positioned(
              bottom: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Row(children: [
                  const Icon(Icons.photo_library_outlined,
                      color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${_currentImageIndex + 1}/${_productImages.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Product info ──────────────────────────────────────────────────────────
  Widget _buildProductInfo() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.product['name'] ?? '',
              style: AppTheme.headingLG),
          const SizedBox(height: 10),
          Row(children: [
            Consumer<LocationProvider>(
              builder: (context, lp, _) => Text(
                lp.formatPrice(widget.product['price'] ?? 0.0,
                    fromCurrencyCode: lp.isInIndia ? 'INR' : 'USD'),
                style: const TextStyle(
                  color: AppTheme.lime,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.lime.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
              child: Text(
                '20% OFF',
                style: AppTheme.labelMD.copyWith(color: AppTheme.lime),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
            const SizedBox(width: 4),
            const Text('4.8',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary)),
            const SizedBox(width: 8),
            Text('(256 Reviews)', style: AppTheme.bodyMD),
          ]),
        ],
      ),
    );
  }

  // ── Variant selector ──────────────────────────────────────────────────────
  Widget _buildSizeSelector() {
    if (_variants == null || _variants!.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Variant', style: AppTheme.headingSM),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_variants!.length, (i) {
                final selected = _selectedSize == i;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => _updateSelectedVariant(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.lime.withOpacity(0.1)
                            : AppTheme.surface2,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: selected
                              ? AppTheme.lime
                              : Colors.white.withOpacity(0.1),
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        _variants![i]['title'] ?? 'Variant ${i + 1}',
                        style: TextStyle(
                          color: selected
                              ? AppTheme.lime
                              : AppTheme.textSecondary,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Quantity selector ─────────────────────────────────────────────────────
  Widget _buildQuantitySelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(children: [
        Text('Quantity', style: AppTheme.headingSM),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface2,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.remove_rounded,
                  color: AppTheme.textSecondary, size: 18),
              onPressed: () {
                if (_quantity > 1) setState(() => _quantity--);
              },
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              constraints: const BoxConstraints(),
            ),
            Text('$_quantity',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary)),
            IconButton(
              icon: const Icon(Icons.add_rounded,
                  color: AppTheme.textSecondary, size: 18),
              onPressed: () => setState(() => _quantity++),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              constraints: const BoxConstraints(),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Description ───────────────────────────────────────────────────────────
  Widget _buildDescription() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Description', style: AppTheme.headingSM),
          const SizedBox(height: 12),
          Html(
            data: widget.product['description'] ?? '',
            style: {
              'body': Style(
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
                fontSize: FontSize(15),
                lineHeight: const LineHeight(1.6),
                color: AppTheme.textSecondary,
              ),
              'p': Style(
                margin: Margins.only(bottom: 12),
                fontSize: FontSize(15),
                lineHeight: const LineHeight(1.6),
                color: AppTheme.textSecondary,
              ),
              'strong': Style(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              'b': Style(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              'h1': Style(fontSize: FontSize(22), fontWeight: FontWeight.bold,
                  margin: Margins.only(top: 14, bottom: 10), color: AppTheme.textPrimary),
              'h2': Style(fontSize: FontSize(20), fontWeight: FontWeight.bold,
                  margin: Margins.only(top: 14, bottom: 10), color: AppTheme.textPrimary),
              'h3': Style(fontSize: FontSize(18), fontWeight: FontWeight.bold,
                  margin: Margins.only(top: 12, bottom: 8), color: AppTheme.textPrimary),
              'h4': Style(fontSize: FontSize(16), fontWeight: FontWeight.bold,
                  margin: Margins.only(top: 10, bottom: 6), color: AppTheme.textPrimary),
              'ul': Style(margin: Margins.only(bottom: 10, left: 14)),
              'ol': Style(margin: Margins.only(bottom: 10, left: 14)),
              'li': Style(margin: Margins.only(bottom: 5),
                  fontSize: FontSize(15), lineHeight: const LineHeight(1.6),
                  color: AppTheme.textSecondary),
            },
          ),
        ],
      ),
    );
  }
}
