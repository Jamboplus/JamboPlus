import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamboplus/models/carousel_model.dart';
import 'package:jamboplus/providers/cache_first.dart';
import 'package:jamboplus/providers/service_providers.dart';

final carouselProvider = FutureProvider<List<CarouselModel>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final storage = ref.read(storageServiceProvider);
  return cacheFirstThenRefresh<List<CarouselModel>>(
    ref: ref,
    loadCache: storage.loadCarouselCache,
    fetchRemote: api.fetchCarousel,
    saveCache: storage.saveCarouselCache,
    isUsable: (v) => v.isNotEmpty,
    didChange: (a, b) => listJsonChanged(a, b, (c) => c.toJson()),
  );
});
