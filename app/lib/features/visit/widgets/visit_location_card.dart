import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../data/models/models.dart';
import '../../../shared/services/location_service.dart';
import '../../../shared/widgets/badges/priority_badge.dart';
import '../../../shared/widgets/maps/interactive_location_map.dart';
import 'visit_location_picker_sheet.dart';

class VisitLocationCard extends StatelessWidget {
  const VisitLocationCard({
    super.key,
    required this.customer,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.onLocationUpdated,
  });

  final CustomerModel customer;
  final double latitude;
  final double longitude;
  final String address;
  final ValueChanged<VisitLocation> onLocationUpdated;

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showVisitLocationPickerSheet(
      context,
      initialLatitude: latitude,
      initialLongitude: longitude,
      initialAddress: address,
    );
    if (picked != null) onLocationUpdated(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        gradient: AppDecorations.cardSheen,
        border: Border.all(color: theme.colorScheme.border),
        boxShadow: AppDecorations.cardShadow(theme.colorScheme.primary),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RouteHeader(customer: customer, theme: theme),
          Container(
            height: 1,
            color: theme.colorScheme.border.withValues(alpha: 0.65),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: InteractiveLocationMap(
              latitude: latitude,
              longitude: longitude,
              height: 180,
              interactive: false,
              onLocationChanged: (_) {},
              onPickLocationPressed: () => _openPicker(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteHeader extends StatelessWidget {
  const _RouteHeader({
    required this.customer,
    required this.theme,
  });

  final CustomerModel customer;
  final ShadThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.brandContainer.withValues(alpha: 0.55),
            theme.colorScheme.card,
          ],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
            ),
            child: const Icon(
              AppIcons.store,
              size: 22,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: theme.textTheme.large.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                _HeaderLine(
                  icon: AppIcons.route,
                  text: customer.routeName,
                  theme: theme,
                ),
                if (customer.location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _HeaderLine(
                    icon: AppIcons.locationPin,
                    text: customer.location,
                    theme: theme,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          PriorityBadge(priority: customer.priority),
        ],
      ),
    );
  }
}

class _HeaderLine extends StatelessWidget {
  const _HeaderLine({
    required this.icon,
    required this.text,
    required this.theme,
  });

  final IconData icon;
  final String text;
  final ShadThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.mutedForeground),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.muted.copyWith(fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
