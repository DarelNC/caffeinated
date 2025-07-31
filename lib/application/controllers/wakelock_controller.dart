import 'package:wakelock_plus/wakelock_plus.dart';

class WakelockController {
  bool _isOn = false;

  bool get isOn => _isOn;

  Future<void> toggle() async {
    if (_isOn) {
      await WakelockPlus.disable();
    } else {
      await WakelockPlus.enable();
    }
    _isOn = !_isOn;
  }
}
