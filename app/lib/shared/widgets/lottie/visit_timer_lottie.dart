import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Clock timer Lottie with brighter hand colors applied at runtime.
class VisitTimerLottie extends StatelessWidget {
  const VisitTimerLottie({
    super.key,
    required this.isActive,
    this.size = 112,
  });

  final bool isActive;
  final double size;

  static const _assetPath = 'assets/lottie/clock_timer.json';

  /// Slightly brightened skin tone for the hand holding the stopwatch.
  static const _brightSkinHand = Color(0xFFE8B48A);

  /// Brighter blue for the rotating clock hand.
  static const _brightClockHand = Color(0xFF7EC8E8);

  static Color _remapColor(Color color) {
    final r = (color.r * 255.0).round().clamp(0, 255);
    final g = (color.g * 255.0).round().clamp(0, 255);
    final b = (color.b * 255.0).round().clamp(0, 255);

    // Original + edited skin-brown fills in the animation.
    final isSkinTone = r >= 150 && r <= 220 && g >= 90 && g <= 170 && b >= 40 && b <= 120;
    if (isSkinTone) return _brightSkinHand;

    // Clock hour-hand fill/stroke blue.
    final isClockHandBlue = r >= 130 && r <= 190 && g >= 170 && g <= 220 && b >= 200;
    if (isClockHandBlue) return _brightClockHand;

    return color;
  }

  static final _delegates = LottieDelegates(
    values: [
      ValueDelegate.color(
        const ['**'],
        callback: (frame) => _remapColor(frame.startValue ?? Colors.transparent),
      ),
      ValueDelegate.strokeColor(
        const ['**'],
        callback: (frame) => _remapColor(frame.startValue ?? Colors.transparent),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      _assetPath,
      width: size,
      height: size,
      repeat: isActive,
      animate: isActive,
      fit: BoxFit.contain,
      delegates: _delegates,
    );
  }
}
