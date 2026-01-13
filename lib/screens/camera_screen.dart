import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import '../services/ml_service.dart';
import 'result_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  File? _image;
  final picker = ImagePicker();

  Future pickImage() async {
    try {
      // Try capturing from camera
      final pickedFile = await picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        setState(() => _image = file);
        
        try {
          // OFFLINE INFERENCE: Run TensorFlow Lite model on device
          // No API calls or network requests - all processing is local
          print('🔬 Starting local inference...');
          final result = await MLService.detectDisease(file);
          print('✅ Inference complete: ${result['top_prediction']}');
          
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ResultScreen(detectionResult: result)),
            );
          }
        } catch (e) {
          // Offline inference errors (no network timeout issues)
          print('❌ Inference error: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Inference error: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        return;
      }
    } catch (e) {
      print('❌ Camera error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // Fallback: use bundled asset when emulator camera isn't available
    try {
      print('📦 Falling back to sample image...');
      final byteData = await rootBundle.load('assets/durian_leaf.png');
      final bytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
      final tempDir = await Directory.systemTemp.createTemp('sau_rieng_ngon_');
      final tempFile = File('${tempDir.path}/durian_leaf.png');
      await tempFile.writeAsBytes(bytes, flush: true);
      setState(() => _image = tempFile);
      
      // OFFLINE INFERENCE: Run on sample image
      print('🔬 Starting local inference on sample image...');
      final result = await MLService.detectDisease(tempFile);
      print('✅ Inference complete: ${result['top_prediction']}');
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ResultScreen(detectionResult: result)),
        );
      }
    } catch (e) {
      print('❌ Inference error on sample: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process sample image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    pickImage();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
