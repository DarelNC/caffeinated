import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'screen_awake_service.dart';

/// Tokens lifted directly from the supplied mockup (New Cycle, Oxblood
/// ground) — see docs/rules.md for what got adapted vs. copied exactly.
class _T {
  static const ground = Color(0xFF2A0F14);
  static const groundDeep = Color(0xFF140609);
  static const emberGlow = Color(0xFF6B1F18);
  static const ink = Color(0xFFF6EFE6);
  static const mutedInk = Color(0xFFD8B6AD);
  static const dim = Color(0xFF8F6A62);
  static const signal = Color(0xFFE9FF4F);
  static const alert = Color(0xFFFF5C1C);
  static const rust = Color(0xFF8C2F1B);

  static const archivoBlack = 'Archivo Black';
  static const majorMono = 'Major Mono Display';
  static const dmSerifItalic = 'DM Serif Display Italic';
  static const spaceGrotesk = 'Space Grotesk';
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
        fontFamily: _T.spaceGrotesk,
        scaffoldBackgroundColor: _T.ground,
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _service = ScreenAwakeService();

  AwakeDuration _duration = AwakeDuration.tenMinutes;
  bool _isRunning = false;
  bool _busy = false;
  String? _error;
  DateTime? _endTime;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncWithReality();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
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
    final status = await _service.getStatus();
    if (!mounted) return;
    setState(() {
      _isRunning = status.isRunning;
      _endTime = status.endTime;
    });
    _restartClockTimer();
    if (status.isRunning) {
      // In case an OEM notification shade let the notification get swiped
      // away while the service kept running in the background.
      await _service.refreshNotification();
    }
  }

  void _restartClockTimer() {
    _clockTimer?.cancel();
    if (!_isRunning || _endTime == null) return;
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (DateTime.now().isAfter(_endTime!)) {
        _clockTimer?.cancel();
        _syncWithReality(); // confirm the native side actually stopped
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _toggle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final wantsRunning = !_isRunning;
      if (wantsRunning) {
        // Awaited, not fire-and-forget: if this is the first-ever start, the
        // permission dialog from initState may not have resolved yet, and
        // starting the foreground service before Android has decided
        // grants/denies POST_NOTIFICATIONS means the notification silently
        // never posts (the service and wake lock still work either way —
        // that permission only gates whether the notification is shown).
        await _requestNotificationPermission();
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
        if (confirmed) {
          _isRunning = wantsRunning;
          _endTime = wantsRunning
              ? (_duration.minutes == null
                  ? null
                  : DateTime.now().add(Duration(minutes: _duration.minutes!)))
              : null;
        } else {
          _error = wantsRunning
              ? "couldn't confirm it started — try again."
              : "couldn't confirm it stopped — try again.";
        }
      });
      _restartClockTimer();
    } on PlatformException catch (e) {
      setState(() => _error = e.message ?? 'something went wrong.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectDuration(AwakeDuration duration) async {
    setState(() {
      _duration = duration;
      if (_isRunning) {
        _endTime = duration.minutes == null
            ? null
            : DateTime.now().add(Duration(minutes: duration.minutes!));
      }
    });
    // If it's already running, re-arm the timer immediately with the new
    // duration rather than making the user stop and start again.
    if (_isRunning) {
      await _service.start(duration);
      _restartClockTimer();
    }
  }

  Duration get _remaining {
    if (_endTime == null) return Duration.zero;
    final diff = _endTime!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.ground,
      body: Stack(
        children: [
          const Positioned.fill(child: _Backdrop()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusRow(isRunning: _isRunning),
                  const SizedBox(height: 24),
                  const _Headline(),
                  const Spacer(flex: 3),
                  SizedBox(
                    width: double.infinity,
                    child: Center(
                      child: GestureDetector(
                        onTap: _busy ? null : _toggle,
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          children: [
                            _MugGlyph(isRunning: _isRunning),
                            const SizedBox(height: 14),
                            Text(
                              _isRunning ? 'tap to let it sleep' : 'tap to caffeinate',
                              style: TextStyle(
                                fontFamily: _T.archivoBlack,
                                fontSize: 15,
                                letterSpacing: 2,
                                color: _isRunning ? _T.signal : _T.dim,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 3),
                  _TimeLeftPanel(
                    duration: _duration,
                    isRunning: _isRunning,
                    remaining: _remaining,
                  ),
                  const SizedBox(height: 20),
                  _DurationGrid(
                    selected: _duration,
                    onSelected: _busy ? null : _selectDuration,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _ErrorNote(message: _error!),
                  ],
                  const Spacer(flex: 2),
                  const _StickyNotes(),
                  const SizedBox(height: 18),
                  const _Footer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient wash + faint grid + two slow-rotating rings, behind everything.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.72, -0.76),
                  radius: 1.15,
                  colors: [_T.emberGlow, _T.ground, _T.groundDeep],
                  stops: [0.0, 0.56, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          Positioned(
            right: -150,
            top: -120,
            child: _RotatingRing(
              size: 420,
              color: _T.signal.withValues(alpha: 0.3),
              dashed: true,
              period: const Duration(seconds: 90),
            ),
          ),
          Positioned(
            left: -190,
            top: 520,
            child: _RotatingRing(
              size: 640,
              color: _T.alert.withValues(alpha: 0.28),
              dashed: false,
              period: const Duration(seconds: 140),
              reverse: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _T.ink.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 26) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 26) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RotatingRing extends StatefulWidget {
  const _RotatingRing({
    required this.size,
    required this.color,
    required this.dashed,
    required this.period,
    this.reverse = false,
  });

  final double size;
  final Color color;
  final bool dashed;
  final Duration period;
  final bool reverse;

  @override
  State<_RotatingRing> createState() => _RotatingRingState();
}

class _RotatingRingState extends State<_RotatingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.period)..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final turns = widget.reverse ? -_c.value : _c.value;
        return Transform.rotate(
          angle: turns * 2 * math.pi,
          child: child,
        );
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: widget.dashed
            ? CustomPaint(painter: _DashedCirclePainter(color: widget.color))
            : DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: widget.color, width: 2),
                ),
              ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final radius = size.width / 2;
    final center = Offset(radius, radius);
    const dashLength = 10.0, gapLength = 8.0;
    final circumference = 2 * math.pi * radius;
    final dashCount = (circumference / (dashLength + gapLength)).floor();
    final anglePerDash = 2 * math.pi / dashCount;
    final dashAngle = anglePerDash * (dashLength / (dashLength + gapLength));
    for (var i = 0; i < dashCount; i++) {
      final start = i * anglePerDash;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        dashAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.isRunning});
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'v0.1 / newcycle',
          style: TextStyle(fontFamily: _T.majorMono, fontSize: 13, color: _T.mutedInk),
        ),
        Text(
          isRunning ? 'awake' : 'asleep',
          style: TextStyle(
            fontFamily: _T.majorMono,
            fontSize: 13,
            color: isRunning ? _T.signal : _T.dim,
          ),
        ),
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STAY',
          style: TextStyle(
            fontFamily: _T.archivoBlack,
            fontSize: 62,
            height: 0.85,
            letterSpacing: -2.5,
            color: _T.ink,
            shadows: [Shadow(color: _T.rust, offset: Offset(6, 6))],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: 52, top: 2),
          child: Text(
            'awake',
            style: TextStyle(
              fontFamily: _T.dmSerifItalic,
              fontStyle: FontStyle.italic,
              fontSize: 42,
              height: 0.95,
              color: _T.signal,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'ON PURPOSE',
            style: TextStyle(
              fontFamily: _T.archivoBlack,
              fontSize: 36,
              height: 0.9,
              letterSpacing: -1.8,
              color: _T.alert,
            ),
          ),
        ),
      ],
    );
  }
}

class _MugGlyph extends StatefulWidget {
  const _MugGlyph({required this.isRunning});
  final bool isRunning;

  @override
  State<_MugGlyph> createState() => _MugGlyphState();
}

class _MugGlyphState extends State<_MugGlyph> with SingleTickerProviderStateMixin {
  late final AnimationController _steam;

  @override
  void initState() {
    super.initState();
    _steam = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat();
  }

  @override
  void dispose() {
    _steam.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 184,
      height: 172,
      child: Stack(
        children: [
          if (widget.isRunning) ...[
            _SteamBar(controller: _steam, left: 38, phase: 0),
            _SteamBar(controller: _steam, left: 70, phase: 0.2115),
            _SteamBar(controller: _steam, left: 102, phase: 0.4230),
          ],
          // Handle: a bracket open on the left, attached to the cup's right edge.
          Positioned(
            right: 0,
            top: 44,
            child: Container(
              width: 44,
              height: 62,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: _T.ink, width: 5),
                  right: BorderSide(color: _T.ink, width: 5),
                  bottom: BorderSide(color: _T.ink, width: 5),
                ),
              ),
            ),
          ),
          // Cup body with the animated liquid fill.
          Positioned(
            left: 12,
            top: 32,
            child: Container(
              width: 124,
              height: 108,
              decoration: BoxDecoration(
                border: Border.all(color: _T.ink, width: 5),
                color: _T.groundDeep,
              ),
              child: ClipRect(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 420),
                    curve: const Cubic(0.16, 0.84, 0.28, 1),
                    width: double.infinity,
                    height: widget.isRunning ? 98 * 0.72 : 0,
                    color: _T.signal,
                  ),
                ),
              ),
            ),
          ),
          // Base.
          Positioned(left: 0, top: 150, child: Container(width: 150, height: 9, color: _T.ink)),
        ],
      ),
    );
  }
}

