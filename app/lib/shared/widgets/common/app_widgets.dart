import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../providers/connectivity_provider.dart';
import '../shad/shad_components.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    if (isOnline) return const SizedBox.shrink();

    return ShadAlert.destructive(
      icon: const Icon(AppIcons.cloudOff, size: 18),
      title: const Text('Offline Mode'),
      description: const Text('Changes will sync when connected'),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.actionLabel,
  });

  final String title;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: theme.textTheme.large),
          if (action != null)
            ShadButton.link(
              onPressed: action,
              child: Text(actionLabel ?? 'View All'),
            ),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: Text(label, style: theme.textTheme.muted),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
    this.readOnly = false,
    this.onTap,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ShadLabeledField(
      label: label,
      controller: controller,
      placeholder: hint,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      leading: prefixIcon != null ? Icon(prefixIcon, size: 18) : null,
      trailing: suffixIcon,
      validator: validator,
    );
  }
}

class QuickActionButton extends StatelessWidget {
  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final accent = color ?? theme.colorScheme.primary;

    return ShadGestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.16),
                    accent.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: accent, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.muted.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.foreground.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class TimelineItem extends StatelessWidget {
  const TimelineItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isFirst,
    required this.isLast,
    this.color,
  });

  final String title;
  final String subtitle;
  final String time;
  final bool isFirst;
  final bool isLast;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final accent = color ?? theme.colorScheme.primary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst ? Colors.transparent : accent.withValues(alpha: 0.3),
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.colorScheme.background, width: 2),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : accent.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: theme.textTheme.muted),
                  const SizedBox(height: 4),
                  Text(time, style: theme.textTheme.muted.copyWith(fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RouteMapSummary extends StatelessWidget {
  const RouteMapSummary({super.key, required this.routeName});

  final String routeName;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        boxShadow: AppDecorations.elevatedShadow(theme.colorScheme.primary),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 168,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.22),
                    AppColors.successGreen.withValues(alpha: 0.12),
                    theme.colorScheme.background,
                  ],
                ),
              ),
              child: Stack(
                children: [
                  CustomPaint(
                    size: const Size(double.infinity, 168),
                    painter: _RouteMapPainter(theme.colorScheme.primary),
                  ),
                  Positioned(
                    left: 14,
                    top: 14,
                    right: 14,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.card.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(AppIcons.route, size: 18, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                routeName,
                                style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '5 stops • 12.4 km • Today',
                                style: theme.textTheme.muted.copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        ShadBadge(
                          backgroundColor: AppColors.successGreen.withValues(alpha: 0.15),
                          foregroundColor: AppColors.successGreen,
                          child: const Text('Live'),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 14,
                    bottom: 12,
                    child: ShadBadge.secondary(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(AppIcons.navigation, size: 14, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          const Text('Tap stops on map'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: theme.colorScheme.card,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _LegendDot(color: AppColors.missingRed, label: 'Missing'),
                  _LegendDot(color: AppColors.outstandingOrange, label: 'Outstanding'),
                  _LegendDot(color: AppColors.followUpBlue, label: 'Follow-up'),
                  _LegendDot(color: AppColors.regularGreen, label: 'Regular'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: ShadTheme.of(context).textTheme.muted.copyWith(fontSize: 10)),
      ],
    );
  }
}

class _RouteMapPainter extends CustomPainter {
  _RouteMapPainter(this.lineColor);

  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final pathPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width * 0.1, size.height * 0.7)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.2, size.width * 0.5, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.7, size.height * 0.8, size.width * 0.9, size.height * 0.3);

    canvas.drawPath(path, pathPaint);

    final stops = [
      (size.width * 0.1, size.height * 0.7, AppColors.missingRed),
      (size.width * 0.35, size.height * 0.35, AppColors.outstandingOrange),
      (size.width * 0.55, size.height * 0.55, AppColors.followUpBlue),
      (size.width * 0.75, size.height * 0.65, AppColors.regularGreen),
      (size.width * 0.9, size.height * 0.3, AppColors.missingRed),
    ];

    for (final (x, y, color) in stops) {
      canvas.drawCircle(
        Offset(x, y),
        7,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(Offset(x, y), 6, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
