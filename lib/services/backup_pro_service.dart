import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/providers.dart';
import '../data/repositories/settings_repository.dart';
import 'backup_service.dart';

const int backupRetentionCount = 14;

final backupProServiceProvider = Provider<BackupProService>((ref) {
  final backupService = ref.read(backupServiceProvider);
  final settingsRepository = ref.read(settingsRepositoryProvider);
  return BackupProService(
    backupService: backupService,
    settingsRepository: settingsRepository,
  );
});

final localBackupsProvider = FutureProvider<List<LocalBackupInfo>>((ref) {
  final service = ref.watch(backupProServiceProvider);
  return service.listLocalBackups();
});

class BackupProService {
  BackupProService({
    required this.backupService,
    required this.settingsRepository,
  });

  final BackupService backupService;
  final SettingsRepository settingsRepository;
  String? _cachedPassphrase;

  Future<File> createBackup({
    required bool encrypted,
    String? passphrase,
    String? note,
    required String trigger,
  }) async {
    final backupMap = await backupService.buildBackupMap();
    backupMap['meta'] = {
      'trigger': trigger,
      if (note != null) 'note': note,
    };

    final jsonString = jsonEncode(backupMap);
    final trimmedPassphrase = passphrase?.trim() ?? '';
    final useEncryption = encrypted && trimmedPassphrase.isNotEmpty;

    final directory = await _backupDirectory();
    final timestamp = _timestamp();
    final file = useEncryption
        ? File(p.join(directory.path, 'gym_runner_backup_$timestamp.grbk'))
        : File(p.join(directory.path, 'gym_runner_backup_$timestamp.json'));

    if (useEncryption) {
      final wrapper = await _encryptPayload(
        jsonString,
        trimmedPassphrase,
        trigger: trigger,
        note: note,
      );
      await file.writeAsString(jsonEncode(wrapper));
    } else {
      await file.writeAsString(jsonString);
    }

    await _enforceRetention();
    return file;
  }

  Future<void> restoreBackupFromFile(
    File file, {
    String? passphraseIfNeeded,
  }) async {
    final content = await file.readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup file.');
    }

    final isEncrypted = _isEncryptedFile(file.path, decoded);
    if (isEncrypted) {
      final passphrase = passphraseIfNeeded?.trim() ?? '';
      if (passphrase.isEmpty) {
        throw StateError('Passphrase required.');
      }
      final payload = await _decryptPayload(decoded, passphrase);
      await backupService.importBackupMap(payload);
      return;
    }

