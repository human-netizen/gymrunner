import 'dart:math';

class WarmupSet {
  const WarmupSet({
    required this.weightKg,
    required this.reps,
  });

  final double weightKg;
  final int reps;
}

double roundToNearestStep(double value, {double step = 2.5}) {
  if (step <= 0) {
    return value;
  }
  final rounded = (value / step).round() * step;
  return double.parse(rounded.toStringAsFixed(2));
}

List<WarmupSet> generateWarmupSets({
  required double workingWeightKg,
  required double barWeightKg,
}) {
  final warmup50 = roundToNearestStep(workingWeightKg * 0.50);
  final warmup70 = roundToNearestStep(workingWeightKg * 0.70);
  final warmup85 = roundToNearestStep(workingWeightKg * 0.85);
  final minWeight = barWeightKg;

  return [
    WarmupSet(weightKg: minWeight, reps: 10),
    WarmupSet(weightKg: max(minWeight, warmup50), reps: 6),
    WarmupSet(weightKg: max(minWeight, warmup70), reps: 3),
    WarmupSet(weightKg: max(minWeight, warmup85), reps: 1),
  ];
}

double suggestNextWorkingWeightKg({
  required double lastWorkingWeightKg,
  required List<int> lastWorkingReps,
  required int repMin,
  required int repMax,
  required int setsTarget,
  required double incrementKg,
}) {
  final considered = lastWorkingReps.take(setsTarget).toList();
  if (considered.length < setsTarget) {
    return lastWorkingWeightKg;
  }
  final hitTop = considered.every((reps) => reps >= repMax);
  return hitTop ? lastWorkingWeightKg + incrementKg : lastWorkingWeightKg;
}
