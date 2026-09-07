import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:elefit_app/utils/app_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_coach_models.dart';
import '../config/secrets.dart';
import 'ai_coach_parser.dart';

/// Firebase REST API Service — avoids SDK version conflicts entirely.
/// Uses identitytoolkit.googleapis.com for Auth and firestore.googleapis.com for Firestore.
class FirebaseRestService {
  static const String _apiKey = Secrets.firebaseApiKey;
  static const String _projectId = 'getfit-with-elefit';
  static const String _authUrl    = 'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$_apiKey';
  static const String _signUpUrl  = 'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$_apiKey';
  static const String _resetUrl   = 'https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=$_apiKey';
  static const String _updateUrl  = 'https://identitytoolkit.googleapis.com/v1/accounts:update?key=$_apiKey';
  static const String _customTokenUrl = 'https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=$_apiKey';
  static const String _firestoreUrl = 'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents';
  static const String _tokenRefreshUrl = 'https://securetoken.googleapis.com/v1/token?key=$_apiKey';

  static const String _prefIdToken = 'fb_id_token';
  static const String _prefUid = 'fb_uid';
  static const String _prefEmail = 'fb_email';
  static const String _prefRefreshToken = 'fb_refresh_token';
  // Stored (encrypted, Keychain/Keystore) so the app can silently sign into the
  // Firebase Auth SDK on startup — the Challenge feature needs a live SDK session.
  static const String _prefPassword = 'fb_password';

  static const _secureStorage = appSecureStorage;

  String? _idToken;
  String? _uid;
  String? _email;
  String? _refreshToken;

  /// Initialize from secure storage (restore session).
  /// Migrates tokens that were previously saved in SharedPreferences.
  Future<void> init() async {
    _idToken = await _secureStorage.read(key: _prefIdToken);
    _uid = await _secureStorage.read(key: _prefUid);
    _email = await _secureStorage.read(key: _prefEmail);
    _refreshToken = await _secureStorage.read(key: _prefRefreshToken);

    // One-time migration: move tokens saved by the old SharedPreferences code
    if (_idToken == null || _uid == null) {
      final prefs = await SharedPreferences.getInstance();
      final oldToken = prefs.getString(_prefIdToken);
      final oldUid = prefs.getString(_prefUid);
      if (oldToken != null && oldUid != null) {
        _idToken = oldToken;
        _uid = oldUid;
        _email = prefs.getString(_prefEmail);
        _refreshToken = prefs.getString(_prefRefreshToken);
        await _secureStorage.write(key: _prefIdToken, value: _idToken!);
        await _secureStorage.write(key: _prefUid, value: _uid!);
        if (_email != null) await _secureStorage.write(key: _prefEmail, value: _email!);
        if (_refreshToken != null) await _secureStorage.write(key: _prefRefreshToken, value: _refreshToken!);
        await prefs.remove(_prefIdToken);
        await prefs.remove(_prefUid);
        await prefs.remove(_prefEmail);
        await prefs.remove(_prefRefreshToken);
      }
    }
  }

  bool get isLoggedIn => _idToken != null && _uid != null;
  String? get uid => _uid;
  String? get email => _email;

  /// The password saved at last login (used to silently re-establish the
  /// Firebase Auth SDK session on startup). Null for sessions created before
  /// this was added — those users must log in once more to seed it.
  Future<String?> get storedPassword => _secureStorage.read(key: _prefPassword);

