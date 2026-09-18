import 'package:flutter/services.dart';

/// Duration options for the "keep screen on" service.
/// `minutes == null` means indefinitely (until the user stops it).
enum AwakeDuration {
  fiveMinutes(5, '5', 'min'),
  tenMinutes(10, '10', 'min'),
  thirtyMinutes(30, '30', 'min'),
  forever(null, '∞', 'ever');

  const AwakeDuration(this.minutes, this.value, this.unit);

  final int? minutes;
  final String value;
  final String unit;

  String get description => minutes == null ? 'forever' : '$minutes min';
}

/// Ground truth for the service, as last reported by the native side.
class ServiceStatus {
  const ServiceStatus({required this.isRunning, required this.endTime});

  final bool isRunning;

  /// Null when not running, or when running indefinitely.
  final DateTime? endTime;
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

  /// Full status including the real end time, so the UI's countdown can be
  /// seeded correctly on launch/resume instead of guessed from local state.
  Future<ServiceStatus> getStatus() async {
    final result = await _channel.invokeMapMethod<String, Object?>('getStatus');
    final endTimeMillis = result?['endTimeMillis'] as int?;
    return ServiceStatus(
      isRunning: result?['isRunning'] as bool? ?? false,
      endTime: endTimeMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(endTimeMillis),
    );
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
