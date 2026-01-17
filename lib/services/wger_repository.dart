import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final wgerRepositoryProvider = Provider<WgerRepository>((ref) {
  return WgerRepository();
});

class WgerRepository {
  WgerRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _host = 'wger.de';
  static const Duration _staleAfter = Duration(days: 7);

  Future<List<WgerTranslationIndexItem>> loadTranslationIndex({
    int languageId = 2,
    void Function(int currentPage, int totalPages)? onProgress,
  }) async {
    final cached = await _readIndexFile(await _translationIndexFile(languageId));
    if (cached != null) {
      if (cached.isStale) {
        unawaited(
          downloadTranslationIndex(
            languageId: languageId,
            onProgress: null,
          ).catchError((_) {}),
        );
      }
      return cached.items
          .map(WgerTranslationIndexItem.fromJson)
          .toList();
    }
    final fresh = await downloadTranslationIndex(
      languageId: languageId,
      onProgress: onProgress,
    );
    return fresh;
  }

  Future<List<WgerTranslationIndexItem>> downloadTranslationIndex({
    int languageId = 2,
    void Function(int currentPage, int totalPages)? onProgress,
  }) async {
    final items = <WgerTranslationIndexItem>[];
    final limit = 200;
    var offset = 0;
    var page = 0;
    int? totalPages;
    String? nextUrl;

    do {
      page += 1;
      Uri uri;
      if (nextUrl != null) {
        uri = Uri.parse(nextUrl);
      } else {
        uri = Uri.https(_host, '/api/v2/exercise-translation/', {
          'language': languageId.toString(),
          'limit': limit.toString(),
          'offset': offset.toString(),
        });
      }

      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        throw Exception(
          'Translation index failed: ${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body);
      final count = data['count'] as int? ?? 0;
      totalPages ??= max(1, (count / limit).ceil());
      final results = data['results'] as List? ?? [];
      for (final item in results) {
        items.add(WgerTranslationIndexItem.fromJson(
          Map<String, dynamic>.from(item as Map),
        ));
      }
      onProgress?.call(page, totalPages);
      nextUrl = data['next']?.toString();
      offset += limit;
    } while (nextUrl != null);

    await _writeIndexFile(
      await _translationIndexFile(languageId),
      items.map((item) => item.toJson()).toList(),
    );
    return items;
  }

  WgerSearchOutput searchIndex(
    List<WgerTranslationIndexItem> items,
    String query,
  ) {
    final normalized = _normalize(query);
    if (normalized.isEmpty) {
      return WgerSearchOutput(
        results: const [],
        suggestions: const [],
      );
    }

    final initialResults =
        _rankedSearch(items, normalized).take(20).toList();
    if (initialResults.isNotEmpty) {
      return WgerSearchOutput(results: initialResults, suggestions: const []);
    }

    final fallbackQueries = _fallbackQueries(normalized);
    for (final fallback in fallbackQueries) {
      final results = _rankedSearch(items, fallback).take(20).toList();
      if (results.isNotEmpty) {
        return WgerSearchOutput(
          results: results,
          suggestions: const [],
        );
      }
    }

    return WgerSearchOutput(
      results: const [],
      suggestions: fallbackQueries,
    );
  }

  Future<WgerMediaBundle> loadMediaForExercise(int exerciseId) async {
    final videos = await _loadMediaIndex(
      file: await _videoIndexFile(),
      path: '/api/v2/video/',
      mapper: WgerVideo.fromJson,
    );
    final images = await _loadMediaIndex(
      file: await _imageIndexFile(),
      path: '/api/v2/exerciseimage/',
      mapper: WgerImage.fromJson,
    );

    final matchedVideos =
        videos.where((item) => item.exerciseId == exerciseId).toList();
    final matchedImages =
        images.where((item) => item.exerciseId == exerciseId).toList();

    matchedImages.sort((a, b) {
      if (a.isMain == b.isMain) {
        return 0;
      }
      return a.isMain ? -1 : 1;
    });

    return WgerMediaBundle(
      videos: matchedVideos,
      images: matchedImages,
    );
  }

  Future<List<T>> _loadMediaIndex<T>({
    required File file,
    required String path,
    required T Function(Map<String, dynamic>) mapper,
  }) async {
    final cached = await _readIndexFile(file);
    if (cached != null) {
      if (cached.isStale) {
        unawaited(
          _refreshMediaIndex(file: file, path: path).catchError((_) {}),
        );
      }
      return cached.items
          .map((item) => mapper(item))
          .toList();
    }

    await _refreshMediaIndex(file: file, path: path);
    final fresh = await _readIndexFile(file);
    if (fresh == null) {
      return [];
    }
    return fresh.items.map((item) => mapper(item)).toList();
  }

  Future<void> _refreshMediaIndex({
    required File file,
    required String path,
  }) async {
    final items = <Map<String, dynamic>>[];
    final limit = 200;
    var offset = 0;
    String? nextUrl;

    do {
      Uri uri;
      if (nextUrl != null) {
        uri = Uri.parse(nextUrl);
      } else {
        uri = Uri.https(_host, path, {
          'limit': limit.toString(),
          'offset': offset.toString(),
        });
      }
      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Media index failed: ${response.statusCode}');
      }
      final data = jsonDecode(response.body);
      final results = data['results'] as List? ?? [];
      for (final item in results) {
        items.add(Map<String, dynamic>.from(item as Map));
      }
      nextUrl = data['next']?.toString();
      offset += limit;
    } while (nextUrl != null);

    await _writeIndexFile(file, items);
  }

