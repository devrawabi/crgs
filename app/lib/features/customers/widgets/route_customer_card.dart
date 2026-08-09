import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/models.dart';
import '../../../shared/widgets/badges/priority_badge.dart';

class RouteCustomerCard extends StatelessWidget {
  const RouteCustomerCard({
    super.key,
    required this.customer,
    required this.onTap,
    this.highlighted = false,
    this.highlightLabel = 'Task',
  });

  final CustomerModel customer;
  final VoidCallback onTap;
  final bool highlighted;
  final String highlightLabel;

  String _missingLabel(CustomerModel customer) {
    final date = customer.lastPurchaseDate;
    if (date == null) return 'No purchase on record';
    final dateText =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final days = customer.daysSincePurchase;
    return days != null
        ? 'Last bill $dateText · ${days}d ago'
        : 'Last bill $dateText';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    final metaParts = <String>[
      if (customer.id.isNotEmpty) customer.id,
      if (customer.contactPerson.isNotEmpty) customer.contactPerson,
      if (customer.mobile.isNotEmpty) customer.mobile,
      if (customer.category.isNotEmpty) customer.category,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ShadGestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: highlighted
                ? AppColors.accent.withValues(alpha: 0.08)
                : theme.colorScheme.card,
            borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
            border: Border.all(
              color: highlighted
                  ? AppColors.accent.withValues(alpha: 0.85)
                  : theme.colorScheme.border,
              width: highlighted ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            customer.name,
                            style: theme.textTheme.large.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (highlighted) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(
                                AppDecorations.radiusPill,
                              ),
                            ),
                            child: Text(
                              highlightLabel,
                              style: theme.textTheme.small.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        PriorityBadge(priority: customer.priority),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      metaParts.join(' · '),
                      style: theme.textTheme.muted.copyWith(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (customer.address.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        customer.address,
                        style: theme.textTheme.muted.copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (customer.isMissing) ...[
                      const SizedBox(height: 3),
                      Text(
                        _missingLabel(customer),
                        style: theme.textTheme.muted.copyWith(
                          fontSize: 12,
                          color: AppColors.missingRed,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (customer.creditAmount > 0 || customer.creditLimit > 0) ...[
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (customer.creditLimit > 0)
                            'Limit ${CurrencyFormatter.format(customer.creditLimit)}',
                          if (customer.creditAmount > 0)
                            'Due ${CurrencyFormatter.format(customer.creditAmount)}',
                        ].join(' · '),
                        style: theme.textTheme.muted.copyWith(
                          fontSize: 12,
                          color: customer.creditAmount > 0
                              ? AppColors.outstandingOrange
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                AppIcons.chevronRight,
                size: 16,
                color: theme.colorScheme.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
