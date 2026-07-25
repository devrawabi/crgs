import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/visits_repository.dart';

class VisitNotifier extends StateNotifier<VisitModel?> {
  VisitNotifier(this._repository) : super(null);

  final VisitsRepository _repository;
  Timer? _timer;
  bool _isStarting = false;
  bool _isEnding = false;

  bool get isStarting => _isStarting;
  bool get isEnding => _isEnding;

  Future<void> startVisit({
    required String employeeCode,
    required String customerId,
    required String customerName,
    required String route,
    required String location,
  }) async {
    if (_isStarting) return;
    _isStarting = true;

    final now = DateTime.now().copyWith(millisecond: 0, microsecond: 0);
    state = VisitModel(
      id: 'visit-${now.millisecondsSinceEpoch}',
      customerId: customerId,
      customerName: customerName,
      employeeCode: employeeCode,
      route: route,
      status: VisitStatus.inProgress,
      startTime: now,
      currentLocation: location,
    );
    _startTimer();

    try {
      final response = await _repository.startVisit(
        employeeCode: employeeCode,
        customerCode: customerId,
        customerName: customerName,
        route: route,
        visitStart: now,
        location: location,
      );

      final serverStart = response['visitStart']?.toString();
      DateTime? parsedStart;
      if (serverStart != null && serverStart.isNotEmpty) {
        // Server may return time-only (HH:mm:ss); keep local date.
        final timeParts = serverStart.split(':');
        if (timeParts.length >= 2 && DateTime.tryParse(serverStart) == null) {
          final h = int.tryParse(timeParts[0]) ?? now.hour;
          final m = int.tryParse(timeParts[1]) ?? now.minute;
          final s = timeParts.length > 2 ? int.tryParse(timeParts[2]) ?? 0 : 0;
          parsedStart = DateTime(now.year, now.month, now.day, h, m, s);
        } else {
          parsedStart = DateTime.tryParse(serverStart);
        }
      }

      if (state != null) {
        state = state!.copyWith(
          startTime: parsedStart ?? state!.startTime,
          persisted: true,
        );
      }
    } catch (_) {
      _timer?.cancel();
      state = null;
      rethrow;
    } finally {
      _isStarting = false;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state?.startTime != null) {
        final duration = DateTime.now().difference(state!.startTime!);
        state = state!.copyWith(
          status: VisitStatus.inProgress,
          duration: duration,
        );
      }
    });
  }

  void updateLocation({
    required double latitude,
    required double longitude,
    required String address,
  }) {
    if (state == null) return;
    state = state!.copyWith(
      currentLocation: address,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<void> checkOut({
    String? reason,
    String? remarks,
    DateTime? followUp,
  }) async {
    if (state == null || _isEnding) return;
    _isEnding = true;

    final endTime = DateTime.now().copyWith(millisecond: 0, microsecond: 0);
    final startTime = state!.startTime ?? endTime;
    final duration = endTime.difference(startTime);

    try {
      if (state!.persisted &&
          state!.employeeCode.isNotEmpty &&
          state!.startTime != null) {
        await _repository.endVisit(
          employeeCode: state!.employeeCode,
          customerCode: state!.customerId,
          visitStart: state!.startTime!,
          visitEnd: endTime,
          duration: duration,
          location: state!.currentLocation,
          reason: reason,
          remarks: remarks,
          followUp: followUp,
        );
      }

      _timer?.cancel();
      state = state!.copyWith(
        status: VisitStatus.completed,
        endTime: endTime,
        duration: duration,
      );
    } finally {
      _isEnding = false;
    }
  }

  void reset() {
    _timer?.cancel();
    state = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final visitsRepositoryProvider = Provider<VisitsRepository>((ref) {
  return VisitsRepository(ref.watch(apiClientProvider));
});

final visitProvider =
    StateNotifierProvider<VisitNotifier, VisitModel?>((ref) {
  return VisitNotifier(ref.watch(visitsRepositoryProvider));
});
