import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/common/app_widgets.dart';
import '../../tasks/providers/task_provider.dart';

class OutstandingCollectionScreen extends ConsumerStatefulWidget {
  const OutstandingCollectionScreen({super.key});

  @override
  ConsumerState<OutstandingCollectionScreen> createState() =>
      _OutstandingCollectionScreenState();
}

class _OutstandingCollectionScreenState
    extends ConsumerState<OutstandingCollectionScreen> {
  final _remarksControllers = <String, TextEditingController>{};
  final _notesControllers = <String, TextEditingController>{};
  final _commitmentDates = <String, DateTime>{};

  @override
  void dispose() {
    for (final c in _remarksControllers.values) {
      c.dispose();
    }
    for (final c in _notesControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _remarks(String id) =>
      _remarksControllers.putIfAbsent(id, TextEditingController.new);

  TextEditingController _notes(String id) =>
      _notesControllers.putIfAbsent(id, TextEditingController.new);

  @override
  Widget build(BuildContext context) {
    final invoices = ref.watch(outstandingInvoicesProvider);
    final dateFormat = DateFormat('dd MMM yyyy');
    final currency = CurrencyFormatter.format;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Outstanding Collection'),
            Text(
              '${invoices.length} invoices pending',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: invoices.length,
        itemBuilder: (_, i) {
          final inv = invoices[i];
          final commitment = _commitmentDates[inv.id];

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        inv.invoiceNumber,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        currency(inv.outstandingAmount),
                        style: const TextStyle(
                          color: AppColors.outstandingOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(inv.customerName, style: Theme.of(context).textTheme.bodySmall),
                  const Divider(height: 24),
                  InfoRow(label: 'Invoice Date', value: dateFormat.format(inv.invoiceDate)),
                  InfoRow(label: 'Due Date', value: dateFormat.format(inv.dueDate)),
                  InfoRow(
                    label: 'Outstanding',
                    value: currency(inv.outstandingAmount),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Collection Commitment Date'),
                    subtitle: Text(
                      commitment != null
                          ? dateFormat.format(commitment)
                          : 'Tap to select date',
                    ),
                    trailing: const Icon(AppIcons.calendar),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (date != null) {
                        setState(() => _commitmentDates[inv.id] = date);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  AppTextField(
                    controller: _remarks(inv.id),
                    label: 'Customer Remarks',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _notes(inv.id),
                    label: 'Follow-up Notes',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Collection recorded for ${inv.invoiceNumber}')),
                      );
                    },
                    style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
                    child: const Text('Save Collection'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
