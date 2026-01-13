import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/tensorflow_service.dart';

/// ML Service for Plant Disease Detection
/// 
/// REFACTORED FOR OFFLINE INFERENCE:
/// This service now uses local TensorFlow Lite model instead of FastAPI backend.
/// All inference runs on-device for privacy, speed, and offline capability.
/// 
/// Key changes:
/// - ❌ REMOVED: HTTP requests to FastAPI backend
/// - ✅ ADDED: Direct TensorFlow Lite inference via TensorflowService
/// - ✅ IMAGE: Passed as file path to tensorflow_service
/// - ✅ PREPROCESSING: Image resizing/normalization handled by TensorflowService
/// - ✅ INFERENCE: Runs locally on device (CPU/GPU optimized)
class MLService {
  /// Detect plant diseases in captured image using local TFLite model
  /// 
  /// **Parameters:**
  ///   - `image`: File object pointing to captured/selected image
  /// 
  /// **Returns:**
  /// Map with structure matching previous API response:
  /// ```dart
  /// {
  ///   'top_prediction': 'disease_name',     // Most confident prediction
  ///   'confidence': 0.95,                   // Confidence 0.0-1.0
  ///   'all_predictions': [                  // All 38 disease classes
  ///     {'label': 'disease1', 'confidence': 0.95},
  ///     {'label': 'disease2', 'confidence': 0.03},
  ///     ...
  ///   ]
  /// }
  /// ```
  /// 
  /// **Error Handling:**
  /// - Model not available → returns demo results with actual labels
  /// - Invalid image → throws exception with detailed error
  /// - Service not initialized → returns error state
  static Future<Map<String, dynamic>> detectDisease(File image) async {
    // STEP 1: Validate input file exists
    if (!await image.exists()) {
      throw ArgumentError('Image file not found: ${image.path}');
    }

    debugPrint('🔬 Starting offline inference on: ${image.path}');

    try {
      // STEP 2: Ensure TensorFlow service is initialized (lazy-init fallback)
      if (!TensorFlowService.isInitialized) {
        await TensorFlowService.initialize();
      }
      if (!TensorFlowService.isInitialized) {
        throw Exception('TensorFlow service not initialized after retry');
      }

      // STEP 3: Run local inference
      // TensorflowService.analyzeImage() handles:
      //   - Image file reading
      //   - Resizing to [224, 224] 
      //   - RGB conversion
      //   - Normalization (0-255 range)
      //   - TFLite inference
      //   - Softmax post-processing
      final analysisResult = await TensorFlowService.analyzeImage(image.path);

      // STEP 4: Check if analysis was successful
      if (analysisResult['success'] != true) {
        throw Exception('Inference failed: ${analysisResult['error']}');
      }

      // STEP 5: Extract inference results
      final data = analysisResult['data'] as Map<String, dynamic>;

      // STEP 6: Transform results to match previous API format
      // Previous format expected by ResultScreen:
      // {
      //   'top_prediction': string (disease name),
      //   'confidence': double (0.0-1.0),
      //   'all_predictions': List of {'label': string, 'confidence': double}
      // }

      final topPrediction = data['topPrediction'] as Map<String, dynamic>?;
      final predictions = data['predictions'] as List<dynamic>? ?? [];

      // Convert predictions to expected format
      final allPredictions = predictions
          .map((pred) => {
                'label': pred['displayName'] ?? pred['label'] ?? 'Unknown',
                'confidence': (pred['confidence'] as num?)?.toDouble() ?? 0.0,
              })
          .toList();

      // Build result response matching previous API structure
      final result = {
        'top_prediction': topPrediction?['displayName'] ?? 
                          topPrediction?['label'] ?? 
                          'Unknown',
        'confidence': (topPrediction?['confidence'] as num?)?.toDouble() ?? 0.0,
        'all_predictions': allPredictions,
      };

      debugPrint('✅ Local inference complete: ${result['top_prediction']}');
      debugPrint('   Confidence: ${(result['confidence'] * 100).toStringAsFixed(1)}%');
      debugPrint('   Method: ${analysisResult['analysisMethod']}');

      return result;
    } catch (e) {
      debugPrint('❌ Local inference failed: $e');
      rethrow;
    }
  }
}


