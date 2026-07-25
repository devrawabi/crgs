import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/tasks_repository.dart';
import '../../auth/providers/auth_provider.dart';

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepository(ref.watch(apiClientProvider));
});

class TasksState {
  const TasksState({
    this.tasks = const [],
    this.isLoading = false,
    this.error,
  });

  final List<TaskModel> tasks;
  final bool isLoading;
  final String? error;

  TasksState copyWith({
    List<TaskModel>? tasks,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      TasksState(
        tasks: tasks ?? this.tasks,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class TasksNotifier extends StateNotifier<TasksState> {
  TasksNotifier(this._repository, this._employeeCode)
      : super(const TasksState(isLoading: true)) {
    load();
  }

  final TasksRepository _repository;
  final String _employeeCode;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final tasks = await _repository.fetchTasks(
        employeeCode: _employeeCode.isEmpty ? null : _employeeCode,
      );
      state = TasksState(tasks: tasks);
    } catch (error) {
      state = TasksState(error: error.toString());
    }
  }

  Future<void> updateStatus(String id, TaskStatus status) async {
    TaskModel? task;
    for (final item in state.tasks) {
      if (item.id == id) {
        task = item;
        break;
      }
    }
    if (task == null) return;

    final type = task.taskTypeCode.trim();
    final employeeCode = task.employeeCode.trim().isNotEmpty
        ? task.employeeCode.trim()
        : _employeeCode;
    final routeNo = (task.routeId ?? '').trim();

    if (type.isEmpty || employeeCode.isEmpty || routeNo.isEmpty) {
      state = state.copyWith(
        error: 'Unable to update task status: missing task identifiers',
      );
      return;
    }

    final previous = state.tasks;
    state = state.copyWith(
      clearError: true,
      tasks: [
        for (final item in state.tasks)
          if (item.id == id) item.copyWith(status: status) else item,
      ],
    );

    try {
      await _repository.updateTaskStatus(
        type: type,
        employeeCode: employeeCode,
        routeNo: routeNo,
        dueDate: task.dueDate,
        status: status,
      );
    } catch (error) {
      state = TasksState(tasks: previous, error: error.toString());
    }
  }
}

final tasksProvider =
    StateNotifierProvider<TasksNotifier, TasksState>((ref) {
  final user = ref.watch(currentUserProvider);
  return TasksNotifier(
    ref.watch(tasksRepositoryProvider),
    user?.employeeCode.trim() ?? '',
  );
});

final followUpsProvider = StateProvider<List<FollowUpModel>>((ref) {
  return MockData.followUps;
});

final customerFollowUpProgressProvider =
    Provider<List<CustomerFollowUpProgress>>((ref) {
  return MockData.customerFollowUpProgress;
});

final outstandingInvoicesProvider =
    Provider<List<OutstandingInvoice>>((ref) {
  return MockData.outstandingInvoices;
});

final recommendedProductsProvider =
    Provider<List<RecommendedProduct>>((ref) {
  return MockData.recommendedProducts;
});

final recoveryReasonsProvider = Provider<List<String>>((ref) {
  return MockData.recoveryReasons;
});
