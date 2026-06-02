import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firebase_messaging_service.dart';

class NotificationTestWidget extends StatefulWidget {
  const NotificationTestWidget({Key? key}) : super(key: key);

  @override
  State<NotificationTestWidget> createState() => _NotificationTestWidgetState();
}

class _NotificationTestWidgetState extends State<NotificationTestWidget> {
  String? _token;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    setState(() => _isLoading = true);
    try {
      final token = await FirebaseMessagingService.getToken();
      setState(() => _token = token);
    } catch (e) {
      debugPrint('Error loading token: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _copyToken() async {
    if (_token != null) {
      await Clipboard.setData(ClipboardData(text: _token!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token copied to clipboard!')),
      );
    }
  }

  Future<void> _subscribeToTopic() async {
    await FirebaseMessagingService.subscribeToTopic('all_users');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Subscribed to "all_users" topic!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Firebase Messaging Test',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_token != null) ...[
              const Text('FCM Token:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _token!,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _copyToken,
                    child: const Text('Copy Token'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _subscribeToTopic,
                    child: const Text('Subscribe to Topic'),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              const Text(
                'Test Instructions:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                '1. Copy the token above\n'
                '2. Go to Firebase Console → Cloud Messaging\n'
                '3. Send test message using this token\n'
                '4. Check notifications in different app states',
                style: TextStyle(fontSize: 12),
              ),
            ] else
              const Text('Failed to load FCM token'),
          ],
        ),
      ),
    );
  }
}
