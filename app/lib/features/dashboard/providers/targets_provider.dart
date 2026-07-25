import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/routes_repository.dart';
import '../../../data/repositories/targets_repository.dart';
import '../../auth/providers/auth_provider.dart';

final targetsRepositoryProvider = Provider<TargetsRepository>((ref) {
  return TargetsRepository(ref.watch(apiClientProvider));
});

bool _matchesAssignedRoute(String routeNo, Set<String> assignedRoutes) {
  if (assignedRoutes.isEmpty) return true;
  final normalized = normalizeRouteNo(routeNo);
  if (normalized.isEmpty) return true;
  return assignedRoutes.contains(normalized);
}

List<PeriodTargetTotals> _aggregateSalesByPeriod(List<SalesTargetModel> targets) {
  final totals = {
    for (final period in TargetPeriod.values) period: PeriodTargetTotals(period: period),
  };

  for (final target in targets) {
    final current = totals[target.period]!;
    totals[target.period] = PeriodTargetTotals(
      period: target.period,
      target: current.target + target.targetAmount,
      achieved: current.achieved + target.achievedAmount,
    );
  }

  return TargetPeriod.values
      .map((period) => totals[period]!)
      .where((total) => total.target > 0 || total.achieved > 0)
      .toList();
}

final executiveTargetsProvider =
    FutureProvider<ExecutiveTargetsData>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const ExecutiveTargetsData();
  }

  final employeeCode = user.employeeCode.trim();
  if (employeeCode.isEmpty) {
    return const ExecutiveTargetsData();
  }

  final repository = ref.watch(targetsRepositoryProvider);
  final assignedRoutes =
      user.assignedRouteNos.map(normalizeRouteNo).where((route) => route.isNotEmpty).toSet();

  final results = await Future.wait([
    repository.fetchSalesTargets(employeeCode: employeeCode),
    repository.fetchProductTargets(employeeCode: employeeCode),
    repository.fetchCustomerTargets(employeeCode: employeeCode),
  ]);

  final salesTargets = (results[0] as List<SalesTargetModel>)
      .where((target) => _matchesAssignedRoute(target.routeNo, assignedRoutes))
      .toList();
  final productTargets = (results[1] as List<ProductTargetModel>)
      .where((target) => _matchesAssignedRoute(target.routeNo, assignedRoutes))
      .toList();
  final customerResult = results[2] as CustomerTargetsResult;
  final customerTargets = customerResult.targets
      .where((target) => _matchesAssignedRoute(target.routeNo, assignedRoutes))
      .toList();

  return ExecutiveTargetsData(
    salesByPeriod: _aggregateSalesByPeriod(salesTargets),
    productTargets: productTargets,
    customerByPeriod: customerTargets,
    newCustomersFlagN: customerResult.newCustomersFlagN,
  );
});
