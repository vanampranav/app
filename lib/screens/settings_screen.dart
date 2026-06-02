import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/shopify_service.dart';
import '../services/health_service.dart';
import 'add_member_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _emailMarketing = false;
  String? _userEmail;
  bool _healthConnected = false;
  bool _healthLoading   = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    const secureStorage = FlutterSecureStorage();
    final prefs = await SharedPreferences.getInstance();
    final email = await secureStorage.read(key: 'user_email');
    final healthConnected = await HealthService().isConnected;
    if (mounted) {
      setState(() {
        _userEmail = email;
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _emailMarketing = prefs.getBool('email_marketing') ?? false;
        _healthConnected = healthConnected;
      });
    }
  }

  Future<void> _toggleHealthConnection() async {
    setState(() => _healthLoading = true);
    if (_healthConnected) {
      await HealthService().disconnect();
      setState(() { _healthConnected = false; _healthLoading = false; });
    } else {
      final granted = await HealthService().requestPermissions();
      setState(() { _healthConnected = granted; _healthLoading = false; });
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: const Text(
            'Health Connect requires the app to be published on Google Play. '
            'You can test it on the emulator (Android 14+).',
          ),
        ));
      }
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('email_marketing', _emailMarketing);
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete your account? This action cannot be undone.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'This will permanently delete:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Your profile information'),
            const Text('• Order history'),
            const Text('• Saved addresses'),
            const Text('• Wishlist items'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Account deletion may take up to 30 days to complete.',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    if (_userEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No account found to delete'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Note: Shopify doesn't have a direct customer deletion API
      // This is a placeholder for the deletion request
      // In a real app, you would:
      // 1. Call your backend API to initiate deletion
      // 2. Your backend would handle the Shopify customer deletion
      // 3. Or redirect to a web page where users can request deletion

      await Future.delayed(const Duration(seconds: 2)); // Simulate API call

      if (!mounted) return;

      // Clear local data
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Close loading dialog
      Navigator.pop(context);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account deletion request submitted. You will receive a confirmation email at $_userEmail within 24 hours.',
            style: TextStyle(fontFamily: "Helvetica", ),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );

      // Navigate back to login
      Navigator.of(context).popUntil((route) => route.isFirst);

    } catch (e) {
      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to submit deletion request. Please try again or contact support.',
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
        title: const Text('Settings'),
        backgroundColor: AppTheme.bg,
        foregroundColor: AppTheme.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Members ──────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Members',
                      style: TextStyle(
                          fontFamily: 'Helvetica',
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'Manage profiles for body composition tracking.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.purple.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.people_outline_rounded,
                          color: AppTheme.purple, size: 22),
                    ),
                    title: const Text('Manage Members'),
                    subtitle: const Text('Add or edit scale profiles'),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppTheme.textTertiary),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AddMemberScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Connected Apps ────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Connected Apps',
                      style: TextStyle(
                          fontFamily: 'Helvetica',
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'Sync your data with your device\'s health platform.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  // Apple Health / Health Connect tile
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: _healthConnected
                            ? AppTheme.lime.withOpacity(0.12)
                            : AppTheme.surface3,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.favorite_outlined,
                          color: _healthConnected
                              ? AppTheme.lime
                              : AppTheme.textTertiary,
                          size: 22),
                    ),
                    title: const Text('Apple Health / Health Connect'),
                    subtitle: Text(
                      _healthConnected
                          ? 'Connected · syncing weight & nutrition'
                          : 'Not connected',
                      style: TextStyle(
                          color: _healthConnected
                              ? AppTheme.lime
                              : Colors.grey[500],
                          fontSize: 12),
                    ),
                    trailing: _healthLoading
                        ? const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(
                                color: AppTheme.lime, strokeWidth: 2))
                        : TextButton(
                            onPressed: _toggleHealthConnection,
                            style: TextButton.styleFrom(
                              foregroundColor: _healthConnected
                                  ? Colors.red
                                  : AppTheme.lime,
                            ),
                            child: Text(_healthConnected
                                ? 'Disconnect'
                                : 'Connect'),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Notifications Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notifications',
                    style: TextStyle(fontFamily: "Helvetica", 
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Push Notifications'),
                    subtitle: const Text('Receive notifications about orders and promotions'),
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                      _saveSettings();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Email Marketing'),
                    subtitle: const Text('Receive promotional emails and newsletters'),
                    value: _emailMarketing,
                    onChanged: (value) {
                      setState(() {
                        _emailMarketing = value;
                      });
                      _saveSettings();
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Privacy Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Privacy & Data',
                    style: TextStyle(fontFamily: "Helvetica", 
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      // Navigate to privacy policy
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Privacy Policy - Coming Soon'),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Terms of Service'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      // Navigate to terms of service
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Terms of Service - Coming Soon'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Account Management Section
          if (_userEmail != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Management',
                      style: TextStyle(fontFamily: "Helvetica", 
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: Icon(Icons.delete_forever, color: Colors.red.shade600),
                      title: Text(
                        'Delete Account',
                        style: TextStyle(color: Colors.red.shade600),
                      ),
                      subtitle: const Text('Permanently delete your account and all data'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: _showDeleteAccountDialog,
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // App Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Information',
                    style: TextStyle(fontFamily: "Helvetica", 
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Version'),
                    trailing: Text('1.0.0'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.bug_report_outlined),
                    title: const Text('Report a Bug'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Bug reporting - Coming Soon'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
