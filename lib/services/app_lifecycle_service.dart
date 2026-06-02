import 'package:flutter/widgets.dart';

class AppLifecycleService extends WidgetsBindingObserver {
  static final AppLifecycleService _instance = AppLifecycleService._internal();
  factory AppLifecycleService() => _instance;
  AppLifecycleService._internal();

  static void initialize() {
    WidgetsBinding.instance.addObserver(_instance);
    debugPrint('✅ App Lifecycle Service initialized');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('📱 App resumed (foreground)');
        break;
      case AppLifecycleState.paused:
        debugPrint('⏸️ App paused (background)');
        break;
      case AppLifecycleState.inactive:
        debugPrint('😴 App inactive');
        break;
      case AppLifecycleState.detached:
        debugPrint('🔌 App detached');
        break;
      case AppLifecycleState.hidden:
        debugPrint('👻 App hidden');
        break;
    }
  }

  static void dispose() {
    WidgetsBinding.instance.removeObserver(_instance);
  }
}
