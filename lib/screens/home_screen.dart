import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Durian Disease Detector')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Detect diseases on durian leaves using AI.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Image.asset('assets/durian_leaf.png', height: 200),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text("Scan Leaf"),
              onPressed: () {
                // Note: Navigation is now handled by the bottom navigation bar
                // This button can still work as a quick access if needed
              },
            ),
          ],
        ),
      ),
    );
  }
}

