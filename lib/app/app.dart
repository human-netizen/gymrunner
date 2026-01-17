import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';
import '../data/seed/seed_service.dart';

class GymRunnerApp extends ConsumerStatefulWidget {
  const GymRunnerApp({super.key});

  @override
  ConsumerState<GymRunnerApp> createState() => _GymRunnerAppState();
}

class _GymRunnerAppState extends ConsumerState<GymRunnerApp> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref.read(seedServiceProvider).seedIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Gym Runner',
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
    );
  }
}
