import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_decorations.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final accent = color ?? theme.colorScheme.primary;

    return ShadGestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          gradient: AppDecorations.cardSheen,
          border: Border.all(color: accent.withValues(alpha: 0.08)),
          boxShadow: AppDecorations.cardShadow(accent),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          child: Stack(
            children: [
              Positioned(
                right: -12,
                top: -12,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accent.withValues(alpha: 0.18),
                                accent.withValues(alpha: 0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: accent, size: 18),
                        ),
                        if (onTap != null)
                          Icon(
                            AppIcons.chevronRight,
                            size: 14,
                            color: theme.colorScheme.mutedForeground,
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      value,
                      style: theme.textTheme.h3.copyWith(
                        color: theme.colorScheme.foreground,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: theme.textTheme.muted.copyWith(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.small.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProgressCard extends StatelessWidget {
  const ProgressCard({
    super.key,
    required this.title,
    required this.percentage,
    required this.current,
    required this.target,
    this.color,
    this.compact = false,
  });

  final String title;
  final double percentage;
  final String current;
  final String target;
  final Color? color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final accent = color ?? theme.colorScheme.primary;
    final clamped = (percentage.clamp(0, 100) / 100).toDouble();

    if (compact) {
      return _CompactProgress(
        title: title,
        percentage: percentage,
        current: current,
        target: target,
        accent: accent,
        clamped: clamped,
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent,
            Color.lerp(accent, Colors.black, 0.12)!,
          ],
        ),
        boxShadow: AppDecorations.elevatedShadow(accent),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.large.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppDecorations.radiusPill),
                ),
                child: Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: theme.textTheme.small.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDecorations.radiusPill),
            child: LinearProgressIndicator(
              value: clamped,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(current, style: theme.textTheme.muted.copyWith(color: Colors.white70)),
              Text(target, style: theme.textTheme.muted.copyWith(color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactProgress extends StatelessWidget {
  const _CompactProgress({
    required this.title,
    required this.percentage,
    required this.current,
    required this.target,
    required this.accent,
    required this.clamped,
  });

  final String title;
  final double percentage;
  final String current;
  final String target;
  final Color accent;
  final double clamped;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
        boxShadow: AppDecorations.cardShadow(accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600)),
              ),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: theme.textTheme.small.copyWith(color: accent, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ShadProgress(
            value: clamped,
            color: accent,
            backgroundColor: accent.withValues(alpha: 0.12),
            minHeight: 6,
          ),
          const SizedBox(height: 6),
          Text('$current / $target', style: theme.textTheme.muted.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}

/// Side-by-side progress summary for dashboard hero.
class ProgressHero extends StatelessWidget {
  const ProgressHero({
    super.key,
    required this.dailyPercent,
    required this.dailyCurrent,
    required this.dailyTarget,
    required this.monthlyPercent,
    required this.monthlyCurrent,
    required this.monthlyTarget,
    required this.dailyColor,
    required this.monthlyColor,
  });

  final double dailyPercent;
  final String dailyCurrent;
  final String dailyTarget;
  final double monthlyPercent;
  final String monthlyCurrent;
  final String monthlyTarget;
  final Color dailyColor;
  final Color monthlyColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ProgressCard(
          title: 'Daily Sales Target',
          percentage: dailyPercent,
          current: dailyCurrent,
          target: dailyTarget,
          color: dailyColor,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ProgressCard(
                title: 'Monthly Target',
                percentage: monthlyPercent,
                current: monthlyCurrent,
                target: monthlyTarget,
                color: monthlyColor,
                compact: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
