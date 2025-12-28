// lib/services/firebase_service.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/ocr_result.dart';

/// Service class for Firebase operations
/// Handles both Firestore (database) and Storage (file uploads)
class FirebaseService {
  // Firestore instance for database operations
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Firebase Storage instance for file uploads
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Collection name in Firestore
  static const String _collectionName = 'ocr_results';

  // Storage path for images
  static const String _storagePath = 'ocr_images';

  /// Upload image to Firebase Storage
  ///
  /// Uploads an image file to Firebase Storage and returns the download URL.
  /// The file is stored with a unique timestamp-based filename.
  ///
  /// Parameters:
  ///   [imagePath] - Local path to the image file on device
  ///
  /// Returns:
  ///   String - Download URL of the uploaded image
  ///
  /// Throws:
  ///   Exception if upload fails
  ///
  /// Example:
  /// ```dart
  /// String url = await _firebaseService.uploadImage('/path/to/image.jpg');
  /// print('Image uploaded: $url');
  /// ```
  Future<String> uploadImage(String imagePath) async {
    try {
      // Get the image file
      final file = File(imagePath);

      // Validate file exists
      if (!await file.exists()) {
        throw Exception('Image file not found');
      }

      // Create unique filename using timestamp
      final fileName = 'ocr_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Create reference to storage location
      final storageRef = _storage.ref().child('$_storagePath/$fileName');

      // Set metadata for the file
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
          'fileSize': (await file.length()).toString(),
        },
      );

      // Upload the file
      final uploadTask = storageRef.putFile(file, metadata);

