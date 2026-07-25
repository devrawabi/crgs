import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/models.dart';

class RoutesRepository {
  RoutesRepository(this._client);

  final ApiClient _client;

  static const _routeImages = [
    'assets/images/routes/route_abu_hamur.jpg',
    'assets/images/routes/route_burgan.jpg',
    'assets/images/routes/route_al_sadd.jpg',
    'assets/images/routes/route_doha_hilal.jpg',
  ];

  Future<List<RouteModel>> fetchAssignedRoutes(List<String> assignedRouteNos) async {
    if (assignedRouteNos.isEmpty) return [];

    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.routes,
      queryParameters: {'limit': 5000},
    );

    final data = response.data;
    if (data == null) {
      throw ApiException(message: 'Empty response from server');
    }

    final routesJson = data['routes'];
    if (routesJson is! List) return [];

    final assigned = assignedRouteNos.map(normalizeRouteNo).toSet();
    final matched = <RouteModel>[];

    for (var index = 0; index < routesJson.length; index++) {
      final item = routesJson[index];
      if (item is! Map) continue;

      final routeno = normalizeRouteNo(item['routeno']?.toString() ?? '');
      final routename = item['routename']?.toString().trim() ?? '';
      if (routeno.isEmpty || !assigned.contains(routeno)) continue;

      matched.add(
        RouteModel.fromDb(
          routeno: routeno,
          routename: routename.isEmpty ? 'Route $routeno' : routename,
          imageAsset: _routeImages[index % _routeImages.length],
        ),
      );
    }

    matched.sort((a, b) => a.name.compareTo(b.name));
    return matched;
  }
}

String normalizeRouteNo(String value) {
  final text = value.trim();
  if (text.isEmpty) return '';
  final numeric = int.tryParse(text);
  if (numeric != null) return numeric.toString();
  return text;
}
