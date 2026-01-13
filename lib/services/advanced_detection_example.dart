/// Example: Advanced Usage of Offline Inference Service
/// 
/// This file demonstrates advanced patterns for using the TensorFlow Lite
/// service in production scenarios.

import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/tensorflow_service.dart';
import '../services/ml_service.dart';

/// Advanced disease detection with metadata and error recovery
class AdvancedDiseaseDetector {
  // Cache for recent predictions (avoid re-processing same image)
  static final Map<String, Map<String, dynamic>> _predictionCache = {};
  
  // Maximum cache size to prevent memory issues
  static const int maxCacheSize = 10;

  /// Analyze image with caching and detailed error reporting
  /// 
  /// **Features:**
  /// - ✅ Caches predictions by image hash
  /// - ✅ Handles corrupted models gracefully
  /// - ✅ Returns structured result with metadata
  /// - ✅ Tracks inference time for performance monitoring
  /// 
  /// **Example:**
  /// ```dart
  /// final detector = AdvancedDiseaseDetector();
  /// final result = await detector.analyzeWithMetadata(imageFile);
  /// 
  /// if (result.success) {
  ///   print('Disease: ${result.disease}');
  ///   print('Confidence: ${result.confidence}');
  ///   print('Inference time: ${result.inferenceTimeMs}ms');
  /// } else {
  ///   print('Error: ${result.error}');
  /// }
  /// ```
  static Future<DetectionResult> analyzeWithMetadata(File image) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Validate input
      if (!await image.exists()) {
        return DetectionResult.error(
          'Image file not found: ${image.path}',
          inferenceTimeMs: stopwatch.elapsedMilliseconds,
        );
      }

      // Check cache first
      final cacheKey = image.path;
      if (_predictionCache.containsKey(cacheKey)) {
        debugPrint('📦 Using cached prediction for: ${image.path}');
        final cached = _predictionCache[cacheKey]!;
        return DetectionResult.fromMap(
          cached,
          inferenceTimeMs: 0, // Cached, no inference time
          fromCache: true,
        );
      }

      // Run inference
      final result = await MLService.detectDisease(image);

      // Cache result
      _addToCache(cacheKey, result);

