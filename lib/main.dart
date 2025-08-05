import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const platform = MethodChannel('foreground_service');
  bool isRunning = false;

  Future<void> toggleService() async {
    try {
      if (isRunning) {
        await platform.invokeMethod('stopService');
      } else {
        await platform.invokeMethod('startService');
      }
      setState(() => isRunning = !isRunning);
    } on PlatformException catch (e) {
      print("Error: '${e.message}'.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Keep Screen On')),
      body: Center(
        child: ElevatedButton(
          onPressed: toggleService,
          child: Text(isRunning ? 'Stop Service' : 'Start Service'),
        ),
      ),
    );
  }
}
