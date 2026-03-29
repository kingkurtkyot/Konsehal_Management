import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/schedule_event.dart';
import '../models/solicitation.dart';

// ─── ANALYTICS EVENT DATA CLASS ──────────────────────────────────────────────
class AnalyticsEvent {
  final String eventType; // 'event_created', 'solicitation_completed', etc.
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  
  AnalyticsEvent({
    required this.eventType,
    required this.timestamp,
    this.metadata = const {},
  });
  
  Map<String, dynamic> toJson() => {
    'eventType': eventType,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
  };
  
  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) {
    return AnalyticsEvent(
      eventType: json['eventType'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      metadata: json['metadata'] ?? {},
    );
  }
}

/// 📊 Analytics Service - Track app usage, impact, and community benefit
class AnalyticsService {
  static const String _analyticsKey = 'app_analytics_data';
  
  // ─── EVENT TRACKING ─────────────────────────────────────────────────────────
  
  /// Log an analytics event
  static Future<void> logEvent({
    required String eventType,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final events = await _loadEvents();
      
      events.add(AnalyticsEvent(
        eventType: eventType,
        timestamp: DateTime.now(),
        metadata: metadata,
      ));
      
      // Keep only last 1000 events to prevent storage bloat
      if (events.length > 1000) {
        events.removeRange(0, events.length - 1000);
      }
      
      final jsonString = jsonEncode(events.map((e) => e.toJson()).toList());
      await prefs.setString(_analyticsKey, jsonString);
    } catch (e) {
      debugPrint('Analytics logging error: $e');
    }
  }
  
  /// Log event creation
  static Future<void> logEventCreated(ScheduleEvent event) async {
    await logEvent(
      eventType: 'event_created',
      metadata: {
        'eventId': event.id,
        'date': event.date,
        'dayOfWeek': event.dayOfWeek,
        'theme': event.theme,
      },
    );
  }
  
  /// Log solicitation request
  static Future<void> logSolicitationCreated(Solicitation solicitation) async {
    await logEvent(
      eventType: 'solicitation_created',
      metadata: {
        'solicitationId': solicitation.id,
        'organizationOrPerson': solicitation.organizationOrPerson,
        'purpose': solicitation.purpose,
      },
    );
  }
  
  /// Log solicitation completion
  static Future<void> logSolicitationCompleted(Solicitation solicitation) async {
    await logEvent(
      eventType: 'solicitation_completed',
      metadata: {
        'solicitationId': solicitation.id,
        'organizationOrPerson': solicitation.organizationOrPerson,
        'amountGiven': solicitation.amountGiven,
      },
    );
  }
  
  /// Log content post creation
  static Future<void> logContentCreated(String dayOfWeek, String contentType) async {
    await logEvent(
      eventType: 'content_created',
      metadata: {
        'dayOfWeek': dayOfWeek,
        'contentType': contentType,
      },
    );
  }
  
  // ─── ANALYTICS QUERIES ──────────────────────────────────────────────────────
  
  static Future<List<AnalyticsEvent>> _loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_analyticsKey);
    if (jsonString == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((e) => AnalyticsEvent.fromJson(e as Map<String, dynamic>)).toList();
  }
  
  /// Get total events count
  static Future<int> getTotalEventCount() async {
    final events = await _loadEvents();
    return events.where((e) => e.eventType == 'event_created').length;
  }
  
  /// Get total solicitations count
  static Future<int> getTotalSolicitationCount() async {
    final events = await _loadEvents();
    return events.where((e) => e.eventType == 'solicitation_created').length;
  }
  
  /// Get total completed solicitations
  static Future<int> getTotalCompletedCount() async {
    final events = await _loadEvents();
    return events.where((e) => e.eventType == 'solicitation_completed').length;
  }
  
  /// Get content creation count by day
  static Future<Map<String, int>> getContentCreationByDay() async {
    final events = await _loadEvents();
    final contentEvents = events.where((e) => e.eventType == 'content_created');
    final result = <String, int>{};
    
    for (final event in contentEvents) {
      final dayOfWeek = event.metadata['dayOfWeek'] as String? ?? '';
      result[dayOfWeek] = (result[dayOfWeek] ?? 0) + 1;
    }
    
    return result;
  }
  
  /// Get events created in the last N days
  static Future<int> getEventsInLastDays(int days) async {
    final events = await _loadEvents();
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    return events.where((e) => 
      e.eventType == 'event_created' && e.timestamp.isAfter(cutoffDate)
    ).length;
  }
  
  /// Get solicitations created in the last N days
  static Future<int> getSolicitationsInLastDays(int days) async {
    final events = await _loadEvents();
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    return events.where((e) => 
      e.eventType == 'solicitation_created' && e.timestamp.isAfter(cutoffDate)
    ).length;
  }
  
  /// Get app usage statistics for a date range
  static Future<Map<String, dynamic>> getUsageStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final events = await _loadEvents();
    final start = startDate ?? DateTime(DateTime.now().year, 1, 1);
    final end = endDate ?? DateTime.now();
    
    final filteredEvents = events.where((e) => 
      !e.timestamp.isBefore(start) && !e.timestamp.isAfter(end)
    ).toList();
    
    final eventCount = filteredEvents.where((e) => e.eventType == 'event_created').length;
    final solicitationCount = filteredEvents.where((e) => e.eventType == 'solicitation_created').length;
    final completedCount = filteredEvents.where((e) => e.eventType == 'solicitation_completed').length;
    final contentCount = filteredEvents.where((e) => e.eventType == 'content_created').length;
    
    return {
      'period': {
        'startDate': start.toIso8601String(),
        'endDate': end.toIso8601String(),
      },
      'events': {
        'eventsCreated': eventCount,
        'solicitationsCreated': solicitationCount,
        'solicitationsCompleted': completedCount,
        'completionRate': solicitationCount == 0 ? 0.0 : (completedCount / solicitationCount) * 100,
      },
      'content': {
        'postsCreated': contentCount,
      },
      'totalActivities': filteredEvents.length,
    };
  }
  
  /// Get daily activity breakdown for the last N days
  static Future<Map<String, int>> getDailyActivityBreakdown(int days) async {
    final events = await _loadEvents();
    final result = <String, int>{};
    
    for (int i = 0; i < days; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      final dayEvents = events.where((e) {
        final eventDate = '${e.timestamp.year}-${e.timestamp.month.toString().padLeft(2, '0')}-${e.timestamp.day.toString().padLeft(2, '0')}';
        return eventDate == dateStr;
      }).length;
      
      if (dayEvents > 0) {
        result[dateStr] = dayEvents;
      }
    }
    
    return result;
  }
  
  /// Clear all analytics data
  static Future<void> clearAnalytics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_analyticsKey);
    } catch (e) {
      debugPrint('Error clearing analytics: $e');
    }
  }
  
  /// Export analytics as JSON
  static Future<String> exportAnalyticsAsJson() async {
    final events = await _loadEvents();
    return jsonEncode(events.map((e) => e.toJson()).toList());
  }
}
