import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../data/models/models.dart';
import '../../../shared/widgets/shad/shad_components.dart';
import '../providers/customer_provider.dart';
import '../widgets/customer_detail_sheet.dart';
import '../widgets/route_customer_card.dart';
import '../../routes/providers/route_provider.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key, required this.routeId});

  final String routeId;

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

enum _CustomerTab { all, missing, outstanding }

/// Recency windows for the Missing tab: (label, days-not-billed).
/// 0 days == "All" (any customer not billed today).
/// Month chips use 30-day months (1→30, 2→60, 4→120) to match the API day threshold.
const _missingWindows = <(String, int)>[
  ('7 days', 7),
  ('15 days', 15),
  ('1 month', 30),
  ('2 months', 60),
  ('4 months', 120),
  ('All', 0),
];

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _searchDebounce;
  Timer? _missingDaysDebounce;

  /// Instant chip/dropdown feedback; network filter applies after debounce.
  int _pendingMissingDays = kDefaultMissingDays;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Riverpod forbids provider writes in initState. Schedule after the
    // current build; route tap usually pre-sets the filter so this is a no-op.
    _scheduleRouteFilter();
  }

  @override
  void didUpdateWidget(covariant CustomerListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeId != widget.routeId) {
      _scheduleRouteFilter();
    }
  }

  void _scheduleRouteFilter() {
    Future(() {
      if (!mounted) return;
      _applyRouteFilter();
    });
  }

  void _applyRouteFilter() {
    _missingDaysDebounce?.cancel();
    final current = ref.read(customerFilterProvider);
    // Route card already stamps routeId before push. Do not wipe an active
    // Missing/Outstanding selection if the route already matches — that race
    // made Missing look broken after a quick tab tap on open.
    if (current.routeId == widget.routeId) {
      _pendingMissingDays = current.missingDays;
      return;
    }
    _pendingMissingDays = kDefaultMissingDays;
    ref.read(customerFilterProvider.notifier).state = const CustomerFilter()
        .copyWith(routeId: widget.routeId);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _missingDaysDebounce?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // Small pages (10): prefetch earlier so the list never stalls mid-scroll.
    if (position.pixels >= position.maxScrollExtent - 480) {
      ref.read(paginatedCustomersProvider.notifier).loadMore();
    }
  }

  _CustomerTab _tabFromFilter(CustomerFilter filter) {
    return switch (filter.priority) {
      CustomerPriority.missing => _CustomerTab.missing,
      CustomerPriority.outstanding => _CustomerTab.outstanding,
      _ => _CustomerTab.all,
    };
  }

  void _selectTab(_CustomerTab tab) {
    final filter = ref.read(customerFilterProvider);
    if (tab == _CustomerTab.missing) {
      // Keep the day-window chip in sync with the filter used for the request.
      if (_pendingMissingDays != filter.missingDays) {
        setState(() => _pendingMissingDays = filter.missingDays);
      }
    }
    ref.read(customerFilterProvider.notifier).state = switch (tab) {
      _CustomerTab.all => filter.copyWith(clearPriority: true),
      _CustomerTab.missing => filter.copyWith(
        priority: CustomerPriority.missing,
      ),
      _CustomerTab.outstanding => filter.copyWith(
        priority: CustomerPriority.outstanding,
      ),
    };
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      // Always read the latest filter so a late debounce cannot overwrite
      // an intervening tab / day-wise change.
      final current = ref.read(customerFilterProvider);
      final trimmed = value.trim();
      if (current.searchQuery == trimmed) return;
      ref.read(customerFilterProvider.notifier).state = current.copyWith(
        searchQuery: trimmed,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final paginated = ref.watch(paginatedCustomersProvider);
    final customers = ref.watch(customersStateProvider);
    final filter = ref.watch(customerFilterProvider);
    final route = ref.watch(routeByIdProvider(widget.routeId));
    final statsAsync = ref.watch(
      routeCustomerStatsProvider((
        routeId: widget.routeId,
        missingDays: filter.missingDays,
      )),
    );
    final stats = statsAsync.valueOrNull;
    final selectedTab = _tabFromFilter(filter);
    final filterMatchesRoute = filter.routeId == widget.routeId;
    final showSkeleton =
        !filterMatchesRoute || (paginated.isLoading && customers.isEmpty);

    return ShadPageScaffold(
      title: route?.name ?? 'Route Customers',
      // Keep subtitle slot stable so the app bar height does not jump when
      // route metadata resolves a frame later.
      subtitle: route != null
          ? '${route.routeNumber} · ${route.zone}'
          : AppConstants.appShortName,
      showBackButton: true,
      floatingActionButton: ShadButton(
        onPressed: () => context.push(RouteNames.newCustomer),
        leading: const Icon(AppIcons.userPlus, size: 18),
        child: const Text('New Customer'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ShadInput(
              controller: _searchController,
              placeholder: const Text('Search customer name or code...'),
              leading: const Icon(AppIcons.search, size: 18),
              onChanged: _onSearchChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _CustomerTabBar(
              selected: selectedTab,
              onSelected: _selectTab,
              allCount: stats?.all,
              missingCount: stats?.missing,
              outstandingCount: stats?.outstanding,
              missingDays: _pendingMissingDays,
              onMissingDaysChanged: _selectMissingWindow,
            ),
          ),
          Expanded(
            child: _buildCustomerList(
              context,
              paginated: paginated,
              customers: customers,
              showSkeleton: showSkeleton,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerList(
    BuildContext context, {
    required PaginatedCustomersState paginated,
    required List<CustomerModel> customers,
    required bool showSkeleton,
  }) {
    if (showSkeleton) {
      return const _CustomerListSkeleton();
    }

    if (paginated.error != null && customers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not load customers',
                style: ShadTheme.of(context).textTheme.large,
              ),
              const SizedBox(height: 8),
              Text(
                paginated.error.toString(),
                style: ShadTheme.of(context).textTheme.muted,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ShadButton(
                onPressed: () =>
                    ref.read(paginatedCustomersProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (customers.isEmpty) {
      return Center(
        child: Text(
          'No customers found',
          style: ShadTheme.of(context).textTheme.muted,
        ),
      );
    }

    final itemCount = customers.length + (paginated.isLoadingMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: () async {
        final missingDays = ref.read(customerFilterProvider).missingDays;
        ref.invalidate(
          routeCustomerStatsProvider((
            routeId: widget.routeId,
            missingDays: missingDays,
          )),
        );
        await ref.read(paginatedCustomersProvider.notifier).refresh();
      },
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: itemCount,
        // Long customer lists do not need keep-alive wrappers per row.
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        itemBuilder: (_, i) {
          if (i >= customers.length) {
            return const Padding(
              padding: EdgeInsets.only(top: 2),
              child: _CustomerSkeletonCard(),
            );
          }

          final customer = customers[i];
          return RouteCustomerCard(
            key: ValueKey(customer.id),
            customer: customer,
            onTap: () => showCustomerDetailSheet(context, customer),
          );
        },
      ),
    );
  }

  void _selectMissingWindow(int days) {
    // Update the dropdown label immediately so the menu feels snappy.
    if (_pendingMissingDays != days) {
      setState(() => _pendingMissingDays = days);
    }

    _missingDaysDebounce?.cancel();
    // Short coalesce so rapid chip taps only commit the last window.
    _missingDaysDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      final current = ref.read(customerFilterProvider);
      if (current.missingDays == days &&
          current.priority == CustomerPriority.missing) {
        return;
      }
      ref.read(customerFilterProvider.notifier).state = current.copyWith(
        missingDays: days,
        priority: CustomerPriority.missing,
      );
    });
  }
}

class _CustomerListSkeleton extends StatelessWidget {
  const _CustomerListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: 6,
      itemBuilder: (_, _) => const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: _CustomerSkeletonCard(),
      ),
    );
  }
}

class _CustomerSkeletonCard extends StatelessWidget {
  const _CustomerSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final fill = theme.colorScheme.mutedForeground.withValues(alpha: 0.12);

    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );

    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(child: bar(180, 14)),
              const SizedBox(width: 24),
              bar(58, 18),
            ],
          ),
          bar(130, 10),
          FractionallySizedBox(
            widthFactor: 0.72,
            alignment: Alignment.centerLeft,
            child: bar(double.infinity, 10),
          ),
        ],
      ),
    );
  }
}

