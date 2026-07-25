import 'package:dio/dio.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';

class ProductReviewsRepository {
  ProductReviewsRepository(this._client);

  final ApiClient _client;

  /// Insert into CRGS_PRODUCTREVIEW (optional image via multipart).
  Future<Map<String, dynamic>> submitReview({
    required String employeeCode,
    required String route,
    required String customerCode,
    required String customerName,
    required String itemCode,
    required String itemName,
    required String reason,
    List<int>? imageBytes,
    String? imageFileName,
  }) async {
    final hasImage = imageBytes != null && imageBytes.isNotEmpty;

    final Response<Map<String, dynamic>> response;
    if (hasImage) {
      final rawName = imageFileName?.trim() ?? '';
      final filename = rawName.isEmpty
          ? 'feedback.jpg'
          : (rawName.contains('.') ? rawName : '$rawName.jpg');
      final formData = FormData.fromMap({
        'employeeCode': employeeCode,
        'route': route,
        'customerCode': customerCode,
        'customerName': customerName,
        'itemCode': itemCode,
        'itemName': itemName,
        'reason': reason,
        'image': MultipartFile.fromBytes(
          imageBytes,
          filename: filename,
        ),
      });
      response = await _client.postMultipart<Map<String, dynamic>>(
        ApiEndpoints.productReviews,
        data: formData,
      );
    } else {
      response = await _client.post<Map<String, dynamic>>(
        ApiEndpoints.productReviews,
        data: {
          'employeeCode': employeeCode,
          'route': route,
          'customerCode': customerCode,
          'customerName': customerName,
          'itemCode': itemCode,
          'itemName': itemName,
          'reason': reason,
        },
      );
    }

    final data = response.data;
    if (data == null) {
      throw ApiException(message: 'Invalid product review response from server');
    }
    return data;
  }
}
