import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/models.dart';

class TasksPage {
  const TasksPage({
    required this.tasks,
    required this.offset,
    required this.limit,
    required this.hasMore,
  });

  final List<TaskModel> tasks;
  final int offset;
  final int limit;
  final bool hasMore;
}

class TasksRepository {
  TasksRepository(this._client);

  final ApiClient _client;

  static const int pageSize = 100;

  Future<TasksPage> fetchTasksPage({
    String? employeeCode,
    int limit = pageSize,
    int offset = 0,
  }) async {
    final queryParameters = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (employeeCode != null && employeeCode.isNotEmpty) {
      queryParameters['employeeCode'] = employeeCode;
    }

    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.tasks,
      queryParameters: queryParameters,
    );

    final data = response.data;
    if (data == null) {
      throw ApiException(message: 'Empty tasks response from server');
    }

    final raw = data['tasks'];
    if (raw is! List) {
      throw ApiException(message: 'Invalid tasks response from server');
    }

    final tasks = raw
        .whereType<Map>()
        .map((item) => TaskModel.fromDb(Map<String, dynamic>.from(item)))
        .toList();

    return TasksPage(
      tasks: tasks,
      offset: (data['offset'] as num?)?.toInt() ?? offset,
      limit: (data['limit'] as num?)?.toInt() ?? limit,
      hasMore: data['has_more'] as bool? ?? tasks.length >= limit,
    );
  }

  /// Fetches tasks — walks pages so task screens stay complete.
  Future<List<TaskModel>> fetchTasks({String? employeeCode}) async {
    final all = <TaskModel>[];
    var offset = 0;
    for (var i = 0; i < 100; i++) {
      final page = await fetchTasksPage(
        employeeCode: employeeCode,
        limit: pageSize,
        offset: offset,
      );
      all.addAll(page.tasks);
      if (!page.hasMore || page.tasks.isEmpty) break;
      offset += page.limit;
    }
    return all;
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
