import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';

import 'screen_awake_service.dart';

/// New Cycle design system, "Oxblood" ground — see docs/rules.md for why
/// this ground was picked over the default Plum, and why fonts are bundled
/// locally instead of fetched from Google Fonts at runtime.
class _Tokens {
  static const ground = Color(0xFF2A0F14);
  static const surface = Color(0xFF221A26);
  static const ink = Color(0xFFF6EFE6);
  static const inkMuted = Color(0xFFD8B6AD); // Oxblood row override
  static const signal = Color(0xFFE9FF4F);
  static const signalInk = Color(0xFF17101B);
  static const alert = Color(0xFFFF5C1C);
  static const accent2 = Color(0xFF8C2F1B); // Oxblood row override

  static const archivoBlack = 'Archivo Black';
  static const majorMono = 'Major Mono Display';
  static const dmSerifItalic = 'DM Serif Display Italic';

  static const pressFeedback = Duration(milliseconds: 110);
  static const enterExit = Duration(milliseconds: 240);
  static const enterExitCurve = Cubic(0.16, 0.84, 0.28, 1);
}

void main() {
  runApp(const CaffeinatedApp());
}

class CaffeinatedApp extends StatelessWidget {
  const CaffeinatedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Caffeinated',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: _Tokens.majorMono,
        scaffoldBackgroundColor: _Tokens.ground,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _service = ScreenAwakeService();

  AwakeDuration _duration = AwakeDuration.tenMinutes;
  bool _isRunning = false;
  bool _busy = false;
  String? _error;

