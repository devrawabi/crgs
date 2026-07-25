import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_icons.dart';
import '../../../shared/widgets/common/app_widgets.dart';
import '../../tasks/providers/task_provider.dart';
import '../../customers/providers/customer_provider.dart';

class RecoveryFormScreen extends ConsumerStatefulWidget {
  const RecoveryFormScreen({super.key, required this.customerId});

  final String customerId;

  @override
  ConsumerState<RecoveryFormScreen> createState() => _RecoveryFormScreenState();
}

class _RecoveryFormScreenState extends ConsumerState<RecoveryFormScreen> {
  String? _selectedReason;
  final _categoryController = TextEditingController();
  final _productController = TextEditingController();
  final _remarksController = TextEditingController();
  final _compProductController = TextEditingController();
  final _compBrandController = TextEditingController();
  final _compPriceController = TextEditingController();
  final _winningFactorsController = TextEditingController();
  final _compRemarksController = TextEditingController();
  bool _showQualitySection = false;
  bool _showCompetitorSection = false;

  @override
  void dispose() {
    _categoryController.dispose();
    _productController.dispose();
    _remarksController.dispose();
    _compProductController.dispose();
    _compBrandController.dispose();
    _compPriceController.dispose();
    _winningFactorsController.dispose();
    _compRemarksController.dispose();
    super.dispose();
  }

  void _onReasonChanged(String? reason) {
    setState(() {
      _selectedReason = reason;
      _showQualitySection = reason == 'Product Quality Issue';
      _showCompetitorSection = reason == 'Competitor Product';
    });
  }

  void _submit() {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a recovery reason')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recovery report submitted successfully')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final customer = ref.watch(customerByIdProvider(widget.customerId));
    final reasons = ref.watch(recoveryReasonsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Missing Customer Recovery'),
            if (customer != null)
              Text(
                customer.name,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: 'Recovery Reason'),
            DropdownButtonFormField<String>(
              initialValue: _selectedReason,
              decoration: InputDecoration(
                labelText: 'Select Reason',
                prefixIcon: Icon(AppIcons.list),
              ),
              items: reasons
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: _onReasonChanged,
            ),
            if (_showQualitySection) ...[
              const SizedBox(height: 24),
              SectionHeader(title: 'Product Quality Feedback'),
              AppTextField(
                controller: _categoryController,
                label: 'Category',
                prefixIcon: AppIcons.category,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _productController,
                label: 'Product',
                prefixIcon: AppIcons.inventory,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _remarksController,
                label: 'Remarks',
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(AppIcons.camera),
                label: const Text('Upload Photo'),
              ),
            ],
            if (_showCompetitorSection) ...[
              const SizedBox(height: 24),
              SectionHeader(title: 'Competitor Analysis'),
              AppTextField(
                controller: _compProductController,
                label: 'Product',
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _compBrandController,
                label: 'Brand',
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _compPriceController,
                label: 'Competitor Price',
                keyboardType: TextInputType.number,
                prefixIcon: AppIcons.rupee,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _winningFactorsController,
                label: 'Winning Factors',
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _compRemarksController,
                label: 'Remarks',
                maxLines: 3,
              ),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
              child: const Text('Submit Recovery Report'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
