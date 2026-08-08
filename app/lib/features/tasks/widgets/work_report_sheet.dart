import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../../../data/repositories/work_reports_repository.dart';
import '../../auth/providers/auth_provider.dart';

final workReportsRepositoryProvider = Provider<WorkReportsRepository>((ref) {
  return WorkReportsRepository(ref.watch(apiClientProvider));
});

Future<bool?> showWorkReportSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: ShadTheme.of(context).colorScheme.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: const _WorkReportSheet(),
    ),
  );
}

class _WorkReportSheet extends ConsumerStatefulWidget {
  const _WorkReportSheet();

  @override
  ConsumerState<_WorkReportSheet> createState() => _WorkReportSheetState();
}

class _WorkReportSheetState extends ConsumerState<_WorkReportSheet> {
  final _customerNameController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _customerNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;

    final customerName = _customerNameController.text.trim();
    final notes = _notesController.text.trim();

    if (customerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the customer name')),
      );
      return;
    }
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter what additional work you did')),
      );
      return;
    }

    final user = ref.read(authProvider).user;
    final employeeCode = user?.employeeCode.trim() ?? '';
    if (employeeCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee session not found')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(workReportsRepositoryProvider).submitReport(
            employeeCode: employeeCode,
            customerName: customerName,
            notes: notes,
          );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Additional work report submitted')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit work report')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Additional Work Report',
              style: theme.textTheme.large.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Report extra work you did outside assigned tasks. '
              'This does not create a new task.',
              style: theme.textTheme.muted.copyWith(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Customer name',
              style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _customerNameController,
              enabled: !_isSaving,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Enter customer name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'What did you do?',
              style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 5,
              maxLength: 1000,
              enabled: !_isSaving,
              decoration: const InputDecoration(
                hintText: 'Describe the additional work you completed…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ShadButton.outline(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ShadButton(
                    onPressed: _isSaving ? null : _submit,
                    leading: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(AppIcons.report, size: 16),
                    child: Text(_isSaving ? 'Saving…' : 'Submit Report'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
