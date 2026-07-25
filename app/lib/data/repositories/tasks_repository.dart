import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/models.dart';

class TasksRepository {
  TasksRepository(this._client);

  final ApiClient _client;

  /// Fetches tasks from the Oracle `CRGS_TASK` table via the backend.
  /// Optionally filters by [employeeCode].
  Future<List<TaskModel>> fetchTasks({String? employeeCode}) async {
    final queryParameters = <String, dynamic>{};
    if (employeeCode != null && employeeCode.isNotEmpty) {
      queryParameters['employeeCode'] = employeeCode;
    }

    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.tasks,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    final raw = response.data?['tasks'];
    if (raw is! List) {
      throw ApiException(message: 'Invalid tasks response from server');
    }

    return raw
        .whereType<Map>()
        .map((item) => TaskModel.fromDb(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Updates `CRGS_TASK.STATUS` for the matching task row.
  Future<void> updateTaskStatus({
    required String type,
    required String employeeCode,
    required String routeNo,
    required DateTime dueDate,
    required TaskStatus status,
  }) async {
    final statusValue = switch (status) {
      TaskStatus.completed => 'Completed',
      TaskStatus.inProgress => 'In Progress',
      TaskStatus.pending => 'Pending',
    };

    await _client.patch<Map<String, dynamic>>(
      ApiEndpoints.taskStatus,
      data: {
        'type': type,
        'employeeCode': employeeCode,
        'routeNo': routeNo,
        'dueDate':
            '${dueDate.year.toString().padLeft(4, '0')}-'
            '${dueDate.month.toString().padLeft(2, '0')}-'
            '${dueDate.day.toString().padLeft(2, '0')}',
        'status': statusValue,
      },
    );
  }
}
