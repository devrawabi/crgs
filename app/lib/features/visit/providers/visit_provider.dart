import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/visits_repository.dart';

class VisitNotifier extends StateNotifier<VisitModel?> {
  VisitNotifier(this._repository) : super(null);

  final VisitsRepository _repository;
  Timer? _persistRetryTimer;
  bool _isStarting = false;
  bool _isEnding = false;
  int _persistAttempts = 0;
  String? _lastStartError;

  static const int _maxPersistAttempts = 5;

  bool get isStarting => _isStarting;
  bool get isEnding => _isEnding;
  String? get lastStartError => _lastStartError;

  bool get isSyncing =>
      state?.status == VisitStatus.inProgress &&
      !(state?.persisted ?? true) &&
      (_isStarting || _persistRetryTimer != null);

  Future<void> startVisit({
    required String employeeCode,
    required String customerId,
    required String customerName,
    required String route,
    required String location,
  }) async {
    final active = state;
    if (active?.status == VisitStatus.inProgress &&
        active?.customerId == customerId) {
      if (active!.persisted) return;
      // Already running locally — just retry server persistence.
      await _persistStart();
      return;
    }

    if (_isStarting) return;
    _isStarting = true;
    _lastStartError = null;
    _persistAttempts = 0;
    _persistRetryTimer?.cancel();

    final now = DateTime.now().copyWith(millisecond: 0, microsecond: 0);
    final safeRoute = route.trim().isEmpty ? '-' : route.trim();
    state = VisitModel(
      id: 'visit-${now.millisecondsSinceEpoch}',
      customerId: customerId,
      customerName: customerName,
      employeeCode: employeeCode,
      route: safeRoute,
      status: VisitStatus.inProgress,
      startTime: now,
      currentLocation: location,
    );

    try {
      await _persistStart();
    } finally {
      _isStarting = false;
    }
  }

  /// Retries saving the open visit to the server (used by UI Retry).
  Future<void> retryPersistStart() async {
    if (state?.status != VisitStatus.inProgress) return;
    if (state!.persisted) return;
    _persistAttempts = 0;
    _lastStartError = null;
    _persistRetryTimer?.cancel();
    _persistRetryTimer = null;
    _isStarting = true;
    try {
      await _persistStart();
    } finally {
      _isStarting = false;
    }
  }

  Future<void> _persistStart() async {
    final visit = state;
    if (visit == null ||
        visit.status != VisitStatus.inProgress ||
        visit.persisted ||
        visit.startTime == null) {
      return;
    }

    try {
      final response = await _repository.startVisit(
        employeeCode: visit.employeeCode,
        customerCode: visit.customerId,
        customerName: visit.customerName,
        route: visit.route.isEmpty ? '-' : visit.route,
        visitStart: visit.startTime!,
        location: visit.currentLocation,
      );

      final serverStart = response['visitStart']?.toString();
      DateTime? parsedStart;
      if (serverStart != null && serverStart.isNotEmpty) {
        // Server may return time-only (HH:mm:ss); keep local date.
        final timeParts = serverStart.split(':');
        if (timeParts.length >= 2 && DateTime.tryParse(serverStart) == null) {
          final now = visit.startTime!;
          final h = int.tryParse(timeParts[0]) ?? now.hour;
          final m = int.tryParse(timeParts[1]) ?? now.minute;
          final s = timeParts.length > 2 ? int.tryParse(timeParts[2]) ?? 0 : 0;
          parsedStart = DateTime(now.year, now.month, now.day, h, m, s);
        } else {
          parsedStart = DateTime.tryParse(serverStart);
        }
      }

      if (state != null && state!.customerId == visit.customerId) {
        state = state!.copyWith(
          startTime: parsedStart ?? state!.startTime,
          persisted: true,
        );
      }
      _lastStartError = null;
      _persistAttempts = 0;
      _persistRetryTimer?.cancel();
      _persistRetryTimer = null;
    } catch (error) {
      _lastStartError = _errorMessage(error);
      // Keep the local visit running so the rep is never blocked by a
      // flaky tunnel / Oracle blip. Auto-retry transient failures.
      if (_isTransientError(error)) {
        _schedulePersistRetry();
      }
      rethrow;
    }
  }

  void _schedulePersistRetry() {
    _persistRetryTimer?.cancel();
    if (_persistAttempts >= _maxPersistAttempts) return;
    if (state?.persisted == true) return;

    final attempt = _persistAttempts;
    _persistAttempts = attempt + 1;
    final delay = Duration(seconds: (2 << attempt).clamp(2, 20));
    _persistRetryTimer = Timer(delay, () async {
      if (state?.status != VisitStatus.inProgress || state?.persisted == true) {
        return;
      }
      try {
        await _persistStart();
      } catch (_) {
        // Error already stored; further retries scheduled inside catch.
      }
    });
  }

  static String _errorMessage(Object error) {
    if (error is ApiException) return error.message;
    return error.toString();
  }

  static bool _isTransientError(Object error) {
    if (error is! ApiException) return true;
    final code = error.statusCode;
    if (code == null) return true;
    if (code == 408 || code == 429 || code >= 500) return true;
    // 4xx validation / auth errors won't succeed on blind retry.
    return false;
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
      // Ensure the visit row exists before ending — covers the case where
      // start timed out but the local timer kept running.
      if (!state!.persisted &&
          state!.employeeCode.isNotEmpty &&
          state!.startTime != null) {
        await _persistStart();
      }

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
      } else {
        throw ApiException(
          message:
              _lastStartError ??
              'Visit was not saved to the server. Check connection and retry.',
        );
      }

      _persistRetryTimer?.cancel();
      _persistRetryTimer = null;
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
    _persistRetryTimer?.cancel();
    _persistRetryTimer = null;
    _lastStartError = null;
    _persistAttempts = 0;
    state = null;
  }

  @override
  void dispose() {
    _persistRetryTimer?.cancel();
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