      // Monitor upload progress (optional)
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
      });

      // Wait for upload to complete
      await uploadTask;

      // Get and return the download URL
      final downloadUrl = await storageRef.getDownloadURL();
      print('Image uploaded successfully: $downloadUrl');

      return downloadUrl;

    } on FirebaseException catch (e) {
      print('Firebase Storage Error: ${e.code} - ${e.message}');
      throw Exception('Failed to upload image: ${e.message}');
    } catch (e) {
      print('Error uploading image: $e');
      rethrow;
    }
  }

  /// Save OCR result to Firestore database
  ///
  /// Stores extracted text and image URL in Firestore with timestamp.
  ///
  /// Parameters:
  ///   [text] - Extracted text from image
  ///   [imageUrl] - Firebase Storage URL of the image
  ///
  /// Returns:
  ///   String - Document ID of the created record
  ///
  /// Throws:
  ///   Exception if save fails
  ///
  /// Example:
  /// ```dart
  /// String docId = await _firebaseService.saveOCRResult(
  ///   'Hello World',
  ///   'https://firebase.storage/.../image.jpg'
  /// );
  /// ```
  Future<String> saveOCRResult(String text, String imageUrl) async {
    try {
      // Prepare document data
      final data = {
        'text': text,
        'imageUrl': imageUrl,
        'timestamp': DateTime.now().toIso8601String(),
        'textLength': text.length,
        'wordCount': text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add document to Firestore
      final docRef = await _firestore.collection(_collectionName).add(data);

      print('OCR result saved with ID: ${docRef.id}');
      return docRef.id;

    } on FirebaseException catch (e) {
      print('Firestore Error: ${e.code} - ${e.message}');
      throw Exception('Failed to save OCR result: ${e.message}');
    } catch (e) {
      print('Error saving to Firestore: $e');
      rethrow;
    }
  }

  /// Get all OCR results as a real-time stream
  ///
  /// Returns a stream that automatically updates when data changes.
  /// Results are ordered by timestamp (most recent first).
  /// Limited to last 50 results for performance.
  ///
  /// Returns:
  ///   Stream<List<OCRResult>> - Live stream of OCR results
  ///
  /// Example:
  /// ```dart
  /// StreamBuilder<List<OCRResult>>(
  ///   stream: _firebaseService.getOCRResults(),
  ///   builder: (context, snapshot) {
  ///     if (snapshot.hasData) {
  ///       return ListView.builder(
  ///         itemCount: snapshot.data!.length,
  ///         itemBuilder: (context, index) {
  ///           return Text(snapshot.data![index].text);
  ///         },
  ///       );
  ///     }
  ///     return CircularProgressIndicator();
  ///   },
  /// )
  /// ```
  Stream<List<OCRResult>> getOCRResults() {
    try {
      return _firestore
          .collection(_collectionName)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          return OCRResult.fromMap(doc.id, doc.data());
        }).toList();
      });
    } catch (e) {
      print('Error getting OCR results stream: $e');
      // Return empty stream on error
      return Stream.value([]);
    }
  }

  /// Get OCR results with pagination
  ///
  /// Fetch results in batches for better performance.
  ///
  /// Parameters:
  ///   [limit] - Number of results to fetch (default: 20)
  ///   [lastDocument] - Last document from previous fetch for pagination
  ///
  /// Returns:
  ///   Future<List<OCRResult>> - List of OCR results
  Future<List<OCRResult>> getOCRResultsPaginated({
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _firestore
          .collection(_collectionName)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      // If there's a last document, start after it (pagination)
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        return OCRResult.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();

    } catch (e) {
      print('Error getting paginated results: $e');
      return [];
    }
  }

  /// Get a single OCR result by ID
  ///
  /// Parameters:
  ///   [id] - Document ID in Firestore
  ///
  /// Returns:
  ///   Future<OCRResult?> - OCR result or null if not found
  Future<OCRResult?> getOCRResultById(String id) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(id).get();

      if (doc.exists && doc.data() != null) {
        return OCRResult.fromMap(doc.id, doc.data()!);
      }

      return null;

    } catch (e) {
      print('Error getting result by ID: $e');
      return null;
    }
  }

  /// Search OCR results by text content
  ///
  /// Searches through stored text for matching content.
  /// Note: This is a basic implementation. For production,
  /// consider using Algolia or similar for better search.
  ///
  /// Parameters:
  ///   [searchQuery] - Text to search for
  ///
  /// Returns:
  ///   Future<List<OCRResult>> - Matching results
  Future<List<OCRResult>> searchOCRResults(String searchQuery) async {
    try {
      // Fetch recent results
      final snapshot = await _firestore
          .collection(_collectionName)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      // Filter results containing search query (case-insensitive)
      final results = snapshot.docs
          .map((doc) => OCRResult.fromMap(doc.id, doc.data()))
          .where((result) =>
          result.text.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();

      return results;

    } catch (e) {
      print('Error searching results: $e');
      return [];
    }
  }

  /// Update an existing OCR result
  ///
  /// Parameters:
  ///   [id] - Document ID to update
  ///   [text] - New text (optional)
  ///   [imageUrl] - New image URL (optional)
  ///
  /// Returns:
  ///   Future<void>
  Future<void> updateOCRResult(String id, {String? text, String? imageUrl}) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (text != null) {
        updates['text'] = text;
        updates['textLength'] = text.length;
      }

      if (imageUrl != null) {
        updates['imageUrl'] = imageUrl;
      }

      await _firestore.collection(_collectionName).doc(id).update(updates);
      print('OCR result updated: $id');

    } catch (e) {
      print('Error updating result: $e');
      rethrow;
    }
  }

  /// Delete OCR result and associated image
  ///
  /// Deletes both the Firestore document and the image from Storage.
  ///
  /// Parameters:
  ///   [id] - Document ID in Firestore
  ///   [imageUrl] - Firebase Storage URL of the image
  ///
  /// Returns:
  ///   Future<void>
  ///
  /// Example:
  /// ```dart
  /// await _firebaseService.deleteOCRResult(
  ///   'doc123',
  ///   'https://firebase.storage/.../image.jpg'
  /// );
  /// ```
  Future<void> deleteOCRResult(String id, String imageUrl) async {
    try {
      // Delete from Firestore
      await _firestore.collection(_collectionName).doc(id).delete();
      print('Firestore document deleted: $id');

      // Delete image from Storage (if URL is valid)
      if (imageUrl.isNotEmpty && imageUrl.startsWith('https://')) {
        try {
          final ref = _storage.refFromURL(imageUrl);
          await ref.delete();
          print('Storage image deleted: $imageUrl');
        } catch (e) {
          print('Error deleting image from storage: $e');
          // Continue even if image deletion fails
        }
      }

    } on FirebaseException catch (e) {
      print('Firebase Error: ${e.code} - ${e.message}');
      throw Exception('Failed to delete OCR result: ${e.message}');
    } catch (e) {
      print('Error deleting result: $e');
      rethrow;
    }
  }

  /// Delete multiple OCR results efficiently
  ///
  /// Uses Firestore batch operations for better performance.
  ///
  /// Parameters:
  ///   [ids] - List of document IDs to delete
  ///
  /// Returns:
  ///   Future<void>
  Future<void> deleteMultipleResults(List<String> ids) async {
    try {
      // Create a batch for efficient deletion
      final batch = _firestore.batch();

      for (String id in ids) {
        batch.delete(_firestore.collection(_collectionName).doc(id));
      }

      // Commit all deletions at once
      await batch.commit();
      print('Deleted ${ids.length} results');

    } catch (e) {
      print('Error deleting multiple results: $e');
      rethrow;
    }
  }

  /// Delete all OCR results
  ///
  /// WARNING: This will delete ALL stored OCR results!
  /// Use with caution.
  ///
  /// Returns:
  ///   Future<void>
  Future<void> deleteAllResults() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).get();

      // Delete in batches (Firestore limit is 500 operations per batch)
      final batch = _firestore.batch();
      int count = 0;

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
        count++;

        // Commit batch every 500 operations
        if (count == 500) {
          await batch.commit();
          count = 0;
        }
      }

      // Commit remaining operations
      if (count > 0) {
        await batch.commit();
      }

      print('Deleted all OCR results');

    } catch (e) {
      print('Error deleting all results: $e');
      rethrow;
    }
  }

  /// Get usage statistics
  ///
  /// Returns stats about stored OCR results.
  ///
  /// Returns:
  ///   Future<Map<String, dynamic>> - Statistics data
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).get();

      int totalResults = snapshot.docs.length;
      int totalCharacters = 0;
      int totalWords = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalCharacters += (data['textLength'] as int?) ?? 0;
        totalWords += (data['wordCount'] as int?) ?? 0;
      }

      return {
        'totalScans': totalResults,
        'totalCharacters': totalCharacters,
        'totalWords': totalWords,
        'averageCharacters': totalResults > 0
            ? (totalCharacters / totalResults).toStringAsFixed(1)
            : '0',
        'averageWords': totalResults > 0
            ? (totalWords / totalResults).toStringAsFixed(1)
            : '0',
      };

    } catch (e) {
      print('Error getting statistics: $e');
      return {
        'totalScans': 0,
        'totalCharacters': 0,
        'totalWords': 0,
        'averageCharacters': '0',
        'averageWords': '0',
      };
    }
  }

  /// Check Firebase connection status
  ///
  /// Tests connectivity to Firestore.
  ///
  /// Returns:
  ///   Future<bool> - true if connected, false otherwise
  Future<bool> checkConnection() async {
    try {
      await _firestore
          .collection(_collectionName)
          .limit(1)
          .get(const GetOptions(source: Source.server));
      return true;
    } catch (e) {
      print('Firebase connection error: $e');
      return false;
    }
  }

  /// Get total storage size used (approximate)
  ///
  /// Note: This requires reading all documents and may be slow.
  ///
  /// Returns:
  ///   Future<int> - Approximate size in bytes
  Future<int> getStorageSize() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).get();
      int totalSize = 0;

      for (var doc in snapshot.docs) {
        // Rough estimation: 1 character ≈ 1 byte
        final data = doc.data();
        final text = data['text'] as String? ?? '';
        totalSize += text.length;
      }

      return totalSize;
    } catch (e) {
      print('Error calculating storage size: $e');
      return 0;
    }
  }

  /// Export all OCR results as JSON
  ///
  /// Returns:
  ///   Future<List<Map<String, dynamic>>> - All results as JSON
  Future<List<Map<String, dynamic>>> exportAllResults() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

    } catch (e) {
      print('Error exporting results: $e');
      return [];
    }
  }
}