import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../data/db/app_database.dart';
import '../services/wger_cache_manager.dart';
import '../services/wger_client.dart';

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
  Map<int, WgerLicense> _licenses = {};
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
            'Demo',
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
          child: const Text('Link demo (wger)'),
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
          _buildAttribution(
            licenseId: _selectedVideo?.licenseId,
            licenseAuthor: _selectedVideo?.licenseAuthor,
          ),
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
          _buildAttribution(
            licenseId: _selectedImage?.licenseId,
            licenseAuthor: _selectedImage?.licenseAuthor,
          ),
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

  Widget _buildAttribution({
    required int? licenseId,
    required String? licenseAuthor,
  }) {
    final license = licenseId == null ? null : _licenses[licenseId];
    final licenseText = license?.shortName.isNotEmpty == true
        ? license!.shortName
        : 'License';
    final authorText = (licenseAuthor == null || licenseAuthor.isEmpty)
        ? 'Unknown'
        : licenseAuthor;
    final licenseUrl = license?.url ?? '';

    return Row(
      children: [
        Expanded(
          child: Text(
            'Demo: wger | $licenseText | $authorText',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        TextButton(
          onPressed: licenseUrl.isEmpty
              ? null
              : () => _openLicenseUrl(licenseUrl),
          child: const Text('View license'),
        ),
      ],
    );
  }

  Future<void> _openLicenseUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _loadLink() async {
    final prefs = await SharedPreferences.getInstance();
    final linked = prefs.getInt(_linkKey(widget.exercise.id));
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

    final client = ref.read(wgerClientProvider);
    try {
      final videos = await client.getVideos(linkedId);
      final images = await client.getImages(linkedId);
      final licenses = await client.getLicenseMap();

      if (!mounted) {
        return;
      }

      _videos = videos;
      _images = _sortImages(images);
      _licenses = licenses;
      _imageIndex = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }

      final selectedVideo = _selectVideo(videos);
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
    final selected = await showModalBottomSheet<WgerTranslation>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _WgerLinkSheet(
        exerciseName: widget.exercise.name,
      ),
    );
    if (selected == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_linkKey(widget.exercise.id), selected.exerciseId);

    if (!mounted) {
      return;
    }

    setState(() {
      _linkedExerciseId = selected.exerciseId;
    });
    await _loadMedia();
  }

  Future<void> _removeLink() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_linkKey(widget.exercise.id));
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

  String _linkKey(int localExerciseId) =>
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
  List<WgerTranslation> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.exerciseName;
    _search(widget.exerciseName);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          if (_loading)
            const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!),
            ),
          if (!_loading && _results.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text('No results yet. Try another search.'),
            ),
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

  void _search(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final client = ref.read(wgerClientProvider);
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        final results = await client.searchTranslations(query);
        if (!mounted) {
          return;
        }
        setState(() {
          _results = results;
        });
      } catch (error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _error = 'Search failed. Check your connection.';
        });
      } finally {
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
      }
    });
  }
}
