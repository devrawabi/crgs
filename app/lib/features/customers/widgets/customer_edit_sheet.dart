import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/models/models.dart';
import '../../../shared/widgets/common/app_widgets.dart';
import '../providers/customer_provider.dart';

Future<CustomerModel?> showCustomerEditSheet(
  BuildContext context,
  CustomerModel customer,
) {
  return showModalBottomSheet<CustomerModel>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: ShadTheme.of(context).colorScheme.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _CustomerEditSheet(customer: customer),
    ),
  );
}

class _CustomerEditSheet extends ConsumerStatefulWidget {
  const _CustomerEditSheet({required this.customer});

  final CustomerModel customer;

  @override
  ConsumerState<_CustomerEditSheet> createState() => _CustomerEditSheetState();
}

class _CustomerEditSheetState extends ConsumerState<_CustomerEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _addressController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameController = TextEditingController(text: c.name);
    _mobileController = TextEditingController(text: c.mobile);
    _addressController = TextEditingController(
      text: c.address.isNotEmpty ? c.address : c.location,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final name = _nameController.text.trim();
    final mobile = _mobileController.text.trim();
    final address = _addressController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer name is required')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Insert edit request into CRGS_CONTACTINFO with FLAG = E.
      await ref.read(customersRepositoryProvider).submitCustomerEdit(
            customerCode: widget.customer.id,
            customerName: name,
            mobile: mobile,
            address: address,
            shopName: name,
            location: widget.customer.location,
          );

      final merged = widget.customer.copyWith(
        name: name,
        mobile: mobile,
        address: address,
        location: address.isNotEmpty ? address : widget.customer.location,
      );

      ref.read(paginatedCustomersProvider.notifier).replaceCustomer(merged);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer edit saved')),
      );
      Navigator.of(context).pop(merged);
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
    final theme = ShadTheme.of(context);

    return SafeArea(
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Customer',
                style: theme.textTheme.h3.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Code ${widget.customer.id}',
                style: theme.textTheme.muted,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _nameController,
                label: 'Customer Name',
                prefixIcon: AppIcons.store,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _mobileController,
                label: 'Mobile',
                prefixIcon: AppIcons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _addressController,
                label: 'Address',
                prefixIcon: AppIcons.locationPin,
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ShadButton.outline(
                      onPressed:
                          _isSaving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ShadButton(
                      onPressed: _isSaving ? null : _save,
                      leading: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(AppIcons.edit, size: 16),
                      child: Text(_isSaving ? 'Saving…' : 'Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
