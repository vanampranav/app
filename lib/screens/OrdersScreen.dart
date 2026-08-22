import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/shopify_service.dart';
import 'package:elefit_app/utils/app_secure_storage.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<dynamic> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    try {
      const _secureStorage = appSecureStorage;
      final accessToken = await _secureStorage.read(key: 'auth_token');
      if (accessToken == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User not logged in';
        });
        return;
      }

      final result = await context.read<ShopifyService>().getCustomerOrders(accessToken: accessToken);
      if (result == null || result['customer'] == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to fetch orders';
        });
        return;
      }

      final orders = result['customer']['orders']['edges'] as List<dynamic>;
      setState(() {
        _orders = orders;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching orders: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _orders.isEmpty
                  ? const Center(child: Text('No orders have been placed till now'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        final order = _orders[index]['node'];
                        return _buildOrderCard(order);
                      },
                    ),
    );
  }

  Widget _buildOrderCard(dynamic order) {
    final orderNumber = order['orderNumber']?.toString() ?? 'N/A';
    final totalPrice = order['totalPrice']['amount']?.toString() ?? '0.0';
    final currencyCode = order['totalPrice']['currencyCode']?.toString() ?? 'USD';
    final processedAt = order['processedAt'] != null
        ? DateFormat.yMMMd().format(DateTime.parse(order['processedAt']))
        : 'N/A';
    final status = order['fulfillmentStatus']?.toString() ?? 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          'Order #$orderNumber',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text('Date: $processedAt'),
            Text('Total: $totalPrice $currencyCode'),
            Text('Status: $status'),
          ],
        ),
        onTap: () {
          // TODO: Navigate to order details screen
        },
      ),
    );
  }
}