import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/common/app_widgets.dart';

class VisitDetailsForm extends StatefulWidget {
  const VisitDetailsForm({
    super.key,
    required this.reasons,
    required this.selectedReason,
    required this.onReasonChanged,
    required this.remarksController,
    required this.expectedOrderController,
    required this.followUpController,
    required this.followUpDate,
    required this.onPickFollowUpDate,
    required this.onQuickFollowUp,
    this.suggestedProductCount = 0,
  });

  final List<String> reasons;
  final String? selectedReason;
  final ValueChanged<String?> onReasonChanged;
  final TextEditingController remarksController;
  final TextEditingController expectedOrderController;
  final TextEditingController followUpController;
  final DateTime? followUpDate;
  final VoidCallback onPickFollowUpDate;
  final ValueChanged<int> onQuickFollowUp;
  final int suggestedProductCount;

  @override
  State<VisitDetailsForm> createState() => _VisitDetailsFormState();
}

class _VisitDetailsFormState extends State<VisitDetailsForm> {
  @override
  void initState() {
    super.initState();
    widget.remarksController.addListener(_onFieldChanged);
    widget.expectedOrderController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    widget.remarksController.removeListener(_onFieldChanged);
    widget.expectedOrderController.removeListener(_onFieldChanged);
    super.dispose();
  }

  void _onFieldChanged() => setState(() {});

  int _completionPercent() {
    var filled = 0;
    if (widget.selectedReason != null) filled++;
    if (widget.remarksController.text.trim().isNotEmpty) filled++;
    if (widget.expectedOrderController.text.trim().isNotEmpty) filled++;
    if (widget.followUpDate != null) filled++;
    return ((filled / 4) * 100).round();
  }

  bool _isQuickDateSelected(int days) {
    if (widget.followUpDate == null) return false;
    final target = DateTime.now().add(Duration(days: days));
    return widget.followUpDate!.year == target.year &&
        widget.followUpDate!.month == target.month &&
        widget.followUpDate!.day == target.day;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final completion = _completionPercent();

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
          _FormHeader(completion: completion, theme: theme),
          Container(
            height: 1,
            color: theme.colorScheme.border.withValues(alpha: 0.65),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _VisitSummaryRow(
                  theme: theme,
                  suggestedCount: widget.suggestedProductCount,
                ),
                const SizedBox(height: 18),
                _SectionLabel(
                  icon: AppIcons.list,
                  title: 'Recovery Reason',
                  subtitle: 'Why is this visit needed?',
                  theme: theme,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.reasons.map((reason) {
                    final selected = widget.selectedReason == reason;
                    return _ReasonChip(
                      label: reason,
                      selected: selected,
                      onTap: () =>
                          widget.onReasonChanged(selected ? null : reason),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                _SectionLabel(
                  icon: AppIcons.note,
                  title: 'Visit Notes',
                  subtitle: 'Capture key observations',
                  theme: theme,
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: widget.remarksController,
                  label: 'Remarks',
                  hint: 'Customer feedback, stock issues, competitor activity...',
                  maxLines: 4,
                  prefixIcon: AppIcons.note,
                ),
                const SizedBox(height: 20),
                _SectionLabel(
                  icon: AppIcons.money,
                  title: 'Order & Follow-up',
                  subtitle: 'Expected value and next action',
                  theme: theme,
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: widget.expectedOrderController,
                  label: 'Expected Order (QAR)',
                  hint: 'Enter expected order amount',
                  keyboardType: TextInputType.number,
                  prefixIcon: AppIcons.rupee,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final amount in const [10000, 25000, 50000, 100000])
                      _QuickAmountChip(
                        amount: amount,
                        selected: widget.expectedOrderController.text ==
                            amount.toString(),
                        onTap: () {
                          widget.expectedOrderController.text =
                              amount.toString();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: widget.followUpController,
                  label: 'Follow-up Date',
                  hint: 'Select follow-up date',
                  readOnly: true,
                  onTap: widget.onPickFollowUpDate,
                  prefixIcon: AppIcons.event,
                  suffixIcon: widget.followUpDate != null
                      ? Icon(
                          AppIcons.check,
                          size: 18,
                          color: AppColors.successGreen,
                        )
                      : Icon(
                          AppIcons.calendar,
                          size: 18,
                          color: theme.colorScheme.mutedForeground,
                        ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final days in const [3, 7, 14, 30])
                      _QuickDateChip(
                        label: days == 7
                            ? '1 week'
                            : days == 14
                                ? '2 weeks'
                                : days == 30
                                    ? '1 month'
                                    : '$days days',
                        selected: _isQuickDateSelected(days),
                        onTap: () => widget.onQuickFollowUp(days),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormHeader extends StatelessWidget {
  const _FormHeader({
    required this.completion,
    required this.theme,
  });

  final int completion;
  final ShadThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isComplete = completion == 100;

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
              AppIcons.clipboard,
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
                  'Visit Details',
                  style: theme.textTheme.large.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete all fields before ending visit',
                  style: theme.textTheme.muted.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isComplete
                  ? AppColors.successGreen.withValues(alpha: 0.12)
                  : AppColors.brand.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDecorations.radiusPill),
              border: Border.all(
                color: isComplete
                    ? AppColors.successGreen.withValues(alpha: 0.35)
                    : AppColors.brand.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              '$completion%',
              style: theme.textTheme.small.copyWith(
                fontWeight: FontWeight.w700,
                color: isComplete ? AppColors.successGreenDark : AppColors.brand,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitSummaryRow extends StatelessWidget {
  const _VisitSummaryRow({
    required this.theme,
    required this.suggestedCount,
  });

  final ShadThemeData theme;
  final int suggestedCount;

  @override
  Widget build(BuildContext context) {
    return _SummaryTile(
      icon: AppIcons.recommend,
      label: 'Suggested',
      value: '$suggestedCount',
      color: AppColors.brand,
      theme: theme,
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ShadThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.large.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.muted.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.theme,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ShadThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.brandContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.brand),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.large.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.muted.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDecorations.radiusPill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.brand.withValues(alpha: 0.12)
                : theme.colorScheme.muted.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(AppDecorations.radiusPill),
            border: Border.all(
              color: selected
                  ? AppColors.brand
                  : theme.colorScheme.border.withValues(alpha: 0.8),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(AppIcons.check, size: 14, color: AppColors.brand),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: theme.textTheme.small.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? AppColors.brandDark : theme.colorScheme.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAmountChip extends StatelessWidget {
  const _QuickAmountChip({
    required this.amount,
    required this.selected,
    required this.onTap,
  });

  final int amount;
  final bool selected;
  final VoidCallback onTap;

  String get _label => CurrencyFormatter.shorthand(amount);

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.brandContainer.withValues(alpha: 0.7)
                : theme.colorScheme.muted.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.brand : theme.colorScheme.border,
            ),
          ),
          child: Text(
            _label,
            style: theme.textTheme.small.copyWith(
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.brandDark : theme.colorScheme.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickDateChip extends StatelessWidget {
  const _QuickDateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.successGreenContainer.withValues(alpha: 0.8)
                : theme.colorScheme.muted.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? AppColors.successGreen
                  : theme.colorScheme.border,
            ),
          ),
          child: Text(
            label,
            style: theme.textTheme.small.copyWith(
              fontWeight: FontWeight.w600,
              color: selected
                  ? AppColors.successGreenDark
                  : theme.colorScheme.foreground,
            ),
          ),
        ),
      ),
    );
  }
}
