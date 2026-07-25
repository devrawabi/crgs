import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../data/repositories/product_reviews_repository.dart';

final productReviewsRepositoryProvider = Provider<ProductReviewsRepository>((
  ref,
) {
  return ProductReviewsRepository(ref.watch(apiClientProvider));
});
