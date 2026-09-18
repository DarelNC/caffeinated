import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';

import 'screen_awake_service.dart';

// A deliberately loud, non-default palette instead of Material's stock
// purple/blue — see docs/rules.md (design.md adaptation).
class _Palette {
  static const idleBg = Color(0xFF1B1023); // dark plum
  static const activeBg = Color(0xFFFF5A1F); // burnt orange, "espresso shot"
  static const ink = Color(0xFF120B15); // near-black, used for hard borders/shadows
  static const cream = Color(0xFFFAF8FD); // matches the bundled SVG artwork
  static const alert = Color(0xFFFFD400);
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
        fontFamily: 'sans-serif',
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
              ? "Couldn't confirm the screen lock started — try again."
              : "Couldn't confirm it stopped — try again.";
        }
      });
    } on PlatformException catch (e) {
      setState(() => _error = e.message ?? 'Something went wrong.');
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
    final bg = _isRunning ? _Palette.activeBg : _Palette.idleBg;
    final fg = _isRunning ? _Palette.ink : _Palette.cream;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      color: bg,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              children: [
                _Brand(color: fg),
                const Spacer(),
                _PulsingIcon(
                  isRunning: _isRunning,
                  fg: fg,
                  bg: bg,
                  pulse: _pulseController,
                ),
                const SizedBox(height: 28),
                Text(
                  _isRunning ? "SCREEN'S AWAKE" : 'SCREEN CAN SLEEP',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: fg,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusSubtitle(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.75),
                    fontSize: 15,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _DurationRow(
                  selected: _duration,
                  fg: fg,
                  onSelected: _busy ? null : _selectDuration,
                ),
                const SizedBox(height: 20),
                if (_error != null) ...[
                  _ErrorBanner(message: _error!),
                  const SizedBox(height: 12),
                ],
                _ToggleButton(
                  isRunning: _isRunning,
                  busy: _busy,
                  bg: bg,
                  fg: fg,
                  onTap: _toggle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusSubtitle() {
    if (!_isRunning) return 'Pick how long, then hit go.';
    if (_duration.minutes == null) return 'Until you say stop.';
    return 'Off again in ${_duration.label.toLowerCase()}.';
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'CAFFEINATED',
        style: TextStyle(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
        ),
      ),
    );
  }
}

class _PulsingIcon extends StatelessWidget {
  const _PulsingIcon({
    required this.isRunning,
    required this.fg,
    required this.bg,
    required this.pulse,
  });

  final bool isRunning;
  final Color fg;
  final Color bg;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    final asset = isRunning
        ? 'assets/images/ic_caffeinated_on_large.svg'
        : 'assets/images/ic_caffeinated_off_large.svg';

    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final scale = isRunning ? 1.0 + (pulse.value * 0.08) : 1.0;
        final glow = isRunning ? 18.0 + (pulse.value * 22.0) : 0.0;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Offset hard-shadow block behind the icon — the "layered,
            // asymmetric" look instead of a flat centered circle.
            Transform.translate(
              offset: const Offset(10, 10),
              child: Container(
                width: 168,
                height: 168,
                decoration: const BoxDecoration(
                  color: _Palette.ink,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Transform.scale(
              scale: scale,
              child: Container(
                width: 168,
                height: 168,
                decoration: BoxDecoration(
                  color: fg,
                  shape: BoxShape.circle,
                  border: Border.all(color: _Palette.ink, width: 5),
                  boxShadow: isRunning
                      ? [
                          BoxShadow(
                            color: _Palette.alert.withValues(alpha: 0.55),
                            blurRadius: glow,
                            spreadRadius: glow * 0.15,
                          ),
                        ]
                      : null,
                ),
                padding: const EdgeInsets.all(40),
                child: SvgPicture.asset(
                  asset,
                  colorFilter: ColorFilter.mode(bg, BlendMode.srcIn),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DurationRow extends StatelessWidget {
  const _DurationRow({
    required this.selected,
    required this.fg,
    required this.onSelected,
  });

  final AwakeDuration selected;
  final Color fg;
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
              fg: fg,
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
    required this.fg,
    required this.onTap,
  });

  final AwakeDuration duration;
  final bool isSelected;
  final Color fg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _Palette.alert : Colors.transparent,
          border: Border.all(color: fg, width: 2.5),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          duration.label,
          style: TextStyle(
            color: isSelected ? _Palette.ink : fg,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.5,
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
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  final bool isRunning;
  final bool busy;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  State<_ToggleButton> createState() => _ToggleButtonState();
}

class _ToggleButtonState extends State<_ToggleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final shadowOffset = _pressed ? 2.0 : 7.0;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.busy ? null : widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: EdgeInsets.only(top: 7 - shadowOffset, left: 7 - shadowOffset),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _Palette.ink,
              offset: Offset(shadowOffset, shadowOffset),
            ),
          ],
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: widget.fg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _Palette.ink, width: 3),
          ),
          alignment: Alignment.center,
          child: widget.busy
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: widget.bg,
                  ),
                )
              : Text(
                  widget.isRunning ? 'LET IT SLEEP' : 'KEEP IT AWAKE',
                  style: TextStyle(
                    color: widget.bg,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 1,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _Palette.alert,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _Palette.ink, width: 2),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: _Palette.ink,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}
