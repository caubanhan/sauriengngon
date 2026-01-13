import 'package:flutter/material.dart';
import 'main_navigation.dart';
import 'models/tensorflow_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize TensorFlow Lite model on app startup
  await TensorFlowService.initialize();
  
  runApp(const DurianDetectApp());
}

class DurianDetectApp extends StatelessWidget {
  const DurianDetectApp({super.key}); 

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phát hiện bệnh sầu riêng',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const MainNavigationPage(),
    );
  }
}

