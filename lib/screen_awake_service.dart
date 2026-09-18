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

  /// Some OEM notification shades (MIUI/HyperOS in particular) let the user
  /// swipe away an "ongoing" notification even though stock Android
  /// shouldn't allow it. The service keeps running either way, but the
  /// visual indicator is gone — this reposts it at its correct remaining
  /// time. A no-op if the service isn't actually running.
  Future<void> refreshNotification() {
    return _channel.invokeMethod('refreshNotification');
  }

  /// `startService`/`stopService` return as soon as Android *accepts* the
  /// request, not once the service has actually run onStartCommand/onDestroy
  /// (that happens on a later turn of the main thread's message loop). So
  /// checking [isRunning] exactly once right after can catch it mid-flight
  /// and report the wrong thing. Poll briefly instead of trusting one check.
  Future<bool> waitUntil(
    bool expected, {
    int attempts = 8,
    Duration interval = const Duration(milliseconds: 60),
  }) async {
    for (var i = 0; i < attempts; i++) {
      if (await isRunning() == expected) return true;
      if (i < attempts - 1) await Future.delayed(interval);
    }
    return false;
  }
}
