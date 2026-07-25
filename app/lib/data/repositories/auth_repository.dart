import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/models.dart';

class AuthRepository {
  AuthRepository(this._client);

  final ApiClient _client;

  Future<UserModel> login({
    required String employeeCode,
    required String password,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.login,
      data: {
        'employeeCode': employeeCode,
        'password': password,
      },
    );

    final data = response.data;
    if (data == null) {
      throw ApiException(message: 'Empty response from server');
    }

    return UserModel.fromLoginResponse(data);
  }

  Future<void> completeOnboarding({required String employeeCode}) async {
    await _client.patch<Map<String, dynamic>>(
      ApiEndpoints.onboarding,
      data: {'employeeCode': employeeCode},
    );
  }
}
