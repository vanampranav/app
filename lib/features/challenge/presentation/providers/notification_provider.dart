import 'dart:async';
import 'dispose_guard_notifier.dart';
import 'package:flutter/material.dart';
import 'package:elefit_app/features/challenge/data/models/challenge_notification.dart';
import 'package:elefit_app/features/challenge/domain/services/challenge_notification_service.dart';

class NotificationProvider with ChangeNotifier, DisposeGuardNotifier {
  final String userId;
  final ChallengeNotificationService _notificationService;

  List<ChallengeNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription? _notificationsSub;

  List<ChallengeNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  NotificationProvider({
    required this.userId,
    required ChallengeNotificationService notificationService,
  }) : _notificationService = notificationService {
    _init();
  }

  void _init() {
    if (userId.isEmpty) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _notificationsSub = _notificationService.streamUserNotifications(userId).listen(
      (data) {
        _notifications = data;
        _unreadCount = data.where((n) => !n.isRead).length;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (err) {
        _isLoading = false;
        _errorMessage = err.toString();
        notifyListeners();
      },
    );
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationService.markAsRead(notificationId);
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    if (userId.isEmpty) return;
    try {
      await _notificationService.markAllAsRead(userId);
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  @override
  void dispose() {
    _notificationsSub?.cancel();
    super.dispose();
  }
}
