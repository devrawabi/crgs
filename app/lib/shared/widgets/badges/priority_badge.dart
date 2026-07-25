import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/models.dart';

class PriorityBadge extends StatelessWidget {
  const PriorityBadge({super.key, required this.priority});

  final CustomerPriority priority;

  (String, Color) get _config => switch (priority) {
        CustomerPriority.missing => ('Missing', AppColors.missingRed),
        CustomerPriority.outstanding => ('Outstanding', AppColors.outstandingOrange),
        CustomerPriority.followUp => ('Follow-up', AppColors.followUpBlue),
        CustomerPriority.regular => ('Regular', AppColors.regularGreen),
      };

  @override
  Widget build(BuildContext context) {
    final (label, color) = _config;

    return ShadBadge.outline(
      backgroundColor: color.withValues(alpha: 0.1),
      foregroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ShadBadge(
      backgroundColor: color.withValues(alpha: 0.15),
      foregroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}

class RiskScoreIndicator extends StatelessWidget {
  const RiskScoreIndicator({super.key, required this.score});

  final int score;

  Color get _color {
    if (score >= 70) return AppColors.missingRed;
    if (score >= 40) return AppColors.outstandingOrange;
    return AppColors.regularGreen;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(AppIcons.warning, size: 14, color: _color),
        const SizedBox(width: 4),
        Text(
          'Risk $score',
          style: TextStyle(
            color: _color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
