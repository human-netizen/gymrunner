import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/providers.dart';
import '../../media/gif_core_manifest.dart';
import '../../media/gif_resolver.dart';

class AssignGifPage extends ConsumerStatefulWidget {
  const AssignGifPage({super.key, required this.exerciseId});

  final int exerciseId;

  @override
  ConsumerState<AssignGifPage> createState() => _AssignGifPageState();
}

class _AssignGifPageState extends ConsumerState<AssignGifPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawQuery = _controller.text.trim();
    final query = rawQuery.toLowerCase();
    final normalizedQuery = normalizeName(rawQuery);
    final installed = ref.watch(mediaPackInstalledProvider).asData?.value;
    final mediaFiles = ref.watch(mediaPackFilesProvider).asData?.value ?? [];
    final filtered = coreGifs.where((item) {
      if (query.isEmpty) {
        return true;
      }
      return item.label.toLowerCase().contains(query);
    }).toList();

    final fullPackResults = <String>[];
    if (installed == true && normalizedQuery.length >= 2) {
      for (final path in mediaFiles) {
        final key = _normalizeFilename(path);
        if (key.contains(normalizedQuery)) {
          fullPackResults.add(path);
        }
      }
      fullPackResults.sort();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Assign demo')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Search GIFs',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Core pack'),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return ListTile(
                      title: Text(item.label),
                      onTap: () => _assignGif(item.assetPath),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    installed == true
                        ? 'Full pack (search to show)'
                        : 'Full pack (not installed)',
                  ),
                ),
                if (installed != true)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Install the media pack in Settings to search all GIFs.',
                    ),
                  )
                else if (normalizedQuery.length < 2)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Type at least 2 characters to search.'),
                  )
                else if (fullPackResults.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('No matches in full pack.'),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: fullPackResults.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final path = fullPackResults[index];
                      return ListTile(
                        title: Text(_labelFromPath(path)),
                        onTap: () => _assignGif(path),
                      );
                    },
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _assignGif(String path) async {
    await ref.read(exerciseRepositoryProvider).updateGifAssetPath(
          widget.exerciseId,
          path,
        );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Demo assigned')),
    );
    Navigator.of(context).pop();
  }

  String _labelFromPath(String path) {
    var base = p.basename(path).replaceAll('_180.gif', '');
    base = base.replaceFirst(RegExp(r'^\d+_'), '');
    return base.replaceAll('_', ' ');
  }

  String _normalizeFilename(String path) {
    final base = p.basename(path);
    return normalizeName(base.replaceAll('_180.gif', ''));
  }
}
