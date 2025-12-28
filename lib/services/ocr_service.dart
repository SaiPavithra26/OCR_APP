// lib/services/ocr_service.dart

import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Service class for Optical Character Recognition (OCR)
/// Uses Google ML Kit for text recognition from images
class OCRService {
  // Text recognizer instance from Google ML Kit
  final TextRecognizer _textRecognizer = TextRecognizer();

  /// Extract text from an image file
  ///
  /// Takes an image file path and returns the extracted text.
  /// Returns error messages if no text is found or if extraction fails.
  ///
  /// Parameters:
  ///   [imagePath] - Full path to the image file on device
  ///
  /// Returns:
  ///   String containing extracted text or error message
  ///
  /// Example:
  /// ```dart
  /// final ocrService = OCRService();
  /// String text = await ocrService.extractTextFromImage('/path/to/image.jpg');
  /// print(text);
  /// ```
  Future<String> extractTextFromImage(String imagePath) async {
    try {
      // Validate image file exists
      final file = File(imagePath);
      if (!await file.exists()) {
        return 'Error: Image file not found';
      }

      // Create InputImage from file path
      final inputImage = InputImage.fromFilePath(imagePath);

      // Process image with ML Kit text recognizer
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      // Extract and clean the text
      String extractedText = recognizedText.text.trim();

      // Check if any text was found
      if (extractedText.isEmpty) {
        return 'No text found in the image. Please try again with a clearer image.';
      }

      // Return the extracted text
      return extractedText;

    } on Exception catch (e) {
      // Handle ML Kit specific exceptions
      print('ML Kit Exception: $e');
      return 'Error: Could not process image. Please try again.';
    } catch (e) {
      // Handle general errors
      print('Error extracting text: $e');
      return 'Error: Could not extract text from image. Please try again.';
    }
  }

  /// Extract text with detailed block information
  ///
  /// Returns structured data including text blocks, lines, and bounding boxes.
  /// Useful for advanced text processing and layout analysis.
  ///
  /// Parameters:
  ///   [imagePath] - Full path to the image file
  ///
  /// Returns:
  ///   Map containing fullText, blocks array, and block count
  Future<Map<String, dynamic>> extractTextWithDetails(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      List<Map<String, dynamic>> blocks = [];

      // Process each text block detected in the image
      for (TextBlock block in recognizedText.blocks) {
        List<Map<String, dynamic>> lines = [];

        // Process each line within the block
        for (TextLine line in block.lines) {
          List<Map<String, dynamic>> elements = [];

          // Process each element (word) within the line
          for (TextElement element in line.elements) {
            elements.add({
              'text': element.text,
              'boundingBox': {
                'left': element.boundingBox.left,
                'top': element.boundingBox.top,
                'right': element.boundingBox.right,
                'bottom': element.boundingBox.bottom,
              },
            });
          }

          lines.add({
            'text': line.text,
            'confidence': line.confidence,
            'elements': elements,
            'boundingBox': {
              'left': line.boundingBox.left,
              'top': line.boundingBox.top,
              'right': line.boundingBox.right,
              'bottom': line.boundingBox.bottom,
            },
          });
        }

        blocks.add({
          'text': block.text,
          'lines': lines,
          'boundingBox': {
            'left': block.boundingBox.left,
            'top': block.boundingBox.top,
            'right': block.boundingBox.right,
            'bottom': block.boundingBox.bottom,
          },
          'recognizedLanguages': block.recognizedLanguages,
        });
      }

      return {
        'fullText': recognizedText.text,
        'blocks': blocks,
        'blockCount': recognizedText.blocks.length,
        'success': true,
      };

    } catch (e) {
      print('Error extracting text with details: $e');
      return {
        'fullText': 'Error extracting text',
        'blocks': [],
        'blockCount': 0,
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Quick check if image contains any readable text
  ///
  /// Performs fast text detection without full extraction.
  /// Useful for pre-validation before processing.
  ///
  /// Parameters:
  ///   [imagePath] - Full path to the image file
  ///
  /// Returns:
  ///   bool - true if text is detected, false otherwise
  Future<bool> hasText(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      return recognizedText.text.trim().isNotEmpty;
    } catch (e) {
      print('Error checking for text: $e');
      return false;
    }
  }

  /// Extract only numbers from image
  ///
  /// Filters extracted text to return only numeric characters.
  /// Useful for reading numbers, phone numbers, prices, etc.
  ///
  /// Parameters:
  ///   [imagePath] - Full path to the image file
  ///
  /// Returns:
  ///   String containing only numbers, or error message
  Future<String> extractNumbers(String imagePath) async {
    try {
      String fullText = await extractTextFromImage(imagePath);

      if (fullText.contains('Error') || fullText.contains('No text found')) {
        return fullText;
      }

      // Extract only digits, spaces, and common number separators
      String numbers = fullText.replaceAll(RegExp(r'[^0-9\s\.,\-\+]'), '');
      numbers = numbers.trim();

      if (numbers.isEmpty) {
        return 'No numbers found in the image';
      }

      return numbers;
    } catch (e) {
      print('Error extracting numbers: $e');
      return 'Error extracting numbers';
    }
  }

  /// Get word count from extracted text
  ///
  /// Parameters:
  ///   [imagePath] - Full path to the image file
  ///
  /// Returns:
  ///   int - Number of words detected
  Future<int> getWordCount(String imagePath) async {
    try {
      String text = await extractTextFromImage(imagePath);

      if (text.contains('Error') || text.contains('No text found')) {
        return 0;
      }

      // Split by whitespace and count non-empty words
      List<String> words = text.split(RegExp(r'\s+'));
      words.removeWhere((word) => word.isEmpty);

      return words.length;
    } catch (e) {
      print('Error getting word count: $e');
      return 0;
    }
  }

  /// Extract text and format it with line breaks preserved
  ///
  /// Maintains the original line structure from the image.
  ///
  /// Parameters:
  ///   [imagePath] - Full path to the image file
  ///
  /// Returns:
  ///   String with line breaks preserved
  Future<String> extractTextWithLineBreaks(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      if (recognizedText.blocks.isEmpty) {
        return 'No text found in the image';
      }

      StringBuffer formattedText = StringBuffer();

      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          formattedText.writeln(line.text);
        }
        formattedText.writeln(); // Add extra line between blocks
      }

      return formattedText.toString().trim();
    } catch (e) {
      print('Error extracting text with line breaks: $e');
      return 'Error extracting text';
    }
  }

  /// Validate if text recognizer is ready
  ///
  /// Returns:
  ///   bool - true if service is ready to use
  bool isReady() {
    return true; // ML Kit text recognizer is always ready once initialized
  }

  /// Get supported languages (informational)
  ///
  /// Returns list of language codes supported by ML Kit text recognition
  List<String> getSupportedLanguages() {
    return [
      'en', 'es', 'fr', 'de', 'it', 'pt', 'nl', 'pl', 'ru',
      'ja', 'ko', 'zh', 'ar', 'hi', 'th', 'vi', 'id', 'tr'
    ];
  }

  /// Clean up resources
  ///
  /// IMPORTANT: Call this when you're done using the OCR service
  /// to free up memory and resources. Typically called in dispose().
  ///
  /// Example:
  /// ```dart
  /// @override
  /// void dispose() {
  ///   _ocrService.dispose();
  ///   super.dispose();
  /// }
  /// ```
  void dispose() {
    _textRecognizer.close();
  }
}