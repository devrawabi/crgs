import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/models.dart';

class RoutesRepository {
  RoutesRepository(this._client);

  final ApiClient _client;

  static const int pageSize = 500;

  static const _routeImages = [
    'assets/images/routes/route_abu_hamur.jpg',
    'assets/images/routes/route_burgan.jpg',
    'assets/images/routes/route_al_sadd.jpg',
    'assets/images/routes/route_doha_hilal.jpg',
  ];

  /// Loads only the user's assigned routes (server filters by `routeNos`).
  Future<List<RouteModel>> fetchAssignedRoutes(List<String> assignedRouteNos) async {
    if (assignedRouteNos.isEmpty) return [];

    final assigned = assignedRouteNos
        .map(normalizeRouteNo)
        .where((no) => no.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (assigned.isEmpty) return [];

    final matched = <RouteModel>[];
    var offset = 0;
    var imageIndex = 0;
    final routeNosParam = assigned.join(',');

    for (var page = 0; page < 20; page++) {
      final response = await _client.get<Map<String, dynamic>>(
        ApiEndpoints.routes,
        queryParameters: {
          'routeNos': routeNosParam,
          'limit': pageSize,
          'offset': offset,
        },
      );

      final data = response.data;
      if (data == null) {
        throw ApiException(message: 'Empty response from server');
      }

      final routesJson = data['routes'];
      if (routesJson is! List || routesJson.isEmpty) break;

      for (final item in routesJson) {
        if (item is! Map) continue;

        final routeno = normalizeRouteNo(item['routeno']?.toString() ?? '');
        final routename = item['routename']?.toString().trim() ?? '';
        if (routeno.isEmpty) continue;

        matched.add(
          RouteModel.fromDb(
            routeno: routeno,
            routename: routename.isEmpty ? 'Route $routeno' : routename,
            imageAsset: _routeImages[imageIndex % _routeImages.length],
          ),
        );
        imageIndex++;
      }

      final hasMore = data['has_more'] == true;
      final limitUsed = (data['limit'] as num?)?.toInt() ?? pageSize;
      if (!hasMore) break;
      offset += limitUsed;
    }

    matched.sort((a, b) => a.name.compareTo(b.name));
    return matched;
  }
}

String normalizeRouteNo(String value) {
  final text = value.trim();
  if (text.isEmpty) return '';
  final asInt = int.tryParse(text);
  if (asInt != null) return asInt.toString();
  // Oracle NUMBER / Decimal sometimes serializes as "18.0".
  final asDouble = double.tryParse(text);
  if (asDouble != null && asDouble == asDouble.roundToDouble()) {
    return asDouble.toInt().toString();
  }
  return text;
}

/// Splits Oracle ROUTE columns that store multiple routes as `58,78,18`.
List<String> parseRouteNos(String value) {
  if (value.trim().isEmpty) return const [];
  return value
      .split(RegExp(r'[,;/|]'))
      .map(normalizeRouteNo)
      .where((route) => route.isNotEmpty)
      .toList(growable: false);
}

/// True when [routeNo] is empty, or any of its comma-separated parts intersect
/// [assignedRoutes]. Empty [assignedRoutes] means "no filter".
bool matchesAssignedRoutes(String routeNo, Set<String> assignedRoutes) {
  if (assignedRoutes.isEmpty) return true;
  final parts = parseRouteNos(routeNo);
  if (parts.isEmpty) return true;
  return parts.any(assignedRoutes.contains);
}
