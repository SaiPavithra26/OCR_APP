// lib/services/tts_service.dart

import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-Speech Service
/// Converts text to spoken words for visually impaired users
class TTSService {
  // Flutter TTS instance
  final FlutterTts _flutterTts = FlutterTts();

  // Track speaking state
  bool _isSpeaking = false;

  // Track initialization state
  bool _isInitialized = false;

  /// Get current speaking state
  bool get isSpeaking => _isSpeaking;

  /// Get initialization state
  bool get isInitialized => _isInitialized;

  /// Initialize Text-to-Speech engine
  ///
  /// Sets up language, speech rate, volume, and event handlers.
  /// Call this once at app startup.
  ///
  /// Returns:
  ///   Future<void>
  ///
  /// Example:
  /// ```dart
  /// final ttsService = TTSService();
  /// await ttsService.initialize();
  /// ```
  Future<void> initialize() async {
    try {
      // Configure TTS settings
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);  // 0.5 = slower, 1.0 = normal
      await _flutterTts.setVolume(1.0);      // 0.0 to 1.0
      await _flutterTts.setPitch(1.0);       // 0.5 to 2.0

      // For Android - set engine parameters
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
      );

      // Set up event handlers
      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        print('TTS: Started speaking');
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        print('TTS: Completed speaking');
      });

      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
        print('TTS: Cancelled speaking');
      });

      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        print('TTS Error: $msg');
      });

      _flutterTts.setPauseHandler(() {
        print('TTS: Paused');
      });

      _flutterTts.setContinueHandler(() {
        print('TTS: Continued');
      });

      _isInitialized = true;
      print('TTS: Initialized successfully');

    } catch (e) {
      print('Error initializing TTS: $e');
      _isInitialized = false;
    }
  }

  /// Speak the given text
  ///
  /// Stops any ongoing speech and speaks the new text.
  ///
  /// Parameters:
  ///   [text] - Text to be spoken
  ///
  /// Returns:
  ///   Future<void>
  ///
  /// Example:
  /// ```dart
  /// await ttsService.speak('Hello, welcome to the app');
  /// ```
  Future<void> speak(String text) async {
    if (text.isEmpty) {
      print('TTS: Empty text, nothing to speak');
      return;
    }

    try {
      // Stop any ongoing speech
      await stop();

      // Small delay to ensure previous speech stopped
      await Future.delayed(const Duration(milliseconds: 100));

      // Speak the new text
      print('TTS: Speaking: ${text.substring(0, text.length > 50 ? 50 : text.length)}...');
      await _flutterTts.speak(text);

    } catch (e) {
      print('Error speaking: $e');
      _isSpeaking = false;
    }
  }

  /// Speak long text with pauses between sentences
  ///
  /// Breaks text into sentences and speaks each one with natural pauses.
  /// Useful for reading long extracted text.
  ///
  /// Parameters:
  ///   [text] - Long text to be spoken
  ///
  /// Returns:
  ///   Future<void>
  ///
  /// Example:
  /// ```dart
  /// await ttsService.speakLongText(longExtractedText);
  /// ```
  Future<void> speakLongText(String text) async {
    if (text.isEmpty) return;

    try {
      // Stop any ongoing speech
      await stop();

      // Split text into sentences
      List<String> sentences = text.split(RegExp(r'[.!?]+'));

      // Speak each sentence
      for (String sentence in sentences) {
        String trimmed = sentence.trim();

        if (trimmed.isEmpty) continue;

        // Speak the sentence
        await speak(trimmed);

        // Wait for this sentence to complete
        while (_isSpeaking) {
          await Future.delayed(const Duration(milliseconds: 100));
        }

        // Small pause between sentences
        await Future.delayed(const Duration(milliseconds: 300));
      }

    } catch (e) {
      print('Error speaking long text: $e');
      _isSpeaking = false;
    }
  }

  /// Stop speaking immediately
  ///
  /// Interrupts any ongoing speech.
  ///
  /// Returns:
  ///   Future<void>
  ///
  /// Example:
  /// ```dart
  /// await ttsService.stop();
  /// ```
  Future<void> stop() async {
    if (_isSpeaking) {
      try {
        await _flutterTts.stop();
        _isSpeaking = false;
        print('TTS: Stopped speaking');
      } catch (e) {
        print('Error stopping TTS: $e');
      }
    }
  }

  /// Pause speaking
  ///
  /// Pauses current speech (can be resumed).
  /// Note: Not all platforms support pause/resume.
  ///
  /// Returns:
  ///   Future<void>
  Future<void> pause() async {
    try {
      await _flutterTts.pause();
      print('TTS: Paused');
    } catch (e) {
      print('Error pausing TTS: $e');
    }
  }

  /// Set speech rate (speed)
  ///
  /// Parameters:
  ///   [rate] - Speed of speech (0.0 to 1.0)
  ///            0.0 = very slow, 0.5 = normal, 1.0 = fast
  ///
  /// Returns:
  ///   Future<void>
  ///
  /// Example:
  /// ```dart
  /// await ttsService.setSpeechRate(0.6); // Slightly slower
  /// ```
  Future<void> setSpeechRate(double rate) async {
    try {
      // Clamp rate between 0.0 and 1.0
      double clampedRate = rate.clamp(0.0, 1.0);
      await _flutterTts.setSpeechRate(clampedRate);
      print('TTS: Speech rate set to $clampedRate');
    } catch (e) {
      print('Error setting speech rate: $e');
    }
  }

  /// Set volume
  ///
  /// Parameters:
  ///   [volume] - Volume level (0.0 to 1.0)
  ///              0.0 = silent, 1.0 = maximum
  ///
  /// Returns:
  ///   Future<void>
  Future<void> setVolume(double volume) async {
    try {
      double clampedVolume = volume.clamp(0.0, 1.0);
      await _flutterTts.setVolume(clampedVolume);
      print('TTS: Volume set to $clampedVolume');
    } catch (e) {
      print('Error setting volume: $e');
    }
  }

  /// Set pitch (tone)
  ///
  /// Parameters:
  ///   [pitch] - Pitch level (0.5 to 2.0)
  ///             0.5 = low, 1.0 = normal, 2.0 = high
  ///
  /// Returns:
  ///   Future<void>
  Future<void> setPitch(double pitch) async {
    try {
      double clampedPitch = pitch.clamp(0.5, 2.0);
      await _flutterTts.setPitch(clampedPitch);
      print('TTS: Pitch set to $clampedPitch');
    } catch (e) {
      print('Error setting pitch: $e');
    }
  }

  /// Set language
  ///
  /// Parameters:
  ///   [language] - Language code (e.g., "en-US", "es-ES", "fr-FR")
  ///
  /// Returns:
  ///   Future<void>
  ///
  /// Example:
  /// ```dart
  /// await ttsService.setLanguage("es-ES"); // Spanish
  /// ```
  Future<void> setLanguage(String language) async {
    try {
      await _flutterTts.setLanguage(language);
      print('TTS: Language set to $language');
    } catch (e) {
      print('Error setting language: $e');
    }
  }

  /// Get available languages
  ///
  /// Returns list of language codes supported by the device.
  ///
  /// Returns:
  ///   Future<List<String>>
  Future<List<String>> getAvailableLanguages() async {
    try {
      final languages = await _flutterTts.getLanguages;
      return List<String>.from(languages);
    } catch (e) {
      print('Error getting languages: $e');
      return ['en-US']; // Return default
    }
  }

  /// Get available voices for current language
  ///
  /// Returns:
  ///   Future<List<String>>
  Future<List<String>> getAvailableVoices() async {
    try {
      final voices = await _flutterTts.getVoices;
      return List<String>.from(voices);
    } catch (e) {
      print('Error getting voices: $e');
      return [];
    }
  }

  /// Set specific voice
  ///
  /// Parameters:
  ///   [voice] - Voice name from getAvailableVoices()
  ///
  /// Returns:
  ///   Future<void>
  Future<void> setVoice(Map<String, String> voice) async {
    try {
      await _flutterTts.setVoice(voice);
      print('TTS: Voice set to ${voice['name']}');
    } catch (e) {
      print('Error setting voice: $e');
    }
  }

  /// Check if TTS is available on device
  ///
  /// Returns:
  ///   Future<bool>
  Future<bool> isAvailable() async {
    try {
      final languages = await _flutterTts.getLanguages;
      return languages.isNotEmpty;
    } catch (e) {
      print('TTS not available: $e');
      return false;
    }
  }

  /// Speak text character by character (for spelling)
  ///
  /// Parameters:
  ///   [text] - Text to spell out
  ///
  /// Returns:
  ///   Future<void>
  Future<void> spellOut(String text) async {
    if (text.isEmpty) return;

    try {
      await stop();

      for (int i = 0; i < text.length; i++) {
        String char = text[i];
        await speak(char);

        // Wait for character to be spoken
        while (_isSpeaking) {
          await Future.delayed(const Duration(milliseconds: 50));
        }

        // Pause between characters
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } catch (e) {
      print('Error spelling out text: $e');
    }
  }

  /// Get current TTS engine information
  ///
  /// Returns:
  ///   Future<Map<String, dynamic>>
  Future<Map<String, dynamic>> getEngineInfo() async {
    try {
      return {
        'initialized': _isInitialized,
        'speaking': _isSpeaking,
        'languages': await getAvailableLanguages(),
        'available': await isAvailable(),
      };
    } catch (e) {
      print('Error getting engine info: $e');
      return {
        'initialized': _isInitialized,
        'speaking': _isSpeaking,
        'error': e.toString(),
      };
    }
  }

  /// Clean up resources
  ///
  /// IMPORTANT: Call this in dispose() to free memory
  ///
  /// Example:
  /// ```dart
  /// @override
  /// void dispose() {
  ///   _ttsService.dispose();
  ///   super.dispose();
  /// }
  /// ```
  void dispose() {
    stop();
    print('TTS: Service disposed');
  }
}