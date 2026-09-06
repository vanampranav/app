import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

abstract class ISpeechProvider {
  bool get isAvailable;
  bool get isListening;
  String? get errorState;
  List<LocaleName> get availableLocales;

  Future<bool> initialize();

  Future<void> startListening({
    required Function(String transcript, bool isFinal) onResult,
    required Function(String error) onError,
    required VoidCallback onStatusChanged,
    String? localeId,
  });

  Future<void> stopListening();
  Future<void> cancelListening();
}

class NativeSpeechProvider implements ISpeechProvider {
  final SpeechToText _speech = SpeechToText();
  bool _isAvailable = false;
  String? _errorState;
  List<LocaleName> _availableLocales = [];

  @override
  bool get isAvailable => _isAvailable;

  @override
  bool get isListening => _speech.isListening;

  @override
  String? get errorState => _errorState;

  @override
  List<LocaleName> get availableLocales => _availableLocales;

  @override
  Future<bool> initialize() async {
    if (_isAvailable) return true;
    try {
      _isAvailable = await _speech.initialize(
        onError: (errorNotification) {
          _errorState = errorNotification.errorMsg;
          debugPrint('SpeechToText onError: ${errorNotification.errorMsg}');
        },
        onStatus: (status) {
          debugPrint('SpeechToText onStatus: $status');
        },
      );
      if (_isAvailable) {
        _availableLocales = await _speech.locales();
      }
      return _isAvailable;
    } catch (e) {
      _errorState = e.toString();
      debugPrint('Error initializing SpeechToText: $e');
      return false;
    }
  }

  @override
  Future<void> startListening({
    required Function(String transcript, bool isFinal) onResult,
    required Function(String error) onError,
    required VoidCallback onStatusChanged,
    String? localeId,
  }) async {
    _errorState = null;
    if (!_isAvailable) {
      final ok = await initialize();
      if (!ok) {
        onError(_errorState ?? 'Speech recognition is not available on this device.');
        return;
      }
    }

    try {
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.confirmation,
          partialResults: true,
          cancelOnError: true,
        ),
        localeId: localeId,
      );
      onStatusChanged();
    } catch (e) {
      _errorState = e.toString();
      onError('I couldn\'t hear anything. Try again.');
      onStatusChanged();
    }
  }

  @override
  Future<void> stopListening() async {
    try {
      await _speech.stop();
    } catch (e) {
      debugPrint('Error stopping speech: $e');
    }
  }

  @override
  Future<void> cancelListening() async {
    try {
      await _speech.cancel();
    } catch (e) {
      debugPrint('Error canceling speech: $e');
    }
  }
}

class SpeechInputService {
  final ISpeechProvider _provider;

  SpeechInputService({ISpeechProvider? provider})
      : _provider = provider ?? NativeSpeechProvider();

  bool get isAvailable => _provider.isAvailable;
  bool get isListening => _provider.isListening;
  String? get errorState => _provider.errorState;
  List<LocaleName> get availableLocales => _provider.availableLocales;

  Future<bool> initialize() async {
    return await _provider.initialize();
  }

  /// Resolve target speech locale according to precedence:
  /// 1. user-selected speechLocale
  /// 2. device/system speech locale (if supported by speech engine)
  /// 3. en-IN (when EleFit/user context indicates Indian English)
  /// 4. safe available locale fallback
  String? resolveTargetLocale(String? userSelectedSpeechLocale) {
    if (userSelectedSpeechLocale != null && userSelectedSpeechLocale.isNotEmpty) {
      return userSelectedSpeechLocale;
    }

    final locales = availableLocales;
    if (locales.isEmpty) return null;

    String norm(String tag) => tag.toLowerCase().replaceAll('-', '_');

    // 2. Check device/system locale
    try {
      final systemLocale = PlatformDispatcher.instance.locale;
      final systemTag = norm(systemLocale.toLanguageTag());
      final systemCode = norm(systemLocale.languageCode);

      final matchSystemTag = locales.cast<LocaleName?>().firstWhere(
            (l) => l != null && norm(l.localeId) == systemTag,
            orElse: () => null,
          );
      if (matchSystemTag != null) {
        return matchSystemTag.localeId;
      }

      final matchSystemCode = locales.cast<LocaleName?>().firstWhere(
            (l) => l != null && norm(l.localeId).startsWith(systemCode),
            orElse: () => null,
          );
      if (matchSystemCode != null) {
        return matchSystemCode.localeId;
      }
    } catch (e) {
      debugPrint('Error inspecting system locale: $e');
    }

    // 3. Fallback to en-IN for EleFit context
    final enIn = locales.cast<LocaleName?>().firstWhere(
          (l) => l != null && norm(l.localeId) == 'en_in',
          orElse: () => null,
        );
    if (enIn != null) {
      return enIn.localeId;
    }

    // 4. Safe available locale fallback
    return locales.first.localeId;
  }

  Future<void> startListening({
    required Function(String transcript, bool isFinal) onResult,
    required Function(String error) onError,
    required VoidCallback onStatusChanged,
    String? localeId,
  }) async {
    final targetLocale = resolveTargetLocale(localeId);
    debugPrint('Starting speech input with localeId: $targetLocale');

    await _provider.startListening(
      onResult: onResult,
      onError: onError,
      onStatusChanged: onStatusChanged,
      localeId: targetLocale,
    );
  }

  Future<void> stopListening() async {
    await _provider.stopListening();
  }

  Future<void> cancelListening() async {
    await _provider.cancelListening();
  }
}
