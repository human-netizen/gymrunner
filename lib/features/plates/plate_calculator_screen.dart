import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

class PlateCalculatorScreen extends ConsumerStatefulWidget {
  const PlateCalculatorScreen({super.key, this.initialTarget});

  final double? initialTarget;

  @override
  ConsumerState<PlateCalculatorScreen> createState() =>
      _PlateCalculatorScreenState();
}

class _PlateCalculatorScreenState
    extends ConsumerState<PlateCalculatorScreen> {
  late final TextEditingController _targetController;
  double? _targetWeight;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTarget;
    _targetWeight = initial;
    _targetController = TextEditingController(
      text: initial == null || initial <= 0
          ? ''
          : initial.toStringAsFixed(1),
    );
    _targetController.addListener(() {
      setState(() {
        _targetWeight = double.tryParse(_targetController.text.trim());
      });
    });
  }

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Plate Calculator')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: settingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) =>
              const Center(child: Text('Failed to load settings.')),
          data: (settings) {
            if (settings == null) {
              return const Center(child: Text('Settings not found.'));
            }

            final barWeightKg = settings.barWeightKg;
            final plateSizes = _parsePlates(settings.plateInventoryCsv);
            final target = _targetWeight;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Target weight (kg)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _targetController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration:
                      const InputDecoration(hintText: 'e.g. 100'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => _adjustTarget(2.5),
                      child: const Text('+2.5'),
                    ),
                    OutlinedButton(
                      onPressed: () => _adjustTarget(5),
                      child: const Text('+5'),
                    ),
                    OutlinedButton(
                      onPressed: () => _adjustTarget(10),
                      child: const Text('+10'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Bar weight: ${barWeightKg.toStringAsFixed(1)} kg',
                ),
                const SizedBox(height: 12),
                if (target == null || target <= 0)
                  const Text('Enter a target weight to see plates.')
                else if (target < barWeightKg)
                  const Text('Target is below bar weight.')
                else ..._buildPlateResult(
                  target,
                  barWeightKg,
                  plateSizes,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _adjustTarget(double delta) {
    final current = double.tryParse(_targetController.text.trim()) ?? 0.0;
    final next = current + delta;
    _targetController.text = next.toStringAsFixed(1);
  }

  List<double> _parsePlates(String csv) {
    final values = <double>[];
    for (final part in csv.split(',')) {
      final parsed = double.tryParse(part.trim());
      if (parsed != null && parsed > 0) {
        values.add(parsed);
      }
    }
    values.sort((a, b) => b.compareTo(a));
    return values;
  }

  List<Widget> _buildPlateResult(
    double target,
    double barWeightKg,
    List<double> plateSizes,
  ) {
    final perSideTarget = (target - barWeightKg) / 2;
    final result = _calculatePlates(perSideTarget, plateSizes);

    final platesText = result.perSidePlates.isEmpty
        ? 'No plates needed'
        : result.perSidePlates.map(_formatPlate).join(' + ');
    final remainderText = result.remainder.abs() <= 0.001
        ? null
        : 'Not possible exactly; remainder ${result.remainder.abs().toStringAsFixed(2)} kg per side';

    return [
      Text('Per side target: ${perSideTarget.toStringAsFixed(2)} kg'),
      const SizedBox(height: 8),
      Text('Plates per side: $platesText'),
      const SizedBox(height: 4),
      Text(
        'Per side total: ${result.perSideTotal.toStringAsFixed(2)} kg',
      ),
      if (remainderText != null) ...[
        const SizedBox(height: 8),
        Text(remainderText),
      ],
    ];
  }

  _PlateCalcResult _calculatePlates(
    double perSideTarget,
    List<double> plateSizes,
  ) {
    var remaining = perSideTarget;
    final plates = <double>[];
    const tolerance = 0.001;

    for (final plate in plateSizes) {
      while (remaining + tolerance >= plate) {
        plates.add(plate);
        remaining -= plate;
      }
    }

    final perSideTotal = plates.fold<double>(0, (sum, p) => sum + p);
    return _PlateCalcResult(
      perSidePlates: plates,
      perSideTotal: perSideTotal,
      remainder: remaining,
    );
  }

  String _formatPlate(double value) {
    if (value % 1 == 0) {
      return value.toStringAsFixed(0);
    }
    return value.toString();
  }
}

class _PlateCalcResult {
  const _PlateCalcResult({
    required this.perSidePlates,
    required this.perSideTotal,
    required this.remainder,
  });

  final List<double> perSidePlates;
  final double perSideTotal;
  final double remainder;
}
