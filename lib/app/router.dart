import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/history/history_screen.dart';
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
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
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
