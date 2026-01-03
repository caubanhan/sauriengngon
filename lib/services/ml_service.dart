import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

/*
Prepare HTTP POST request
Add headers:
Authorization (your API key)
Content-Type: image format or octet-stream
Attach image bytes
Send request to model endpoint
Receive JSON response
Extract:
top predicted label
confidence score
 */
class MLService {
  static Future<Map<String, dynamic>> detectDisease(File image) async {
    // Local Python backend API endpoint
    // For Android emulator: use 10.0.2.2
    // For real device: replace with your PC's IP address (run 'ipconfig' to find it)
    final uri = Uri.parse('http://10.0.2.2:5000/predict');

    // Read file bytes
    final bytes = await image.readAsBytes();
    
    // Base64-encode with data URI prefix
    final base64Data = base64Encode(bytes);
    final pathLower = image.path.toLowerCase();
    final isPng = pathLower.endsWith('.png');
    final mime = isPng ? 'image/png' : 'image/jpeg';
    final dataUri = 'data:$mime;base64,$base64Data';

    final payload = jsonEncode({'image': dataUri});

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: payload,
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        throw HttpException('Prediction failed: ${response.statusCode}\n${response.body}');
      }

      final dynamic decoded = json.decode(response.body);
      
      // Parse response from newserver.py:
      // {
      //   "top_prediction": "disease_name",
      //   "confidence": 0.95,
      //   "all_predictions": [
      //     {"label": "disease1", "confidence": 0.95},
      //     {"label": "disease2", "confidence": 0.03},
      //     ...
      //   ]
      // }
      
      final topPrediction = decoded['top_prediction'];
      final confidence = decoded['confidence'];
      final allPredictions = decoded['all_predictions'];

      if (topPrediction is String && confidence is num && allPredictions is List) {
        return {
          'top_prediction': topPrediction,
          'confidence': (confidence as num).toDouble(),
          'all_predictions': allPredictions,
        };
      }

      throw HttpException('Unexpected response format: ${response.body}');
    } catch (e) {
      if (e is HttpException) rethrow;
      throw HttpException('Error calling backend: $e');
    }
  }
}