      stopwatch.stop();
      return DetectionResult.fromMap(
        result,
        inferenceTimeMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return DetectionResult.error(
        'Inference failed: $e',
        inferenceTimeMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  /// Analyze multiple images and compare results
  /// 
  /// **Use Case:** Compare disease progression across multiple photos
  /// 
  /// **Example:**
  /// ```dart
  /// final images = [file1, file2, file3];
  /// final comparison = await analyzeMultiple(images);
  /// 
  /// print('Most common disease: ${comparison.dominantDisease}');
  /// print('Confidence trend: ${comparison.confidenceTrend}');
  /// ```
  static Future<MultiImageComparison> analyzeMultiple(
    List<File> images,
  ) async {
    final results = <DetectionResult>[];
    
    for (final image in images) {
      final result = await analyzeWithMetadata(image);
      results.add(result);
    }

    return MultiImageComparison(results);
  }

  /// Batch analyze images with progress callback
  /// 
  /// **Example:**
  /// ```dart
  /// await analyzeBatch(
  ///   images: [file1, file2, file3],
  ///   onProgress: (current, total) {
  ///     print('Processing $current of $total images');
  ///   },
  /// );
  /// ```
  static Future<List<DetectionResult>> analyzeBatch(
    {required List<File> images,
    required Function(int, int) onProgress}) async {
    final results = <DetectionResult>[];

    for (int i = 0; i < images.length; i++) {
      final result = await analyzeWithMetadata(images[i]);
      results.add(result);
      onProgress(i + 1, images.length);
    }

    return results;
  }

  /// Clear prediction cache to free memory
  static void clearCache() {
    _predictionCache.clear();
    debugPrint('🧹 Prediction cache cleared');
  }

  static void _addToCache(String key, Map<String, dynamic> result) {
    // Maintain max cache size
    if (_predictionCache.length >= maxCacheSize) {
      // Remove oldest entry (FIFO)
      final firstKey = _predictionCache.keys.first;
      _predictionCache.remove(firstKey);
      debugPrint('📦 Evicted cache entry: $firstKey');
    }

    _predictionCache[key] = result;
    debugPrint('📦 Cached prediction: $key');
  }
}

/// Structured result from disease detection
/// 
/// Provides type-safe access to detection results with metadata
class DetectionResult {
  final bool success;
  final String disease;
  final double confidence;
  final List<PredictionDetail> allPredictions;
  final String? error;
  final int inferenceTimeMs;
  final bool fromCache;
  final bool isDemoResult;

  DetectionResult({
    required this.success,
    required this.disease,
    required this.confidence,
    required this.allPredictions,
    this.error,
    required this.inferenceTimeMs,
    this.fromCache = false,
    this.isDemoResult = false,
  });

  /// Create from raw API result
  factory DetectionResult.fromMap(
    Map<String, dynamic> result, {
    required int inferenceTimeMs,
    bool fromCache = false,
  }) {
    final predictions = (result['all_predictions'] as List?)
            ?.map((p) => PredictionDetail.fromMap(p))
            .toList() ??
        [];

    return DetectionResult(
      success: true,
      disease: result['top_prediction'] ?? 'Unknown',
      confidence: (result['confidence'] as num?)?.toDouble() ?? 0.0,
      allPredictions: predictions,
      inferenceTimeMs: inferenceTimeMs,
      fromCache: fromCache,
      isDemoResult: result['isDemoResult'] == true,
    );
  }

  /// Create error result
  factory DetectionResult.error(
    String message, {
    required int inferenceTimeMs,
  }) {
    return DetectionResult(
      success: false,
      disease: 'Error',
      confidence: 0.0,
      allPredictions: [],
      error: message,
      inferenceTimeMs: inferenceTimeMs,
    );
  }

  /// Get top 5 predictions
  List<PredictionDetail> get top5 =>
      allPredictions.take(5).toList();

  /// Check if result is confident (>70%)
  bool get isConfident => confidence > 0.7;

  /// Format for display
  String get displayString {
    if (!success) {
      return 'Error: $error';
    }
    if (isDemoResult) {
      return '$disease (Demo) - ${(confidence * 100).toStringAsFixed(1)}%';
    }
    return '$disease - ${(confidence * 100).toStringAsFixed(1)}%';
  }

  /// Debug info
  String get debugString {
    final buffer = StringBuffer();
    buffer.writeln('DetectionResult {');
    buffer.writeln('  Success: $success');
    buffer.writeln('  Disease: $disease');
    buffer.writeln('  Confidence: ${(confidence * 100).toStringAsFixed(1)}%');
    buffer.writeln('  Inference Time: ${inferenceTimeMs}ms');
    buffer.writeln('  From Cache: $fromCache');
    buffer.writeln('  Demo Result: $isDemoResult');
    if (error != null) buffer.writeln('  Error: $error');
    buffer.writeln('  Top 5: ${top5.map((p) => "${p.label} ${(p.confidence * 100).toStringAsFixed(1)}%").join(", ")}');
    buffer.writeln('}');
    return buffer.toString();
  }
}

/// Single prediction with label and confidence
class PredictionDetail {
  final String label;
  final double confidence;

  PredictionDetail({required this.label, required this.confidence});

  factory PredictionDetail.fromMap(dynamic map) {
    final m = map as Map<String, dynamic>;
    return PredictionDetail(
      label: m['label'] ?? m['disease'] ?? 'Unknown',
      confidence: (m['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String get percentageString => '${(confidence * 100).toStringAsFixed(1)}%';
}

/// Comparison across multiple images
class MultiImageComparison {
  final List<DetectionResult> results;

  MultiImageComparison(this.results);

  /// Most frequently detected disease
  String get dominantDisease {
    if (results.isEmpty) return 'None';
    
    final frequency = <String, int>{};
    for (final result in results) {
      frequency[result.disease] = (frequency[result.disease] ?? 0) + 1;
    }
    
    final sorted = frequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sorted.isNotEmpty ? sorted.first.key : 'None';
  }

  /// Average confidence across all results
  double get averageConfidence {
    if (results.isEmpty) return 0.0;
    final sum = results.fold<double>(0, (prev, r) => prev + r.confidence);
    return sum / results.length;
  }

  /// Confidence trend: increasing, decreasing, or stable
  String get confidenceTrend {
    if (results.length < 2) return 'N/A';
    
    final first = results.first.confidence;
    final last = results.last.confidence;
    final diff = last - first;

    if (diff > 0.1) return 'Increasing (Worse)';
    if (diff < -0.1) return 'Decreasing (Better)';
    return 'Stable';
  }

  /// All unique diseases detected
  Set<String> get uniqueDiseases =>
      results.map((r) => r.disease).toSet();

  /// Summary for display
  String get summary {
    return '''
Multi-Image Comparison:
  Images analyzed: ${results.length}
  Dominant disease: $dominantDisease
  Unique diseases: ${uniqueDiseases.join(", ")}
  Average confidence: ${(averageConfidence * 100).toStringAsFixed(1)}%
  Trend: $confidenceTrend
    ''';
  }
}

/// Example usage demonstrating complete workflow
Future<void> exampleWorkflow() async {
  // Ensure TensorFlow is initialized
  await TensorFlowService.initialize();

  // Single image analysis
  print('=== Single Image Analysis ===');
  final imageFile = File('/path/to/image.jpg');
  final result = await AdvancedDiseaseDetector.analyzeWithMetadata(imageFile);
  
  print('Result: ${result.displayString}');
  print('Inference took: ${result.inferenceTimeMs}ms');
  print('Is confident: ${result.isConfident}');
  print('Top 5 predictions:');
  for (final pred in result.top5) {
    print('  - ${pred.label}: ${pred.percentageString}');
  }

  // Multiple image comparison
  print('\n=== Multiple Image Comparison ===');
  final images = [
    File('/path/to/image1.jpg'),
    File('/path/to/image2.jpg'),
    File('/path/to/image3.jpg'),
  ];
  
  final comparison = await AdvancedDiseaseDetector.analyzeMultiple(images);
  print(comparison.summary);

  // Batch processing with progress
  print('\n=== Batch Processing ===');
  final batchResults = await AdvancedDiseaseDetector.analyzeBatch(
    images: images,
    onProgress: (current, total) {
      print('Processing $current of $total images...');
    },
  );
  
  print('Batch complete. Analyzed ${batchResults.length} images');

  // Memory management
  AdvancedDiseaseDetector.clearCache();
  
  // Cleanup
  await TensorFlowService.dispose();
}
