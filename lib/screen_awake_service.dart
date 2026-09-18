import 'package:flutter/services.dart';

/// Duration options for the "keep screen on" service.
/// `minutes == null` means indefinitely (until the user stops it).
enum AwakeDuration {
  fiveMinutes(5, '5 MIN'),
  tenMinutes(10, '10 MIN'),
  thirtyMinutes(30, '30 MIN'),
  forever(null, 'FOREVER');

  const AwakeDuration(this.minutes, this.label);

  final int? minutes;
  final String label;
}

/// Thin wrapper around the native Android foreground service that actually
/// holds the wake lock. Keeping this separate from the UI means the widget
/// tree never talks to a MethodChannel directly.
class ScreenAwakeService {
  ScreenAwakeService() : _channel = const MethodChannel('foreground_service');

  final MethodChannel _channel;

  Future<void> start(AwakeDuration duration) {
    return _channel.invokeMethod('startService', {
      'durationMinutes': duration.minutes ?? 0,
    });
  }

  Future<void> stop() {
    return _channel.invokeMethod('stopService');
  }

  /// Asks the native side for ground truth instead of trusting local state —
  /// the service can die in the background without the app knowing.
  Future<bool> isRunning() async {
    final result = await _channel.invokeMethod<bool>('isServiceRunning');
    return result ?? false;
  }
}
