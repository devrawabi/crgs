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
    this.isLoadingMore = false,
    this.hasMore = false,
    this.error,
  });

  final List<TaskModel> tasks;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  TasksState copyWith({
    List<TaskModel>? tasks,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) =>
      TasksState(
        tasks: tasks ?? this.tasks,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
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
      final page = await _repository.fetchTasksPage(
        employeeCode: _employeeCode.isEmpty ? null : _employeeCode,
        offset: 0,
      );
      state = TasksState(
        tasks: page.tasks,
        hasMore: page.hasMore,
      );
    } catch (error) {
      state = TasksState(error: error.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final page = await _repository.fetchTasksPage(
        employeeCode: _employeeCode.isEmpty ? null : _employeeCode,
        offset: state.tasks.length,
      );
      state = state.copyWith(
        tasks: [...state.tasks, ...page.tasks],
        hasMore: page.hasMore,
        isLoadingMore: false,
      );
    } catch (error) {
      state = state.copyWith(
        isLoadingMore: false,
        error: error.toString(),
      );
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
    final previousHasMore = state.hasMore;
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
      state = TasksState(
        tasks: previous,
        hasMore: previousHasMore,
        error: error.toString(),
      );
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

final outstandingInvoicesProvider =
    Provider<List<OutstandingInvoice>>((ref) {
  return MockData.outstandingInvoices;
});

final recoveryReasonsProvider = Provider<List<String>>((ref) {
  return MockData.recoveryReasons;
});
