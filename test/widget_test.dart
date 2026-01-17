// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gym_runner/app/app.dart';
import 'package:gym_runner/data/db/app_database.dart';
import 'package:gym_runner/data/providers.dart';
import 'package:gym_runner/data/repositories/review_repository.dart';
import 'package:gym_runner/data/repositories/session_repository.dart';
import 'package:gym_runner/data/seed/seed_service.dart';

void main() {
  testWidgets('App starts on Today tab', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          seedServiceProvider.overrideWithValue(_FakeSeedService()),
          settingsStreamProvider.overrideWith(
            (ref) => Stream<Setting?>.value(null),
          ),
          programsStreamProvider.overrideWith(
            (ref) => Stream<List<Program>>.value(const []),
          ),
          activeSessionProvider.overrideWith(
            (ref) => Stream<Session?>.value(null),
          ),
          activeSessionBundleProvider.overrideWith(
            (ref) => Stream<ActiveSessionBundle?>.value(null),
          ),
          reviewSummaryProvider.overrideWith(
            (ref, range) => Stream<ReviewSummary>.value(
              const ReviewSummary(
                sessionsCompleted: 0,
                totalWorkingSets: 0,
                totalVolume: 0,
                totalDuration: Duration.zero,
                muscleSummary: [],
                exerciseHighlights: [],
              ),
            ),
          ),
        ],
        child: const GymRunnerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Programs'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}

class _FakeSeedService implements SeedService {
  @override
  Future<void> seedIfNeeded() async {}
}
