import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

String normalizeName(String value) {
  final lower = value.toLowerCase();
  final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  final collapsed = replaced.replaceAll(RegExp(r'_+'), '_');
  return collapsed.replaceAll(RegExp(r'^_+|_+$'), '');
}

const Map<String, String> mentzerGifMap = {
  'dumbbell_flyes': 'assets/gifs_core/0308_dumbbell_fly_180.gif',
  'incline_presses': 'assets/gifs_core/0314_dumbbell_incline_bench_press_180.gif',
  'incline_press': 'assets/gifs_core/0314_dumbbell_incline_bench_press_180.gif',
  'incline_dumbbell_press':
      'assets/gifs_core/0314_dumbbell_incline_bench_press_180.gif',
  'straight_arm_pulldown':
      'assets/gifs_core/0238_cable_straight_arm_pulldown_180.gif',
  'straight_arm_pulldowns':
      'assets/gifs_core/0238_cable_straight_arm_pulldown_180.gif',
  'palms_up_pulldown':
      'assets/gifs_core/0245_cable_underhand_pulldown_180.gif',
  'palms_up_pulldowns':
      'assets/gifs_core/0245_cable_underhand_pulldown_180.gif',
  'underhand_pulldown':
      'assets/gifs_core/0245_cable_underhand_pulldown_180.gif',
  'deadlift': 'assets/gifs_core/0032_barbell_deadlift_180.gif',
  'leg_extensions': 'assets/gifs_core/0585_lever_leg_extension_180.gif',
  'leg_extension': 'assets/gifs_core/0585_lever_leg_extension_180.gif',
  'leg_presses': 'assets/gifs_core/0739_sled_45_leg_press_180.gif',
  'leg_press': 'assets/gifs_core/0739_sled_45_leg_press_180.gif',
  'standing_calf_raises':
      'assets/gifs_core/0605_lever_standing_calf_raise_180.gif',
  'standing_calf_raise':
      'assets/gifs_core/0605_lever_standing_calf_raise_180.gif',
  'sit_ups': 'assets/gifs_core/0001_3_4_sit-up_180.gif',
  'sit_ups_weighted': 'assets/gifs_core/0001_3_4_sit-up_180.gif',
  'dumbbell_lateral_raises':
      'assets/gifs_core/0334_dumbbell_lateral_raise_180.gif',
  'dumbbell_lateral_raise':
      'assets/gifs_core/0334_dumbbell_lateral_raise_180.gif',
  'bent_over_dumbbell_laterals':
      'assets/gifs_core/0378_dumbbell_rear_fly_180.gif',
  'rear_delt_fly': 'assets/gifs_core/0378_dumbbell_rear_fly_180.gif',
  'triceps_pressdowns':
      'assets/gifs_core/0241_cable_triceps_pushdown_v-bar_180.gif',
  'triceps_pressdown':
      'assets/gifs_core/0241_cable_triceps_pushdown_v-bar_180.gif',
  'triceps_pushdown':
      'assets/gifs_core/0241_cable_triceps_pushdown_v-bar_180.gif',
  'dips': 'assets/gifs_core/0814_triceps_dip_180.gif',
};

String? lookupMentzerGif(String exerciseName) {
  final key = normalizeName(exerciseName);
  return mentzerGifMap[key];
}

Future<bool> assetExists(String path) async {
  try {
    await rootBundle.load(path);
    return true;
  } catch (_) {
    return false;
  }
}

class ResolvedGif {
  const ResolvedGif({required this.path, required this.isAsset});

  final String path;
  final bool isAsset;
}

String _normalizeFilename(String filename) {
  var name = filename.toLowerCase();
  name = name.replaceAll('_180', '');
  name = name.replaceAll('.gif', '');
  name = name.replaceFirst(RegExp(r'^\d+_'), '');
  return normalizeName(name);
}

Map<String, String> buildFullPackIndex(List<String> filePaths) {
  final map = <String, String>{};
  for (final path in filePaths) {
    final filename = p.basename(path);
    final key = _normalizeFilename(filename);
    map.putIfAbsent(key, () => path);
  }
  return map;
}

Future<bool> fileExists(String path) async {
  return File(path).exists();
}

Future<ResolvedGif?> resolveGif({
  required String exerciseName,
  String? storedPath,
  Map<String, String>? fullPackIndex,
}) async {
  if (storedPath != null && storedPath.isNotEmpty) {
    if (storedPath.startsWith('assets/')) {
      if (await assetExists(storedPath)) {
        return ResolvedGif(path: storedPath, isAsset: true);
      }
    } else if (await fileExists(storedPath)) {
      return ResolvedGif(path: storedPath, isAsset: false);
    }
  }

  final mapped = lookupMentzerGif(exerciseName);
  if (mapped != null && await assetExists(mapped)) {
    return ResolvedGif(path: mapped, isAsset: true);
  }

  if (fullPackIndex != null) {
    final key = normalizeName(exerciseName);
    final match = fullPackIndex[key];
    if (match != null && await fileExists(match)) {
      return ResolvedGif(path: match, isAsset: false);
    }
  }

  return null;
}
