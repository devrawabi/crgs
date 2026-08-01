import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
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
