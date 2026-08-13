import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Thrown when neither a sidecar zip nor a bundled asset copy of the media
/// pack can be found. Carries the path the pack is expected at so the UI can
/// tell the user where to put it.
class MediaPackSourceMissingException implements Exception {
  MediaPackSourceMissingException(this.expectedPath);

  final String? expectedPath;

  @override
  String toString() {
    if (expectedPath == null) {
      return 'Media pack not found. Copy gifs_180.zip into the app storage '
          'directory and try again.';
    }
    return 'Media pack not found. Copy gifs_180.zip to $expectedPath and '
        'try again.';
  }
}

class MediaPackService {
  /// Optional bundled copy. The pack is normally shipped as a sidecar file
  /// rather than an asset, to keep it out of the APK.
  static const String _zipAssetPath = 'assets/media_pack/gifs_180.zip';
  static const String _zipFileName = 'gifs_180.zip';
  static const String _installMarker = '.installed';
  static const String _folderName = 'gifs_180';

  Directory? _cachedDir;
  List<String>? _cachedFiles;

  Future<Directory> _getTargetDir() async {
    if (_cachedDir != null) {
      return _cachedDir!;
    }
    final supportDir = await getApplicationSupportDirectory();
    final targetDir = Directory(p.join(supportDir.path, _folderName));
    _cachedDir = targetDir;
    return targetDir;
  }

  /// Directory the sidecar zip is read from. On Android this is the app's
  /// external files dir, which is readable without any runtime permission and
  /// reachable over adb.
  Future<Directory?> _getSidecarDir() async {
    try {
      return await getExternalStorageDirectory();
    } on UnsupportedError {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Where the user should place the pack, for display in error messages.
  Future<String?> sidecarZipPath() async {
    final dir = await _getSidecarDir();
    if (dir == null) {
      return null;
    }
    return p.join(dir.path, _zipFileName);
  }

  Future<bool> isInstalled() async {
    final dir = await _getTargetDir();
    final marker = File(p.join(dir.path, _installMarker));
    return marker.exists();
  }

  /// Reads the pack from the sidecar file if present, otherwise falls back to
  /// a bundled asset copy (only present in builds that still embed it).
  Future<Uint8List> _loadPackBytes() async {
    final sidecarPath = await sidecarZipPath();
    if (sidecarPath != null) {
      final sidecar = File(sidecarPath);
      if (await sidecar.exists()) {
        return sidecar.readAsBytes();
      }
    }

    try {
      final data = await rootBundle.load(_zipAssetPath);
      return data.buffer.asUint8List();
    } on FlutterError {
      throw MediaPackSourceMissingException(sidecarPath);
    }
  }

  Future<void> installPack({
    void Function(double progress)? onProgress,
  }) async {
    final dir = await _getTargetDir();
    await dir.create(recursive: true);

    // Older builds copied the zip here before extracting; drop any leftover
    // so it does not sit around costing ~115MB of device storage.
    final staleCopy = File(p.join(dir.path, _zipFileName));
    if (await staleCopy.exists()) {
      await staleCopy.delete();
    }

    final archive = ZipDecoder().decodeBytes(await _loadPackBytes());

    var total = archive.length;
    var done = 0;
    for (final file in archive) {
      final filename = file.name;
      if (filename.endsWith('/')) {
        continue;
      }
      final outFile = File(p.join(dir.path, filename));
      await outFile.create(recursive: true);
      await outFile.writeAsBytes(file.content as List<int>);
      done += 1;
      if (onProgress != null && total > 0) {
        onProgress(done / total);
      }
    }

    final marker = File(p.join(dir.path, _installMarker));
    await marker.writeAsString('installed');
    _cachedFiles = null;
  }

  Future<List<String>> listGifFiles() async {
    if (_cachedFiles != null) {
      return _cachedFiles!;
    }
    final dir = await _getTargetDir();
    if (!await isInstalled()) {
      return [];
    }
    final entries = await dir
        .list(recursive: true)
        .where((entity) => entity is File && entity.path.endsWith('.gif'))
        .map((entity) => entity.path)
        .toList();
    entries.sort();
    _cachedFiles = entries;
    return entries;
  }
}
