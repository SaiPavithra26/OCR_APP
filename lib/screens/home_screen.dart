// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import 'dart:io';
import '../services/ocr_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../services/firebase_service.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Service instances
  final OCRService _ocrService = OCRService();
  final SpeechService _speechService = SpeechService();
  final TTSService _ttsService = TTSService();
  final FirebaseService _firebaseService = FirebaseService();
  final ImagePicker _picker = ImagePicker();

  // State variables
  String _extractedText = '';
  File? _selectedImage;
  bool _isLoading = false;
  bool _isListening = false;
  String _statusMessage = 'Tap microphone to start';
  Color _statusColor = Colors.blue;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  /// Initialize all services on app start
  Future<void> _initializeServices() async {
    try {
      // Initialize Text-to-Speech
      await _ttsService.initialize();

      // Initialize Speech Recognition
      bool speechAvailable = await _speechService.initialize();

      if (!speechAvailable) {
        _updateStatus('Speech recognition not available', Colors.orange);
      }

      // Welcome message after 1 second
      await Future.delayed(const Duration(seconds: 1));
      await _ttsService.speak(
          'Welcome to Accessible OCR. Ready to assist you. '
              'Say capture to take a photo, or say help for available commands.'
      );

    } catch (e) {
      print('Error initializing services: $e');
      _updateStatus('Error initializing app', Colors.red);
    }
  }

  /// Update status message and color
  void _updateStatus(String message, Color color) {
    setState(() {
      _statusMessage = message;
      _statusColor = color;
    });
  }

  /// Provide haptic feedback
  void _vibrate() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100);
    }
  }

  /// Request camera and microphone permissions
  bool _isRequestingPermission = false;

  Future<bool> _requestPermissions() async {
    if (_isRequestingPermission) return false;
    _isRequestingPermission = true;

    final statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    _isRequestingPermission = false;

    return statuses.values.every((status) => status.isGranted);
  }

  /// Start listening for voice commands
  Future<void> _startListening() async {
    if (_isLoading || _isListening) return;

    bool hasPermissions = await _requestPermissions();
    if (!hasPermissions) {
      await _ttsService.speak('Microphone permission required');
      return;
    }

    _vibrate();
    await _ttsService.stop();
    await _ttsService.speak('Listening');

    _updateStatus('Listening for command...', Colors.blue);

    setState(() => _isListening = true);

    await _speechService.startListening(
      onResult: (command) => _processVoiceCommand(command),
      onListeningComplete: () {
        setState(() => _isListening = false);
        _updateStatus('Tap microphone to start', Colors.blue);
      },
    );
  }


  /// Process recognized voice command
  Future<void> _processVoiceCommand(String command) async {
    print('Voice command received: $command');
    _vibrate();

    // Capture commands
    if (command.contains('capture') ||
        command.contains('take photo') ||
        command.contains('camera') ||
        command.contains('picture')) {
      await _captureImage();
    }
    // Read commands
    else if (command.contains('read') ||
        command.contains('speak') ||
        command.contains('say')) {
      await _readText();
    }
    // Stop commands
    else if (command.contains('stop') ||
        command.contains('pause')) {
      await _stopReading();
    }
    // History commands
    else if (command.contains('history') ||
        command.contains('past') ||
        command.contains('previous')) {
      _openHistory();
    }
    // Help commands
    else if (command.contains('help') ||
        command.contains('command') ||
        command.contains('what can')) {
      await _showHelp();
    }
    // Gallery commands
    else if (command.contains('gallery') ||
        command.contains('photo')) {
      await _pickFromGallery();
    }
    // Unknown command
    else {
      await _ttsService.speak(
          'Command not recognized. Say help for available commands.'
      );
    }
  }

  /// Capture image from camera
  /// Capture image from camera
  Future<void> _captureImage() async {
    try {
      setState(() {
        _selectedImage = null; // clear previous image
      });

      bool hasPermissions = await _requestPermissions();
      if (!hasPermissions) {
        await _ttsService.speak('Camera permission required');
        return;
      }

      await _ttsService.speak('Opening camera');
      _updateStatus('Opening camera...', Colors.green);

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (image == null) {
        await _ttsService.speak('No image captured');
        _updateStatus('Tap microphone to start', Colors.blue);
        return;
      }

      await _processImage(image.path);

    } catch (e) {
      print('Error capturing image: $e');
      _updateStatus('Error capturing image', Colors.red);
      await _ttsService.speak(
        'Error capturing image. Please try again.',
      );
    }
  }


  /// Pick image from gallery
  Future<void> _pickFromGallery() async {
    try {
      await _ttsService.speak('Opening gallery');
      _updateStatus('Opening gallery...', Colors.green);

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (image == null) {
        await _ttsService.speak('No image selected');
        _updateStatus('Tap microphone to start', Colors.blue);
        return;
      }

      await _processImage(image.path);

    } catch (e) {
      print('Error picking image: $e');
      _updateStatus('Error selecting image', Colors.red);
      await _ttsService.speak('Error selecting image. Please try again.');
    }
  }

  /// Process captured or selected image
  Future<void> _processImage(String imagePath) async {
    setState(() {
      _selectedImage = File(imagePath);
      _isLoading = true;
    });

    _updateStatus('Processing image...', Colors.orange);
    await _ttsService.speak('Processing image. Please wait.');

    try {
      // Extract text using OCR
      final text = await _ocrService.extractTextFromImage(imagePath);

      setState(() {
        _extractedText = text;
        _isLoading = false;
      });

      _vibrate();

      // Handle extraction results
      if (text.contains('No text found') || text.contains('Error')) {
        _updateStatus(text, Colors.orange);
        await _ttsService.speak(text);
      } else {
        _updateStatus('Text extracted successfully', Colors.green);
        await _ttsService.speak(
            'Text extracted successfully. Say read it to hear the text, or capture for a new photo.'
        );

        // Save to Firebase in background
        _saveToFirebase(text, imagePath);
      }

    } catch (e) {
      print('Error processing image: $e');
      setState(() {
        _isLoading = false;
        _extractedText = 'Error processing image';
      });
      _updateStatus('Error processing image', Colors.red);
      await _ttsService.speak('Error processing image. Please try again.');
    }
  }

  /// Save OCR result to Firebase
  Future<void> _saveToFirebase(String text, String imagePath) async {
    try {
      final imageUrl = await _firebaseService.uploadImage(imagePath);
      await _firebaseService.saveOCRResult(text, imageUrl);
      print('Successfully saved to Firebase');
    } catch (e) {
      print('Error saving to Firebase: $e');
      // Don't show error to user, as this is background operation
    }
  }

  /// Read extracted text aloud
  Future<void> _readText() async {
    if (_extractedText.isEmpty) {
      await _ttsService.speak('No text available. Please capture an image first.');
      return;
    }

    if (_extractedText.contains('No text found') || _extractedText.contains('Error')) {
      await _ttsService.speak(_extractedText);
      return;
    }

    _vibrate();
    _updateStatus('Reading text...', Colors.purple);
    await _ttsService.speak('Reading text now.');
    await _ttsService.speakLongText(_extractedText);
    _updateStatus('Tap microphone to start', Colors.blue);
  }

  /// Stop text-to-speech
  Future<void> _stopReading() async {
    await _ttsService.stop();
    _vibrate();
    _updateStatus('Stopped', Colors.blue);
    await _ttsService.speak('Stopped');
  }

  /// Open history screen
  void _openHistory() {
    _ttsService.speak('Opening history');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HistoryScreen()),
    );
  }

  /// Show help commands
  Future<void> _showHelp() async {
    await _ttsService.speak(
        'Available commands: '
            'Say capture or take photo to use camera. '
            'Say gallery to select from photos. '
            'Say read it to hear extracted text. '
            'Say stop to stop reading. '
            'Say history to view past scans. '
            'Say help to repeat these commands.'
    );
  }

  @override
  void dispose() {
    _ocrService.dispose();
    _speechService.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📷 Accessible OCR'),
        actions: [
          // History button
          IconButton(
            icon: const Icon(Icons.history, size: 32),
            onPressed: _openHistory,
            tooltip: 'View History',
          ),
          // Help button
          IconButton(
            icon: const Icon(Icons.help_outline, size: 32),
            onPressed: _showHelp,
            tooltip: 'Help',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Status Card
              Card(
                color: _isListening
                    ? Colors.blue.shade50
                    : Colors.grey.shade50,
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        size: 48,
                        color: _statusColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _statusMessage,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _statusColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Image Preview
              Expanded(
                child: _selectedImage != null
                    ? Card(
                  elevation: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      _selectedImage!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
                  ),
                )
                    : Card(
                  color: Colors.grey.shade100,
                  elevation: 2,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_camera,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No image captured',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Say "Capture" or tap camera button',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Loading Indicator
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(
                        strokeWidth: 4,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Processing image...',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),

              // Control Buttons
              if (!_isLoading)
                Row(
                  children: [
                    // Voice Command Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _startListening,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isListening
                              ? Colors.red
                              : Colors.blue,
                          padding: const EdgeInsets.all(24),
                          elevation: 4,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              size: 40,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isListening ? 'Listening...' : 'Voice\nCommand',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Camera Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _captureImage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.all(24),
                          elevation: 4,
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.camera_alt, size: 40),
                            SizedBox(height: 8),
                            Text(
                              'Capture\nPhoto',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      // Floating Action Button for Read
      floatingActionButton: _extractedText.isNotEmpty &&
          !_extractedText.contains('No text found') &&
          !_extractedText.contains('Error')
          ? FloatingActionButton.extended(
        onPressed: _readText,
        backgroundColor: Colors.purple,
        icon: const Icon(Icons.volume_up, size: 28),
        label: const Text(
          'Read Text',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      )
          : null,
    );
  }
}