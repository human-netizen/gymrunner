import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../media/gif_resolver.dart';

class ExerciseDemoScreen extends ConsumerWidget {
  const ExerciseDemoScreen({super.key, required this.exerciseId});

  final int exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exerciseAsync = ref.watch(exerciseProvider(exerciseId));

    return Scaffold(
      appBar: AppBar(
        title: exerciseAsync.maybeWhen(
          data: (exercise) => Text(exercise?.name ?? 'Exercise'),
          orElse: () => const Text('Exercise'),
        ),
      ),
      body: exerciseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
        data: (exercise) {
          if (exercise == null) {
            return const Center(child: Text('Exercise not found.'));
          }
          final fullPackIndex = ref.watch(mediaPackIndexProvider).asData?.value;
          return FutureBuilder<ResolvedGif?>(
            future: resolveGif(
              exerciseName: exercise.name,
              storedPath: exercise.gifAssetPath,
              fullPackIndex: fullPackIndex,
            ),
            builder: (context, snapshot) {
              final resolved = snapshot.data;
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    exercise.name,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (resolved != null)
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 180,
                          maxHeight: 180,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: resolved.isAsset
                              ? Image.asset(
                                  resolved.path,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                  filterQuality: FilterQuality.none,
                                )
                              : Image.file(
                                  File(resolved.path),
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                  filterQuality: FilterQuality.none,
                                ),
                        ),
                      ),
                    )
                  else ...[
                    const Text('No demo assigned.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          context.push('/library/assign/${exercise.id}'),
                      child: const Text('Assign GIF'),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}
