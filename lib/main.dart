import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/analytics_service.dart';
import 'services/firebase_rest_service.dart';
import 'firebase_options.dart';
import 'models/cart_model.dart';
import 'models/wishlist_model.dart';
import 'models/address_model.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/product_details_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'theme/app_theme.dart';
import 'services/shopify_service.dart';
import 'services/onesignal_service.dart';
import 'services/navigation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'providers/location_provider.dart';
import 'widgets/main_layout.dart';
import 'screens/OrdersScreen.dart';
import 'screens/HelpScreen.dart';

// Challenge feature
import 'package:elefit_app/features/challenge/data/repositories/challenge_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_participant_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_submission_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/payment_record_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_notification_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/admin_audit_log_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/challenge_package_repository.dart';
import 'package:elefit_app/features/challenge/data/repositories/user_repository.dart';
import 'package:elefit_app/features/challenge/domain/services/admin_audit_service.dart';
import 'package:elefit_app/features/challenge/domain/services/challenge_package_service.dart';
import 'package:elefit_app/features/challenge/domain/services/challenge_notification_service.dart';
import 'package:elefit_app/features/challenge/domain/services/challenge_service.dart';
import 'package:elefit_app/features/challenge/domain/services/participant_enrollment_service.dart';
import 'package:elefit_app/features/challenge/domain/services/payment_approval_service.dart';
import 'package:elefit_app/features/challenge/domain/services/submission_review_service.dart';
import 'package:elefit_app/features/challenge/domain/services/auth_service.dart';
import 'package:elefit_app/features/challenge/presentation/providers/home_challenge_entry_provider.dart';
import 'package:elefit_app/features/challenge/presentation/providers/notification_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (core + SDK for the Challenge feature + Crashlytics)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Route uncaught framework errors to Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    // Route uncaught async errors to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    // Continue without Firebase - OneSignal handles notifications
  }

  // Initialize analytics and log app open
  await AnalyticsService.initialize();
  AnalyticsService.logAppOpened();

  // Initialize OneSignal for notifications and in-app messages.
  // Fire-and-forget — do NOT await, so the notification-permission dialog never
  // blocks first paint (the app shows immediately; the prompt appears over it).
  OneSignalService.initialize();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppTheme.surfaceColor,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (ctx) => CartModel()),
        ChangeNotifierProvider(create: (ctx) => WishlistModel()),
        ChangeNotifierProvider(create: (ctx) => AddressModel()),
        ChangeNotifierProvider(create: (ctx) => ThemeProvider()),
        ChangeNotifierProvider(create: (ctx) => LocationProvider()),
        ChangeNotifierProvider(create: (ctx) => AuthService()),
        ChangeNotifierProxyProvider<LocationProvider, ShopifyService>(
          create: (_) => ShopifyService(),
          update: (_, locationProvider, shopifyService) {
            shopifyService!.setIndiaMode(locationProvider.isInIndia);
            return shopifyService;
          },
        ),

        // Challenge feature — repositories
        Provider(create: (_) => ChallengeRepository()),
        Provider(create: (_) => ChallengeParticipantRepository()),
        Provider(create: (_) => ChallengeSubmissionRepository()),
        Provider(create: (_) => ChallengePackageRepository()),
        Provider(create: (_) => PaymentRecordRepository()),
        Provider(create: (_) => ChallengeNotificationRepository()),
        Provider(create: (_) => AdminAuditLogRepository()),
        Provider(create: (_) => UserRepository()),

        // Challenge feature — services
        ProxyProvider<AdminAuditLogRepository, AdminAuditService>(
          update: (_, repo, __) => AdminAuditService(auditLogRepository: repo),
        ),
        ProxyProvider2<ChallengePackageRepository, ChallengeParticipantRepository, ChallengePackageService>(
          update: (_, repo, repoP, __) => ChallengePackageService(
            packageRepository: repo,
            participantRepository: repoP,
          ),
        ),
        ProxyProvider3<
            ChallengeNotificationRepository,
            ChallengeParticipantRepository,
            ChallengeSubmissionRepository,
            ChallengeNotificationService>(
          update: (_, repoN, repoP, repoS, __) => ChallengeNotificationService(
            notificationRepository: repoN,
            participantRepository: repoP,
            submissionRepository: repoS,
          ),
        ),
        ProxyProvider3<ChallengeRepository, AdminAuditService, ChallengePackageRepository, ChallengeService>(
          update: (_, repo, auditS, pkgRepo, __) => ChallengeService(
            challengeRepository: repo,
            auditService: auditS,
            packageRepository: pkgRepo,
          ),
        ),
        ProxyProvider4<
            ChallengeParticipantRepository,
            ChallengeRepository,
            AdminAuditService,
            ChallengeNotificationService,
            ParticipantEnrollmentService>(
          update: (_, repoP, repoC, auditS, notifyS, __) => ParticipantEnrollmentService(
            participantRepository: repoP,
            challengeRepository: repoC,
            auditService: auditS,
            notificationService: notifyS,
          ),
        ),
        ProxyProvider5<
            PaymentRecordRepository,
            ChallengeParticipantRepository,
            ChallengeRepository,
            AdminAuditService,
            ChallengeNotificationService,
            PaymentApprovalService>(
          update: (_, repoPay, repoP, repoC, auditS, notifyS, __) => PaymentApprovalService(
            paymentRepository: repoPay,
            participantRepository: repoP,
            challengeRepository: repoC,
            auditService: auditS,
            notificationService: notifyS,
          ),
        ),
        ProxyProvider5<
            ChallengeSubmissionRepository,
            ChallengeParticipantRepository,
            ChallengeRepository,
            AdminAuditService,
            ChallengeNotificationService,
            SubmissionReviewService>(
          update: (_, repoS, repoP, repoC, auditS, notifyS, __) => SubmissionReviewService(
            submissionRepository: repoS,
            participantRepository: repoP,
            challengeRepository: repoC,
            auditService: auditS,
            notificationService: notifyS,
          ),
        ),
        ChangeNotifierProxyProvider<AuthService, HomeChallengeEntryProvider>(
          create: (ctx) => HomeChallengeEntryProvider(
            userId: ctx.read<AuthService>().currentUser?.id ?? '',
            participantRepository: ctx.read<ChallengeParticipantRepository>(),
          ),
          update: (ctx, auth, previous) {
            if (previous?.userId == auth.currentUser?.id) return previous!;
            return HomeChallengeEntryProvider(
              userId: auth.currentUser?.id ?? '',
              participantRepository: ctx.read<ChallengeParticipantRepository>(),
            );
          },
        ),
        ChangeNotifierProxyProvider<AuthService, NotificationProvider>(
          create: (ctx) => NotificationProvider(
            userId: ctx.read<AuthService>().currentUser?.id ?? '',
            notificationService: ctx.read<ChallengeNotificationService>(),
          ),
          update: (ctx, auth, previous) {
            if (previous?.userId == auth.currentUser?.id) return previous!;
            return NotificationProvider(
              userId: auth.currentUser?.id ?? '',
              notificationService: ctx.read<ChallengeNotificationService>(),
            );
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'EleFit',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          debugShowCheckedModeBanner: false,
          navigatorKey: NavigationService.navigatorKey,
          navigatorObservers: [AnalyticsService.observer],
          home: const _SplashRouter(),
          onGenerateRoute: (settings) {
            if (settings.name == '/product-details') {
              final args = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(
                builder: (context) => MainLayout(
                  currentIndex: 1, // Shop tab
                  child: ProductDetailsScreen(product: args['product']),
                ),
              );
            }
            return null;
          },
        );
      },
    );
  }
}

