import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/models.dart';

class VisitsRepository {
  VisitsRepository(this._client);

  final ApiClient _client;

  /// Lists visit rows from Oracle `CRGS_VISITDETAILS`.
  Future<List<VisitRecordModel>> fetchVisits({
    String? employeeCode,
    String? customerCode,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.visits,
      queryParameters: {
        if (employeeCode != null && employeeCode.trim().isNotEmpty)
          'employeeCode': employeeCode.trim(),
        if (customerCode != null && customerCode.trim().isNotEmpty)
          'customerCode': customerCode.trim(),
      },
    );

    final data = response.data;
    if (data == null) {
      throw ApiException(message: 'Empty response from server');
    }

    final visitsJson = data['visits'];
    if (visitsJson is! List) return const [];

    return visitsJson
        .whereType<Map>()
        .map((item) => VisitRecordModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Inserts a row into Oracle `CRGS_VISITDETAILS` when a visit starts.
  Future<Map<String, dynamic>> startVisit({
    required String employeeCode,
    required String customerCode,
    required String customerName,
    required String route,
    required DateTime visitStart,
    String location = '',
    String? reason,
    String? remarks,
    DateTime? followUp,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.visitsStart,
      data: {
        'employeeCode': employeeCode,
        'customerCode': customerCode,
        'customerName': customerName,
        'route': route,
        'visitDate': _dateOnly(visitStart),
        'visitStart': _timeOnly(visitStart),
        'location': location,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
        if (followUp != null) 'followUp': _dateOnly(followUp),
      },
    );

    final data = response.data;
    if (data == null) {
      throw ApiException(message: 'Invalid start visit response from server');
    }
    return data;
  }

  /// Updates `VISITEND` and `TOTALDURATION` (plus form fields) when a visit ends.
  Future<Map<String, dynamic>> endVisit({
    required String employeeCode,
    required String customerCode,
    required DateTime visitStart,
    required DateTime visitEnd,
    required Duration duration,
    String location = '',
    String? reason,
    String? remarks,
    DateTime? followUp,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.visitsEnd,
      data: {
        'employeeCode': employeeCode,
        'customerCode': customerCode,
        'visitStart': _timeOnly(visitStart),
        'visitEnd': _timeOnly(visitEnd),
        'totalDuration': _formatDuration(duration),
        'durationSeconds': duration.inSeconds,
        'location': location,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
        if (followUp != null) 'followUp': _dateOnly(followUp),
      },
    );

    final data = response.data;
    if (data == null) {
      throw ApiException(message: 'Invalid end visit response from server');
    }
    return data;
  }

  static String _dateOnly(DateTime value) {
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// VISITSTART / VISITEND: time only (HH:mm:ss). Date is stored in VISITDATE.
  static String _timeOnly(DateTime value) {
    final local = value.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  static String _formatDuration(Duration duration) {
    final h = duration.inHours.toString().padLeft(2, '0');
    final m = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final s = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
