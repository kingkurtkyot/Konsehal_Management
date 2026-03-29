import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/schedule_event.dart';
import '../models/solicitation.dart';
import '../models/scheduled_post.dart';
import 'supabase_service.dart';

class StorageService {
  static final _supabase = SupabaseService().client;
  
  static const String _scheduleKey = 'schedule_events';
  static const String _solicitationKey = 'solicitations';
  static const String _galleryKey = 'photo_gallery_paths';
  static const String _scheduledPostsKey = 'scheduled_content_posts';

  // --- Utility: Sync Local to Cloud ---

  static Future<void> syncLocalToCloud() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Sync Solicitations
    final localSols = await _loadLocalSolicitations();
    for (var sol in localSols) {
      await _supabase.from('solicitations').upsert(sol.toJson());
    }

    // 2. Sync Schedule
    final localEvents = await _loadLocalScheduleEvents();
    for (var event in localEvents) {
      await _supabase.from('schedule_events').upsert(event.toJson());
    }

    // 3. Sync Posts
    final localPosts = await _loadLocalScheduledPosts();
    for (var post in localPosts) {
      await _supabase.from('scheduled_posts').upsert(post.toJson());
    }
  }

  // ── Schedule Events ──────────────────────────────────────────────────────────

  static Future<List<ScheduleEvent>> loadScheduleEvents() async {
    try {
      final response = await _supabase.from('schedule_events').select().order('date', ascending: true);
      final List<ScheduleEvent> cloudEvents = response.map((j) => ScheduleEvent.fromJson(Map<String, dynamic>.from(j))).toList();
      
      // Update local cache
      await _saveLocalScheduleEvents(cloudEvents);
      return cloudEvents;
    } catch (e) {
      // Fallback to local cache if offline
      return await _loadLocalScheduleEvents();
    }
  }

  static Future<void> saveScheduleEvents(List<ScheduleEvent> events) async {
    // We usually do individual upserts in cloud-sync apps, but for bulk:
    for (var e in events) {
      await _supabase.from('schedule_events').upsert(e.toJson());
    }
    await _saveLocalScheduleEvents(events);
  }

  static Future<void> addScheduleEvents(List<ScheduleEvent> newEvents) async {
    for (var e in newEvents) {
      await _supabase.from('schedule_events').insert(e.toJson());
    }
    final existing = await _loadLocalScheduleEvents();
    existing.addAll(newEvents);
    await _saveLocalScheduleEvents(existing);
  }

  static Future<void> deleteScheduleEvent(String id) async {
    await _supabase.from('schedule_events').delete().match({'id': id});
    final events = await _loadLocalScheduleEvents();
    events.removeWhere((e) => e.id == id);
    await _saveLocalScheduleEvents(events);
  }

  static Future<void> deleteScheduleEvents(List<String> ids) async {
    await _supabase.from('schedule_events').delete().filter('id', 'in', ids);
    final events = await _loadLocalScheduleEvents();
    events.removeWhere((e) => ids.contains(e.id));
    await _saveLocalScheduleEvents(events);
  }

  // ── Solicitations ────────────────────────────────────────────────────────────

  static Future<List<Solicitation>> loadSolicitations() async {
    try {
      final response = await _supabase.from('solicitations').select().order('created_at', ascending: false);
      final List<Solicitation> cloudItems = response.map((j) => Solicitation.fromJson(Map<String, dynamic>.from(j))).toList();
      
      await _saveLocalSolicitations(cloudItems);
      return cloudItems;
    } catch (e) {
      return await _loadLocalSolicitations();
    }
  }

  static Future<void> saveSolicitations(List<Solicitation> items) async {
    for (var s in items) {
      await _supabase.from('solicitations').upsert(s.toJson());
    }
    await _saveLocalSolicitations(items);
  }

  static Future<void> addSolicitations(List<Solicitation> newItems) async {
    for (var s in newItems) {
      await _supabase.from('solicitations').insert(s.toJson());
    }
    final existing = await _loadLocalSolicitations();
    existing.addAll(newItems);
    await _saveLocalSolicitations(existing);
  }

  static Future<void> updateSolicitation(Solicitation updated) async {
    await _supabase.from('solicitations').upsert(updated.toJson());
    final items = await _loadLocalSolicitations();
    final index = items.indexWhere((s) => s.id == updated.id);
    if (index != -1) {
      items[index] = updated;
      await _saveLocalSolicitations(items);
    }
  }

  static Future<void> deleteSolicitation(String id) async {
    await _supabase.from('solicitations').delete().match({'id': id});
    final items = await _loadLocalSolicitations();
    items.removeWhere((s) => s.id == id);
    await _saveLocalSolicitations(items);
  }

  static Future<void> deleteSolicitations(List<String> ids) async {
    await _supabase.from('solicitations').delete().filter('id', 'in', ids);
    final items = await _loadLocalSolicitations();
    items.removeWhere((s) => ids.contains(s.id));
    await _saveLocalSolicitations(items);
  }

  // ── Scheduled Content Posts ──────────────────────────────────────────────────

  static Future<List<ScheduledPost>> loadScheduledPosts() async {
    try {
      final response = await _supabase.from('scheduled_posts').select().order('scheduled_date', ascending: true);
      final List<ScheduledPost> cloudPosts = response.map((j) => ScheduledPost.fromJson(Map<String, dynamic>.from(j))).toList();
      
      await _saveLocalScheduledPosts(cloudPosts);
      return cloudPosts;
    } catch (e) {
      return await _loadLocalScheduledPosts();
    }
  }

  static Future<void> addScheduledPost(ScheduledPost post) async {
    await _supabase.from('scheduled_posts').insert(post.toJson());
    final posts = await _loadLocalScheduledPosts();
    posts.add(post);
    await _saveLocalScheduledPosts(posts);
  }

  static Future<void> deleteScheduledPost(String id) async {
    await _supabase.from('scheduled_posts').delete().match({'id': id});
    final posts = await _loadLocalScheduledPosts();
    posts.removeWhere((p) => p.id == id);
    await _saveLocalScheduledPosts(posts);
  }

  // --- Private Local Helpers (Caching) ---

  static Future<List<ScheduleEvent>> _loadLocalScheduleEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_scheduleKey);
    if (jsonString == null) return [];
    return (jsonDecode(jsonString) as List).map((j) => ScheduleEvent.fromJson(j)).toList();
  }

  static Future<void> _saveLocalScheduleEvents(List<ScheduleEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scheduleKey, jsonEncode(events.map((e) => e.toJson()).toList()));
  }

  static Future<List<Solicitation>> _loadLocalSolicitations() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_solicitationKey);
    if (jsonString == null) return [];
    return (jsonDecode(jsonString) as List).map((j) => Solicitation.fromJson(j)).toList();
  }

  static Future<void> _saveLocalSolicitations(List<Solicitation> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_solicitationKey, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  static Future<List<ScheduledPost>> _loadLocalScheduledPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_scheduledPostsKey);
    if (jsonString == null) return [];
    return (jsonDecode(jsonString) as List).map((j) => ScheduledPost.fromJson(j)).toList();
  }

  static Future<void> _saveLocalScheduledPosts(List<ScheduledPost> posts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scheduledPostsKey, jsonEncode(posts.map((p) => p.toJson()).toList()));
  }

  // --- Gallery remains Local only for now ---

  static Future<List<String>> loadGalleryPaths() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_galleryKey);
    if (jsonString == null) return [];
    return (jsonDecode(jsonString) as List).cast<String>();
  }

  static Future<void> addGalleryPath(String path) async {
    final paths = await loadGalleryPaths();
    paths.insert(0, path);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_galleryKey, jsonEncode(paths));
  }

  static Future<void> removeGalleryPath(String path) async {
    final paths = await loadGalleryPaths();
    paths.remove(path);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_galleryKey, jsonEncode(paths));
  }

  // --- Gemini Fallback Pointers ---
  static Future<int> getLastFallbackIndex(String category) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('fallback_$category') ?? -1;
  }

  static Future<void> setLastFallbackIndex(String category, int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('fallback_$category', index);
  }
}