    await backupService.importBackupMap(decoded);
  }

  Future<List<LocalBackupInfo>> listLocalBackups() async {
    final directory = await _backupDirectory();
    if (!await directory.exists()) {
      return [];
    }

    final entries = await directory.list().where((entry) {
      if (entry is! File) {
        return false;
      }
      final name = p.basename(entry.path);
      return name.startsWith('gym_runner_backup_') &&
          (name.endsWith('.json') || name.endsWith('.grbk'));
    }).cast<File>().toList();

    final results = <LocalBackupInfo>[];

    for (final file in entries) {
      final stat = await file.stat();
      final name = p.basename(file.path);
      final ext = p.extension(name).toLowerCase();
      bool encrypted = ext == '.grbk';
      String? trigger;
      String? note;

      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) {
          final encryptedFlag = decoded['encrypted'] == true;
          encrypted = encrypted || encryptedFlag;
          if (decoded['meta'] is Map<String, dynamic>) {
            final meta = decoded['meta'] as Map<String, dynamic>;
            trigger = meta['trigger']?.toString();
            note = meta['note']?.toString();
          }
          if (decoded['trigger'] != null) {
            trigger = decoded['trigger']?.toString();
          }
          if (decoded['note'] != null) {
            note = decoded['note']?.toString();
          }
        }
      } catch (_) {
        // Ignore parsing issues; still show file.
      }

      results.add(
        LocalBackupInfo(
          file: file,
          fileName: name,
          modifiedAt: stat.modified,
          sizeBytes: stat.size,
          encrypted: encrypted,
          trigger: trigger,
          note: note,
        ),
      );
    }

    results.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return results;
  }

  Future<void> deleteBackup(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<File?> getLatestBackup() async {
    final backups = await listLocalBackups();
    if (backups.isEmpty) {
      return null;
    }
    return backups.first.file;
  }

  Future<void> runAutoBackupIfNeeded() async {
    final settings = await settingsRepository.ensureSingleRow();
    if (!settings.backupAutoEnabled) {
      return;
    }

    final now = DateTime.now();
    final last = settings.lastAutoBackupAt;
    if (last != null && now.difference(last) < const Duration(hours: 24)) {
      return;
    }

    final encrypted = settings.backupEncryptionEnabled;
    String? passphrase;
    if (encrypted) {
      passphrase = await _readPassphrase();
      if (passphrase == null || passphrase.isEmpty) {
        if (kDebugMode) {
          debugPrint('Auto-backup skipped: missing passphrase.');
        }
        return;
      }
    }

    await createBackup(
      encrypted: encrypted,
      passphrase: passphrase,
      trigger: 'auto',
    );
    await settingsRepository.updateLastAutoBackupAt(now);
  }

  Future<void> setAutoBackupEnabled(bool enabled) {
    return settingsRepository.updateBackupAutoEnabled(enabled);
  }

  Future<void> setEncryptionEnabled(
    bool enabled, {
    String? passphrase,
  }) async {
    await settingsRepository.updateBackupEncryptionEnabled(enabled);
    if (!enabled) {
      await _clearPassphrase();
      return;
    }
    if (passphrase != null && passphrase.trim().isNotEmpty) {
      await _storePassphrase(passphrase.trim());
    }
  }

  Future<String?> readStoredPassphrase() {
    return _readPassphrase();
  }

  Future<void> clearStoredPassphrase() {
    return _clearPassphrase();
  }

  Future<Directory> _backupDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(docs.path, 'backups'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<void> _enforceRetention() async {
    final backups = await listLocalBackups();
    if (backups.length <= backupRetentionCount) {
      return;
    }
    final toDelete = backups.sublist(backupRetentionCount);
    for (final backup in toDelete) {
      await deleteBackup(backup.file);
    }
  }

  Future<Map<String, dynamic>> _encryptPayload(
    String payload,
    String passphrase, {
    required String trigger,
    String? note,
  }) async {
    final algorithm = AesGcm.with256bits();
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final key = await _deriveKey(passphrase, salt);
    final secretBox = await algorithm.encrypt(
      utf8.encode(payload),
      secretKey: key,
      nonce: nonce,
    );

    return {
      'format': 'gym_runner_backup',
      'version': 1,
      'encrypted': true,
      'kdf': 'pbkdf2_sha256',
      'iterations': _kdfIterations,
      'salt_b64': base64Encode(salt),
      'nonce_b64': base64Encode(secretBox.nonce),
      'ciphertext_b64': base64Encode(secretBox.cipherText),
      'mac_b64': base64Encode(secretBox.mac.bytes),
      'createdAt': DateTime.now().toIso8601String(),
      'trigger': trigger,
      if (note != null) 'note': note,
    };
  }

  Future<Map<String, dynamic>> _decryptPayload(
    Map<String, dynamic> wrapper,
    String passphrase,
  ) async {
    final salt = base64Decode(wrapper['salt_b64']?.toString() ?? '');
    final nonce = base64Decode(wrapper['nonce_b64']?.toString() ?? '');
    final ciphertext = base64Decode(wrapper['ciphertext_b64']?.toString() ?? '');
    final macBytes = base64Decode(wrapper['mac_b64']?.toString() ?? '');
    final iterations =
        int.tryParse(wrapper['iterations']?.toString() ?? '') ??
            _kdfIterations;

    final key = await _deriveKey(passphrase, salt, iterations: iterations);
    final algorithm = AesGcm.with256bits();
    final secretBox = SecretBox(
      ciphertext,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    try {
      final clearBytes = await algorithm.decrypt(
        secretBox,
        secretKey: key,
      );
      final decoded = jsonDecode(utf8.decode(clearBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid backup payload.');
      }
      return decoded;
    } catch (_) {
      throw StateError('Wrong passphrase.');
    }
  }

  Future<SecretKey> _deriveKey(
    String passphrase,
    List<int> salt, {
    int iterations = _kdfIterations,
  }) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
  }

  Future<void> _storePassphrase(String passphrase) {
    _cachedPassphrase = passphrase;
    return Future.value();
  }

  Future<String?> _readPassphrase() {
    return Future.value(_cachedPassphrase);
  }

  Future<void> _clearPassphrase() {
    _cachedPassphrase = null;
    return Future.value();
  }

  bool _isEncryptedFile(String path, Map<String, dynamic> decoded) {
    if (p.extension(path).toLowerCase() == '.grbk') {
      return true;
    }
    return decoded['encrypted'] == true;
  }

  List<int> _randomBytes(int length) {
    final rand = Random.secure();
    return List<int>.generate(length, (_) => rand.nextInt(256));
  }

  String _timestamp() {
    final now = DateTime.now();
    return '${now.year}${_two(now.month)}${_two(now.day)}_'
        '${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}

class LocalBackupInfo {
  const LocalBackupInfo({
    required this.file,
    required this.fileName,
    required this.modifiedAt,
    required this.sizeBytes,
    required this.encrypted,
    required this.trigger,
    required this.note,
  });

  final File file;
  final String fileName;
  final DateTime modifiedAt;
  final int sizeBytes;
  final bool encrypted;
  final String? trigger;
  final String? note;
}

const int _kdfIterations = 150000;
