import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/customers_repository.dart';
import '../../../shared/widgets/shad/shad_components.dart';
import '../../customers/widgets/customer_detail_sheet.dart';
import '../../customers/widgets/route_customer_card.dart';
import '../../tasks/providers/task_provider.dart';

/// Synthetic route id used by [RouteListScreen] for Other-route tasks.
const String kOthersRouteId = 'others';

class OthersCustomersScreen extends ConsumerStatefulWidget {
  const OthersCustomersScreen({super.key});

  @override
  ConsumerState<OthersCustomersScreen> createState() =>
      _OthersCustomersScreenState();
}

class _OthersCustomersScreenState extends ConsumerState<OthersCustomersScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<CustomerModel> _customers = const [];
  Set<String> _highlightedIds = const {};
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    Future(_load);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<TaskModel> get _openOtherRouteTasks {
    return ref
        .read(tasksProvider)
        .tasks
        .where(
          (task) =>
              task.taskTypeCode == 'other_route' &&
              task.status != TaskStatus.completed,
        )
        .toList(growable: false);
  }

  Set<String> _collectAssignedCodes(List<TaskModel> tasks) {
    final codes = <String>{};
    for (final task in tasks) {
      for (final code in task.customerCodes) {
        final trimmed = code.trim();
        if (trimmed.isNotEmpty) codes.add(trimmed);
      }
    }
    return codes;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tasks = _openOtherRouteTasks;
      final codes = _collectAssignedCodes(tasks);
      if (codes.isEmpty) {
        if (!mounted) return;
        setState(() {
          _customers = const [];
          _highlightedIds = const {};
          _loading = false;
          _error = tasks.isEmpty
              ? 'No open Other-route tasks.'
              : 'No customers assigned to Other-route tasks yet.';
        });
        return;
      }

      final repo = CustomersRepository(ref.read(apiClientProvider));
      final page = await repo.fetchCustomersByCodes(
        codes: codes.toList(),
        limit: 100,
        search: _query,
      );

      final byId = {
        for (final customer in page.customers) customer.id.trim(): customer,
      };
      final ordered = <CustomerModel>[
        for (final code in codes)
          if (byId.containsKey(code)) byId[code]!,
      ];

      if (!mounted) return;
      setState(() {
        _customers = ordered;
        _highlightedIds = codes;
        _loading = false;
        _error = ordered.isEmpty
            ? 'Assigned customers were not found in the customer list.'
            : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final taskCount = _openOtherRouteTasks.length;

    return ShadPageScaffold(
      showHeader: true,
      showBackButton: true,
      title: 'Others',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  const Icon(AppIcons.tasks, color: AppColors.accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      taskCount == 1
                          ? '1 open Other-route task · assigned customers highlighted'
                          : '$taskCount open Other-route tasks · assigned customers highlighted',
                      style: theme.textTheme.small.copyWith(
                        color: theme.colorScheme.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search assigned customers',
                prefixIcon: const Icon(AppIcons.search, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                ),
                isDense: true,
              ),
              onChanged: (value) {
                _query = value.trim();
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 280), _load);
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _customers.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.muted,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: _customers.length,
                          itemBuilder: (context, index) {
                            final customer = _customers[index];
                            final highlighted =
                                _highlightedIds.contains(customer.id.trim());
                            return RouteCustomerCard(
                              customer: customer,
                              highlighted: highlighted,
                              highlightLabel: 'Task',
                              onTap: () =>
                                  showCustomerDetailSheet(context, customer),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
