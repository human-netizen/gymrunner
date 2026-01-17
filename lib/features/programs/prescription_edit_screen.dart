import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/prescription_repository.dart';

class PrescriptionEditScreen extends ConsumerStatefulWidget {
  const PrescriptionEditScreen({
    super.key,
    required this.prescriptionId,
  });

  final int prescriptionId;

  @override
  ConsumerState<PrescriptionEditScreen> createState() =>
      _PrescriptionEditScreenState();
}

class _PrescriptionEditScreenState
    extends ConsumerState<PrescriptionEditScreen> {
  final TextEditingController _setsController = TextEditingController();
  final TextEditingController _repMinController = TextEditingController();
  final TextEditingController _repMaxController = TextEditingController();
  final TextEditingController _restController = TextEditingController();
  final TextEditingController _incrementController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _warmupEnabled = false;
  bool _initialized = false;

  @override
  void dispose() {
    _setsController.dispose();
    _repMinController.dispose();
    _repMaxController.dispose();
    _restController.dispose();
    _incrementController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prescriptionAsync =
        ref.watch(prescriptionProvider(widget.prescriptionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Prescription')),
      body: prescriptionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const Center(
          child: Text('Failed to load prescription.'),
        ),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Prescription not found.'));
          }

          _initializeFields(data);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Text(
                  data.exercise.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _setsController,
                        decoration: const InputDecoration(labelText: 'Sets'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _repMinController,
                        decoration: const InputDecoration(labelText: 'Rep min'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _repMaxController,
                        decoration: const InputDecoration(labelText: 'Rep max'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _restController,
                  decoration: const InputDecoration(
                    labelText: 'Rest seconds (blank = exercise default)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _incrementController,
                  decoration: const InputDecoration(
                    labelText: 'Increment kg (blank = exercise default)',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _warmupEnabled,
                  onChanged: (value) =>
                      setState(() => _warmupEnabled = value),
                  title: const Text('Warmup enabled'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => _save(context, data),
                  child: const Text('Save Changes'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _initializeFields(PrescriptionWithExercise data) {
    if (_initialized) {
      return;
    }

    _setsController.text = data.prescription.setsTarget.toString();
    _repMinController.text = data.prescription.repMin.toString();
    _repMaxController.text = data.prescription.repMax.toString();
    _restController.text = data.prescription.restSeconds?.toString() ?? '';
    _incrementController.text =
        data.prescription.incrementKg?.toString() ?? '';
    _notesController.text = data.prescription.notes ?? '';
    _warmupEnabled = data.prescription.warmupEnabled;
    _initialized = true;
  }

  Future<void> _save(
    BuildContext context,
    PrescriptionWithExercise data,
  ) async {
    final sets = int.tryParse(_setsController.text.trim());
    final repMin = int.tryParse(_repMinController.text.trim());
    final repMax = int.tryParse(_repMaxController.text.trim());

    if (sets == null || repMin == null || repMax == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter sets and reps.')),
      );
      return;
    }

    final restText = _restController.text.trim();
    final restSeconds = restText.isEmpty ? null : int.tryParse(restText);
    if (restText.isNotEmpty && restSeconds == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rest seconds must be a number.')),
      );
      return;
    }

    final incrementText = _incrementController.text.trim();
    final incrementKg =
        incrementText.isEmpty ? null : double.tryParse(incrementText);
    if (incrementText.isNotEmpty && incrementKg == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Increment must be a number.')),
      );
      return;
    }

    final notes = _notesController.text.trim();

    await ref.read(prescriptionRepositoryProvider).updatePrescription(
          id: data.prescription.id,
          setsTarget: sets,
          repMin: repMin,
          repMax: repMax,
          restSeconds: restSeconds,
          warmupEnabled: _warmupEnabled,
          incrementKg: incrementKg,
          notes: notes.isEmpty ? null : notes,
        );

    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pop();
  }
}
