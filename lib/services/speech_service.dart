// lib/services/speech_service.dart

import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

/// Speech Recognition Service
/// Converts spoken words to text for voice commands
class SpeechService {
  // Speech to Text instance
  final SpeechToText _speechToText = SpeechToText();

  // Track listening state
  bool _isListening = false;

  // Track initialization state
  bool _isInitialized = false;

  // Track availability
  bool _isAvailable = false;

  /// Get current listening state
  bool get isListening => _isListening;

  /// Get initialization state
  bool get isInitialized => _isInitialized;

  /// Get availability state
  bool get isAvailable => _isAvailable;

  /// Initialize Speech Recognition
  ///
  /// Requests microphone permission and initializes the speech engine.
  /// Call this once at app startup.
  ///
  /// Returns:
  ///   Future<bool> - true if successful, false otherwise
  ///
  /// Example:
  /// ```dart
  /// final speechService = SpeechService();
  /// bool success = await speechService.initialize();
  /// if (success) {
  ///   print('Speech recognition ready');
  /// }
  /// ```
  Future<bool> initialize() async {
    try {
      // Request microphone permission
      var status = await Permission.microphone.request();

      if (!status.isGranted) {
        print('Microphone permission denied');
        return false;
      }

      // Initialize speech to text
      _isAvailable = await _speechToText.initialize(
        onError: (error) {
          print('Speech recognition error: ${error.errorMsg}');
          _isListening = false;
        },
        onStatus: (status) {
          print('Speech recognition status: $status');
          if (status == 'notListening' || status == 'done') {
            _isListening = false;
          } else if (status == 'listening') {
            _isListening = true;
          }
        },
        debugLogging: true,
      );

      _isInitialized = _isAvailable;

      if (_isAvailable) {
        print('Speech recognition initialized successfully');
      } else {
        print('Speech recognition not available on this device');
      }

      return _isAvailable;

    } catch (e) {
      print('Error initializing speech recognition: $e');
      _isInitialized = false;
      _isAvailable = false;
      return false;
    }
  }

  /// Start listening for voice commands
  ///
  /// Begins listening and calls onResult when speech is recognized.
  ///
  /// Parameters:
  ///   [onResult] - Callback function called with recognized text
  ///   [onListeningComplete] - Callback when listening stops
  ///   [listenDuration] - Maximum listening duration (default: 5 seconds)
  ///
  /// Returns:
  ///   Future<void>
  ///
  /// Example:
  /// ```dart
  /// await speechService.startListening(
  ///   onResult: (text) => print('Heard: $text'),
  ///   onListeningComplete: () => print('Done listening'),
  /// );
  /// ```
  Future<void> startListening({
    required Function(String) onResult,
    required Function() onListeningComplete,
    Duration listenDuration = const Duration(seconds: 5),
  }) async {
    if (!_isAvailable) {
      print('Speech recognition not available');
      return;
    }

    if (_isListening) {
      print('Already listening');
      return;
    }

    try {
      _isListening = true;

      await _speechToText.listen(
        onResult: (result) {
          if (result.finalResult) {
            // Final result received
            final recognizedText = result.recognizedWords.toLowerCase();
            print('Final result: $recognizedText');

            _isListening = false;
            onResult(recognizedText);
            onListeningComplete();
          } else {
            // Partial result (still listening)
            print('Partial result: ${result.recognizedWords}');
          }
        },
        listenFor: listenDuration,
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      );

    } catch (e) {
      print('Error starting to listen: $e');
      _isListening = false;
      onListeningComplete();
    }
  }

  /// Start listening with custom options
  ///
  /// Advanced listening with more control over parameters.
  ///
  /// Parameters:
  ///   [onResult] - Callback for recognized text
  ///   [onListeningComplete] - Callback when done
  ///   [locale] - Language locale (e.g., "en-US", "es-ES")
  ///   [listenDuration] - How long to listen
  ///   [pauseDuration] - Silence duration before stopping
  ///   [partialResults] - Get results while speaking
  ///
  /// Returns:
  ///   Future<void>
  Future<void> startListeningCustom({
    required Function(String) onResult,
    required Function() onListeningComplete,
    String locale = 'en-US',
    Duration listenDuration = const Duration(seconds: 5),
    Duration pauseDuration = const Duration(seconds: 3),
    bool partialResults = false,
  }) async {
    if (!_isAvailable) {
      print('Speech recognition not available');
      return;
    }

    if (_isListening) {
      await stopListening();
    }

    try {
      _isListening = true;

      await _speechToText.listen(
        onResult: (result) {
          if (result.finalResult) {
            final recognizedText = result.recognizedWords.toLowerCase();
            _isListening = false;
            onResult(recognizedText);
            onListeningComplete();
          } else if (partialResults) {
            onResult(result.recognizedWords.toLowerCase());
          }
        },
        listenFor: listenDuration,
        pauseFor: pauseDuration,
        partialResults: partialResults,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
        localeId: locale,
      );

    } catch (e) {
      print('Error in custom listening: $e');
      _isListening = false;
      onListeningComplete();
    }
  }

