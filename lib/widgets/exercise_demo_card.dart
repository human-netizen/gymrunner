import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../data/db/app_database.dart';
import '../services/wger_cache_manager.dart';
import '../services/wger_repository.dart';

class ExerciseDemoCard extends ConsumerStatefulWidget {
  const ExerciseDemoCard({super.key, required this.exercise});

  final Exercise exercise;

  @override
  ConsumerState<ExerciseDemoCard> createState() => _ExerciseDemoCardState();
}

class _ExerciseDemoCardState extends ConsumerState<ExerciseDemoCard> {
  int? _linkedExerciseId;
  bool _loadingLink = true;
  bool _loadingMedia = false;
  String? _error;
  List<WgerVideo> _videos = [];
  List<WgerImage> _images = [];
  WgerVideo? _selectedVideo;
  WgerImage? _selectedImage;
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _muted = true;
  Timer? _imageTimer;
  int _imageIndex = 0;
  bool _imagePaused = false;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadLink();
  }

  @override
  void dispose() {
    _imageTimer?.cancel();
    _videoController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 8),
            if (_loadingLink)
              const Center(child: CircularProgressIndicator())
            else if (_linkedExerciseId == null)
              _buildLinkPrompt(context)
            else
              _buildDemoContent(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Demo (wger)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (_linkedExerciseId != null)
          PopupMenuButton<_DemoMenuAction>(
            onSelected: (action) {
              switch (action) {
                case _DemoMenuAction.change:
                  _openLinkSheet();
                case _DemoMenuAction.remove:
                  _removeLink();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _DemoMenuAction.change,
                child: Text('Change linked demo'),
              ),
              PopupMenuItem(
                value: _DemoMenuAction.remove,
                child: Text('Remove demo link'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildLinkPrompt(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Link a demo to see a movement walkthrough.'),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _openLinkSheet,
          child: const Text('Find demo'),
        ),
      ],
    );
  }

  Widget _buildDemoContent(BuildContext context) {
    if (_loadingMedia) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_error!),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _loadMedia,
            child: const Text('Retry'),
          ),
        ],
      );
    }

    if (_selectedVideo != null && _videoReady && _videoController != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: VideoPlayer(_videoController!),
                ),
                IconButton(
                  icon: Icon(_muted ? Icons.volume_off : Icons.volume_up),
                  color: Colors.white,
                  onPressed: _toggleMute,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _buildAttribution(licenseAuthor: _selectedVideo?.licenseAuthor),
        ],
      );
    }

    if (_images.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _toggleImagePause,
            child: SizedBox(
              height: 200,
              child: PageView.builder(
                itemCount: _images.length,
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _imageIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  final image = _images[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: image.url,
                      cacheManager: WgerCacheManager.instance,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) =>
                          const Center(child: Icon(Icons.broken_image)),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildAttribution(licenseAuthor: _selectedImage?.licenseAuthor),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text('Connect to the internet to load demo media.'),
      ],
    );
  }

  Widget _buildAttribution({required String? licenseAuthor}) {
    final authorText = (licenseAuthor == null || licenseAuthor.isEmpty)
        ? 'Unknown'
        : licenseAuthor;

    return Row(
      children: [
        Expanded(
          child: Text(
            'Source: wger | $authorText',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Future<void> _loadLink() async {
    final linked = await _readLink(widget.exercise.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _linkedExerciseId = linked;
      _loadingLink = false;
    });
    if (linked != null) {
      await _loadMedia();
    }
  }

  Future<void> _loadMedia() async {
    final linkedId = _linkedExerciseId;
    if (linkedId == null) {
      return;
    }

    setState(() {
      _loadingMedia = true;
      _error = null;
    });

    try {
      final repository = ref.read(wgerRepositoryProvider);
      final bundle = await repository.loadMediaForExercise(linkedId);

      if (!mounted) {
        return;
      }

      _videos = bundle.videos;
      _images = _sortImages(bundle.images).take(3).toList();
      _imageIndex = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }

      final selectedVideo = _selectVideo(_videos);
      _selectedVideo = selectedVideo;
      _selectedImage = _images.isNotEmpty ? _images.first : null;

      if (selectedVideo != null) {
        final ready = await _prepareVideo(selectedVideo.url);
        if (!ready) {
          _selectedVideo = null;
        }
      }

      if (_selectedVideo == null && _images.isEmpty) {
        _error = 'Connect to the internet to load demo media.';
      } else if (_selectedVideo == null) {
        _startImageLoop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _error = 'Connect to the internet to load demo media.';
    } finally {
      if (mounted) {
        setState(() {
          _loadingMedia = false;
        });
      }
    }
  }

  Future<bool> _prepareVideo(String url) async {
    try {
      final cached = await WgerCacheManager.instance.getFileFromCache(url);
      File file;
      if (cached != null && await cached.file.exists()) {
        file = cached.file;
      } else {
        file = await WgerCacheManager.instance.getSingleFile(url);
      }

      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(_muted ? 0 : 1);
      await controller.play();

      _videoController?.dispose();
      _videoController = controller;
      _videoReady = true;
      return true;
    } catch (_) {
      _videoController?.dispose();
      _videoController = null;
      _videoReady = false;
      return false;
    }
  }

  void _startImageLoop() {
    _imageTimer?.cancel();
    if (_images.length < 2) {
      return;
    }
    _imageTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_imagePaused) {
        return;
      }
      if (!_pageController.hasClients) {
        return;
      }
      final nextIndex = (_imageIndex + 1) % _images.length;
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _toggleImagePause() {
    setState(() {
      _imagePaused = !_imagePaused;
    });
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
    });
    _videoController?.setVolume(_muted ? 0 : 1);
  }

  Future<void> _openLinkSheet() async {
    final selected = await showModalBottomSheet<WgerTranslationIndexItem>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _WgerLinkSheet(
        exerciseName: widget.exercise.name,
      ),
    );
    if (selected == null) {
      return;
    }

    await _writeLink(widget.exercise.id, selected.exerciseId);

    if (!mounted) {
      return;
    }

    setState(() {
      _linkedExerciseId = selected.exerciseId;
    });
    await _loadMedia();
  }

  Future<void> _removeLink() async {
    await _removeLinkFromPrefs(widget.exercise.id);
    _imageTimer?.cancel();
    await _videoController?.dispose();
    if (!mounted) {
      return;
    }
    setState(() {
      _linkedExerciseId = null;
      _videos = [];
      _images = [];
      _selectedVideo = null;
      _selectedImage = null;
      _videoReady = false;
    });
  }

  List<WgerImage> _sortImages(List<WgerImage> images) {
    final main = images.where((img) => img.isMain).toList();
    final rest = images.where((img) => !img.isMain).toList();
    return [...main, ...rest];
  }

  WgerVideo? _selectVideo(List<WgerVideo> videos) {
    if (videos.isEmpty) {
      return null;
    }
    final h264 = videos.firstWhere(
      (video) => (video.codec ?? '').toLowerCase().contains('h264'),
      orElse: () => videos.first,
    );
    return h264.url.isEmpty ? videos.first : h264;
  }

  Future<int?> _readLink(int localExerciseId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_linksKey);
    if (raw == null) {
      final legacy = prefs.getInt(_legacyLinkKey(localExerciseId));
      if (legacy != null) {
        await _writeLink(localExerciseId, legacy);
        await prefs.remove(_legacyLinkKey(localExerciseId));
      }
      return legacy;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final value = decoded['$localExerciseId'];
      if (value is int) {
        return value;
      }
      final parsed = int.tryParse(value.toString());
      if (parsed == null) {
        final legacy = prefs.getInt(_legacyLinkKey(localExerciseId));
        if (legacy != null) {
          await _writeLink(localExerciseId, legacy);
          await prefs.remove(_legacyLinkKey(localExerciseId));
        }
        return legacy;
      }
      return parsed;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeLink(int localExerciseId, int wgerExerciseId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_linksKey);
    final map = <String, dynamic>{};
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          map.addAll(decoded);
        }
      } catch (_) {}
    }
    map['$localExerciseId'] = wgerExerciseId;
    await prefs.setString(_linksKey, jsonEncode(map));
  }

  Future<void> _removeLinkFromPrefs(int localExerciseId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_linksKey);
    if (raw == null) {
      await prefs.remove(_legacyLinkKey(localExerciseId));
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        decoded.remove('$localExerciseId');
        await prefs.setString(_linksKey, jsonEncode(decoded));
      }
    } catch (_) {}
    await prefs.remove(_legacyLinkKey(localExerciseId));
  }

  static const String _linksKey = 'wger_links_map';
  String _legacyLinkKey(int localExerciseId) =>
      'wger_link_$localExerciseId';
}

