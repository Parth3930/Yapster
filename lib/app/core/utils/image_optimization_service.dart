import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

class ImageOptimizationService extends GetxService {
  static ImageOptimizationService get to => Get.find<ImageOptimizationService>();
  
  // Custom cache manager for images with specific settings
  late final CacheManager _customCacheManager;
  
  // Image cache settings
  final int _maxCacheSizeInMB = 100;
  final int _maxCacheEntries = 500;
  final Duration _cacheValidity = const Duration(days: 30);
  
  // Statistics for monitoring
  final RxInt imagesLoaded = 0.obs;
  final RxInt imagesLoadedFromCache = 0.obs;
  final RxInt totalImageSizeDownloaded = 0.obs;
  final RxInt totalImageSizeOptimized = 0.obs;
  
  // Initialize service
  Future<ImageOptimizationService> init() async {
    await _initCacheManager();
    return this;
  }
  
  // Initialize the cache manager
  Future<void> _initCacheManager() async {
    _customCacheManager = CacheManager(
      Config(
        'yapster_image_cache',
        stalePeriod: _cacheValidity,
        maxNrOfCacheObjects: _maxCacheEntries,
        repo: JsonCacheInfoRepository(
          databaseName: 'yapster_image_cache_db',
        ),
        fileService: HttpFileService(),
      ),
    );
  }
  
  // Get an image from the network with optimizations
  CachedNetworkImage getOptimizedNetworkImage({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit? fit,
    Widget? placeholder,
    Widget? errorWidget,
    bool applySmartDownsize = true,
  }) {
    // Apply query parameters to optimize image loading if URL supports it
    String optimizedUrl = imageUrl;
    if (applySmartDownsize && _isResizableUrl(imageUrl)) {
      optimizedUrl = _getOptimizedImageUrl(imageUrl, width, height);
    }
    
    return CachedNetworkImage(
      imageUrl: optimizedUrl,
      width: width,
      height: height,
      fit: fit ?? BoxFit.cover,
      placeholder: (context, url) => placeholder ?? 
        const Center(child: CircularProgressIndicator()),
      errorWidget: (context, url, error) => errorWidget ??
        const Icon(Icons.error),
      cacheManager: _customCacheManager,
      fadeInDuration: const Duration(milliseconds: 300),
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
      // Track image loading stats
      imageBuilder: (context, imageProvider) {
        imagesLoaded.value++;
        return Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: imageProvider,
              fit: fit ?? BoxFit.cover,
            ),
          ),
        );
      },
    );
  }
  
  // Check if URL can be resized (based on common image CDNs)
  bool _isResizableUrl(String url) {
    return url.contains('supabase.co') || 
           url.contains('cloudinary.com') ||
           url.contains('imgix.net') ||
           url.contains('githubusercontent.com');
  }
  
  // Add resize parameters to URL
  String _getOptimizedImageUrl(String imageUrl, double? width, double? height) {
    if (imageUrl.isEmpty) return imageUrl;
    
    try {
      final Uri uri = Uri.parse(imageUrl);
      
      // Different CDNs use different query parameters
      if (uri.host.contains('supabase')) {
        // Supabase Storage resize params
        var queryParams = Map<String, dynamic>.from(uri.queryParameters);
        if (width != null) queryParams['width'] = width.toInt().toString();
        if (height != null) queryParams['height'] = height.toInt().toString();
        queryParams['quality'] = '80'; // Auto-optimize quality
        return uri.replace(queryParameters: queryParams).toString();
      } else if (uri.host.contains('cloudinary')) {
        // Cloudinary transformation URL structure
        var parts = imageUrl.split('/upload/');
        if (parts.length == 2) {
          String transform = 'q_auto,f_auto'; // auto quality and format
          if (width != null) transform += ',w_${width.toInt()}';
          if (height != null) transform += ',h_${height.toInt()}';
          return '${parts[0]}/upload/$transform/${parts[1]}';
        }
      } else if (uri.host.contains('githubusercontent')) {
        // GitHub optimized image paths (raw images)
        if (width != null && width <= 200) {
          return '$imageUrl?size=200';
        } else if (width != null && width <= 400) {
          return '$imageUrl?size=400';
        }
      }
    } catch (e) {
      debugPrint('Error optimizing URL $imageUrl: $e');
    }
    
    return imageUrl;
  }
  
  // Preload important images to improve UX
  Future<void> preloadImages(List<String> imageUrls) async {
    for (final url in imageUrls) {
      try {
        await _customCacheManager.getSingleFile(url);
      } catch (e) {
        debugPrint('Error preloading image $url: $e');
      }
    }
  }
  
  // Clear image cache
  Future<void> clearImageCache() async {
    await _customCacheManager.emptyCache();
    imagesLoaded.value = 0;
    imagesLoadedFromCache.value = 0;
    totalImageSizeDownloaded.value = 0;
    totalImageSizeOptimized.value = 0;
    debugPrint('Image cache cleared');
  }
  
  // Get cache statistics
  Future<Map<String, dynamic>> getImageCacheStats() async {
    final cacheSize = await _calculateCacheSize();
    return {
      'imagesLoaded': imagesLoaded.value,
      'imagesLoadedFromCache': imagesLoadedFromCache.value,
      'cacheHitRatio': imagesLoaded.value > 0 
          ? imagesLoadedFromCache.value / imagesLoaded.value 
          : 0.0,
      'totalImageSizeDownloaded': totalImageSizeDownloaded.value,
      'totalImageSizeOptimized': totalImageSizeOptimized.value,
      'bandwidthSavings': totalImageSizeDownloaded.value > 0 
          ? totalImageSizeOptimized.value / totalImageSizeDownloaded.value * 100
          : 0.0,
      'currentCacheSizeMB': cacheSize / (1024 * 1024), // Convert bytes to MB
    };
  }
  
  // Calculate total cache size
  Future<int> _calculateCacheSize() async {
    int totalSize = 0;
    try {
      final cacheDir = await getTemporaryDirectory();
      final dir = Directory('${cacheDir.path}/libCachedImageData');
      if (await dir.exists()) {
        await for (final file in dir.list(recursive: true)) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
      }
    } catch (e) {
      debugPrint('Error calculating cache size: $e');
    }
    return totalSize;
  }
} 