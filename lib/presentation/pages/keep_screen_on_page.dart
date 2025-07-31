import 'package:flutter/material.dart';
import '../../application/controllers/wakelock_controller.dart';

class KeepScreenOnPage extends StatefulWidget {
  const KeepScreenOnPage({super.key});

  @override
  State<KeepScreenOnPage> createState() => _KeepScreenOnPageState();
}

class _KeepScreenOnPageState extends State<KeepScreenOnPage> {
  final _controller = WakelockController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Keep Screen On')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await _controller.toggle();
            setState(() {});
          },
          child: Text(_controller.isOn ? 'Desactivar' : 'Activar'),
        ),
      ),
    );
  }
}