  Iterable<WgerTranslationIndexItem> _rankedSearch(
    List<WgerTranslationIndexItem> items,
    String normalizedQuery,
  ) {
    final tokens = normalizedQuery.split(' ').where((t) => t.isNotEmpty).toList();
    final scored = <_ScoredItem>[];

    for (final item in items) {
      final normalizedName = _normalize(item.name);
      if (normalizedName.isEmpty) {
        continue;
      }
      final score = _scoreItem(normalizedName, normalizedQuery, tokens);
      if (score <= 0) {
        continue;
      }
      scored.add(_ScoredItem(item: item, score: score));
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) {
        return byScore;
      }
      return a.item.name.length.compareTo(b.item.name.length);
    });

    return scored.map((item) => item.item);
  }

  int _scoreItem(
    String normalizedName,
    String normalizedQuery,
    List<String> tokens,
  ) {
    if (normalizedName.contains(normalizedQuery)) {
      return 1000 + (100 - (normalizedName.length - normalizedQuery.length).abs());
    }

    final allTokensPresent =
        tokens.isNotEmpty && tokens.every(normalizedName.contains);
    if (allTokensPresent) {
      return 800 + tokens.length;
    }

    var partialMatches = 0;
    for (final token in tokens) {
      if (normalizedName.contains(token)) {
        partialMatches += 1;
      } else {
        for (final nameToken in normalizedName.split(' ')) {
          if (nameToken.startsWith(token) || token.startsWith(nameToken)) {
            partialMatches += 1;
            break;
          }
        }
      }
    }
    if (partialMatches > 0) {
      return 400 + partialMatches;
    }
    return 0;
  }

  List<String> _fallbackQueries(String normalizedQuery) {
    final tokens = normalizedQuery.split(' ').where((t) => t.isNotEmpty).toList();
    final suggestions = <String>[];
    if (tokens.length >= 2) {
      suggestions.add(tokens.sublist(tokens.length - 2).join(' '));
    }
    if (tokens.isNotEmpty) {
      suggestions.add(tokens.last);
    }

    if (normalizedQuery.contains('bulgarian') ||
        normalizedQuery.contains('split squat')) {
      suggestions.add('rear foot elevated');
    }
    return suggestions.toSet().toList();
  }

  String _normalize(String input) {
    final lower = input.toLowerCase();
    final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    return cleaned.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<_IndexCache?> _readIndexFile(File file) async {
    if (!await file.exists()) {
      return null;
    }
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final fetchedAt = decoded['fetchedAt'] as int?;
      final items = (decoded['items'] as List? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      final fetched = fetchedAt == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(fetchedAt);
      final isStale = DateTime.now().difference(fetched) > _staleAfter;
      return _IndexCache(items: items, isStale: isStale);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeIndexFile(
    File file,
    List<Map<String, dynamic>> items,
  ) async {
    final payload = jsonEncode({
      'fetchedAt': DateTime.now().millisecondsSinceEpoch,
      'items': items,
    });
    await file.parent.create(recursive: true);
    await file.writeAsString(payload);
  }

  Future<File> _translationIndexFile(int languageId) async {
    final base = await _baseDir();
    return File(p.join(base.path, 'wger_translation_index_$languageId.json'));
  }

  Future<File> _videoIndexFile() async {
    final base = await _baseDir();
    return File(p.join(base.path, 'wger_video_index.json'));
  }

  Future<File> _imageIndexFile() async {
    final base = await _baseDir();
    return File(p.join(base.path, 'wger_image_index.json'));
  }

  Future<Directory> _baseDir() async {
    if (_baseDirCache != null) {
      return _baseDirCache!;
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'wger'));
    _baseDirCache = dir;
    return dir;
  }

  Directory? _baseDirCache;
}

class WgerTranslationIndexItem {
  WgerTranslationIndexItem({
    required this.id,
    required this.name,
    required this.exerciseId,
  });

  final int id;
  final String name;
  final int exerciseId;

  factory WgerTranslationIndexItem.fromJson(Map<String, dynamic> json) {
    return WgerTranslationIndexItem(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
      exerciseId: json['exercise'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'exercise': exerciseId,
      };
}

class WgerVideo {
  WgerVideo({
    required this.id,
    required this.exerciseId,
    required this.url,
    required this.codec,
    required this.licenseAuthor,
  });

  final int id;
  final int exerciseId;
  final String url;
  final String? codec;
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
      licenseAuthor: json['license_author']?.toString(),
    );
  }
}

class WgerImage {
  WgerImage({
    required this.id,
    required this.exerciseId,
    required this.url,
    required this.isMain,
    required this.licenseAuthor,
  });

  final int id;
  final int exerciseId;
  final String url;
  final bool isMain;
  final String? licenseAuthor;

  factory WgerImage.fromJson(Map<String, dynamic> json) {
    return WgerImage(
      id: json['id'] as int,
      exerciseId: json['exercise'] as int,
      url: json['image']?.toString() ?? '',
      isMain: json['is_main'] as bool? ?? false,
      licenseAuthor: json['license_author']?.toString(),
    );
  }
}

class WgerMediaBundle {
  WgerMediaBundle({required this.videos, required this.images});

  final List<WgerVideo> videos;
  final List<WgerImage> images;
}

class WgerSearchOutput {
  const WgerSearchOutput({
    required this.results,
    required this.suggestions,
  });

  final List<WgerTranslationIndexItem> results;
  final List<String> suggestions;
}

class _ScoredItem {
  _ScoredItem({required this.item, required this.score});

  final WgerTranslationIndexItem item;
  final int score;
}

class _IndexCache {
  _IndexCache({required this.items, required this.isStale});

  final List<Map<String, dynamic>> items;
  final bool isStale;
}
