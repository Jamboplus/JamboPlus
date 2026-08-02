import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamboplus/models/carousel_model.dart';
import 'package:jamboplus/providers/service_providers.dart';

final carouselProvider = FutureProvider<List<CarouselModel>>((ref) async {
  return ref.read(apiServiceProvider).fetchCarousel();
});
