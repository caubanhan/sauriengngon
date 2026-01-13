/// Quick Reference: Offline Inference Implementation
/// 
/// Copy-paste ready code for common scenarios

import 'dart:io';
import 'models/tensorflow_service.dart';
import 'services/ml_service.dart';

// ============================================================================
// SCENARIO 1: Basic Single Image Analysis (Most Common)
// ============================================================================
Future<void> analyzeImageBasic(File imageFile) async {
  try {
    // Initialize model once at app startup
    await TensorFlowService.initialize();
    
    // Run inference
    final result = await MLService.detectDisease(imageFile);
    
    // Access results
    final disease = result['top_prediction'] as String;
    final confidence = result['confidence'] as double;
    final allPredictions = result['all_predictions'] as List;
    
    print('Disease: $disease');
    print('Confidence: ${(confidence * 100).toStringAsFixed(1)}%');
    print('Predictions: ${allPredictions.length}');
  } catch (e) {
    print('Error: $e');
  }
}

// ============================================================================
// SCENARIO 2: Show Loading State During Inference
// ============================================================================
class InferenceController {
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _result;

  Future<void> analyzeWithUI(
    File image, {
    required Function(bool) onLoadingChanged,
    required Function(String?) onErrorChanged,
    required Function(Map<String, dynamic>) onResultChanged,
  }) async {
    try {
      onLoadingChanged(true);
      _error = null;

      // This is where inference happens (100-400ms)
      _result = await MLService.detectDisease(image);

      onResultChanged(_result!);
      onLoadingChanged(false);
    } catch (e) {
      _error = 'Inference failed: $e';
      onErrorChanged(_error);
      onLoadingChanged(false);
    }
  }
}

// ============================================================================
// SCENARIO 3: Batch Processing Multiple Images
// ============================================================================
Future<List<Map<String, dynamic>>> analyzeBatchImages(List<File> images) async {
  final results = <Map<String, dynamic>>[];

  for (final image in images) {
    try {
      final result = await MLService.detectDisease(image);
      results.add({
        'image': image.path,
        'success': true,
        'result': result,
      });
    } catch (e) {
      results.add({
        'image': image.path,
        'success': false,
        'error': e.toString(),
      });
    }
  }

  return results;
}

// ============================================================================
// SCENARIO 4: Extract Just the Top Prediction
// ============================================================================
Future<String> getDiseaseName(File image) async {
  final result = await MLService.detectDisease(image);
  return result['top_prediction'] as String;
}

// ============================================================================
// SCENARIO 5: Check Prediction Confidence
// ============================================================================
Future<bool> isConfidentPrediction(File image, {double minConfidence = 0.7}) async {
  final result = await MLService.detectDisease(image);
  final confidence = result['confidence'] as double;
  return confidence >= minConfidence;
}

