import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _plateController = TextEditingController();
  bool _plateInitialized = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref.read(settingsRepositoryProvider).ensureSingleRow();
    });
  }

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final settingsAsync = ref.watch(settingsStreamProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: settingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => const Center(
            child: Text('Failed to load settings.'),
          ),
          data: (settings) {
            _maybeInitPlates(settings);
            final barWeightKg = settings?.barWeightKg;
            final plateCsv = settings?.plateInventoryCsv;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Placeholder for settings controls.'),
                const SizedBox(height: 24),
                const Text('DB Status: OK'),
                const SizedBox(height: 8),
                Text(
                  barWeightKg == null
                      ? 'Bar Weight: --'
                      : 'Bar Weight: ${barWeightKg.toStringAsFixed(1)} kg',
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.tonal(
                      onPressed: settings == null
                          ? null
                          : () => _updateBarWeight(settings.barWeightKg - 2.5),
                      child: const Text('- 2.5 kg'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonal(
                      onPressed: settings == null
                          ? null
                          : () => _updateBarWeight(settings.barWeightKg + 2.5),
                      child: const Text('+ 2.5 kg'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Plates',
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  plateCsv == null
                      ? 'Current: --'
                      : 'Current: $plateCsv',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _plateController,
                  decoration: const InputDecoration(
                    labelText: 'Plate inventory (kg per side)',
                    hintText: '20,15,10,5,2.5,1.25',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: settings == null ? null : _savePlateInventory,
                  child: const Text('Save Plates'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _updateBarWeight(double value) async {
    await ref.read(settingsRepositoryProvider).updateBarWeightKg(value);
  }

  void _maybeInitPlates(Setting? settings) {
    if (_plateInitialized || settings == null) {
      return;
    }
    _plateController.text = settings.plateInventoryCsv;
    _plateInitialized = true;
  }

  Future<void> _savePlateInventory() async {
    final raw = _plateController.text.trim();
    final values = <double>[];
    for (final part in raw.split(',')) {
      final parsed = double.tryParse(part.trim());
      if (parsed != null && parsed > 0) {
        values.add(parsed);
      }
    }

    if (values.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid plate sizes.')),
      );
      return;
    }

    values.sort((a, b) => b.compareTo(a));
    final normalized = values.map(_formatPlate).join(',');

    await ref
        .read(settingsRepositoryProvider)
        .updatePlateInventoryCsv(normalized);

    if (!mounted) {
      return;
    }
    _plateController.text = normalized;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Plates saved.')),
    );
  }

  String _formatPlate(double value) {
    if (value % 1 == 0) {
      return value.toStringAsFixed(0);
    }
    return value.toString();
  }
}
