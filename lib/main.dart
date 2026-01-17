// Run:
// flutter pub get
// dart run build_runner build --delete-conflicting-outputs
// flutter run

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  runApp(const ProviderScope(child: GymRunnerApp()));
}
