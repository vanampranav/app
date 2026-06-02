import 'package:flutter/foundation.dart';
import 'package:graphql/client.dart';
import 'dart:async';
import '../config/shopify_config.dart';

class ShopifyService with ChangeNotifier {
  static const String _storeUrl = ShopifyConfig.storeUrl;
  static const String _storefrontAccessToken = ShopifyConfig.storefrontAccessToken;

  static const String _indiaStoreUrl = ShopifyConfig.indiaStoreUrl;
  static const String _indiaStorefrontAccessToken = ShopifyConfig.indiaStorefrontAccessToken;

  GraphQLClient? _client;
  GraphQLClient? _indiaClient;
  bool _isInitialized = false;
  bool _isIndia = false;

  final Map<String, Map<String, dynamic>?> _productsCache = {};
  final Map<String, Map<String, dynamic>?> _indiaProductsCache = {};

  bool get isIndiaMode => _isIndia;

  void setIndiaMode(bool isIndia) {
    if (_isIndia == isIndia) return;
    _isIndia = isIndia;
    notifyListeners();
  }

  String _cacheKey({String? collectionHandle, String? tag}) {
    if (collectionHandle != null && collectionHandle.isNotEmpty) return 'collection:$collectionHandle';
    if (tag != null && tag.isNotEmpty) return 'tag:$tag';
    return 'all';
  }

  Map<String, dynamic>? getCachedProducts({String? collectionHandle, String? tag}) {
    final cache = _isIndia ? _indiaProductsCache : _productsCache;
    return cache[_cacheKey(collectionHandle: collectionHandle, tag: tag)];
  }

  ShopifyService() {
    initialize();
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    _client = GraphQLClient(
      cache: GraphQLCache(),
      link: HttpLink(
        'https://$_storeUrl/api/2024-01/graphql',
        defaultHeaders: {
          'X-Shopify-Storefront-Access-Token': _storefrontAccessToken,
          'Content-Type': 'application/json',
        },
      ),
      defaultPolicies: DefaultPolicies(
        query: Policies(fetch: FetchPolicy.noCache),
        mutate: Policies(fetch: FetchPolicy.noCache),
      ),
    );

    _indiaClient = GraphQLClient(
      cache: GraphQLCache(),
      link: HttpLink(
        'https://$_indiaStoreUrl/api/2024-01/graphql.json',
        defaultHeaders: {
          'X-Shopify-Access-Token': _indiaStorefrontAccessToken,
          'Content-Type': 'application/json',
        },
      ),
      defaultPolicies: DefaultPolicies(
        query: Policies(fetch: FetchPolicy.noCache),
        mutate: Policies(fetch: FetchPolicy.noCache),
      ),
    );

    _isInitialized = true;
  }

  Future<GraphQLClient> get client async {
    if (!_isInitialized) await initialize();
    return _isIndia ? _indiaClient! : _client!;
  }

