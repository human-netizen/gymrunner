import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/rest_timer.dart';

class RestTimerBar extends ConsumerWidget {
  const RestTimerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(restTimerProvider);
    final notifier = ref.read(restTimerProvider.notifier);
    final minutes = (timerState.remainingSeconds ~/ 60)
        .toString()
        .padLeft(2, '0');
    final seconds = (timerState.remainingSeconds % 60)
        .toString()
        .padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rest: $minutes:$seconds',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: notifier.togglePause,
                child: Text(timerState.isRunning ? 'Pause' : 'Resume'),
              ),
              TextButton(
                onPressed: notifier.reset,
                child: const Text('Reset'),
              ),
              TextButton(
                onPressed: () => notifier.addSeconds(30),
                child: const Text('+30s'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
