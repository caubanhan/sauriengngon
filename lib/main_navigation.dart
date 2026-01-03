import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/history_screen.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState(); 
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;

  // List of screens
  final List<Widget> _screens = const [
    HomeScreen(),
    CameraScreen(),
    HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: [
          // Home tab
          NavigationDestination(
            icon: const Icon(Icons.home),
            label: 'Home',
          ),

          // Camera tab (centered, larger, prominent)
          NavigationDestination(
            icon: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).primaryColor,
              ),
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 32,
              ),
            ),
            label: 'Camera',
          ),

          // History tab
          NavigationDestination(
            icon: const Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
