// lib/services/notification_service.dart
// Handles: schedule event reminders + solicitation deadline alerts

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import '../models/schedule_event.dart';
import '../models/solicitation.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // ─── INITIALIZATION ─────────────────────────────────────────────────────────

  static Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    // Set Philippine timezone (Asia/Manila)
    tz.setLocalLocation(tz.getLocation('Asia/Manila'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Notification tapped: ${details.payload}');
      },
    );

    // Request all necessary permissions
    await requestPermissions();

    _initialized = true;
  }

  /// Request all notification-related permissions
  static Future<void> requestPermissions() async {
    // Request notification permission (Android 13+)
    final notifPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    if (notifPlugin != null) {
      await notifPlugin.requestNotificationsPermission();
      await notifPlugin.requestExactAlarmsPermission();
    }

    // Also request via permission_handler for broader coverage
    final notifStatus = await Permission.notification.status;
    if (!notifStatus.isGranted) {
      await Permission.notification.request();
    }

    // Request exact alarm permission for Android 12+
    final alarmStatus = await Permission.scheduleExactAlarm.status;
    if (!alarmStatus.isGranted) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  // ─── CREATE NOTIFICATION CHANNELS ──────────────────────────────────────────

  static Future<void> _ensureChannelsCreated() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'schedule_reminder',
          'Schedule Reminders',
          description: 'Reminders for upcoming schedule events',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'solicitation_warning',
          'Solicitation Warnings',
          description: 'Warnings for upcoming solicitation deadlines',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'solicitation_urgent',
          'Urgent Solicitation Alerts',
          description: 'Urgent alerts for imminent solicitation deadlines',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
    }
  }

  // ─── SCHEDULE EVENT NOTIFICATIONS ──────────────────────────────────────────

  /// Schedule a reminder notification for an event.
  /// Fires: 1 DAY before + 1 HOUR before + AT event time.
  static Future<void> scheduleEventNotification(ScheduleEvent event) async {
    await _ensureChannelsCreated();
    
    final eventDateTime = _parseEventDateTime(event.date, event.time);
    if (eventDateTime == null) {
      debugPrint('Could not parse event date/time: ${event.date} ${event.time}');
      return;
    }

    final now = DateTime.now();

    // ── 1 DAY BEFORE ──
    final oneDayBefore = eventDateTime.subtract(const Duration(days: 1));
    if (oneDayBefore.isAfter(now)) {
      await _scheduleNotification(
        id: _eventNotifId(event.id, 'day'),
        title: '📅 Event Tomorrow!',
        body: '${event.theme} — ${event.time} at ${event.location}',
        scheduledDate: tz.TZDateTime.from(oneDayBefore, tz.local),
        payload: 'schedule:${event.id}',
        channelId: 'schedule_reminder',
        channelName: 'Schedule Reminders',
        importance: Importance.high,
        priority: Priority.high,
      );
      debugPrint('Scheduled day-before notification for ${event.theme}');
    }

    // ── 1 HOUR BEFORE ──
    final oneHourBefore = eventDateTime.subtract(const Duration(hours: 1));
    if (oneHourBefore.isAfter(now)) {
      await _scheduleNotification(
        id: _eventNotifId(event.id, 'hour'),
        title: '⏰ Event in 1 Hour!',
        body: '${event.theme} — ${event.time} at ${event.location}',
        scheduledDate: tz.TZDateTime.from(oneHourBefore, tz.local),
        payload: 'schedule:${event.id}',
        channelId: 'schedule_reminder',
        channelName: 'Schedule Reminders',
        importance: Importance.max,
        priority: Priority.max,
      );
      debugPrint('Scheduled hour-before notification for ${event.theme}');
    }

    // ── AT EVENT TIME ──
    if (eventDateTime.isAfter(now)) {
      await _scheduleNotification(
        id: _eventNotifId(event.id, 'event'),
        title: '🔔 Event Starting Now!',
        body: '${event.theme} at ${event.location}',
        scheduledDate: tz.TZDateTime.from(eventDateTime, tz.local),
        payload: 'schedule:${event.id}',
        channelId: 'schedule_reminder',
        channelName: 'Schedule Reminders',
        importance: Importance.max,
        priority: Priority.max,
      );
      debugPrint('Scheduled at-time notification for ${event.theme}');
    }
  }

  static Future<void> cancelEventNotification(String eventId) async {
    await _plugin.cancel(_eventNotifId(eventId, 'day'));
    await _plugin.cancel(_eventNotifId(eventId, 'hour'));
    await _plugin.cancel(_eventNotifId(eventId, 'event'));
  }

  static Future<void> cancelAllEventNotifications() async {
    for (int i = 10000; i < 20000; i++) {
      await _plugin.cancel(i);
    }
  }

  // ─── SOLICITATION DEADLINE NOTIFICATIONS ───────────────────────────────────

  static Future<void> scheduleSolicitationNotification(Solicitation sol) async {
    await _ensureChannelsCreated();
    
    final targetDate = _parseSolicitationDate(sol.targetDate);
    if (targetDate == null) return;

    final now = DateTime.now();

    // ── 3 DAYS BEFORE — Warning ──
    final threeDaysBefore = targetDate.subtract(const Duration(days: 3));
    if (threeDaysBefore.isAfter(now)) {
      await _scheduleNotification(
        id: _solNotifId(sol.id, '3day'),
        title: '⚠️ Solicitation Due in 3 Days',
        body: '${sol.organizationOrPerson} — ${sol.purpose}',
        scheduledDate: tz.TZDateTime.from(
          DateTime(threeDaysBefore.year, threeDaysBefore.month,
              threeDaysBefore.day, 9, 0),
          tz.local,
        ),
        payload: 'solicitation:${sol.id}',
        channelId: 'solicitation_warning',
        channelName: 'Solicitation Warnings',
        importance: Importance.high,
        priority: Priority.high,
      );
    }

    // ── 2 DAYS BEFORE — Urgent ──
    final twoDaysBefore = targetDate.subtract(const Duration(days: 2));
    if (twoDaysBefore.isAfter(now)) {
      await _scheduleNotification(
        id: _solNotifId(sol.id, '2day'),
        title: '🔔 Solicitation Due in 2 Days!',
        body: '${sol.organizationOrPerson} — ${sol.purpose}',
        scheduledDate: tz.TZDateTime.from(
          DateTime(twoDaysBefore.year, twoDaysBefore.month,
              twoDaysBefore.day, 9, 0),
          tz.local,
        ),
        payload: 'solicitation:${sol.id}',
        channelId: 'solicitation_warning',
        channelName: 'Solicitation Warnings',
        importance: Importance.high,
        priority: Priority.high,
      );
    }

    // ── 1 DAY BEFORE — ALARM ──
    final oneDayBefore = targetDate.subtract(const Duration(days: 1));
    if (oneDayBefore.isAfter(now)) {
      await _scheduleNotification(
        id: _solNotifId(sol.id, '1day'),
        title: '🚨 URGENT: Solicitation Due TOMORROW!',
        body: '${sol.organizationOrPerson} — Act now! ${sol.purpose}',
        scheduledDate: tz.TZDateTime.from(
          DateTime(oneDayBefore.year, oneDayBefore.month,
              oneDayBefore.day, 8, 0),
          tz.local,
        ),
        payload: 'solicitation:${sol.id}',
        channelId: 'solicitation_urgent',
        channelName: 'Urgent Solicitation Alerts',
        importance: Importance.max,
        priority: Priority.max,
      );
    }

    // ── ON THE DAY ITSELF ──
    final onDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 8, 0);
    if (onDay.isAfter(now)) {
      await _scheduleNotification(
        id: _solNotifId(sol.id, 'today'),
        title: '🚨 SOLICITATION DUE TODAY!',
        body: '${sol.organizationOrPerson} — ${sol.purpose}. Handle immediately!',
        scheduledDate: tz.TZDateTime.from(onDay, tz.local),
        payload: 'solicitation:${sol.id}',
        channelId: 'solicitation_urgent',
        channelName: 'Urgent Solicitation Alerts',
        importance: Importance.max,
        priority: Priority.max,
      );
    }
  }

  static Future<void> cancelSolicitationNotification(String solId) async {
    await _plugin.cancel(_solNotifId(solId, '3day'));
    await _plugin.cancel(_solNotifId(solId, '2day'));
    await _plugin.cancel(_solNotifId(solId, '1day'));
    await _plugin.cancel(_solNotifId(solId, 'today'));
  }

  // ─── PRIVATE HELPERS ────────────────────────────────────────────────────────

  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required String payload,
    required String channelId,
    required String channelName,
    required Importance importance,
    required Priority priority,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            importance: importance,
            priority: priority,
            playSound: true,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
            styleInformation: BigTextStyleInformation(body),
            icon: '@mipmap/ic_launcher',
            color: const Color(0xFF1B5E20),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('✅ Notification scheduled: $title at $scheduledDate (id: $id)');
    } catch (e) {
      debugPrint('❌ Failed to schedule notification: $e');
    }
  }

  // Unique stable int IDs from string IDs
  static int _eventNotifId(String eventId, String suffix) {
    final hash = (eventId + suffix).hashCode.abs() % 9000 + 10000;
    return hash;
  }

  static int _solNotifId(String solId, String suffix) {
    final hash = (solId + suffix).hashCode.abs() % 9000 + 20000;
    return hash;
  }

  /// Parse "MM/DD/YYYY" + "HH:MM AM/PM" into DateTime
  static DateTime? _parseEventDateTime(String date, String time) {
    try {
      final dateParts = date.split('/');
      if (dateParts.length != 3) return null;
      final month = int.parse(dateParts[0]);
      final day = int.parse(dateParts[1]);
      final year = int.parse(dateParts[2]);

      int hour = 0, minute = 0;
      final timeTrimmed = time.trim().toUpperCase();
      final isPM = timeTrimmed.contains('PM');
      final isAM = timeTrimmed.contains('AM');
      final timePart = timeTrimmed
          .replaceAll('AM', '')
          .replaceAll('PM', '')
          .trim();
      final timeParts = timePart.split(':');
      hour = int.parse(timeParts[0]);
      minute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;
      if (isPM && hour != 12) hour += 12;
      if (isAM && hour == 12) hour = 0;

      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  /// Parse solicitation target date
  static DateTime? _parseSolicitationDate(String targetDate) {
    try {
      final s = targetDate.trim();
      if (s.isEmpty || s.toUpperCase() == 'ASAP') return null;

      final slashParts = s.split('/');
      if (slashParts.length == 3) {
        return DateTime(
          int.parse(slashParts[2]),
          int.parse(slashParts[0]),
          int.parse(slashParts[1]),
        );
      }

      final months = {
        'january': 1, 'february': 2, 'march': 3, 'april': 4,
        'may': 5, 'june': 6, 'july': 7, 'august': 8,
        'september': 9, 'october': 10, 'november': 11, 'december': 12,
      };

      for (final entry in months.entries) {
        if (s.toLowerCase().contains(entry.key)) {
          final yearMatch = RegExp(r'\d{4}').firstMatch(s);
          final year = yearMatch != null ? int.parse(yearMatch.group(0)!) : DateTime.now().year;

          final dayMatch = RegExp(r'\b(\d{1,2})\b').firstMatch(
              s.replaceAll(RegExp(r'\d{4}'), ''));
          final day = dayMatch != null ? int.parse(dayMatch.group(0)!) : 1;

          return DateTime(year, entry.value, day);
        }
      }
    } catch (_) {}
    return null;
  }
}
