import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/models.dart';

class WorkReportsRepository {
  WorkReportsRepository(this._client);

  final ApiClient _client;

  Future<WorkReportModel> submitReport({
    required String employeeCode,
    required String customerName,
    required String notes,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.workReports,
      data: {
        'employeeCode': employeeCode,
        'customerName': customerName.trim(),
        'notes': notes.trim(),
      },
    );

    final data = response.data;
    if (data == null) {
      throw ApiException(message: 'Invalid work report response from server');
    }
    return WorkReportModel.fromJson(data);
  }
}
