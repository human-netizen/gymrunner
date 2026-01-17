import 'package:flutter_riverpod/flutter_riverpod.dart';

final gymModeProvider =
    NotifierProvider<GymModeNotifier, bool>(GymModeNotifier.new);

class GymModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }

  void set(bool value) {
    state = value;
  }
}
