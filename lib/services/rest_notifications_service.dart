import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;


const int restNotificationId = 7001;

final restNotificationsServiceProvider =
    Provider<RestNotificationsService>((ref) {
  return RestNotificationsService();
});

final restNotificationSettingsProvider = AsyncNotifierProvider<
    RestNotificationSettingsNotifier,
    RestNotificationSettings>(
  RestNotificationSettingsNotifier.new,
);

class RestNotificationsService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _tzInitialized = false;
  void Function(String? payload)? _onTap;

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    if (!_tzInitialized) {
      tzdata.initializeTimeZones();
      _tzInitialized = true;
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      defaultPresentAlert: false,
      defaultPresentBadge: false,
      defaultPresentSound: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    _initialized = true;
  }

  Future<bool> requestPermissionIfNeeded() async {
    await init();

    if (Platform.isAndroid) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidImpl?.requestNotificationsPermission();
      return granted ?? true;
    }

    if (Platform.isIOS) {
      final iosImpl = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted =
          await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? true;
    }

    return true;
  }

  Future<void> scheduleRestEnd({
    required Duration duration,
    required String title,
    required String body,
    String? payloadJson,
    bool playSound = true,
  }) async {
    if (duration.inSeconds <= 0) {
      return;
    }

    await init();
    await cancelRestEnd();

    final scheduledDate = tz.TZDateTime.now(tz.local).add(duration);

    final androidDetails = AndroidNotificationDetails(
      'rest_timer',
      'Rest Timer',
      channelDescription: 'Rest timer alerts',
      importance: Importance.high,
      priority: Priority.high,
      playSound: playSound,
    );
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: playSound,
    );
    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    try {
      await _plugin.zonedSchedule(
        restNotificationId,
        title,
        body,
        scheduledDate,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payloadJson,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Exact schedule failed: $error');
      }
      await _plugin.zonedSchedule(
        restNotificationId,
        title,
        body,
        scheduledDate,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payloadJson,
      );
    }
  }

  Future<void> cancelRestEnd() async {
    await init();
    await _plugin.cancel(restNotificationId);
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  void setOnNotificationTap(void Function(String? payload) handler) {
    _onTap = handler;
  }

  void _onNotificationResponse(NotificationResponse response) {
    _onTap?.call(response.payload);
  }
}

class RestNotificationSettings {
  const RestNotificationSettings({
    required this.enabled,
    required this.soundEnabled,
  });

  final bool enabled;
  final bool soundEnabled;

  RestNotificationSettings copyWith({
    bool? enabled,
    bool? soundEnabled,
  }) {
    return RestNotificationSettings(
      enabled: enabled ?? this.enabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
    );
  }
}

class RestNotificationSettingsNotifier
    extends AsyncNotifier<RestNotificationSettings> {
  static const String _enabledKey = 'rest_notifications_enabled';
  static const String _soundKey = 'rest_notifications_sound';

  @override
  Future<RestNotificationSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey) ?? false;
    final soundEnabled = prefs.getBool(_soundKey) ?? true;
    return RestNotificationSettings(
      enabled: enabled,
      soundEnabled: soundEnabled,
    );
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    final current = state.value ??
        const RestNotificationSettings(enabled: false, soundEnabled: true);
    state = AsyncData(current.copyWith(enabled: value));
  }

  Future<void> setSoundEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundKey, value);
    final current = state.value ??
        const RestNotificationSettings(enabled: false, soundEnabled: true);
    state = AsyncData(current.copyWith(soundEnabled: value));
  }
}
