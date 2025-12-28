// lib/models/ocr_result.dart

/// Model class for OCR results
/// Represents a scanned text with its image and metadata
class OCRResult {
  final String id;           // Unique identifier from Firestore
  final String text;         // Extracted text from image
  final String imageUrl;     // Firebase Storage URL of the image
  final DateTime timestamp;  // When the scan was performed

  OCRResult({
    required this.id,
    required this.text,
    required this.imageUrl,
    required this.timestamp,
  });

  /// Convert OCRResult to Map for Firebase Firestore
  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'imageUrl': imageUrl,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Create OCRResult from Firebase Firestore document
  factory OCRResult.fromMap(String id, Map<String, dynamic> map) {
    return OCRResult(
      id: id,
      text: map['text'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  /// Create a copy with updated fields
  OCRResult copyWith({
    String? id,
    String? text,
    String? imageUrl,
    DateTime? timestamp,
  }) {
    return OCRResult(
      id: id ?? this.id,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'OCRResult(id: $id, text: ${text.substring(0, text.length > 50 ? 50 : text.length)}..., timestamp: $timestamp)';
  }
}