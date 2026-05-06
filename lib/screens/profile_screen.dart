import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/shopify_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_screen.dart';
import 'settings_screen.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/location_provider.dart';
import '../screens/OrdersScreen.dart';
import '../screens/HelpScreen.dart';
import '../screens/address_screen.dart';
import '../models/address_model.dart';
import '../services/onesignal_service.dart';
import '../services/navigation_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isAuthenticated = false;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final email = prefs.getString('user_email');
    setState(() {
      _isAuthenticated = token != null;
      _userEmail = email;
    });
  }

  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_email');
    setState(() {
      _isAuthenticated = false;
      _userEmail = null;
    });
  }

  void _showPasswordRecoveryDialog() {
    print('Password recovery dialog triggered');
    final emailController = TextEditingController(text: _userEmail ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your email address and we\'ll send you a link to reset your password.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                await _sendPasswordResetEmail(emailController.text);
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendPasswordResetEmail(String email) async {
    print('Sending password reset email to: $email');
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final shopifyService = ShopifyService();
      print('Calling Shopify customerRecover...');
      final result = await shopifyService.customerRecover(email: email);
      print('Shopify result: $result');

      if (!mounted) return;
      
      // Close loading indicator
      Navigator.pop(context);

      if (result != null) {
        final errors = result['customerRecover']?['customerUserErrors'] as List?;
        
        if (errors == null || errors.isEmpty) {
          // Success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Password reset link sent to $email. Please check your email.',
                style: TextStyle(fontFamily: "Helvetica", ),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          // Show error
          final errorMessage = errors.first['message'] ?? 'Failed to send reset email';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorMessage,
                style: TextStyle(fontFamily: "Helvetica", ),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        // Network or other error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to send reset email. Please try again.',
              style: TextStyle(fontFamily: "Helvetica", ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      // Close loading indicator if still showing
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'An error occurred. Please try again.',
            style: TextStyle(fontFamily: "Helvetica", ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: _isAuthenticated
            ? [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    await _signOut();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Signed out successfully')),
                      );
                    }
                  },
                ),
              ]
            : null,
      ),
      body: _isAuthenticated ? _buildProfileContent() : _buildSignInPrompt(),
    );
  }

  Widget _buildSignInPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_circle_outlined,
            size: 64,
            color: Theme.of(context).primaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Sign in to view your profile',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Access your orders, wishlist, and more',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (context) => const AuthScreen(),
                ),
              );
              if (result == true) {
                await _checkAuthStatus();
              }
            },
            child: const Text('Sign In'),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              _showPasswordRecoveryDialog();
            },
            icon: const Icon(Icons.lock_reset),
            label: const Text('Forgot Password?'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_userEmail != null)
          ListTile(
            leading: const Icon(Icons.email),
            title: Text(_userEmail!),
          ),
        const Divider(),
        _buildThemeToggle(context),
        if (kIsWeb) ...[
          const Divider(),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Select Region'),
            trailing: DropdownButton<String>(
              value: context.watch<LocationProvider>().countryCode,
              items: const [
                DropdownMenuItem(value: 'US', child: Text('United States (USD)')),
                DropdownMenuItem(value: 'IN', child: Text('India (INR)')),
              ],
              onChanged: (String? newValue) {
                if (newValue != null) {
                  context.read<LocationProvider>().setCountry(newValue);
                }
              },
            ),
          ),
        ],
        const Divider(),
        ListTile(
          leading: const Icon(Icons.shopping_bag_outlined),
          title: const Text('My Orders'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const OrdersScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: const Text('Shipping Addresses'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const AddressScreen(),
              ),
            );
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.lock_reset),
          title: const Text('Change Password'),
          onTap: () {
            _showPasswordRecoveryDialog();
          },
        ),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('Settings'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const SettingsScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('About'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const HelpScreen(),
              ),
            );
          },
        ),
        //ListTile(
          //leading: const Icon(Icons.help_outline),
          //title: const Text('Help & Support'),
          //onTap: () {
            // Navigate to help screen
          //},
        //),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sign Out'),
          onTap: () async {
            await _signOut();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Signed out successfully')),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildThemeToggle(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.themeMode == ThemeMode.dark;
        return ListTile(
          leading: Icon(
            isDark ? Icons.dark_mode : Icons.light_mode,
            color: Theme.of(context).iconTheme.color,
          ),
          title: Text(
            'Dark Mode',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          trailing: Switch(
            value: isDark,
            onChanged: (value) {
              themeProvider.toggleTheme();
            },
            activeColor: AppTheme.accentColor,
          ),
        );
      },
    );
  }
}