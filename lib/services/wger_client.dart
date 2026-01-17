import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

final wgerClientProvider = Provider<WgerClient>((ref) {
  return WgerClient();
});

class WgerClient {
  WgerClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _host = 'wger.de';
  static const int _cacheDays = 7;
  static const int _licenseCacheDays = 30;

  Future<List<WgerTranslation>> searchTranslations(
    String query, {
    int language = 2,
    int limit = 20,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return [];
    }

    final initial = await _fetchTranslations(
      query: trimmed,
      language: language,
      limit: limit,
    );

    final filtered = _filterByQuery(initial, trimmed);
    if (filtered.isNotEmpty) {
      return filtered.take(limit).toList();
    }

    final fallback = await _fetchTranslationsFallback(
      query: trimmed,
      language: language,
      limit: limit,
      maxPages: 3,
    );
    return fallback.take(limit).toList();
  }

  Future<List<WgerVideo>> getVideos(int exerciseId) async {
    final cached = await _readMediaCache(exerciseId);
    final cachedVideos = cached?.videos ?? const [];
    if (cached != null && !cached.stale && cachedVideos.isNotEmpty) {
      return cachedVideos;
    }

    try {
      final results = await _fetchVideos(exerciseId);
      if (results.isNotEmpty) {
        await _writeMediaCache(
          exerciseId,
          videos: results,
          images: cached?.images ?? const [],
        );
        return results;
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Wger videos fetch failed: $error');
      }
    }

    return cachedVideos;
  }

  Future<List<WgerImage>> getImages(int exerciseId) async {
    final cached = await _readMediaCache(exerciseId);
    final cachedImages = cached?.images ?? const [];
    if (cached != null && !cached.stale && cachedImages.isNotEmpty) {
      return cachedImages;
    }

    try {
      final results = await _fetchImages(exerciseId);
      if (results.isNotEmpty) {
        await _writeMediaCache(
          exerciseId,
          videos: cached?.videos ?? const [],
          images: results,
        );
        return results;
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Wger images fetch failed: $error');
      }
    }

    return cachedImages;
  }