enum _DemoMenuAction { change, remove }

class _WgerLinkSheet extends ConsumerStatefulWidget {
  const _WgerLinkSheet({required this.exerciseName});

  final String exerciseName;

  @override
  ConsumerState<_WgerLinkSheet> createState() => _WgerLinkSheetState();
}

class _WgerLinkSheetState extends ConsumerState<_WgerLinkSheet> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<WgerTranslationIndexItem> _index = [];
  List<WgerTranslationIndexItem> _results = [];
  List<String> _suggestions = [];
  bool _loadingIndex = false;
  bool _indexReady = false;
  int? _currentPage;
  int? _totalPages;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.exerciseName;
    _loadIndex();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queryEmpty = _controller.text.trim().isEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Search wger exercises',
            ),
            onChanged: _search,
          ),
          const SizedBox(height: 12),
          if (_loadingIndex)
            Text(
              _currentPage == null || _totalPages == null
                  ? 'Preparing exercise library...'
                  : 'Preparing exercise library... ($_currentPage/$_totalPages pages)',
            ),
          if (_error != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _loadIndex,
              child: const Text('Retry'),
            ),
          ],
          if (_indexReady && _results.isEmpty && queryEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text('Type to search.'),
            ),
          if (_indexReady &&
              _results.isEmpty &&
              _suggestions.isNotEmpty &&
              !queryEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Try: ${_suggestions.join(' / ')}',
                ),
              ),
            ),
          if (_indexReady &&
              _results.isEmpty &&
              _suggestions.isEmpty &&
              !queryEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text('No results. Try another search.'),
            ),
          if (_results.isNotEmpty)
            SizedBox(
              height: 320,
              child: ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _results[index];
                  return ListTile(
                    title: Text(item.name),
                    subtitle: Text('wger ID: ${item.exerciseId}'),
                    onTap: () => Navigator.of(context).pop(item),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _loadIndex() async {
    _debounce?.cancel();
    setState(() {
      _loadingIndex = true;
      _error = null;
      _indexReady = false;
      _currentPage = null;
      _totalPages = null;
    });
    try {
      final repository = ref.read(wgerRepositoryProvider);
      final items = await repository.loadTranslationIndex(
        onProgress: (current, total) {
          if (!mounted) {
            return;
          }
          setState(() {
            _currentPage = current;
            _totalPages = total;
          });
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _index = _coerceIndexItems(items);
        _indexReady = true;
      });
      _search(_controller.text);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingIndex = false;
        });
      }
    }
  }

  void _search(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!_indexReady) {
        return;
      }
      if (query.trim().isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          _results = [];
          _suggestions = [];
        });
        return;
      }
      final repository = ref.read(wgerRepositoryProvider);
      final output = repository.searchIndex(_index, query);
      if (!mounted) {
        return;
      }
      setState(() {
        _results = _coerceIndexItems(output.results);
        _suggestions = output.suggestions;
      });
    });
  }

  List<WgerTranslationIndexItem> _coerceIndexItems(
    Iterable<dynamic> rawItems,
  ) {
    final output = <WgerTranslationIndexItem>[];
    for (final item in rawItems) {
      if (item is WgerTranslationIndexItem) {
        output.add(item);
        continue;
      }
      if (item is Map) {
        try {
          output.add(
            WgerTranslationIndexItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          );
        } catch (_) {}
        continue;
      }
      try {
        final id = (item as dynamic).id as int;
        final name = (item as dynamic).name?.toString() ?? '';
        final exerciseId = (item as dynamic).exerciseId as int;
        output.add(
          WgerTranslationIndexItem(
            id: id,
            name: name,
            exerciseId: exerciseId,
          ),
        );
      } catch (_) {
        // Skip unknown item shape.
      }
    }
    return output;
  }
}
