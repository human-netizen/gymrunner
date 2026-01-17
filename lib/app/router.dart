import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/providers.dart';
import '../services/rest_notifications_service.dart';
import '../state/rest_timer.dart';
import '../features/history/history_screen.dart';
import '../features/history/exercise_detail_screen.dart';
import '../features/history/session_detail_screen.dart';
import '../features/plates/plate_calculator_screen.dart';
import '../features/programs/programs_screen.dart';
import '../features/programs/program_detail_screen.dart';
import '../features/programs/day_detail_screen.dart';
import '../features/programs/exercise_library_screen.dart';
import '../features/programs/exercise_picker_screen.dart';
import '../features/programs/prescription_edit_screen.dart';
import '../features/review/review_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/backup_manager_screen.dart';
import '../features/today/today_screen.dart';
import '../features/today/exercise_runner_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/today',
    routes: [
      GoRoute(
        path: '/plates',
        builder: (context, state) => PlateCalculatorScreen(
          initialTarget: _doubleQueryParam(state, 'target'),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/today',
                builder: (context, state) => const TodayScreen(),
                routes: [
                  GoRoute(
                    path: 'runner/:sessionExerciseId',
                    builder: (context, state) => ExerciseRunnerScreen(
                      sessionExerciseId:
                          _intParam(state, 'sessionExerciseId'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/programs',
                builder: (context, state) => const ProgramsScreen(),
                routes: [
                  GoRoute(
                    path: 'exercises',
                    builder: (context, state) =>
                        const ExerciseLibraryScreen(),
                  ),
                  GoRoute(
                    path: ':programId',
                    builder: (context, state) => ProgramDetailScreen(
                      programId: _intParam(state, 'programId'),
                    ),
                    routes: [
                      GoRoute(
                        path: 'day/:dayId',
                        builder: (context, state) => DayDetailScreen(
                          programId: _intParam(state, 'programId'),
                          dayId: _intParam(state, 'dayId'),
                        ),
                        routes: [
                          GoRoute(
                            path: 'pick',
                            builder: (context, state) => ExercisePickerScreen(
                              dayId: _intParam(state, 'dayId'),
                            ),
                          ),
                          GoRoute(
                            path: 'prescription/:prescriptionId',
                            builder: (context, state) =>
                                PrescriptionEditScreen(
                              prescriptionId:
                                  _intParam(state, 'prescriptionId'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                builder: (context, state) => const HistoryScreen(),
                routes: [
                  GoRoute(
                    path: 'exercise/:exerciseId',
                    builder: (context, state) => ExerciseDetailScreen(
                      exerciseId: _intParam(state, 'exerciseId'),
                    ),
                  ),
                  GoRoute(
                    path: ':sessionId',
                    builder: (context, state) => SessionDetailScreen(
                      sessionId: _intParam(state, 'sessionId'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/review',
                builder: (context, state) => const ReviewScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'backups',
                    builder: (context, state) => const BackupManagerScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  bool _wakelockEnabled = false;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  RestTimerState? _latestTimerState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref
        .read(restNotificationsServiceProvider)
        .setOnNotificationTap(_handleNotificationTap);
    ref.listen<RestTimerState>(restTimerProvider, (previous, next) {
      _latestTimerState = next;
      _handleRestTimerChange(next);
    });
    ref.listen<AsyncValue<RestNotificationSettings>>(
      restNotificationSettingsProvider,
      (previous, next) {
        if (next.asData?.value.enabled != true) {
          _cancelRestNotification();
          return;
        }
        if (_lifecycleState != AppLifecycleState.resumed &&
            _latestTimerState != null) {
          _scheduleRestNotification(_latestTimerState!);
        }
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setWakelock(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      _cancelRestNotification();
      return;
    }
    if (_latestTimerState != null) {
      _scheduleRestNotification(_latestTimerState!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(activeSessionProvider);
    final hasActiveSession = sessionAsync.asData?.value != null;
    final shouldEnable =
        widget.navigationShell.currentIndex == 0 && hasActiveSession;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setWakelock(shouldEnable);
    });

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: (index) {
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_list_outlined),
            selectedIcon: Icon(Icons.view_list),
            label: 'Programs',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Review',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  void _setWakelock(bool enable) {
    if (_wakelockEnabled == enable) {
      return;
    }
    _wakelockEnabled = enable;
    try {
      if (enable) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }
    } catch (_) {
      // Ignore wakelock failures to keep the app usable.
    }
  }

  void _handleNotificationTap(String? payload) {
    if (payload != null && payload.isNotEmpty) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) {
          final route = decoded['go']?.toString();
          if (route != null && route.isNotEmpty) {
            AppRouter.router.go(route);
            return;
          }
        }
      } catch (_) {}
    }
    AppRouter.router.go('/today');
  }

  void _handleRestTimerChange(RestTimerState state) {
    if (state.remainingSeconds <= 0 || !state.isRunning) {
      _cancelRestNotification();
      return;
    }
    if (_lifecycleState == AppLifecycleState.resumed) {
      _cancelRestNotification();
      return;
    }
    _scheduleRestNotification(state);
  }

  void _scheduleRestNotification(RestTimerState state) {
    final settings = ref.read(restNotificationSettingsProvider).asData?.value;
    if (settings == null || !settings.enabled) {
      return;
    }
    final service = ref.read(restNotificationsServiceProvider);
    unawaited(_scheduleWithPermission(service, settings, state));
  }

  Future<void> _scheduleWithPermission(
    RestNotificationsService service,
    RestNotificationSettings settings,
    RestTimerState state,
  ) async {
    if (state.remainingSeconds <= 0) {
      return;
    }
    final granted = await service.requestPermissionIfNeeded();
    if (!granted) {
      return;
    }
    await service.scheduleRestEnd(
      duration: Duration(seconds: state.remainingSeconds),
      title: 'Rest finished',
      body: 'Next set ready',
      payloadJson: '{"go":"/today"}',
      playSound: settings.soundEnabled,
    );
  }

  void _cancelRestNotification() {
    final service = ref.read(restNotificationsServiceProvider);
    unawaited(service.cancelRestEnd());
  }
}

int _intParam(GoRouterState state, String key) {
  final value = state.pathParameters[key];
  return value == null ? 0 : int.parse(value);
}

double? _doubleQueryParam(GoRouterState state, String key) {
  final value = state.uri.queryParameters[key];
  if (value == null) {
    return null;
  }
  return double.tryParse(value);
}
