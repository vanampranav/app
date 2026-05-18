import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Firebase REST API Service — avoids SDK version conflicts entirely.
/// Uses identitytoolkit.googleapis.com for Auth and firestore.googleapis.com for Firestore.
class FirebaseRestService {
  static const String _apiKey = 'AIzaSyA2zu144EAVw0j7lC9uTyjPfBmSW7jHEbU';
  static const String _projectId = 'getfit-with-elefit';
  static const String _authUrl = 'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$_apiKey';
  static const String _firestoreUrl = 'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents';

  static const String _prefIdToken = 'fb_id_token';
  static const String _prefUid = 'fb_uid';
  static const String _prefEmail = 'fb_email';

  String? _idToken;
  String? _uid;
  String? _email;

  /// Initialize from SharedPreferences (restore session)
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _idToken = prefs.getString(_prefIdToken);
    _uid = prefs.getString(_prefUid);
    _email = prefs.getString(_prefEmail);
  }

  bool get isLoggedIn => _idToken != null && _uid != null;
  String? get uid => _uid;
  String? get email => _email;

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

    // Persist session
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefIdToken, _idToken!);
    await prefs.setString(_prefUid, _uid!);
    await prefs.setString(_prefEmail, _email!);

    return data;
  }

  /// Sign out
  Future<void> signOut() async {
    _idToken = null;
    _uid = null;
    _email = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefIdToken);
    await prefs.remove(_prefUid);
    await prefs.remove(_prefEmail);
  }

  /// Get user profile from Firestore `users/{uid}`
  Future<Map<String, dynamic>?> getUserProfile([String? overrideUid]) async {
    final targetUid = overrideUid ?? _uid;
    if (targetUid == null || _idToken == null) return null;

    final url = '$_firestoreUrl/users/$targetUid';
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $_idToken'},
    );

    if (response.statusCode != 200) return null;

    final raw = jsonDecode(response.body);
    return _firestoreDocToMap(raw['fields'] ?? {});
  }

  /// Save fitness plan to Firestore profile as a JSON string
  Future<void> saveFitnessPlan(Map<String, dynamic> planJson) async {
    final payload = jsonEncode(planJson);
    await updateUserProfile({'fitnessPlan': payload});
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
    switch (code) {
      case 'EMAIL_NOT_FOUND': return 'No account found with this email';
      case 'INVALID_PASSWORD': return 'Incorrect password';
      case 'USER_DISABLED': return 'This account has been disabled';
      case 'INVALID_LOGIN_CREDENTIALS': return 'Invalid email or password';
      default: return code;
    }
  }
}
