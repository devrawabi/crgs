import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/models.dart';
import '../../../shared/utils/map_launcher.dart';
import '../../../shared/widgets/badges/priority_badge.dart';
import '../../../shared/widgets/common/app_widgets.dart';
import '../../../shared/widgets/maps/location_map_preview.dart';
import 'customer_edit_sheet.dart';

Future<void> showCustomerDetailSheet(
  BuildContext context,
  CustomerModel customer,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: ShadTheme.of(context).colorScheme.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _CustomerDetailSheet(customer: customer),
  );
}

class _CustomerDetailSheet extends StatefulWidget {
  const _CustomerDetailSheet({required this.customer});

  final CustomerModel customer;

  @override
  State<_CustomerDetailSheet> createState() => _CustomerDetailSheetState();
}

class _CustomerDetailSheetState extends State<_CustomerDetailSheet> {
  late CustomerModel _customer;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _startVisit(BuildContext context) {
    Navigator.pop(context);
    context.push('/visit/${_customer.id}');
  }

  Future<void> _edit() async {
    final updated = await showCustomerEditSheet(context, _customer);
    if (updated == null || !mounted) return;
    setState(() => _customer = updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final customer = _customer;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (_, scrollController) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        customer.name,
                        style: theme.textTheme.h3
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PriorityBadge(priority: customer.priority),
                    const SizedBox(width: 4),
                    ShadIconButton.ghost(
                      onPressed: _edit,
                      icon: const Icon(AppIcons.edit, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionTitle(theme, 'Customer Information'),
                InfoRow(
                  label: 'Customer Code',
                  value: customer.id,
                  icon: AppIcons.store,
                ),
                InfoRow(
                  label: 'Type',
                  value: _display(customer.customerType),
                  icon: AppIcons.user,
                ),
                InfoRow(
                  label: 'Mobile',
                  value: _display(customer.mobile),
                  icon: AppIcons.phone,
                ),
                if (customer.wpno.isNotEmpty)
                  InfoRow(
                    label: 'WhatsApp',
                    value: customer.wpno,
                    icon: AppIcons.phone,
                  ),
                InfoRow(
                  label: 'Address',
                  value: _display(customer.address),
                  icon: AppIcons.locationPin,
                ),
                InfoRow(
                  label: 'Route',
                  value: _display(customer.routeName),
                  icon: AppIcons.route,
                ),
                InfoRow(
                  label: 'Category',
                  value: _display(
                    customer.categoryName.isNotEmpty
                        ? customer.categoryName
                        : customer.categoryCode,
                  ),
                  icon: AppIcons.store,
                ),
                if (customer.customerStatus.isNotEmpty)
                  InfoRow(label: 'Status', value: customer.customerStatus),
                if (customer.createdStatus.isNotEmpty)
                  InfoRow(
                    label: 'Created Status',
                    value: customer.createdStatus,
                  ),
                const SizedBox(height: 16),
                _sectionTitle(theme, 'Credit Information'),
                InfoRow(
                  label: 'Credit Limit',
                  value: CurrencyFormatter.format(customer.creditLimit),
                ),
                InfoRow(
                  label: 'Credit Amount',
                  value: CurrencyFormatter.format(customer.creditAmount),
                ),
                if (customer.locationMap.isNotEmpty &&
                    !MapLauncher.hasValidCoordinates(
                      customer.latitude,
                      customer.longitude,
                    ))
                  InfoRow(label: 'Location Map', value: customer.locationMap),
                if (MapLauncher.hasValidCoordinates(
                  customer.latitude,
                  customer.longitude,
                )) ...[
                  const SizedBox(height: 20),
                  _sectionTitle(theme, 'Location Map'),
                  LocationMapPreview(
                    latitude: customer.latitude,
                    longitude: customer.longitude,
                  ),
                  const SizedBox(height: 12),
                  ShadButton.outline(
                    width: double.infinity,
                    onPressed: () => MapLauncher.showMapPicker(
                      context,
                      lat: customer.latitude,
                      lng: customer.longitude,
                      label: customer.name,
                    ),
                    leading: const Icon(AppIcons.navigation, size: 16),
                    child: const Text('Open in Maps'),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
            decoration: BoxDecoration(
              color: theme.colorScheme.card,
              border: Border(
                top: BorderSide(color: theme.colorScheme.border),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ShadButton.outline(
                    onPressed: () => _call(customer.mobile),
                    leading: const Icon(AppIcons.phone, size: 16),
                    child: const Text('Call'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ShadButton(
                    onPressed: () => _startVisit(context),
                    leading: const Icon(AppIcons.play, size: 16),
                    child: const Text('Start Visit'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(ShadThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.large.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  String _display(String value) => value.isNotEmpty ? value : 'N/A';
}