class _SteamBar extends StatelessWidget {
  const _SteamBar({required this.controller, required this.left, required this.phase});

  final AnimationController controller;
  final double left;
  final double phase;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = (controller.value + phase) % 1.0;
        final opacity = t < 0.35 ? (t / 0.35) : (1 - (t - 0.35) / 0.65);
        final translateY = -22 * t + 6 * (1 - t);
        final scaleY = 0.7 + 0.55 * t;
        return Positioned(
          left: left,
          top: 22,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, translateY),
              child: Transform.scale(
                scaleY: scaleY,
                alignment: Alignment.bottomCenter,
                child: Container(width: 6, height: 24, color: _T.signal),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TimeLeftPanel extends StatelessWidget {
  const _TimeLeftPanel({
    required this.duration,
    required this.isRunning,
    required this.remaining,
  });

  final AwakeDuration duration;
  final bool isRunning;
  final Duration remaining;

  String get _clockText {
    if (duration.minutes == null) return isRunning ? 'forever' : 'standby';
    final total = isRunning ? remaining : Duration(minutes: duration.minutes!);
    final mm = total.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = total.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final color = isRunning ? _T.signal : _T.dim;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: _T.ink.withValues(alpha: 0.18), width: 2),
        color: _T.groundDeep,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'TIME LEFT',
            style: TextStyle(
              fontFamily: _T.spaceGrotesk,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1.1,
              color: _T.dim,
            ),
          ),
          Text(
            _clockText,
            style: TextStyle(
              fontFamily: _T.archivoBlack,
              fontSize: 30,
              letterSpacing: -0.6,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationGrid extends StatelessWidget {
  const _DurationGrid({required this.selected, required this.onSelected});

  final AwakeDuration selected;
  final ValueChanged<AwakeDuration>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'KEEP IT UP FOR',
          style: TextStyle(
            fontFamily: _T.spaceGrotesk,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 1.1,
            color: _T.mutedInk,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final d in AwakeDuration.values) ...[
              Expanded(
                child: _DurationTile(
                  duration: d,
                  isSelected: d == selected,
                  onTap: onSelected == null ? null : () => onSelected!(d),
                ),
              ),
              if (d != AwakeDuration.values.last) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }
}

class _DurationTile extends StatelessWidget {
  const _DurationTile({
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
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          border: Border.all(color: _T.ink, width: 2),
          color: isSelected ? _T.signal : Colors.transparent,
          boxShadow: isSelected
              ? const [BoxShadow(color: _T.rust, offset: Offset(4, 4))]
              : null,
        ),
        child: Column(
          children: [
            SizedBox(
              height: 30,
              child: Center(
                child: Transform.translate(
                  offset: Offset(0, duration.value == '∞' ? -4 : 0),
                  child: Text(
                    duration.value,
                    style: TextStyle(
                      fontFamily: _T.archivoBlack,
                      // The infinity glyph sits smaller/thinner than digits
                      // at the same size in this face — bump it so it reads
                      // as the same visual weight, not a shrunken afterthought.
                      fontSize: duration.value == '∞' ? 34 : 24,
                      color: isSelected ? _T.ground : _T.ink,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              duration.unit,
              style: TextStyle(
                fontFamily: _T.spaceGrotesk,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.9,
                color: isSelected ? _T.ground : _T.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: _T.groundDeep,
        border: Border.fromBorderSide(BorderSide(color: _T.alert, width: 2)),
        boxShadow: [BoxShadow(color: _T.alert, offset: Offset(4, 4))],
      ),
      child: Text(
        message,
        style: const TextStyle(fontFamily: _T.spaceGrotesk, color: _T.ink, fontSize: 13),
      ),
    );
  }
}

class _StickyNotes extends StatelessWidget {
  const _StickyNotes();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const _FloatingNote(
          angle: -0.03,
          period: Duration(milliseconds: 6800),
          child: SizedBox(
            width: 150,
            child: Text(
              'one job. it does it.',
              style: TextStyle(
                fontFamily: _T.dmSerifItalic,
                fontStyle: FontStyle.italic,
                fontSize: 19,
                height: 1.2,
                color: _T.mutedInk,
              ),
            ),
          ),
        ),
        _FloatingNote(
          angle: 0.05,
          period: const Duration(milliseconds: 7400),
          child: Container(
            width: 150,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: _T.ink,
            child: const Text(
              'your laptop will not decide for you',
              style: TextStyle(
                fontFamily: _T.spaceGrotesk,
                fontWeight: FontWeight.w500,
                fontSize: 12,
                height: 1.35,
                color: _T.ground,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FloatingNote extends StatefulWidget {
  const _FloatingNote({required this.angle, required this.period, required this.child});

  final double angle;
  final Duration period;
  final Widget child;

  @override
  State<_FloatingNote> createState() => _FloatingNoteState();
}

class _FloatingNoteState extends State<_FloatingNote> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.period)..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.translate(
          offset: Offset(0, -6 * t),
          child: Transform.rotate(angle: widget.angle + (0.021 * t), child: child),
        );
      },
      child: widget.child,
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'nc',
              style: TextStyle(fontFamily: _T.majorMono, fontSize: 30, color: _T.ink),
            ),
            SizedBox(height: 4),
            Text(
              'running on coffee and bad decisions ☕',
              style: TextStyle(
                fontFamily: _T.spaceGrotesk,
                fontWeight: FontWeight.w500,
                fontSize: 11,
                color: _T.dim,
              ),
            ),
          ],
        ),
        Transform.rotate(
          angle: -0.12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(border: Border.all(color: _T.alert, width: 2)),
            child: const Text(
              'UNTESTED',
              style: TextStyle(
                fontFamily: _T.spaceGrotesk,
                fontWeight: FontWeight.w700,
                fontSize: 10,
                letterSpacing: 1,
                color: _T.alert,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