// Checks onboarding flag and routes to the appropriate first screen.
class _SplashRouter extends StatefulWidget {
  const _SplashRouter();

  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final prefs = await SharedPreferences.getInstance();
    final onboarded = prefs.getBool('onboarded') ?? false;

    // Silently re-establish the Firebase Auth SDK session (Challenge feature)
    // from the stored REST credentials. Must complete before routing so the
    // home screen's challenge providers see the signed-in user.
    await _ensureFirebaseSdkSession();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => onboarded
            ? MainLayout(currentIndex: 0, child: const HomeScreen())
            : const OnboardingScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }

  /// If the user has a REST session but the Firebase Auth SDK has none, sign the
  /// SDK in using the stored credentials. Firebase Auth then persists its own
  /// session across launches, so this only does real work the first time after
  /// a login. Best-effort — never blocks routing.
  Future<void> _ensureFirebaseSdkSession() async {
    try {
      if (FirebaseAuth.instance.currentUser != null) return; // already signed in
      final rest = FirebaseRestService();
      await rest.init();
      if (!rest.isLoggedIn) return; // no REST session either
      final email = rest.email;
      final password = await rest.storedPassword;
      if (email == null || password == null) {
        // Session predates password storage — user must log in once more.
        debugPrint('Startup: no stored password; SDK sign-in deferred to next login');
        return;
      }
      if (!mounted) return;
      await context.read<AuthService>().signIn(email, password);
      debugPrint('Startup: Firebase Auth SDK session restored');
    } catch (e) {
      debugPrint('Startup: could not restore Firebase Auth SDK session: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Minimal splash while SharedPreferences loads (< 100ms)
    return const Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            color: AppTheme.lime,
            strokeWidth: 2.5,
          ),
        ),
      ),
    );
  }
}