  /// Start continuous listening (keeps listening until manually stopped)
  ///
  /// Parameters:
  ///   [onResult] - Callback for each recognized phrase
  ///   [onError] - Callback for errors
  ///
  /// Returns:
  ///   Future<void>
  Future<void> startContinuousListening({
    required Function(String) onResult,
    Function(String)? onError,
  }) async {
    if (!_isAvailable) {
      print('Speech recognition not available');
      return;
    }

    try {
      _isListening = true;

      await _speechToText.listen(
        onResult: (result) {
          if (result.finalResult) {
            onResult(result.recognizedWords.toLowerCase());
          }
        },
        listenFor: const Duration(minutes: 10), // Long duration
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      );

    } catch (e) {
      print('Error in continuous listening: $e');
      _isListening = false;
      if (onError != null) {
        onError(e.toString());
      }
    }
  }

  /// Stop listening immediately
  ///
  /// Stops speech recognition and processes any partial results.
  ///
  /// Returns:
  ///   Future<void>
  ///
  /// Example:
  /// ```dart
  /// await speechService.stopListening();
  /// ```
  Future<void> stopListening() async {
    if (_isListening) {
      try {
        await _speechToText.stop();
        _isListening = false;
        print('Stopped listening');
      } catch (e) {
        print('Error stopping listening: $e');
      }
    }
  }

  /// Cancel listening without processing
  ///
  /// Cancels recognition and discards any partial results.
  ///
  /// Returns:
  ///   Future<void>
  Future<void> cancelListening() async {
    if (_isListening) {
      try {
        await _speechToText.cancel();
        _isListening = false;
        print('Cancelled listening');
      } catch (e) {
        print('Error cancelling listening: $e');
      }
    }
  }

  /// Get available locales (languages)
  ///
  /// Returns list of supported language locales.
  ///
  /// Returns:
  ///   Future<List<LocaleName>>
  ///
  /// Example:
  /// ```dart
  /// List<LocaleName> locales = await speechService.getAvailableLocales();
  /// for (var locale in locales) {
  ///   print('${locale.name}: ${locale.localeId}');
  /// }
  /// ```
  Future<List<LocaleName>> getAvailableLocales() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      return await _speechToText.locales();
    } catch (e) {
      print('Error getting locales: $e');
      return [];
    }
  }

  /// Check if a specific locale is supported
  ///
  /// Parameters:
  ///   [localeId] - Locale identifier (e.g., "en-US")
  ///
  /// Returns:
  ///   Future<bool>
  Future<bool> isLocaleSupported(String localeId) async {
    try {
      final locales = await getAvailableLocales();
      return locales.any((locale) => locale.localeId == localeId);
    } catch (e) {
      print('Error checking locale support: $e');
      return false;
    }
  }

  /// Get system locale (device language)
  ///
  /// Returns:
  ///   Future<LocaleName?>
  Future<LocaleName?> getSystemLocale() async {
    try {
      return await _speechToText.systemLocale();
    } catch (e) {
      print('Error getting system locale: $e');
      return null;
    }
  }

  /// Check microphone permission status
  ///
  /// Returns:
  ///   Future<bool>
  Future<bool> hasMicrophonePermission() async {
    try {
      final status = await Permission.microphone.status;
      return status.isGranted;
    } catch (e) {
      print('Error checking microphone permission: $e');
      return false;
    }
  }

  /// Request microphone permission
  ///
  /// Returns:
  ///   Future<bool>
  Future<bool> requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      return status.isGranted;
    } catch (e) {
      print('Error requesting microphone permission: $e');
      return false;
    }
  }

  /// Get last recognized text
  ///
  /// Returns:
  ///   String - Last recognized words
  String getLastRecognizedWords() {
    try {
      return _speechToText.lastRecognizedWords;
    } catch (e) {
      print('Error getting last words: $e');
      return '';
    }
  }

  /// Check if device has speech recognition
  ///
  /// Returns:
  ///   Future<bool>
  Future<bool> hasRecognition() async {
    try {
      return await _speechToText.hasPermission;
    } catch (e) {
      print('Error checking recognition: $e');
      return false;
    }
  }

  /// Get current listening status
  ///
  /// Returns detailed status information
  ///
  /// Returns:
  ///   Map<String, dynamic>
  Map<String, dynamic> getStatus() {
    return {
      'isListening': _isListening,
      'isInitialized': _isInitialized,
      'isAvailable': _isAvailable,
      'hasPermission': _speechToText.hasPermission,
      'lastWords': _speechToText.lastRecognizedWords,
    };
  }

  /// Test speech recognition
  ///
  /// Quick test to verify speech recognition is working.
  ///
  /// Returns:
  ///   Future<bool>
  Future<bool> testRecognition() async {
    try {
      if (!_isInitialized) {
        bool initialized = await initialize();
        if (!initialized) return false;
      }

      bool hasPermission = await hasMicrophonePermission();
      if (!hasPermission) {
        hasPermission = await requestMicrophonePermission();
      }

      return hasPermission && _isAvailable;
    } catch (e) {
      print('Error testing recognition: $e');
      return false;
    }
  }

  /// Get error message if initialization failed
  ///
  /// Returns:
  ///   String - Error description or empty string
  String getErrorMessage() {
    if (!_isInitialized) {
      return 'Speech recognition not initialized';
    }
    if (!_isAvailable) {
      return 'Speech recognition not available on this device';
    }
    return '';
  }

  /// Clean up resources
  ///
  /// IMPORTANT: Call this in dispose() to free memory
  ///
  /// Example:
  /// ```dart
  /// @override
  /// void dispose() {
  ///   _speechService.dispose();
  ///   super.dispose();
  /// }
  /// ```
  void dispose() {
    if (_isListening) {
      stopListening();
    }
    print('Speech service disposed');
  }
}