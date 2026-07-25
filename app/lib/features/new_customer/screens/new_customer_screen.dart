import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/models/models.dart';
import '../../../features/customers/providers/customer_provider.dart';
import '../../../shared/widgets/common/app_widgets.dart';

class NewCustomerScreen extends ConsumerStatefulWidget {
  const NewCustomerScreen({super.key});

  @override
  ConsumerState<NewCustomerScreen> createState() => _NewCustomerScreenState();
}

class _NewCustomerScreenState extends ConsumerState<NewCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _locationController = TextEditingController();
  final _addressController = TextEditingController();
  final _businessTypeController = TextEditingController();
  final _expectedAmountController = TextEditingController();
  final _interestedProductsController = TextEditingController();
  final _remarksController = TextEditingController();
  ProspectStatus _status = ProspectStatus.prospect;
  bool _isSaving = false;

  @override
  void dispose() {
    _customerNameController.dispose();
    _shopNameController.dispose();
    _contactNumberController.dispose();
    _locationController.dispose();
    _addressController.dispose();
    _businessTypeController.dispose();
    _expectedAmountController.dispose();
    _interestedProductsController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  String get _statusLabel => switch (_status) {
        ProspectStatus.prospect => 'Prospect',
        ProspectStatus.followUp => 'Follow-up',
        ProspectStatus.converted => 'Converted',
      };

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final expectedRaw = _expectedAmountController.text.trim();
    double? expectedAmount;
    if (expectedRaw.isNotEmpty) {
      expectedAmount = double.tryParse(expectedRaw);
      if (expectedAmount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid expected amount')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final result = await ref.read(customersRepositoryProvider).createContactInfo(
            customerName: _customerNameController.text,
            shopName: _shopNameController.text,
            contactNumber: _contactNumberController.text,
            location: _locationController.text,
            address: _addressController.text,
            businessType: _businessTypeController.text,
            products: _interestedProductsController.text,
            remarks: _remarksController.text,
            status: _statusLabel,
            expectedAmount: expectedAmount,
            flag: 'N',
          );

      if (!mounted) return;
      final code = result['customerCode']?.toString() ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            code.isEmpty
                ? 'Customer saved'
                : 'Customer saved (code $code)',
          ),
        ),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Customer')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: _customerNameController,
                label: 'Customer Name',
                prefixIcon: AppIcons.user,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _shopNameController,
                label: 'Shop Name',
                prefixIcon: AppIcons.store,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _contactNumberController,
                label: 'Contact Number',
                prefixIcon: AppIcons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _locationController,
                label: 'Location',
                prefixIcon: AppIcons.locationPin,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _addressController,
                label: 'Address',
                prefixIcon: AppIcons.mapPin,
                hint: 'Street / building / area',
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _businessTypeController,
                label: 'Business Type',
                prefixIcon: AppIcons.business,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _expectedAmountController,
                label: 'Expected Amount',
                keyboardType: TextInputType.number,
                prefixIcon: AppIcons.rupee,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _interestedProductsController,
                label: 'Interested Products',
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _remarksController,
                label: 'Remarks',
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              const Text(
                'Status',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              SegmentedButton<ProspectStatus>(
                segments: const [
                  ButtonSegment(
                    value: ProspectStatus.prospect,
                    label: Text('Prospect'),
                  ),
                  ButtonSegment(
                    value: ProspectStatus.followUp,
                    label: Text('Follow-up'),
                  ),
                  ButtonSegment(
                    value: ProspectStatus.converted,
                    label: Text('Converted'),
                  ),
                ],
                selected: {_status},
                onSelectionChanged: _isSaving
                    ? null
                    : (s) => setState(() => _status = s.first),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _isSaving ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Customer'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
