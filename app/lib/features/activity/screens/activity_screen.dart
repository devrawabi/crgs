import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_theme_extensions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/models.dart';
import '../../../shared/widgets/badges/priority_badge.dart';
import '../../../shared/widgets/shad/shad_components.dart';
import '../../auth/providers/auth_provider.dart';
import '../../customers/providers/customer_provider.dart';
import '../../market_research/screens/market_research_screen.dart';
import '../../orders/providers/orders_provider.dart';
import '../../orders/screens/orders_screen.dart';
import '../../visit/providers/visit_provider.dart';

enum _ActivityTab { orders, visited, newCustomers, marketResearch }

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  _ActivityTab _selectedTab = _ActivityTab.orders;

  List<VisitRecordModel> _visits = const [];
  List<ContactInfoModel> _newCustomers = const [];
  List<MarketResearchRecordModel> _research = const [];
  bool _listsLoading = false;
  String? _listsError;

  @override
  void initState() {
    super.initState();
    Future(_loadLists);
  }

  Future<void> _loadLists() async {
    setState(() {
      _listsLoading = true;
      _listsError = null;
    });

    try {
      final employeeCode =
          ref.read(authProvider).user?.employeeCode.trim() ?? '';

      final results = await Future.wait([
        ref.read(visitsRepositoryProvider).fetchVisits(
              employeeCode: employeeCode.isEmpty ? null : employeeCode,
            ),
        ref.read(customersRepositoryProvider).fetchContactInfo(),
        ref.read(marketResearchRepositoryProvider).fetchResearch(
              employeeCode: employeeCode.isEmpty ? null : employeeCode,
            ),
      ]);

      if (!mounted) return;
      setState(() {
        _visits = results[0] as List<VisitRecordModel>;
        _newCustomers = results[1] as List<ContactInfoModel>;
        _research = results[2] as List<MarketResearchRecordModel>;
        _listsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _listsError = e.toString();
        _listsLoading = false;
      });
    }
  }

  Future<void> _refreshCurrentTab() async {
    if (_selectedTab == _ActivityTab.orders) {
      await ref.read(ordersProvider.notifier).load();
      return;
    }
    await _loadLists();
  }

  /// Unique visited customers (latest visit first).
  List<VisitRecordModel> get _uniqueVisitedCustomers {
    final seen = <String>{};
    final unique = <VisitRecordModel>[];
    for (final visit in _visits) {
      final key = visit.customerCode.isNotEmpty
          ? visit.customerCode
          : visit.customerName.toLowerCase();
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      unique.add(visit);
    }
    return unique;
  }

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(ordersProvider);
    final visited = _uniqueVisitedCustomers;

    return Scaffold(
      backgroundColor: RouteMasterColors.background(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeading(
            title: 'Activity',
            subtitle: _subtitle(
              ordersCount: ordersState.orders.length,
              visitedCount: visited.length,
              newCount: _newCustomers.length,
              researchCount: _research.length,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _ActivityTabBar(
              selected: _selectedTab,
              onSelected: (tab) => setState(() => _selectedTab = tab),
              ordersCount: ordersState.orders.length,
              visitedCount: visited.length,
              newCount: _newCustomers.length,
              researchCount: _research.length,
            ),
          ),
          Expanded(
            child: switch (_selectedTab) {
              _ActivityTab.orders => const OrdersListBody(),
              _ActivityTab.visited => _ActivityListBody(
                  isLoading: _listsLoading && visited.isEmpty,
                  error: _listsError,
                  emptyMessage: 'No visited customers yet',
                  emptyIcon: AppIcons.customers,
                  onRetry: _loadLists,
                  onRefresh: _refreshCurrentTab,
                  children: visited
                      .map((visit) => _VisitedCustomerCard(visit: visit))
                      .toList(),
                ),
              _ActivityTab.newCustomers => _ActivityListBody(
                  isLoading: _listsLoading && _newCustomers.isEmpty,
                  error: _listsError,
                  emptyMessage: 'No new customers added yet',
                  emptyIcon: AppIcons.userPlus,
                  onRetry: _loadLists,
                  onRefresh: _refreshCurrentTab,
                  children: _newCustomers
                      .map((c) => _NewCustomerCard(customer: c))
                      .toList(),
                ),
              _ActivityTab.marketResearch => _ActivityListBody(
                  isLoading: _listsLoading && _research.isEmpty,
                  error: _listsError,
                  emptyMessage: 'No market research submitted yet',
                  emptyIcon: AppIcons.science,
                  onRetry: _loadLists,
                  onRefresh: _refreshCurrentTab,
                  children: _research
                      .map((item) => _MarketResearchCard(record: item))
                      .toList(),
                ),
            },
          ),
        ],
      ),
    );
  }

  String _subtitle({
    required int ordersCount,
    required int visitedCount,
    required int newCount,
    required int researchCount,
  }) {
    if (_listsLoading && ordersCount == 0) return 'Loading activity...';
    return '$ordersCount orders · $visitedCount visited · $newCount new · $researchCount research';
  }
}

class _ActivityTabBar extends StatelessWidget {
  const _ActivityTabBar({
    required this.selected,
    required this.onSelected,
    required this.ordersCount,
    required this.visitedCount,
    required this.newCount,
    required this.researchCount,
  });

