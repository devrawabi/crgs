import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/routes_repository.dart';
import '../../auth/providers/auth_provider.dart';

final routesRepositoryProvider = Provider<RoutesRepository>((ref) {
  return RoutesRepository(ref.watch(apiClientProvider));
});

final assignedRoutesProvider = FutureProvider<List<RouteModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final repository = ref.watch(routesRepositoryProvider);
  return repository.fetchAssignedRoutes(user.assignedRouteNos);
});

final routeByIdProvider = Provider.family<RouteModel?, String>((ref, id) {
  final routes = ref.watch(assignedRoutesProvider).valueOrNull ?? [];
  try {
    return routes.firstWhere((route) => route.id == id);
  } catch (_) {
    return null;
  }
});
