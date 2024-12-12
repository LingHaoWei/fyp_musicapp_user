import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  final _cacheManager = DefaultCacheManager();
  final _memoryCache = <String, ImageProvider>{};

  Future<ImageProvider> getImage(String path,
      {bool useMemoryCache = true}) async {
    if (useMemoryCache && _memoryCache.containsKey(path)) {
      return _memoryCache[path]!;
    }

    final file = await _cacheManager.getSingleFile(path);
    final provider = FileImage(file);

    if (useMemoryCache) {
      _memoryCache[path] = provider;
    }

    return provider;
  }

  Widget getCachedImage({
    required String path,
    double? width,
    double? height,
    BoxFit? fit,
    Widget Function(BuildContext, Widget, ImageChunkEvent?)? loadingBuilder,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  }) {
    return FutureBuilder<ImageProvider>(
      future: getImage(path),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return errorBuilder?.call(
                context,
                snapshot.error!,
                snapshot.stackTrace,
              ) ??
              const Icon(Icons.error);
        }

        if (!snapshot.hasData) {
          return loadingBuilder?.call(
                context,
                const SizedBox(),
                null,
              ) ??
              const CircularProgressIndicator();
        }

        return Image(
          image: snapshot.data!,
          width: width,
          height: height,
          fit: fit,
          loadingBuilder: loadingBuilder,
          errorBuilder: errorBuilder,
        );
      },
    );
  }

  Future<void> preloadImages(List<String> paths) async {
    for (final path in paths) {
      await getImage(path);
    }
  }

  void clearCache() {
    _memoryCache.clear();
    _cacheManager.emptyCache();
  }

  void removeFromCache(String path) {
    _memoryCache.remove(path);
    _cacheManager.removeFile(path);
  }
}