  final _ActivityTab selected;
  final ValueChanged<_ActivityTab> onSelected;
  final int ordersCount;
  final int visitedCount;
  final int newCount;
  final int researchCount;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final tabs = [
      (_ActivityTab.orders, 'Orders ($ordersCount)'),
      (_ActivityTab.visited, 'Visited ($visitedCount)'),
      (_ActivityTab.newCustomers, 'New ($newCount)'),
      (_ActivityTab.marketResearch, 'Research ($researchCount)'),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.muted,
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (final (tab, label) in tabs)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _ActivityTabChip(
                  label: label,
                  selected: selected == tab,
                  onTap: () => onSelected(tab),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTabChip extends StatelessWidget {
  const _ActivityTabChip({
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

class _ActivityListBody extends StatelessWidget {
  const _ActivityListBody({
    required this.isLoading,
    required this.error,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.onRetry,
    required this.onRefresh,
    required this.children,
  });

  final bool isLoading;
  final String? error;
  final String emptyMessage;
  final IconData emptyIcon;
  final VoidCallback onRetry;
  final Future<void> Function() onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && children.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Unable to load list',
                style: theme.textTheme.large.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                error!,
                style: theme.textTheme.muted.copyWith(fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ShadButton.outline(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (children.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                emptyIcon,
                size: 40,
                color: theme.colorScheme.mutedForeground.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                style: theme.textTheme.muted.copyWith(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, index) => children[index],
      ),
    );
  }
}

class _VisitedCustomerCard extends StatelessWidget {
  const _VisitedCustomerCard({required this.visit});

  final VisitRecordModel visit;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final meta = <String>[
      if (visit.customerCode.isNotEmpty) visit.customerCode,
      if (visit.visitDate.isNotEmpty) visit.visitDate,
      if (visit.route.isNotEmpty) 'Route ${visit.route}',
    ];

    return _ActivityCard(
      icon: AppIcons.customers,
      iconColor: AppColors.successGreen,
      title: visit.customerName.isEmpty
          ? 'Customer ${visit.customerCode}'
          : visit.customerName,
      subtitle: meta.join(' · '),
      badge: visit.isCompleted ? 'Visited' : 'In progress',
      badgeColor:
          visit.isCompleted ? AppColors.successGreen : AppColors.primaryBlue,
      details: [
        if (visit.visitStart.isNotEmpty || visit.visitEnd.isNotEmpty)
          (
            'Time',
            [
              if (visit.visitStart.isNotEmpty) visit.visitStart,
              if (visit.visitEnd.isNotEmpty) visit.visitEnd,
            ].join(' – '),
          ),
        if (visit.totalDuration.isNotEmpty) ('Duration', visit.totalDuration),
        if (visit.location.isNotEmpty) ('Location', visit.location),
        if (visit.reason.isNotEmpty) ('Reason', visit.reason),
      ],
      theme: theme,
    );
  }
}

class _NewCustomerCard extends StatelessWidget {
  const _NewCustomerCard({required this.customer});

  final ContactInfoModel customer;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final meta = <String>[
      if (customer.shopName.isNotEmpty) customer.shopName,
      if (customer.contactNumber.isNotEmpty) customer.contactNumber,
      if (customer.businessType.isNotEmpty) customer.businessType,
    ];

    return _ActivityCard(
      icon: AppIcons.userPlus,
      iconColor: AppColors.brand,
      title: customer.customerName.isEmpty
          ? customer.shopName
          : customer.customerName,
      subtitle: meta.join(' · '),
      badge: customer.status.isEmpty ? 'New' : customer.status,
      badgeColor: AppColors.followUpBlue,
      details: [
        if (customer.location.isNotEmpty) ('Location', customer.location),
        if (customer.address.isNotEmpty) ('Address', customer.address),
        if (customer.expectedAmount != null)
          ('Expected', CurrencyFormatter.format(customer.expectedAmount!)),
        if (customer.products.isNotEmpty) ('Products', customer.products),
        if (customer.customerCode.isNotEmpty) ('Code', customer.customerCode),
      ],
      theme: theme,
    );
  }
}

class _MarketResearchCard extends StatelessWidget {
  const _MarketResearchCard({required this.record});

  final MarketResearchRecordModel record;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final preview = [
      if (record.marketTrend.isNotEmpty) record.marketTrend,
      if (record.notes.isNotEmpty) record.notes,
      if (record.newOpportunities.isNotEmpty) record.newOpportunities,
    ].join(' · ');

    return _ActivityCard(
      icon: AppIcons.science,
      iconColor: AppColors.brand,
      title: record.route.isEmpty ? 'Market research' : 'Route ${record.route}',
      subtitle: preview.isEmpty ? 'Research entry' : preview,
      badge: 'Research',
      badgeColor: AppColors.brand,
      details: [
        if (record.marketTrend.isNotEmpty) ('Trends', record.marketTrend),
        if (record.fastMovingProducts.isNotEmpty)
          ('Fast moving', record.fastMovingProducts),
        if (record.slowMovingProducts.isNotEmpty)
          ('Slow moving', record.slowMovingProducts),
        if (record.competitorPromotions.isNotEmpty)
          ('Competitors', record.competitorPromotions),
        if (record.newOpportunities.isNotEmpty)
          ('Opportunities', record.newOpportunities),
        if (record.notes.isNotEmpty) ('Notes', record.notes),
      ],
      theme: theme,
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.details,
    required this.theme,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final List<(String, String)> details;
  final ShadThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RouteMasterColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RouteMasterColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: context.isDarkTheme ? 0.24 : 0.04,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.large.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.muted.copyWith(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              StatusBadge(label: badge, color: badgeColor),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: theme.colorScheme.border),
            const SizedBox(height: 10),
            for (var i = 0; i < details.length; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      details[i].$1,
                      style: theme.textTheme.muted.copyWith(fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      details[i].$2,
                      style: theme.textTheme.small.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