  // A continuous pulse while active — deliberately on its own cycle, not
  // synced to press/enter-exit motion (per the system's motion rules).
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _requestNotificationPermission();
    _syncWithReality();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The service can be killed by the OS while backgrounded (Doze, a swipe
    // from recents on some OEMs). Re-check ground truth on resume instead of
    // trusting whatever the toggle last said.
    if (state == AppLifecycleState.resumed) {
      _syncWithReality();
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  Future<void> _syncWithReality() async {
    final running = await _service.isRunning();
    if (mounted) setState(() => _isRunning = running);
    if (running) {
      // In case an OEM notification shade let the notification get swiped
      // away while the service kept running in the background.
      await _service.refreshNotification();
    }
  }

  Future<void> _toggle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final wantsRunning = !_isRunning;
      if (wantsRunning) {
        await _service.start(_duration);
      } else {
        await _service.stop();
      }
      // Trust, but verify: ask the native side what actually happened
      // instead of flipping a local flag and hoping. The native call
      // returning doesn't mean onStartCommand/onDestroy ran yet, so give
      // it a brief window to catch up before believing it failed.
      final confirmed = await _service.waitUntil(wantsRunning);
      setState(() {
        _isRunning = confirmed ? wantsRunning : _isRunning;
        if (!confirmed) {
          _error = wantsRunning
              ? "couldn't confirm it started — try again."
              : "couldn't confirm it stopped — try again.";
        }
      });
    } on PlatformException catch (e) {
      setState(() => _error = e.message ?? 'something went wrong.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectDuration(AwakeDuration duration) async {
    setState(() => _duration = duration);
    // If it's already running, re-arm the timer immediately with the new
    // duration rather than making the user stop and start again.
    if (_isRunning) {
      await _service.start(duration);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Tokens.ground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            children: [
              const _Brand(),
              const Spacer(),
              // The empty-state pattern (icon + Archivo Black heading + one
              // DM Serif italic line) is the one place this system sanctions
              // centering — everything else stays flush left.
              Center(
                child: Column(
                  children: [
                    _PulsingIcon(isRunning: _isRunning, pulse: _pulseController),
                    const SizedBox(height: 32),
                    Text(
                      _isRunning ? "SCREEN'S AWAKE" : 'SCREEN CAN SLEEP',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: _Tokens.archivoBlack,
                        color: _Tokens.ink,
                        fontSize: 36,
                        height: 1.05,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _statusSubtitle(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: _Tokens.dmSerifItalic,
                        fontStyle: FontStyle.italic,
                        color: _Tokens.inkMuted,
                        fontSize: 19,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _DurationRow(
                selected: _duration,
                onSelected: _busy ? null : _selectDuration,
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                _ErrorToast(message: _error!),
                const SizedBox(height: 12),
              ],
              _ToggleButton(
                isRunning: _isRunning,
                busy: _busy,
                onTap: _toggle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusSubtitle() {
    if (!_isRunning) return 'pick a duration, then go.';
    if (_duration.minutes == null) return 'runs until you stop it.';
    return 'stops in ${_duration.label.toLowerCase()}.';
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'CAFFEINATED',
        style: TextStyle(
          fontFamily: _Tokens.majorMono,
          color: _Tokens.ink,
          fontSize: 13,
          letterSpacing: 3,
        ),
      ),
    );
  }
}

class _PulsingIcon extends StatelessWidget {
  const _PulsingIcon({required this.isRunning, required this.pulse});

  final bool isRunning;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    final asset = isRunning
        ? 'assets/images/ic_caffeinated_on_large.svg'
        : 'assets/images/ic_caffeinated_off_large.svg';

    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        // Elevation is offset distance, not blur — a "breathing" hard
        // shadow instead of a soft glow. Independent cycle from press/toast
        // motion, per the system's rule that ambient loops don't sync.
        final offset = isRunning ? 3.0 + (pulse.value * 5.0) : 0.0;
        return Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            color: _Tokens.surface,
            border: Border.all(color: _Tokens.ink, width: 2),
            boxShadow: [
              BoxShadow(
                color: _Tokens.accent2,
                offset: Offset(offset, offset),
              ),
            ],
          ),
          padding: const EdgeInsets.all(38),
          child: AnimatedSwitcher(
            duration: _Tokens.enterExit,
            switchInCurve: _Tokens.enterExitCurve,
            switchOutCurve: _Tokens.enterExitCurve,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: SvgPicture.asset(
              asset,
              key: ValueKey(isRunning),
              colorFilter: const ColorFilter.mode(
                _Tokens.ink,
                BlendMode.srcIn,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DurationRow extends StatelessWidget {
  const _DurationRow({required this.selected, required this.onSelected});

  final AwakeDuration selected;
  final ValueChanged<AwakeDuration>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final duration in AwakeDuration.values) ...[
          Expanded(
            child: _DurationChip(
              duration: duration,
              isSelected: duration == selected,
              onTap: onSelected == null ? null : () => onSelected!(duration),
            ),
          ),
          if (duration != AwakeDuration.values.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.duration,
    required this.isSelected,
    required this.onTap,
  });

  final AwakeDuration duration;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: _Tokens.pressFeedback,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _Tokens.signal : Colors.transparent,
          border: Border.all(color: _Tokens.ink, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          duration.label,
          style: TextStyle(
            fontFamily: _Tokens.majorMono,
            color: isSelected ? _Tokens.signalInk : _Tokens.ink,
            fontSize: 12,
            letterSpacing: 0.96, // 0.08em @ 12px
          ),
        ),
      ),
    );
  }
}

class _ToggleButton extends StatefulWidget {
  const _ToggleButton({
    required this.isRunning,
    required this.busy,
    required this.onTap,
  });

  final bool isRunning;
  final bool busy;
  final VoidCallback onTap;

  @override
  State<_ToggleButton> createState() => _ToggleButtonState();
}

class _ToggleButtonState extends State<_ToggleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // Primary button: resting 3px offset, pressed collapses to 0 and the
    // button moves into its own shadow.
    final shadowOffset = _pressed ? 0.0 : 3.0;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.busy ? null : widget.onTap,
      child: AnimatedContainer(
        duration: _Tokens.pressFeedback,
        curve: Curves.easeOut,
        margin: EdgeInsets.only(top: 3 - shadowOffset, left: 3 - shadowOffset),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: _Tokens.accent2,
              offset: Offset(shadowOffset, shadowOffset),
            ),
          ],
        ),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: _Tokens.signal,
            border: Border.all(color: _Tokens.ink, width: 2),
          ),
          alignment: Alignment.center,
          child: widget.busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: _Tokens.signalInk,
                  ),
                )
              : Text(
                  widget.isRunning ? 'let it sleep' : 'keep it awake',
                  style: const TextStyle(
                    fontFamily: _Tokens.majorMono,
                    color: _Tokens.signalInk,
                    fontSize: 14,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ErrorToast extends StatelessWidget {
  const _ErrorToast({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: _Tokens.surface,
        border: Border.fromBorderSide(BorderSide(color: _Tokens.alert, width: 2)),
        boxShadow: [BoxShadow(color: _Tokens.alert, offset: Offset(4, 4))],
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        message,
        style: const TextStyle(
          fontFamily: _Tokens.majorMono,
          color: _Tokens.ink,
          fontSize: 14,
        ),
      ),
    );
  }
}