  Future<String?> createCheckout(List<Map<String, dynamic>> items, {
    String? customerAccessToken,
    Map<String, dynamic>? shippingAddress,
  }) async {
    try {
      final graphQLClient = await client;
      
      debugPrint('Creating cart with items: $items');
      debugPrint('Customer access token: ${customerAccessToken != null ? 'provided' : 'not provided'}');
      debugPrint('Shipping address: ${shippingAddress != null ? 'provided' : 'not provided'}');

      // Step 1: Validate customer access token if provided
      if (customerAccessToken != null) {
        debugPrint('Validating customer access token...');
        final isValidToken = await _validateCustomerAccessToken(customerAccessToken);
        if (!isValidToken) {
          debugPrint('Customer access token is invalid or expired, proceeding without authentication');
          customerAccessToken = null;
        } else {
          debugPrint('Customer access token is valid');
        }
      }

      // Step 2: Create cart with customer authentication if available
      String createCartMutation;
      Map<String, dynamic> cartVariables = {};
      
      if (customerAccessToken != null) {
        // Enhanced cart creation with customer authentication
        createCartMutation = '''
          mutation cartCreate(\$input: CartInput!) {
            cartCreate(input: \$input) {
              cart {
                id
                checkoutUrl
                buyerIdentity {
                  email
                  phone
                  customer {
                    id
                    email
                    firstName
                    lastName
                  }
                }
              }
              userErrors {
                field
                message
              }
            }
          }
        ''';
        
        cartVariables = {
          'input': {
            'buyerIdentity': {
              'customerAccessToken': customerAccessToken,
            }
          }
        };
      } else {
        // Simple cart creation without authentication
        createCartMutation = '''
          mutation cartCreate {
            cartCreate {
              cart {
                id
                checkoutUrl
              }
              userErrors {
                field
                message
              }
            }
          }
        ''';
      }

      // Create cart
      final createCartResult = await graphQLClient.mutate(
        MutationOptions(
          document: gql(createCartMutation),
          variables: cartVariables,
        ),
      );

      if (createCartResult.hasException) {
        debugPrint('Error creating cart: ${createCartResult.exception}');
        return null;
      }

      final cartData = createCartResult.data?['cartCreate'];
      if (cartData == null || cartData['cart'] == null) {
        debugPrint('Invalid cart data received');
        debugPrint('Full response: ${createCartResult.data}');
        return null;
      }

      // Debug: Log cart creation result
      final cart = cartData['cart'];
      final cartId = cart['id'] as String;
      debugPrint('Cart created successfully with ID: $cartId');
      
      // Debug: Check if buyer identity was set
      if (cart['buyerIdentity'] != null) {
        final buyerIdentity = cart['buyerIdentity'];
        debugPrint('Buyer identity set: ${buyerIdentity}');
        if (buyerIdentity['customer'] != null) {
          final customer = buyerIdentity['customer'];
          debugPrint('Customer authenticated: ${customer['email']} (${customer['firstName']} ${customer['lastName']})');
        } else {
          debugPrint('Warning: Buyer identity exists but no customer data');
        }
      } else {
        debugPrint('Warning: No buyer identity in cart - customer authentication may have failed');
      }
      
      // Add lines mutation
      const String addLinesMutation = '''
        mutation cartLinesAdd(\$cartId: ID!, \$lines: [CartLineInput!]!) {
          cartLinesAdd(cartId: \$cartId, lines: \$lines) {
            cart {
              id
              checkoutUrl
              lines(first: 10) {
                edges {
                  node {
                    id
                    quantity
                    merchandise {
                      ... on ProductVariant {
                        id
                      }
                    }
                  }
                }
              }
            }
            userErrors {
              field
              message
            }
          }
        }
      ''';

      // Format line items - ensure proper variant ID format
      final lines = items.map((item) {
        String variantId = item['variantId'].toString();
        
        // If the ID doesn't have the proper Shopify format, add it
        if (!variantId.startsWith('gid://shopify/ProductVariant/')) {
          // Remove any existing Shopify prefix if present
          variantId = variantId.replaceAll('gid://shopify/ProductVariant/', '');
          variantId = variantId.replaceAll('gid://shopify/Product/', '');
          // Add the correct prefix
          variantId = 'gid://shopify/ProductVariant/$variantId';
        }
        
        return {
          'merchandiseId': variantId,
          'quantity': item['quantity'],
        };
      }).toList();

      debugPrint('Adding lines to cart: $lines');

      // Add items to cart
      final addLinesResult = await graphQLClient.mutate(
        MutationOptions(
          document: gql(addLinesMutation),
          variables: {
            'cartId': cartId,
            'lines': lines,
          },
        ),
      );

      if (addLinesResult.hasException) {
        debugPrint('Error adding lines to cart: ${addLinesResult.exception}');
        return null;
      }

      final addLinesData = addLinesResult.data?['cartLinesAdd'];
      if (addLinesData == null) {
        debugPrint('Invalid response data received');
        debugPrint('Response data: ${addLinesResult.data}');
        return null;
      }

      if (addLinesData['userErrors'] != null && 
          (addLinesData['userErrors'] as List).isNotEmpty) {
        debugPrint('Cart line errors: ${addLinesData['userErrors']}');
        return null;
      }

      if (addLinesData['cart'] == null) {
        debugPrint('Invalid cart data received after adding lines');
        debugPrint('Response data: ${addLinesResult.data}');
        return null;
      }

      // Step 3: Update cart with shipping address if available
      String? finalCheckoutUrl = addLinesData['cart']['checkoutUrl'] as String?;
      if (finalCheckoutUrl == null) {
        debugPrint('No checkout URL returned');
        return null;
      }

      if (shippingAddress != null) {
        debugPrint('Updating cart with shipping address...');
        
        const String updateCartMutation = '''
          mutation cartBuyerIdentityUpdate(\$cartId: ID!, \$buyerIdentity: CartBuyerIdentityInput!) {
            cartBuyerIdentityUpdate(cartId: \$cartId, buyerIdentity: \$buyerIdentity) {
              cart {
                id
                checkoutUrl
                buyerIdentity {
                  email
                  phone
                  deliveryAddressPreferences {
                    ... on MailingAddress {
                      address1
                      address2
                      city
                      province
                      country
                      zip
                    }
                  }
                }
              }
              userErrors {
                field
                message
              }
            }
          }
        ''';

        Map<String, dynamic> buyerIdentity = {};
        
        // Add customer access token if available
        if (customerAccessToken != null) {
          buyerIdentity['customerAccessToken'] = customerAccessToken;
        }
        
        // Add delivery address preferences only if shippingAddress is not null
        if (shippingAddress != null) {
          buyerIdentity['deliveryAddressPreferences'] = [
            {
              'deliveryAddress': {
                'address1': shippingAddress['address1'],
                'address2': shippingAddress['address2'] ?? '',
                'city': shippingAddress['city'],
                'company': shippingAddress['company'] ?? '',
                'country': shippingAddress['country'],
                'firstName': shippingAddress['firstName'],
                'lastName': shippingAddress['lastName'],
                'phone': shippingAddress['phone'] ?? '',
                'province': shippingAddress['province'],
                'zip': shippingAddress['zip'],
              }
            }
          ];
        }

        final updateResult = await graphQLClient.mutate(
          MutationOptions(
            document: gql(updateCartMutation),
            variables: {
              'cartId': cartId,
              'buyerIdentity': buyerIdentity,
            },
          ),
        );

        if (updateResult.hasException) {
          debugPrint('Warning: Could not update cart with address: ${updateResult.exception}');
          // Continue with original checkout URL even if address update fails
        } else {
          final updateData = updateResult.data?['cartBuyerIdentityUpdate'];
          if (updateData != null && updateData['cart'] != null) {
            final updatedCheckoutUrl = updateData['cart']['checkoutUrl'] as String?;
            if (updatedCheckoutUrl != null) {
              finalCheckoutUrl = updatedCheckoutUrl;
              debugPrint('Successfully updated cart with shipping address');
            }
          }
        }
      }

      debugPrint('Created cart and got checkout URL: $finalCheckoutUrl');
      return finalCheckoutUrl;
    } catch (e, stackTrace) {
      debugPrint('Exception while creating cart: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<bool> _validateCustomerAccessToken(String customerAccessToken) async {
    const String validateQuery = '''
      query customer(\$customerAccessToken: String!) {
        customer(customerAccessToken: \$customerAccessToken) {
          id
          email
          firstName
          lastName
        }
      }
    ''';

    try {
      final graphQLClient = await client;
      final result = await graphQLClient.query(
        QueryOptions(
          document: gql(validateQuery),
          variables: {
            'customerAccessToken': customerAccessToken,
          },
          fetchPolicy: FetchPolicy.noCache,
        ),
      );

      if (result.hasException) {
        debugPrint('Customer validation error: ${result.exception}');
        return false;
      }

      final customerData = result.data?['customer'];
      if (customerData != null) {
        debugPrint('Customer validated: ${customerData['email']} (${customerData['firstName']} ${customerData['lastName']})');
        return true;
      }
      
      debugPrint('Customer access token is invalid or expired');
      return false;
    } catch (e) {
      debugPrint('Customer validation failed: $e');
      return false;
    }
  }

  Future<bool> testConnection() async {
    const String testQuery = '''
      query {
        shop {
          name
          primaryDomain {
            url
          }
        }
      }
    ''';

    try {
      final graphQLClient = await client;
      final result = await graphQLClient.query(
        QueryOptions(
          document: gql(testQuery),
          fetchPolicy: FetchPolicy.noCache,
        ),
      );

      if (result.hasException) {
        debugPrint('API Test Error: ${result.exception}');
        return false;
      }

      final shopData = result.data?['shop'];
      if (shopData != null) {
        debugPrint('Connected to shop: ${shopData['name']}');
        debugPrint('Shop URL: ${shopData['primaryDomain']['url']}');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Connection test failed: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getProducts({int first = 250, String? collectionHandle, String? tag}) async {
    String query;
    
    if (collectionHandle != null && collectionHandle.isNotEmpty) {
      // Query products by collection handle
      query = '''
        query {
          collection(handle: "$collectionHandle") {
            products(first: $first) {
              edges {
                node {
                  id
                  title
                  handle
                  description
                  descriptionHtml
                  priceRange {
                    minVariantPrice {
                      amount
                      currencyCode
                    }
                  }
                  images(first: 5) {
                    edges {
                      node {
                        url
                        altText
                      }
                    }
                  }
                  variants(first: 10) {
                    edges {
                      node {
                        id
                        title
                        price {
                          amount
                          currencyCode
                        }
                        availableForSale
                        selectedOptions {
                          name
                          value
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      ''';
    } else if (tag != null && tag.isNotEmpty) {
      // Query products by tag
      query = '''
        query {
          products(first: $first, query: "tag:$tag") {
            edges {
              node {
                id
                title
                handle
                description
                descriptionHtml
                priceRange {
                  minVariantPrice {
                    amount
                    currencyCode
                  }
                }
                images(first: 5) {
                  edges {
                    node {
                      url
                      altText
                    }
                  }
                }
                variants(first: 10) {
                  edges {
                    node {
                      id
                      title
                      price {
                        amount
                        currencyCode
                      }
                      availableForSale
                      selectedOptions {
                        name
                        value
                      }
                    }
                  }
                }
              }
            }
          }
        }
      ''';
    } else {
      // Query all products
      query = '''
        query {
          products(first: $first) {
            edges {
              node {
                id
                title
                handle
                description
                descriptionHtml
                priceRange {
                  minVariantPrice {
                    amount
                    currencyCode
                  }
                }
                images(first: 5) {
                  edges {
                    node {
                      url
                      altText
                    }
                  }
                }
                variants(first: 10) {
                  edges {
                    node {
                      id
                      title
                      price {
                        amount
                        currencyCode
                      }
                      availableForSale
                      selectedOptions {
                        name
                        value
                      }
                    }
                  }
                }
              }
            }
          }
        }
      ''';
    }

    try {
      final graphQLClient = await client;
      final QueryOptions options = QueryOptions(
        document: gql(query),
        fetchPolicy: FetchPolicy.noCache,
      );

      final QueryResult result = await graphQLClient.query(options);

      if (result.hasException) {
        debugPrint('Error fetching products: ${result.exception}');
        return null;
      }

      Map<String, dynamic>? response;

      if (collectionHandle != null && collectionHandle.isNotEmpty) {
        if (result.data?['collection'] != null) {
          response = {'products': result.data!['collection']['products']};
        }
      } else {
        response = result.data;
      }

      if (response != null) {
        final cache = _isIndia ? _indiaProductsCache : _productsCache;
        cache[_cacheKey(collectionHandle: collectionHandle, tag: tag)] = response;
      }

      return response;
    } catch (e) {
      debugPrint('Exception while fetching products: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getCollections({int first = 20}) async {
    const String query = '''
      query {
        collections(first: 20) {
          edges {
            node {
              id
              title
              handle
              description
            }
          }
        }
      }
    ''';

    try {
      final graphQLClient = await client;
      final QueryOptions options = QueryOptions(
        document: gql(query),
        fetchPolicy: FetchPolicy.noCache,
      );

      final QueryResult result = await graphQLClient.query(options);

      if (result.hasException) {
        debugPrint('Error fetching collections: ${result.exception}');
        return [];
      }

      if (result.data?['collections']?['edges'] != null) {
        final collections = (result.data!['collections']['edges'] as List)
            .map((edge) => edge['node'] as Map<String, dynamic>)
            .toList();
        
        debugPrint('Available collections:');
        for (var collection in collections) {
          debugPrint('  - ${collection['title']} (handle: ${collection['handle']})');
        }
        
        return collections;
      }

      return [];
    } catch (e) {
      debugPrint('Exception while fetching collections: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getProductById(String productId) async {
    // Convert numeric ID to Shopify GID format if needed
    String gid = productId;
    if (RegExp(r'^\d+$').hasMatch(productId)) {
      gid = 'gid://shopify/Product/$productId';
    }
    
    String query = '''
      query {
        product(id: "$gid") {
          id
          title
          handle
          description
          priceRange {
            minVariantPrice {
              amount
              currencyCode
            }
          }
          images(first: 5) {
            edges {
              node {
                url
                altText
              }
            }
          }
          variants(first: 10) {
            edges {
              node {
                id
                title
                price {
                  amount
                  currencyCode
                }
                availableForSale
                selectedOptions {
                  name
                  value
                }
              }
            }
          }
        }
      }
    ''';

    try {
      final graphQLClient = await client;
      final QueryOptions options = QueryOptions(
        document: gql(query),
        fetchPolicy: FetchPolicy.noCache,
      );

      final QueryResult result = await graphQLClient.query(options);

      if (result.hasException) {
        debugPrint('Error fetching product by ID: ${result.exception}');
        return null;
      }

      if (result.data?['product'] != null) {
        return result.data?['product'];
      } else {
        debugPrint('Product not found with ID: $productId');
        return null;
      }
    } catch (e) {
      debugPrint('Exception while fetching product by ID: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> customerAccessTokenCreate({
    required String email,
    required String password,
  }) async {
    const String mutation = '''
      mutation customerAccessTokenCreate(\$input: CustomerAccessTokenCreateInput!) {
        customerAccessTokenCreate(input: \$input) {
          customerAccessToken {
            accessToken
            expiresAt
          }
          customerUserErrors {
            code
            field
            message
          }
        }
      }
    ''';

    try {
      final graphQLClient = await client;
      final MutationOptions options = MutationOptions(
        document: gql(mutation),
        variables: {
          'input': {
            'email': email,
            'password': password,
          },
        },
      );

      final QueryResult result = await graphQLClient.mutate(options);

      if (result.hasException) {
        debugPrint('Error creating access token: ${result.exception}');
        return null;
      }

      return result.data;
    } catch (e) {
      debugPrint('Exception while creating access token: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> createCustomer({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    const String mutation = '''
      mutation customerCreate(\$input: CustomerCreateInput!) {
        customerCreate(input: \$input) {
          customer {
            id
            email
            firstName
            lastName
          }
          customerUserErrors {
            code
            field
            message
          }
        }
      }
    ''';

    try {
      final graphQLClient = await client;
      final MutationOptions options = MutationOptions(
        document: gql(mutation),
        variables: {
          'input': {
            'email': email,
            'password': password,
            'firstName': firstName,
            'lastName': lastName,
          },
        },
      );

      final QueryResult result = await graphQLClient.mutate(options);

      if (result.hasException) {
        debugPrint('Error creating customer: ${result.exception}');
        return null;
      }

      return result.data;
    } catch (e) {
      debugPrint('Exception while creating customer: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> customerRecover({required String email}) async {
    const String mutation = '''
      mutation customerRecover(\$email: String!) {
        customerRecover(email: \$email) {
          customerUserErrors {
            code
            field
            message
          }
        }
      }
    ''';

    try {
      final graphQLClient = await client;
      final MutationOptions options = MutationOptions(
        document: gql(mutation),
        variables: {
          'email': email,
        },
      );

      final QueryResult result = await graphQLClient.mutate(options);

      if (result.hasException) {
        debugPrint('Error sending password recovery email: ${result.exception}');
        return null;
      }

      return result.data;
    } catch (e) {
      debugPrint('Exception while sending password recovery email: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getCustomerOrders({required String accessToken}) async {
    const String query = '''
      query customer(\$accessToken: String!) {
        customer(customerAccessToken: \$accessToken) {
          orders(first: 20) {
            edges {
              node {
                id
                orderNumber
                processedAt
                totalPrice {
                  amount
                  currencyCode
                }
                fulfillmentStatus
                lineItems(first: 10) {
                  edges {
                    node {
                      title
                      quantity
                      variant {
                        id
                        title
                        price {
                          amount
                          currencyCode
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    ''';

    try {
      final graphQLClient = await client;
      final QueryOptions options = QueryOptions(
        document: gql(query),
        variables: {
          'accessToken': accessToken,
        },
        fetchPolicy: FetchPolicy.noCache,
      );

      final QueryResult result = await graphQLClient.query(options);

      if (result.hasException) {
        debugPrint('Error fetching orders: ${result.exception}');
        return null;
      }

      return result.data;
    } catch (e) {
      debugPrint('Exception while fetching orders: $e');
      return null;
    }
  }
}