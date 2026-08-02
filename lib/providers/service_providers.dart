import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamboplus/services/api_service.dart';
import 'package:jamboplus/services/storage_service.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final storageServiceProvider =
    Provider<StorageService>((ref) => StorageService());