// ============================================================================
// SCENARIO 6: Get Top N Predictions
// ============================================================================
Future<List<Map<String, dynamic>>> getTopPredictions(
  File image, {
  int topN = 5,
}) async {
  final result = await MLService.detectDisease(image);
  final allPredictions = (result['all_predictions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  return allPredictions.take(topN).toList();
}

// ============================================================================
// SCENARIO 7: Cache Predictions to Avoid Re-processing Same Image
// ============================================================================
class PredictionCache {
  final Map<String, Map<String, dynamic>> _cache = {};
  static const int _maxSize = 10;

  Future<Map<String, dynamic>> analyze(File image) async {
    final key = image.path;

    // Check cache first
    if (_cache.containsKey(key)) {
      print('📦 Using cached result for: $key');
      return _cache[key]!;
    }

    // Run inference
    final result = await MLService.detectDisease(image);

    // Store in cache (with size limit)
    if (_cache.length >= _maxSize) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
    }
    _cache[key] = result;

    return result;
  }

  void clear() => _cache.clear();
  int get size => _cache.length;
}

// Usage:
// final cache = PredictionCache();
// final result = await cache.analyze(imageFile);  // First call: inferences
// final result2 = await cache.analyze(imageFile); // Second call: from cache

// ============================================================================
// SCENARIO 8: Compare Predictions from Multiple Angles
// ============================================================================
Future<Map<String, dynamic>> getAveragePrediction(List<File> images) async {
  final allResults = await analyzeBatchImages(images);
  
  // Count occurrences of each disease
  final diseaseCount = <String, int>{};
  final totalConfidence = <String, double>{};

  for (final resultData in allResults) {
    if (resultData['success'] == true) {
      final result = resultData['result'] as Map<String, dynamic>;
      final disease = result['top_prediction'] as String;
      final confidence = result['confidence'] as double;

      diseaseCount[disease] = (diseaseCount[disease] ?? 0) + 1;
      totalConfidence[disease] = (totalConfidence[disease] ?? 0) + confidence;
    }
  }

  // Find most common disease
  if (diseaseCount.isEmpty) {
    return {'disease': 'Unknown', 'avgConfidence': 0.0};
  }

  final mostCommon = diseaseCount.entries
      .reduce((a, b) => a.value > b.value ? a : b)
      .key;

  final avgConfidence = totalConfidence[mostCommon]! / diseaseCount[mostCommon]!;

  return {
    'disease': mostCommon,
    'avgConfidence': avgConfidence,
    'occurrences': diseaseCount[mostCommon],
    'totalImages': images.length,
  };
}

// ============================================================================
// SCENARIO 9: Filter Predictions by Confidence Threshold
// ============================================================================
Future<List<Map<String, dynamic>>> getHighConfidencePredictions(
  File image, {
  double minConfidence = 0.1,
}) async {
  final result = await MLService.detectDisease(image);
  final allPredictions = (result['all_predictions'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  return allPredictions
      .where((pred) => (pred['confidence'] as double) >= minConfidence)
      .toList();
}

// ============================================================================
// SCENARIO 10: Export Results for Analysis
// ============================================================================
Future<String> exportResultsAsJSON(
  File image,
  Map<String, dynamic> result,
) async {
  final json = {
    'timestamp': DateTime.now().toIso8601String(),
    'imagePath': image.path,
    'imageSize': await image.length(),
    'topPrediction': result['top_prediction'],
    'confidence': result['confidence'],
    'allPredictions': result['all_predictions'],
  };

  return jsonEncode(json);
}

// ============================================================================
// SCENARIO 11: Display Results in Console
// ============================================================================
void printPrettyResults(Map<String, dynamic> result) {
  final disease = result['top_prediction'] as String;
  final confidence = result['confidence'] as double;
  final allPredictions = (result['all_predictions'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  print('═' * 50);
  print('🔬 INFERENCE RESULTS');
  print('═' * 50);
  print('Top Prediction: $disease');
  print('Confidence: ${(confidence * 100).toStringAsFixed(1)}%');
  print('─' * 50);
  print('All Predictions (${allPredictions.length} classes):');

  for (int i = 0; i < allPredictions.length && i < 10; i++) {
    final pred = allPredictions[i];
    final label = pred['label'] as String;
    final conf = pred['confidence'] as double;
    final bar = '█' * (conf * 20).toInt();
    print('  ${i + 1}. $label ${(conf * 100).toStringAsFixed(1)}% $bar');
  }

  if (allPredictions.length > 10) {
    print('  ... and ${allPredictions.length - 10} more');
  }

  print('═' * 50);
}

// ============================================================================
// SCENARIO 12: Error Recovery with Retry Logic
// ============================================================================
Future<Map<String, dynamic>?> analyzeWithRetry(
  File image, {
  int maxRetries = 3,
  Duration delayBetweenRetries = const Duration(seconds: 1),
}) async {
  for (int attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      print('Attempt $attempt of $maxRetries...');
      return await MLService.detectDisease(image);
    } catch (e) {
      print('Attempt $attempt failed: $e');
      
      if (attempt < maxRetries) {
        await Future.delayed(delayBetweenRetries);
      }
    }
  }

  print('All retries failed');
  return null;
}

// ============================================================================
// SCENARIO 13: Performance Monitoring
// ============================================================================
Future<Map<String, dynamic>> analyzeWithProfiling(File image) async {
  final stopwatch = Stopwatch()..start();

  try {
    final result = await MLService.detectDisease(image);
    stopwatch.stop();

    print('⏱️ Performance Metrics:');
    print('  Total time: ${stopwatch.elapsedMilliseconds}ms');
    print('  Disease: ${result['top_prediction']}');
    print('  Confidence: ${(result['confidence'] * 100).toStringAsFixed(1)}%');

    return result;
  } catch (e) {
    stopwatch.stop();
    print('❌ Inference failed after ${stopwatch.elapsedMilliseconds}ms: $e');
    rethrow;
  }
}

// ============================================================================
// SCENARIO 14: Determine if Additional Photos Needed
// ============================================================================
Future<bool> needsConfirmation(
  File image, {
  double confidenceThreshold = 0.7,
}) async {
  final result = await MLService.detectDisease(image);
  final confidence = result['confidence'] as double;

  // If confidence is low, recommend taking more photos
  return confidence < confidenceThreshold;
}

// Usage in UI:
// if (await needsConfirmation(image)) {
//   showDialog('Low confidence. Take another photo?');
// }

// ============================================================================
// SCENARIO 15: Initialize All at Once (Best Practice)
// ============================================================================
class AppState {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    print('🚀 Initializing app...');
    
    // Initialize TensorFlow
    final success = await TensorFlowService.initialize();
    if (!success) {
      print('⚠️ TensorFlow initialization had issues, will use fallback');
    }

    _initialized = true;
    print('✅ App initialization complete');
  }

  static bool get isInitialized => _initialized;
}

// Usage in main.dart:
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await AppState.init();
//   runApp(const MyApp());
// }

// ============================================================================
// IMPORTS REQUIRED
// ============================================================================
/*
import 'dart:io';
import 'dart:convert' show jsonEncode;
import 'models/tensorflow_service.dart';
import 'services/ml_service.dart';
*/