  /// Create a new account via Firebase Auth REST API
  Future<Map<String, dynamic>> createAccount(String email, String password) async {
    final response = await http.post(
      Uri.parse(_signUpUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.toLowerCase().trim(),
        'password': password,
        'returnSecureToken': true,
      }),
    );
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      final message = err['error']?['message'] ?? 'Sign up failed';
      throw Exception(_friendlyAuthError(message));
    }
    final data = jsonDecode(response.body);
    _idToken      = data['idToken'];
    _uid          = data['localId'];
    _email        = data['email'];
    _refreshToken = data['refreshToken'];
    await _secureStorage.write(key: _prefIdToken,      value: _idToken!);
    await _secureStorage.write(key: _prefUid,          value: _uid!);
    await _secureStorage.write(key: _prefEmail,        value: _email!);
    await _secureStorage.write(key: _prefPassword,     value: password);
    if (_refreshToken != null) {
      await _secureStorage.write(key: _prefRefreshToken, value: _refreshToken!);
    }
    // Seed the Firestore user doc immediately so the admin dashboard can see new users.
    try {
      await updateUserProfile({
        'email': _email ?? '',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
    return data;
  }

  /// Send a password-reset email via Firebase Auth REST API
  Future<void> sendPasswordReset(String email) async {
    final response = await http.post(
      Uri.parse(_resetUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'requestType': 'PASSWORD_RESET',
        'email': email.toLowerCase().trim(),
      }),
    );
    if (response.statusCode != 200) {
      String reason = '';
      try {
        reason = (jsonDecode(response.body)['error']?['message'] ?? '').toString();
      } catch (_) {}
      if (reason.contains('EMAIL_NOT_FOUND')) {
        throw Exception('No account found with that email address.');
      }
      if (reason.contains('INVALID_EMAIL')) {
        throw Exception('That email address looks invalid.');
      }
      throw Exception('Failed to send reset email. Please try again.');
    }
  }

  // ── profiles/{uid} collection ─────────────────────────────────────────────

  /// Write all onboarding data to `profiles/{uid}`.
  /// Also back-fills key fields into `users/{uid}` for AI Coach compatibility.
  Future<void> saveOnboardingProfile(Map<String, dynamic> data) async {
    if (_uid == null || _idToken == null) throw Exception('Not logged in');

    final fields = <String, dynamic>{};
    data.forEach((k, v) => fields[k] = _valueToFirestore(v));
    fields['updatedAt'] = {'timestampValue': DateTime.now().toUtc().toIso8601String()};

    // PATCH creates or merges — works even if the document doesn't exist yet.
    final fieldPaths = fields.keys.toList();
    final mask = fieldPaths.map((p) => 'updateMask.fieldPaths=$p').join('&');
    final url = '$_firestoreUrl/profiles/$_uid?$mask';

    final response = await http.patch(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $_idToken', 'Content-Type': 'application/json'},
      body: jsonEncode({'fields': fields}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to save profile to Firebase');
    }

    // Sync key fields into users/{uid} so the AI Coach wizard can pre-fill.
    try {
      await updateUserProfile({
        'email':         _email              ?? '',
        'firstName':     data['firstName']   ?? '',
        'age':           data['age']          ?? 0,
        'height':        data['heightCm']     ?? 0,
        'weight':        data['weightKg']     ?? 0,
        'targetWeight':  data['targetWeightKg'] ?? 0,
        'gender':        data['gender']       ?? '',
        'activityLevel': data['activityLevel'] ?? '',
      });
    } catch (_) {}
  }

  /// Load onboarding profile from `profiles/{uid}`. Returns null if not found.
  Future<Map<String, dynamic>?> getOnboardingProfile() async {
    if (_uid == null || _idToken == null) return null;
    final url = '$_firestoreUrl/profiles/$_uid';
    final response = await _authenticatedGet(url);
    if (response.statusCode != 200) return null;
    final raw = jsonDecode(response.body);
    return _firestoreDocToMap(raw['fields'] ?? {});
  }

  /// Sign in with email + password via Firebase Auth REST API
  Future<Map<String, dynamic>> signIn(String email, String password) async {
    final response = await http.post(
      Uri.parse(_authUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.toLowerCase().trim(),
        'password': password,
        'returnSecureToken': true,
      }),
    );

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      final message = err['error']?['message'] ?? 'Login failed';
      throw Exception(_friendlyAuthError(message));
    }

    final data = jsonDecode(response.body);
    _idToken = data['idToken'];
    _uid = data['localId'];
    _email = data['email'];
    _refreshToken = data['refreshToken'];

    // Persist session
    await _secureStorage.write(key: _prefIdToken, value: _idToken!);
    await _secureStorage.write(key: _prefUid, value: _uid!);
    await _secureStorage.write(key: _prefEmail, value: _email!);
    await _secureStorage.write(key: _prefPassword, value: password);
    if (_refreshToken != null) await _secureStorage.write(key: _prefRefreshToken, value: _refreshToken!);

    return data;
  }

  /// Attempts sign-in; returns true on success (session established), false on a
  /// credential error (bad password / no such user), and rethrows other errors
  /// (network, too-many-attempts, disabled). Used by the Shopify bridge login.
  Future<bool> trySignIn(String email, String password) async {
    final response = await http.post(
      Uri.parse(_authUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.toLowerCase().trim(),
        'password': password,
        'returnSecureToken': true,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _idToken = data['idToken'];
      _uid = data['localId'];
      _email = data['email'];
      _refreshToken = data['refreshToken'];
      await _secureStorage.write(key: _prefIdToken, value: _idToken!);
      await _secureStorage.write(key: _prefUid, value: _uid!);
      await _secureStorage.write(key: _prefEmail, value: _email!);
      await _secureStorage.write(key: _prefPassword, value: password);
      if (_refreshToken != null) {
        await _secureStorage.write(key: _prefRefreshToken, value: _refreshToken!);
      }
      return true;
    }
    final code =
        (jsonDecode(response.body)['error']?['message'] ?? '').toString();
    if (code.contains('EMAIL_NOT_FOUND') ||
        code.contains('INVALID_PASSWORD') ||
        code.contains('INVALID_LOGIN_CREDENTIALS')) {
      return false;
    }
    throw Exception(_friendlyAuthError(code));
  }

  /// Changes the signed-in user's password (accounts:update) and refreshes the
  /// stored session. Used to sync a Shopify password into Firebase after a
  /// bridge login so future direct logins work.
  Future<void> updatePassword(String newPassword) async {
    if (_idToken == null) throw Exception('Not signed in.');
    final response = await http.post(
      Uri.parse(_updateUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'idToken': _idToken,
        'password': newPassword,
        'returnSecureToken': true,
      }),
    );
    if (response.statusCode != 200) {
      final message =
          jsonDecode(response.body)['error']?['message'] ?? 'Password update failed';
      throw Exception(_friendlyAuthError(message));
    }
    final data = jsonDecode(response.body);
    if (data['idToken'] != null) {
      _idToken = data['idToken'];
      await _secureStorage.write(key: _prefIdToken, value: _idToken!);
    }
    if (data['refreshToken'] != null) {
      _refreshToken = data['refreshToken'];
      await _secureStorage.write(key: _prefRefreshToken, value: _refreshToken!);
    }
    await _secureStorage.write(key: _prefPassword, value: newPassword);
  }

  /// Establishes the REST session from a Firebase custom token (minted server-
  /// side for a validated Shopify customer). No password is involved, so nothing
  /// about the user's credential changes.
  Future<void> signInWithCustomToken(String token, {String? email}) async {
    final response = await http.post(
      Uri.parse(_customTokenUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'returnSecureToken': true}),
    );
    if (response.statusCode != 200) {
      final message = jsonDecode(response.body)['error']?['message'] ??
          'Custom token sign-in failed';
      throw Exception(_friendlyAuthError(message));
    }
    final data = jsonDecode(response.body);
    _idToken = data['idToken'];
    _uid = data['localId'];
    _email = email ?? _email;
    _refreshToken = data['refreshToken'];
    await _secureStorage.write(key: _prefIdToken, value: _idToken!);
    await _secureStorage.write(key: _prefUid, value: _uid!);
    if (_email != null) await _secureStorage.write(key: _prefEmail, value: _email!);
    if (_refreshToken != null) {
      await _secureStorage.write(key: _prefRefreshToken, value: _refreshToken!);
    }
    // Custom-token session has no password to store; the refresh token keeps the
    // REST session alive, and the Firebase SDK persists its own session.
    await _secureStorage.delete(key: _prefPassword);
  }

  /// Sign out
  Future<void> signOut() async {
    _idToken = null;
    _uid = null;
    _email = null;
    _refreshToken = null;
    await _secureStorage.delete(key: _prefIdToken);
    await _secureStorage.delete(key: _prefUid);
    await _secureStorage.delete(key: _prefEmail);
    await _secureStorage.delete(key: _prefRefreshToken);
    await _secureStorage.delete(key: _prefPassword);
  }

  /// Get user profile from Firestore `users/{uid}`
  Future<Map<String, dynamic>?> getUserProfile([String? overrideUid]) async {
    final targetUid = overrideUid ?? _uid;
    if (targetUid == null || _idToken == null) return null;

    final url = '$_firestoreUrl/users/$targetUid';
    final response = await _authenticatedGet(url);

    if (response.statusCode != 200) return null;

    final raw = jsonDecode(response.body);
    return _firestoreDocToMap(raw['fields'] ?? {});
  }

  /// Save a fitness plan to the aiCoachSchedules subcollection.
  /// Returns the new Firestore document ID.
  Future<String> saveUserPlan(FitnessPlan plan) async {
    if (_uid == null || _idToken == null) throw Exception('Not logged in');

    final planName = plan.name.isNotEmpty ? plan.name : 'Fitness Plan - ${_fmtDate(plan.generatedDate)}';
    final effectiveStart = plan.startDate ?? plan.generatedDate;

    // Store using the same schema as the Next.js app so both platforms can read each other's plans
    final fields = <String, dynamic>{
      'name': {'stringValue': planName},
      'goal': {'stringValue': plan.goal},
      'planGenerationDate': {'stringValue': plan.generatedDate.toIso8601String()},
      'startDate': {'stringValue': effectiveStart.toIso8601String()},
      'createdAt': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
      'calculatedData': {
        'mapValue': {
          'fields': {
            'targetCalories': {'integerValue': plan.dailyCalories.toString()},
            'workoutFocus': {'stringValue': plan.workoutFocus},
            'proteinGrams': {'integerValue': (plan.macros['protein'] ?? 0).toString()},
            'carbsGrams': {'integerValue': (plan.macros['carbs'] ?? 0).toString()},
            'fatGrams': {'integerValue': (plan.macros['fat'] ?? 0).toString()},
          },
        },
      },
      // Keep planData as a fallback for the Flutter app's own reader
      'planData': {'stringValue': jsonEncode(plan.copyWith(startDate: effectiveStart).toJson())},
    };

    final url = '$_firestoreUrl/users/$_uid/aiCoachSchedules';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $_idToken', 'Content-Type': 'application/json'},
      body: jsonEncode({'fields': fields}),
    );

    if (response.statusCode != 200) throw Exception('Failed to save plan');
    final docName = (jsonDecode(response.body)['name'] as String);
    final planId = docName.split('/').last;

    // Keep legacy fitnessPlan field in sync for backward compat
    try {
      await updateUserProfile({'fitnessPlan': jsonEncode(plan.copyWith(id: planId, name: planName, startDate: effectiveStart).toJson())});
    } catch (_) {}

    return planId;
  }

  /// Returns the current active plan ID from user's Firestore profile or SharedPreferences.
  Future<String?> getActivePlanId() async {
    if (_uid == null || _idToken == null) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('active_fitness_plan_id');
    }

    try {
      final profile = await getUserProfile();
      final activeId = profile?['activeFitnessPlanId']?.toString();
      if (activeId != null && activeId.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('active_fitness_plan_id', activeId);
        return activeId;
      }
    } catch (e) {
      debugPrint('Error getting active plan ID from profile: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('active_fitness_plan_id');
  }

  /// Sets the active fitness plan ID for the authenticated user.
  Future<void> setActivePlan(String planId) async {
    if (_uid == null || _idToken == null) throw Exception('Not logged in');

    await updateUserProfile({'activeFitnessPlanId': planId});

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_fitness_plan_id', planId);
  }

  /// Clears the active fitness plan for the authenticated user.
  Future<void> clearActivePlan() async {
    if (_uid == null || _idToken == null) throw Exception('Not logged in');

    await updateUserProfile({'activeFitnessPlanId': ''});

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_fitness_plan_id');
  }

  /// Returns the full active FitnessPlan, or null if no active plan is configured.
  Future<FitnessPlan?> getActivePlan() async {
    final activeId = await getActivePlanId();
    if (activeId == null || activeId.isEmpty) return null;
    return getPlanById(activeId);
  }

  /// Fetch all saved plan summaries for the current user, newest first.
  /// Handles both Next.js format (name/planGenerationDate/calculatedData)
  /// and Flutter format (planName/generatedDate/dailyCalories).
  /// Falls back to the legacy fitnessPlan field if the subcollection is empty.
  Future<List<FitnessPlanSummary>> getUserPlans() async {
    if (_uid == null || _idToken == null) return [];

    final url = '$_firestoreUrl/users/$_uid/aiCoachSchedules';
    final response = await _authenticatedGet(url);

    List<FitnessPlanSummary> summaries = [];

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final docs = data['documents'] as List? ?? [];
      for (final doc in docs) {
        try {
          final f = _firestoreDocToMap(doc['fields'] as Map<String, dynamic>? ?? {});
          final docName = doc['name'] as String;
          final planId = docName.split('/').last;

          // Name: Flutter saves as 'planName', Next.js saves as 'name'
          final name = f['planName']?.toString().isNotEmpty == true
              ? f['planName'].toString()
              : (f['name']?.toString().isNotEmpty == true ? f['name'].toString() : 'Fitness Plan');

          // Date: Flutter saves as 'generatedDate', Next.js saves as 'planGenerationDate'
          final dateStr = (f['generatedDate']?.toString().isNotEmpty == true
              ? f['generatedDate']
              : f['planGenerationDate'])?.toString() ?? '';
          final generatedDate = DateTime.tryParse(dateStr) ?? DateTime.now();

          // Calories: Flutter saves as 'dailyCalories', Next.js nests in 'calculatedData'
          final calcData = f['calculatedData'] as Map<String, dynamic>? ?? {};
          final dailyCalories = (f['dailyCalories'] as num?)?.toInt()
              ?? (calcData['targetCalories'] as num?)?.toInt()
              ?? 0;

          // Workout focus: Flutter saves top-level, Next.js nests in 'calculatedData'
          final workoutFocus = f['workoutFocus']?.toString().isNotEmpty == true
              ? f['workoutFocus'].toString()
              : (calcData['workoutFocus']?.toString() ?? '');

          summaries.add(FitnessPlanSummary(
            id: planId,
            name: name,
            goal: f['goal']?.toString() ?? '',
            dailyCalories: dailyCalories,
            workoutFocus: workoutFocus,
            generatedDate: generatedDate,
          ));
        } catch (_) {}
      }
    }

    // Sort newest first
    summaries.sort((a, b) => b.generatedDate.compareTo(a.generatedDate));

    // Legacy fallback: if subcollection is empty, check the old fitnessPlan field
    if (summaries.isEmpty) {
      final profile = await getUserProfile();
      if (profile != null && profile['fitnessPlan'] != null) {
        try {
          final planJson = jsonDecode(profile['fitnessPlan'] as String) as Map<String, dynamic>;
          final plan = FitnessPlan.fromJson(planJson);
          summaries.add(FitnessPlanSummary(
            id: '__legacy__',
            name: plan.name.isNotEmpty ? plan.name : 'Fitness Plan - ${_fmtDate(plan.generatedDate)}',
            goal: plan.goal,
            dailyCalories: plan.dailyCalories,
            workoutFocus: plan.workoutFocus,
            generatedDate: plan.generatedDate,
          ));
        } catch (_) {}
      }
    }

    return summaries;
  }

  /// Fetch the full plan data for a specific plan ID.
  /// Handles Next.js format (raw mealPlan/workoutPlan text + calculatedData)
  /// and Flutter format (planData JSON blob), plus the legacy '__legacy__' sentinel.
  Future<FitnessPlan?> getPlanById(String planId) async {
    if (_uid == null || _idToken == null) return null;

    if (planId == '__legacy__') {
      final profile = await getUserProfile();
      if (profile == null || profile['fitnessPlan'] == null) return null;
      try {
        return FitnessPlan.fromJson(jsonDecode(profile['fitnessPlan'] as String));
      } catch (_) { return null; }
    }

    final url = '$_firestoreUrl/users/$_uid/aiCoachSchedules/$planId';
    final response = await _authenticatedGet(url);

    if (response.statusCode != 200) return null;

    try {
      final f = _firestoreDocToMap(
          (jsonDecode(response.body)['fields'] as Map<String, dynamic>?) ?? {});

      // ── Flutter format: full plan stored as JSON string in 'planData' ──
      final planDataStr = f['planData']?.toString();
      if (planDataStr != null && planDataStr.isNotEmpty) {
        final planJson = jsonDecode(planDataStr) as Map<String, dynamic>;
        return FitnessPlan.fromJson({
          ...planJson,
          'id': planId,
          'name': f['planName'] ?? f['name'] ?? planJson['name'] ?? '',
        });
      }

      // ── Next.js format: raw text in 'mealPlan' / 'workoutPlan' ──
      final mealPlanText = f['mealPlan']?.toString() ?? '';
      final workoutPlanText = f['workoutPlan']?.toString() ?? '';

      final calcData = f['calculatedData'] as Map<String, dynamic>? ?? {};
      final targetCalories = (calcData['targetCalories'] as num?)?.toInt() ?? 0;
      final workoutFocus = calcData['workoutFocus']?.toString() ?? '';
      final proteinG = (calcData['proteinGrams'] as num?)?.toInt() ?? 0;
      final carbsG = (calcData['carbsGrams'] as num?)?.toInt() ?? 0;
      final fatG = (calcData['fatGrams'] as num?)?.toInt() ?? 0;

      final dateStr = (f['planGenerationDate']?.toString().isNotEmpty == true
          ? f['planGenerationDate']
          : f['generatedDate'])?.toString() ?? '';
      final generatedDate = DateTime.tryParse(dateStr) ?? DateTime.now();

      final name = f['name']?.toString().isNotEmpty == true
          ? f['name'].toString()
          : (f['planName']?.toString().isNotEmpty == true
              ? f['planName'].toString()
              : 'Fitness Plan - ${_fmtDate(generatedDate)}');

      return FitnessPlan(
        id: planId,
        name: name,
        dailyCalories: targetCalories,
        macros: {'protein': proteinG, 'carbs': carbsG, 'fat': fatG},
        goal: f['goal']?.toString() ?? '',
        workoutFocus: workoutFocus,
        generatedDate: generatedDate,
        weeklyMeals: mealPlanText.isNotEmpty
            ? AiCoachParser.parseMealPlan(mealPlanText)
            : List.generate(7, (_) => DayMeals(mealsByTime: {})),
        weeklyWorkouts: workoutPlanText.isNotEmpty
            ? AiCoachParser.parseWorkoutPlan(workoutPlanText)
            : List.generate(7, (_) => DayWorkout(name: 'Rest Day', isRestDay: true)),
      );
    } catch (_) { return null; }
  }

  /// Deduct 1 credit from the user's balance. Throws if no credits remain.
  Future<void> decrementCredits() async {
    if (_uid == null || _idToken == null) throw Exception('Not logged in');
    final profile = await getUserProfile();
    final credits = (profile?['credits'] as num?)?.toInt() ?? 0;
    if (credits <= 0) throw Exception('No credits remaining. Purchase more credits to generate a plan.');
    await updateUserProfile({'credits': credits - 1});
  }

  /// Save fitness plan to Firestore profile as a JSON string (legacy — kept for compat)
  Future<void> saveFitnessPlan(Map<String, dynamic> planJson) async {
    final payload = jsonEncode(planJson);
    await updateUserProfile({'fitnessPlan': payload});
  }

  String _fmtDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day.toString().padLeft(2,'0')} ${m[d.month-1]} ${d.year}';
  }

  /// Update user profile in Firestore `users/{uid}`
  Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    if (_uid == null || _idToken == null) throw Exception('Not logged in');

    final fields = <String, dynamic>{};
    final fieldPaths = <String>[];

    updates.forEach((key, value) {
      fields[key] = _valueToFirestore(value);
      fieldPaths.add(key);
    });

    // Add updatedAt
    fields['updatedAt'] = {'timestampValue': DateTime.now().toUtc().toIso8601String()};
    fieldPaths.add('updatedAt');

    final mask = fieldPaths.map((p) => 'updateMask.fieldPaths=$p').join('&');
    final url = '$_firestoreUrl/users/$_uid?$mask';

    final response = await http.patch(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $_idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'fields': fields}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update profile');
    }
  }

  // --- Token refresh ---

  Future<bool> _tryRefreshToken() async {
    if (_refreshToken == null) return false;
    try {
      final response = await http.post(
        Uri.parse(_tokenRefreshUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'grant_type=refresh_token&refresh_token=$_refreshToken',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _idToken = data['id_token'] as String?;
        _uid = (data['user_id'] ?? data['localId']) as String?;
        _refreshToken = data['refresh_token'] as String?;
        if (_idToken != null) await _secureStorage.write(key: _prefIdToken, value: _idToken!);
        if (_uid != null) await _secureStorage.write(key: _prefUid, value: _uid!);
        if (_refreshToken != null) await _secureStorage.write(key: _prefRefreshToken, value: _refreshToken!);
        return true;
      }
    } catch (_) {}
    return false;
  }

  // GET with automatic token refresh on 401
  Future<http.Response> _authenticatedGet(String url) async {
    var response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $_idToken'},
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      if (await _tryRefreshToken()) {
        response = await http.get(
          Uri.parse(url),
          headers: {'Authorization': 'Bearer $_idToken'},
        );
      }
    }
    return response;
  }

  // --- Firestore value converters ---

  Map<String, dynamic> _firestoreDocToMap(Map<String, dynamic> fields) {
    final result = <String, dynamic>{};
    fields.forEach((key, value) {
      result[key] = _firestoreValueToDart(value);
    });
    return result;
  }

  dynamic _firestoreValueToDart(Map<String, dynamic> value) {
    if (value.containsKey('stringValue')) return value['stringValue'];
    if (value.containsKey('integerValue')) return int.tryParse(value['integerValue'].toString()) ?? 0;
    if (value.containsKey('doubleValue')) return value['doubleValue'];
    if (value.containsKey('booleanValue')) return value['booleanValue'];
    if (value.containsKey('nullValue')) return null;
    if (value.containsKey('timestampValue')) return value['timestampValue'];
    if (value.containsKey('arrayValue')) {
      final values = value['arrayValue']['values'] as List? ?? [];
      return values.map((v) => _firestoreValueToDart(v)).toList();
    }
    if (value.containsKey('mapValue')) {
      return _firestoreDocToMap(value['mapValue']['fields'] ?? {});
    }
    return null;
  }

  Map<String, dynamic> _valueToFirestore(dynamic value) {
    if (value == null) return {'nullValue': null};
    if (value is String) return {'stringValue': value};
    if (value is int) return {'integerValue': value.toString()};
    if (value is double) return {'doubleValue': value};
    if (value is bool) return {'booleanValue': value};
    if (value is List) {
      return {'arrayValue': {'values': value.map((v) => _valueToFirestore(v)).toList()}};
    }
    return {'stringValue': value.toString()};
  }

  String _friendlyAuthError(String code) {
    // Strip trailing detail after " : " that Firebase sometimes appends
    final base = code.contains(' : ') ? code.split(' : ').first : code;
    switch (base) {
      case 'EMAIL_NOT_FOUND':           return 'No account found with this email.';
      case 'INVALID_PASSWORD':          return 'Incorrect password.';
      case 'USER_DISABLED':             return 'This account has been disabled.';
      case 'INVALID_LOGIN_CREDENTIALS': return 'Invalid email or password.';
      case 'EMAIL_EXISTS':              return 'An account with this email already exists.';
      case 'WEAK_PASSWORD':             return 'Password must be at least 6 characters.';
      case 'INVALID_EMAIL':             return 'Please enter a valid email address.';
      case 'TOO_MANY_ATTEMPTS_TRY_LATER': return 'Too many attempts. Please try again later.';
      case 'OPERATION_NOT_ALLOWED':     return 'Sign-up is currently disabled.';
      default:                          return code;
    }
  }
}
