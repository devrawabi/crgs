import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/models.dart';

class ItemsRepository {
  ItemsRepository(this._client);

  final ApiClient _client;

  Future<List<AlternativeProductModel>> fetchItems({
    String? search,
    int limit = 500,
    int offset = 0,
  }) async {
    final queryParameters = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    final trimmedSearch = search?.trim() ?? '';
    if (trimmedSearch.isNotEmpty) {
      queryParameters['search'] = trimmedSearch;
    }

    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.items,
      queryParameters: queryParameters,
    );

    final raw = response.data?['items'];
    if (raw is! List) {
      throw ApiException(message: 'Invalid items response from server');
    }

    return raw
        .whereType<Map>()
        .map((item) => _fromItemMaster(Map<String, dynamic>.from(item)))
        .where((product) => product.id.isNotEmpty || product.name.isNotEmpty)
        .toList();
  }

  AlternativeProductModel _fromItemMaster(Map<String, dynamic> json) {
    final code = json['itemcode']?.toString().trim() ?? '';
    final name = json['itemname']?.toString().trim() ?? '';
    final baseUom = json['baseuom']?.toString().trim() ?? '';
    final retailRaw = json['retailprice'];
    final unitPrice = retailRaw is num
        ? retailRaw.toDouble()
        : double.tryParse(retailRaw?.toString() ?? '') ?? 0;

    return AlternativeProductModel(
      id: code.isNotEmpty ? code : name,
      name: name.isNotEmpty ? name : code,
      imageUrl: '',
      details: '',
      category: 'All Products',
      baseUom: baseUom,
      unitPrice: unitPrice,
    );
  }
}