class _CustomerTabBar extends StatelessWidget {
  const _CustomerTabBar({
    required this.selected,
    required this.onSelected,
    required this.allCount,
    required this.missingCount,
    required this.outstandingCount,
    required this.missingDays,
    required this.onMissingDaysChanged,
  });

  final _CustomerTab selected;
  final ValueChanged<_CustomerTab> onSelected;
  final int? allCount;
  final int? missingCount;
  final int? outstandingCount;
  final int missingDays;
  final ValueChanged<int> onMissingDaysChanged;

  String _tabLabel(String label, int? count) {
    // Avoid All (0) → All (276) width jumps while stats are still loading.
    if (count == null) return label;
    return '$label ($count)';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    final tabs = [
      (_CustomerTab.all, _tabLabel('All', allCount)),
      (_CustomerTab.missing, _tabLabel('Missing', missingCount)),
      (_CustomerTab.outstanding, _tabLabel('Outstanding', outstandingCount)),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.muted,
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (tab, label) in tabs)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: _CustomerTabChip(
                          label: label,
                          selected: selected == tab,
                          onTap: () => onSelected(tab),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (selected == _CustomerTab.missing) ...[
              const SizedBox(width: 4),
              _MissingWindowDropdown(
                value: missingDays,
                onChanged: onMissingDaysChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CustomerTabChip extends StatelessWidget {
  const _CustomerTabChip({
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
      color: selected ? theme.colorScheme.background : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: theme.textTheme.small.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? theme.colorScheme.foreground
                  : theme.colorScheme.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}

class _MissingWindowDropdown extends StatelessWidget {
  const _MissingWindowDropdown({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  String get _label {
    for (final (label, days) in _missingWindows) {
      if (days == value) return label;
    }
    return _missingWindows.first.$1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final accent = theme.colorScheme.primary;

    return PopupMenuButton<int>(
      tooltip: 'Not billed in',
      initialValue: value,
      onSelected: onChanged,
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
      ),
      itemBuilder: (context) => [
        for (final (label, days) in _missingWindows)
          PopupMenuItem<int>(
            value: days,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.small.copyWith(
                      fontWeight: days == value
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: days == value
                          ? accent
                          : theme.colorScheme.foreground,
                    ),
                  ),
                ),
                if (days == value)
                  Icon(AppIcons.check, size: 16, color: accent),
              ],
            ),
          ),
      ],
      child: Material(
        color: theme.colorScheme.background,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _label,
                style: theme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.foreground,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: theme.colorScheme.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
