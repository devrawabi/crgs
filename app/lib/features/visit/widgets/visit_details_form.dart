import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/common/app_widgets.dart';
import 'visit_product_feedback_section.dart';

class VisitDetailsForm extends StatefulWidget {
  const VisitDetailsForm({
    super.key,
    required this.customerId,
    required this.customerName,
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

  final String customerId;
  final String customerName;
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

  int? _selectedQuickAmount() {
    final text = widget.expectedOrderController.text.trim();
    final amount = int.tryParse(text);
    if (amount == null) return null;
    const options = [10000, 25000, 50000, 100000];
    return options.contains(amount) ? amount : null;
  }

  int? _selectedQuickFollowUpDays() {
    for (final days in const [3, 7, 14, 30]) {
      if (_isQuickDateSelected(days)) return days;
    }
    return null;
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
                _ShadQuickSelect<String>(
                  key: ValueKey('reason-${widget.selectedReason}'),
                  label: 'Select reason',
                  placeholder: 'Select a recovery reason',
                  initialValue: widget.selectedReason,
                  options: widget.reasons,
                  optionLabel: (reason) => reason,
                  onChanged: widget.onReasonChanged,
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
                  hint: 'Stock issues, competitor activity, store notes...',
                  maxLines: 4,
                  prefixIcon: AppIcons.note,
                ),
                const SizedBox(height: 20),
                VisitProductFeedbackSection(
                  customerId: widget.customerId,
                  customerName: widget.customerName,
                ),
                const SizedBox(height: 20),
                _SectionLabel(
                  icon: AppIcons.money,
                  title: 'Order & Follow-up',
                  subtitle: 'Expected value and next action',
                  theme: theme,
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: AppTextField(
                        controller: widget.expectedOrderController,
                        label: 'Expected Order (QAR)',
                        hint: 'Enter expected order amount',
                        keyboardType: TextInputType.number,
                        prefixIcon: AppIcons.rupee,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: _ShadQuickSelect<int>(
                        key: ValueKey('amount-${_selectedQuickAmount()}'),
                        label: 'Quick',
                        placeholder: 'Amount',
                        initialValue: _selectedQuickAmount(),
                        options: const [10000, 25000, 50000, 100000],
                        optionLabel: CurrencyFormatter.shorthand,
                        onChanged: (amount) {
                          if (amount == null) return;
                          widget.expectedOrderController.text =
                              amount.toString();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: AppTextField(
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
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: _ShadQuickSelect<int>(
                        key: ValueKey(
                          'followup-${_selectedQuickFollowUpDays()}',
                        ),
                        label: 'Quick',
                        placeholder: 'Period',
                        initialValue: _selectedQuickFollowUpDays(),
                        options: const [3, 7, 14, 30],
                        optionLabel: (days) => switch (days) {
                          7 => '1 week',
                          14 => '2 weeks',
                          30 => '1 month',
                          _ => '$days days',
                        },
                        onChanged: (days) {
                          if (days == null) return;
                          widget.onQuickFollowUp(days);
                        },
                      ),
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

/// Matches [ShadLabeledField] label + control layout so it aligns with [AppTextField].
class _ShadQuickSelect<T> extends StatelessWidget {
  const _ShadQuickSelect({
    super.key,
    required this.label,
    required this.placeholder,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
    this.initialValue,
  });

  final String label;
  final String placeholder;
  final List<T> options;
  final String Function(T value) optionLabel;
  final ValueChanged<T?> onChanged;
  final T? initialValue;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.small.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.foreground,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ShadSelect<T>(
            initialValue: initialValue,
            placeholder: Text(placeholder),
            onChanged: onChanged,
            selectedOptionBuilder: (context, value) => Text(
              optionLabel(value),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            options: options.map(
              (value) => ShadOption(
                value: value,
                child: Text(optionLabel(value)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