  Future<Map<int, WgerLicense>> getLicenseMap() async {
    final cached = await _readLicenseCache();
    if (cached != null && !cached.stale) {
      return cached.map;
    }

    try {
      final uri = Uri.https(_host, '/api/v2/license/');
      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        throw Exception('License fetch failed: ${response.statusCode}');
      }
      final data = jsonDecode(response.body);
      final results = _parseResults(data);
      final map = <int, WgerLicense>{};
      for (final item in results) {
        final license = WgerLicense.fromJson(item);
        map[license.id] = license;
      }
      await _writeLicenseCache(map);
      return map;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Wger license fetch failed: $error');
      }
    }

    return cached?.map ?? {};
  }

  Future<List<WgerTranslation>> _fetchTranslations({
    required String query,
    required int language,
    required int limit,
  }) async {
    final params = <String, String>{
      'search': query,
      'language': language.toString(),
      'limit': limit.toString(),
    };
    final uri = Uri.https(_host, '/api/v2/exercise-translation/', params);
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Search failed: ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    return _parseResults(data)
        .map(WgerTranslation.fromJson)
        .toList();
  }

  Future<List<WgerTranslation>> _fetchTranslationsFallback({
    required String query,
    required int language,
    required int limit,
    required int maxPages,
  }) async {
    final params = <String, String>{
      'language': language.toString(),
      'limit': '50',
    };
    final results = await _fetchPaged(
      '/api/v2/exercise-translation/',
      params,
      maxPages,
    );
    final translations =
        results.map(WgerTranslation.fromJson).toList();
    return _filterByQuery(translations, query);
  }

  List<WgerTranslation> _filterByQuery(
    List<WgerTranslation> items,
    String query,
  ) {
    final q = query.toLowerCase();
    return items
        .where((item) => item.name.toLowerCase().contains(q))
        .toList();
  }

  Future<List<WgerVideo>> _fetchVideos(int exerciseId) async {
    final params = <String, String>{
      'exercise': exerciseId.toString(),
      'limit': '50',
    };
    final uri = Uri.https(_host, '/api/v2/video/', params);
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Video fetch failed: ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    final results = _parseResults(data)
        .map(WgerVideo.fromJson)
        .where((video) => video.exerciseId == exerciseId)
        .toList();
    if (results.isNotEmpty) {
      return results;
    }

    final fallbackResults = await _fetchPaged(
      '/api/v2/video/',
      {'limit': '50'},
      3,
    );
    return fallbackResults
        .map(WgerVideo.fromJson)
        .where((video) => video.exerciseId == exerciseId)
        .toList();
  }

  Future<List<WgerImage>> _fetchImages(int exerciseId) async {
    final params = <String, String>{
      'exercise': exerciseId.toString(),
      'limit': '50',
    };
    final uri = Uri.https(_host, '/api/v2/exerciseimage/', params);
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Image fetch failed: ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    final results = _parseResults(data)
        .map(WgerImage.fromJson)
        .where((image) => image.exerciseId == exerciseId)
        .toList();
    if (results.isNotEmpty) {
      return results;
    }

    final fallbackResults = await _fetchPaged(
      '/api/v2/exerciseimage/',
      {'limit': '50'},
      5,
    );
    return fallbackResults
        .map(WgerImage.fromJson)
        .where((image) => image.exerciseId == exerciseId)
        .toList();
  }

  List<Map<String, dynamic>> _parseResults(dynamic data) {
    if (data is Map<String, dynamic> && data['results'] is List) {
      return (data['results'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _fetchPaged(
    String path,
    Map<String, String> params,
    int maxPages,
  ) async {
    final results = <Map<String, dynamic>>[];
    var page = 0;
    String? nextUrl;
    do {
      page += 1;
      if (page > maxPages) {
        break;
      }
      Uri uri;
      if (nextUrl != null) {
        uri = Uri.parse(nextUrl);
      } else {
        uri = Uri.https(_host, path, params);
      }
      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        break;
      }
      final data = jsonDecode(response.body);
      results.addAll(_parseResults(data));
      if (data is Map<String, dynamic>) {
        nextUrl = data['next']?.toString();
      } else {
        nextUrl = null;
      }
    } while (nextUrl != null);

    return results;
  }

  Future<_MediaCache?> _readMediaCache(int exerciseId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_mediaCacheKey(exerciseId));
    if (raw == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final fetchedAt = decoded['fetchedAt'] as int?;
      final videosRaw = decoded['videos'] as List?;
      final imagesRaw = decoded['images'] as List?;
      final videos = videosRaw == null
          ? <WgerVideo>[]
          : videosRaw
              .map((item) => WgerVideo.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ))
              .toList();
      final images = imagesRaw == null
          ? <WgerImage>[]
          : imagesRaw
              .map((item) => WgerImage.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ))
              .toList();
      if (fetchedAt != null) {
        final fetched =
            DateTime.fromMillisecondsSinceEpoch(fetchedAt);
        final age = DateTime.now().difference(fetched);
        if (age.inDays > _cacheDays) {
          return _MediaCache(
            fetchedAt: fetched,
            videos: videos,
            images: images,
            stale: true,
          );
        }
      }
      return _MediaCache(
        fetchedAt: fetchedAt == null
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : DateTime.fromMillisecondsSinceEpoch(fetchedAt),
        videos: videos,
        images: images,
        stale: false,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeMediaCache(
    int exerciseId, {
    required List<WgerVideo> videos,
    required List<WgerImage> images,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'fetchedAt': DateTime.now().millisecondsSinceEpoch,
      'videos': videos.map((item) => item.toJson()).toList(),
      'images': images.map((item) => item.toJson()).toList(),
    });
    await prefs.setString(_mediaCacheKey(exerciseId), payload);
  }

  Future<_LicenseCache?> _readLicenseCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_licenseCacheKey);
    final fetchedAt = prefs.getInt(_licenseCacheFetchedKey);
    if (raw == null || fetchedAt == null) {
      return null;
    }
    final fetched = DateTime.fromMillisecondsSinceEpoch(fetchedAt);
    final age = DateTime.now().difference(fetched);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return null;
      }
      final map = <int, WgerLicense>{};
      for (final item in decoded) {
        final license =
            WgerLicense.fromJson(Map<String, dynamic>.from(item as Map));
        map[license.id] = license;
      }
      return _LicenseCache(
        map: map,
        stale: age.inDays > _licenseCacheDays,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeLicenseCache(Map<int, WgerLicense> map) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(
      map.values.map((item) => item.toJson()).toList(),
    );
    await prefs.setString(_licenseCacheKey, payload);
    await prefs.setInt(
      _licenseCacheFetchedKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  String _mediaCacheKey(int exerciseId) =>
      'wger_cache_meta_$exerciseId';
}

class WgerTranslation {
  WgerTranslation({
    required this.id,
    required this.exerciseId,
    required this.name,
    required this.language,
  });

  final int id;
  final int exerciseId;
  final String name;
  final int language;

  factory WgerTranslation.fromJson(Map<String, dynamic> json) {
    return WgerTranslation(
      id: json['id'] as int,
      exerciseId: json['exercise'] as int,
      name: json['name']?.toString() ?? '',
      language: json['language'] as int? ?? 0,
    );
  }
}

class WgerVideo {
  WgerVideo({
    required this.id,
    required this.exerciseId,
    required this.url,
    required this.codec,
    required this.licenseId,
    required this.licenseAuthor,
  });

  final int id;
  final int exerciseId;
  final String url;
  final String? codec;
  final int? licenseId;
  final String? licenseAuthor;

  factory WgerVideo.fromJson(Map<String, dynamic> json) {
    final url = json['video']?.toString() ??
        json['video_url']?.toString() ??
        json['url']?.toString() ??
        '';
    return WgerVideo(
      id: json['id'] as int,
      exerciseId: json['exercise'] as int,
      url: url,
      codec: json['codec']?.toString(),
      licenseId: json['license'] as int?,
      licenseAuthor: json['license_author']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'exercise': exerciseId,
        'video': url,
        'codec': codec,
        'license': licenseId,
        'license_author': licenseAuthor,
      };
}

class WgerImage {
  WgerImage({
    required this.id,
    required this.exerciseId,
    required this.url,
    required this.isMain,
    required this.licenseId,
    required this.licenseAuthor,
  });

  final int id;
  final int exerciseId;
  final String url;
  final bool isMain;
  final int? licenseId;
  final String? licenseAuthor;

  factory WgerImage.fromJson(Map<String, dynamic> json) {
    return WgerImage(
      id: json['id'] as int,
      exerciseId: json['exercise'] as int,
      url: json['image']?.toString() ?? '',
      isMain: json['is_main'] as bool? ?? false,
      licenseId: json['license'] as int?,
      licenseAuthor: json['license_author']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'exercise': exerciseId,
        'image': url,
        'is_main': isMain,
        'license': licenseId,
        'license_author': licenseAuthor,
      };
}

class WgerLicense {
  WgerLicense({
    required this.id,
    required this.shortName,
    required this.fullName,
    required this.url,
  });

  final int id;
  final String shortName;
  final String fullName;
  final String url;

  factory WgerLicense.fromJson(Map<String, dynamic> json) {
    return WgerLicense(
      id: json['id'] as int,
      shortName: json['short_name']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'short_name': shortName,
        'full_name': fullName,
        'url': url,
      };
}

class _MediaCache {
  _MediaCache({
    required this.fetchedAt,
    required this.videos,
    required this.images,
    required this.stale,
  });

  final DateTime fetchedAt;
  final List<WgerVideo> videos;
  final List<WgerImage> images;
  final bool stale;
}

class _LicenseCache {
  _LicenseCache({required this.map, required this.stale});

  final Map<int, WgerLicense> map;
  final bool stale;
}

const String _licenseCacheKey = 'wger_license_cache';
const String _licenseCacheFetchedKey = 'wger_license_cache_fetched_at';
