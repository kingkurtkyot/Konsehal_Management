import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';
import '../services/settings_service.dart';
import '../widgets/help_legend_dialog.dart';
import '../models/schedule_event.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../widgets/schedule_event_card.dart';
import '../widgets/image_picker_bottom_sheet.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  
  late TabController _tabController;
  List<ScheduleEvent> _events = [];
  bool _isLoading = false;
  bool _isProcessing = false;
  String _filterDay = 'All';
  
  // Multi-select
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  

  final List<String> _dayFilters = [
    'All', 'Monday', 'Tuesday', 'Wednesday',
    'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- DATA LOADING & FILTERING ---

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    final events = await StorageService.loadScheduleEvents();
    if (!mounted) return;
    setState(() {
      _events = events;
      _isLoading = false;
    });
  }

  List<ScheduleEvent> get _upcomingEvents {
    final now = DateTime.now();
    final twoHoursAgo = now.subtract(const Duration(hours: 2));
    final list = _events.where((e) {
      final eventDateTime = e.parsedDateTime;
      if (eventDateTime == null) return true;
      return !eventDateTime.isBefore(twoHoursAgo);
    }).toList();
    
    // Sort by nearest date first
    list.sort((a, b) {
      final dateA = a.parsedDateTime;
      final dateB = b.parsedDateTime;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateA.compareTo(dateB);
    });
    
    return list;
  }

  Map<String, List<ScheduleEvent>> get _historyEventsGrouped {
    final now = DateTime.now();
    final twoHoursAgo = now.subtract(const Duration(hours: 2));
    final history = _events.where((e) {
      final eventDateTime = e.parsedDateTime;
      if (eventDateTime == null) return false;
      return eventDateTime.isBefore(twoHoursAgo);
    }).toList();
    
    // Sort by most recent first
    history.sort((a, b) {
      final dateA = a.parsedDateTime;
      final dateB = b.parsedDateTime;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });

    // Group by date string
    final grouped = <String, List<ScheduleEvent>>{};
    for (final e in history) {
      final dateKey = e.date;
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(e);
    }
    return grouped;
  }

  List<ScheduleEvent> get _historyEvents {
    final now = DateTime.now();
    final twoHoursAgo = now.subtract(const Duration(hours: 2));
    return _events.where((e) {
      final eventDateTime = e.parsedDateTime;
      if (eventDateTime == null) return false;
      return eventDateTime.isBefore(twoHoursAgo);
    }).toList();
  }

  List<ScheduleEvent> _applyFilter(List<ScheduleEvent> list) {
    if (_filterDay == 'All') return list;
    return list.where((e) => e.dayOfWeek.toLowerCase() == _filterDay.toLowerCase()).toList();
  }

  // --- SELECTION MODE ---

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) _selectedIds.clear();
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _startSelection(String id) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(id);
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${_selectedIds.length} Event(s)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to delete the selected events?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      for (final id in _selectedIds) {
        await NotificationService.cancelEventNotification(id);
      }
      await StorageService.deleteScheduleEvents(_selectedIds.toList());
      _selectedIds.clear();
      _isSelectionMode = false;
      await _loadEvents();
      if (mounted) _showSnackbar('Events deleted.');
    }
  }

  // --- ACTIONS ---

  Future<void> _pickAndProcessImage() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Add Schedule Events',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _choiceButton(
                      icon: Icons.add_photo_alternate,
                      label: 'Single Image',
                      onTap: () => Navigator.pop(context, 'single'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _choiceButton(
                      icon: Icons.collections,
                      label: 'Multiple Images',
                      onTap: () => Navigator.pop(context, 'multiple'),
                    ),
                  ),
                ],  
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _choiceButton(
                  icon: Icons.auto_awesome,
                  label: 'AI Text Entry',
                  onTap: () => Navigator.pop(context, 'ai_text'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _choiceButton(
                  icon: Icons.edit_note,
                  label: 'Manual Entry (Fill Fields)',
                  onTap: () => Navigator.pop(context, 'manual'),
                ),
              ),
            ],
          ),
        ),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
    if (choice == null || !mounted) return;

    if (choice == 'manual') {
      _showManualEntryDialog();
      return;
    }

    if (choice == 'ai_text') {
      _showAITextEntryDialog();
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => const ImagePickerBottomSheet(),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
    if (source == null || !mounted) return;

    final picker = ImagePicker();
    List<XFile> pickedFiles = [];
    
    if (choice == 'multiple') {
      pickedFiles = await picker.pickMultiImage(imageQuality: 85);
    } else {
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) pickedFiles = [picked];
    }

    if (pickedFiles.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      List<ScheduleEvent> allNewEvents = [];
      for (final pickedFile in pickedFiles) {
        final imageFile = File(pickedFile.path);
        final newEvents = await GeminiService.extractScheduleFromImage(imageFile);
        allNewEvents.addAll(newEvents);
      }

      if (allNewEvents.isEmpty) {
        if (mounted) _showSnackbar('No schedule events found in the image(s).', isError: true);
        return;
      }

      // Generate unique IDs
      allNewEvents = allNewEvents.map((e) => e.copyWith(
        id: 'evt_${DateTime.now().millisecondsSinceEpoch}_${allNewEvents.indexOf(e)}',
      )).toList();

      await StorageService.addScheduleEvents(allNewEvents);
      
      for (final event in allNewEvents) {
        await NotificationService.scheduleEventNotification(event);
      }

      await _loadEvents();
      if (mounted) _showSnackbar('${allNewEvents.length} event(s) added successfully!');
    } catch (e) {
      if (mounted) _showSnackbar('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showAITextEntryDialog() {
    final textCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFF1B5E20)),
            const SizedBox(width: 8),
            Text('AI Text Entry', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste or type your schedule info below. AI will automatically extract and organize the details.',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g., Meeting with Barangay Captain on April 5, 2026 at 2pm at Barangay Hall about community cleanup...',
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 8,
                minLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () async {
              if (textCtrl.text.trim().isEmpty) {
                _showSnackbar('Please enter some text', isError: true);
                return;
              }
              Navigator.pop(ctx);
              await _processAIText(textCtrl.text);
            },
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('Process with AI'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processAIText(String text) async {
    setState(() => _isProcessing = true);
    try {
      var newEvents = await GeminiService.extractScheduleFromText(text);
      if (newEvents.isEmpty) {
        if (mounted) _showSnackbar('Could not extract events from the text.', isError: true);
        return;
      }

      newEvents = newEvents.map((e) => e.copyWith(
        id: 'evt_${DateTime.now().millisecondsSinceEpoch}_${newEvents.indexOf(e)}',
      )).toList();

      await StorageService.addScheduleEvents(newEvents);
      for (final event in newEvents) {
        await NotificationService.scheduleEventNotification(event);
      }
      await _loadEvents();
      if (mounted) _showSnackbar('${newEvents.length} event(s) added successfully!');
    } catch (e) {
      if (mounted) _showSnackbar('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showManualEntryDialog() {
    final themeCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    final locationCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Schedule Event', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: themeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Event Title',
                  hintText: 'e.g., Barangay Meeting',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dateCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Date',
                  hintText: 'Tap to pick date',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                  );
                  if (picked != null) {
                    dateCtrl.text = '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}';
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timeCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Time',
                  hintText: 'Tap to pick time',
                  suffixIcon: Icon(Icons.access_time),
                ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.now(),
                  );
                  if (picked != null) {
                    final hour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
                    final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
                    timeCtrl.text = '$hour:${picked.minute.toString().padLeft(2, '0')} $period';
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationCtrl,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (themeCtrl.text.isEmpty || dateCtrl.text.isEmpty || timeCtrl.text.isEmpty) {
                _showSnackbar('Please fill title, date and time', isError: true);
                return;
              }
              
              // Auto-calculate day of week
              String dayOfWeek = '';
              try {
                final parts = dateCtrl.text.split('/');
                if (parts.length == 3) {
                  final dt = DateTime(int.parse(parts[2]), int.parse(parts[0]), int.parse(parts[1]));
                  const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
                  dayOfWeek = days[dt.weekday - 1];
                }
              } catch (_) {}

              final event = ScheduleEvent(
                id: 'evt_${DateTime.now().millisecondsSinceEpoch}',
                date: dateCtrl.text,
                time: timeCtrl.text,
                dayOfWeek: dayOfWeek,
                theme: themeCtrl.text,
                location: locationCtrl.text.isEmpty ? 'Not specified' : locationCtrl.text,
                fullDescription: themeCtrl.text,
              );
              Navigator.pop(ctx);
              await StorageService.addScheduleEvents([event]);
              await NotificationService.scheduleEventNotification(event);
              await _loadEvents();
              if (mounted) _showSnackbar('Event added successfully!');
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _choiceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B5E20).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF1B5E20).withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF1B5E20), size: 28),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> _exportEventAsImage(ScheduleEvent event) async {
    try {
      setState(() => _isProcessing = true);
      
      // Render the event card as an image using an OverlayEntry
      final bytes = await _renderEventToImage(event);
      if (bytes == null) {
        _showSnackbar('Error capturing image', isError: true);
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = 'schedule_${event.id}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Schedule Event: ${event.theme}',
      );
      
      if (mounted) _showSnackbar('Event exported as image!');
    } catch (e) {
      if (mounted) _showSnackbar('Error exporting: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<List<int>?> _renderEventToImage(ScheduleEvent event) async {
    final key = GlobalKey();
    final overlay = Overlay.of(context);
    
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        left: -2000, // off-screen
        child: RepaintBoundary(
          key: key,
          child: Material(
            color: Colors.white,
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B5E20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month, color: Colors.white, size: 24),
                        const SizedBox(width: 10),
                        Text('SCHEDULE EVENT', style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 1,
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(event.theme, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: const Color(0xFF1C2833))),
                  const SizedBox(height: 12),
                  _exportInfoRow(Icons.calendar_today, 'Date', '${event.date} (${event.dayOfWeek})'),
                  const SizedBox(height: 8),
                  _exportInfoRow(Icons.access_time, 'Time', event.time),
                  const SizedBox(height: 8),
                  _exportInfoRow(Icons.location_on, 'Location', event.location),
                  if (event.fullDescription.isNotEmpty && event.fullDescription != event.theme) ...[
                    const SizedBox(height: 8),
                    _exportInfoRow(Icons.description, 'Details', event.fullDescription),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey.shade300)),
                    ),
                    child: Row(
                      children: [
                        Text('Konsehal Matthew Lagaya', style: GoogleFonts.poppins(
                          fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600,
                        )),
                        const Spacer(),
                        Text('#SerbisyongTapatparasaLahat', style: GoogleFonts.poppins(
                          fontSize: 9, color: Colors.grey.shade400, fontStyle: FontStyle.italic,
                        )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } finally {
      entry.remove();
    }
  }

  Widget _exportInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF1B5E20)),
        const SizedBox(width: 8),
        Text('$label: ', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        Expanded(child: Text(value, style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF2C3E50), fontWeight: FontWeight.w600))),
      ],
    );
  }

  Future<void> _exportDayBundle(String date, List<ScheduleEvent> dayEvents) async {
    try {
      setState(() => _isProcessing = true);
      
      final key = GlobalKey();
      final overlay = Overlay.of(context);
      
      final entry = OverlayEntry(
        builder: (context) => Positioned(
          left: -2000,
          child: RepaintBoundary(
            key: key,
            child: Material(
              color: Colors.white,
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month, color: Colors.white, size: 24),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('DAILY SCHEDULE', style: GoogleFonts.poppins(
                                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 1,
                              )),
                              Text(date, style: GoogleFonts.poppins(
                                color: Colors.white70, fontSize: 12,
                              )),
                            ],
                          ),
                          const Spacer(),
                          Text('${dayEvents.length}', style: GoogleFonts.poppins(
                            color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900,
                          )),
                          const SizedBox(width: 4),
                          Text('events', style: GoogleFonts.poppins(
                            color: Colors.white70, fontSize: 11,
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...dayEvents.asMap().entries.map((entry) {
                      final i = entry.key;
                      final event = entry.value;
                      return Container(
                        margin: EdgeInsets.only(bottom: i < dayEvents.length - 1 ? 12 : 0),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(event.theme, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
                            const SizedBox(height: 6),
                            _exportInfoRow(Icons.access_time, 'Time', event.time),
                            const SizedBox(height: 4),
                            _exportInfoRow(Icons.location_on, 'Location', event.location),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.grey.shade300)),
                      ),
                      child: Row(
                        children: [
                          Text('Konsehal Matthew Lagaya', style: GoogleFonts.poppins(
                            fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600,
                          )),
                          const Spacer(),
                          Text('#SerbisyongTapatparasaLahat', style: GoogleFonts.poppins(
                            fontSize: 9, color: Colors.grey.shade400, fontStyle: FontStyle.italic,
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      overlay.insert(entry);
      await Future.delayed(const Duration(milliseconds: 300));

      try {
        final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) throw Exception('Could not render');
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final bytes = byteData!.buffer.asUint8List();

        final tempDir = await getTemporaryDirectory();
        final fileName = 'schedule_day_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes);
        
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Daily Schedule: $date',
        );
        if (mounted) _showSnackbar('Day schedule exported!');
      } finally {
        entry.remove();
      }
    } catch (e) {
      if (mounted) _showSnackbar('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF1B5E20),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showScheduleHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => HelpLegendDialog(
        title: 'Schedule Organizer',
        items: [
          LegendItem(
            icon: Icons.auto_awesome,
            label: 'AI Extraction',
            description: 'Snap a photo of a written schedule or paste text. AI will automatically create events for you.',
            color: const Color(0xFF1B5E20),
          ),
          LegendItem(
            icon: Icons.touch_app_rounded,
            label: 'Selection Mode',
            description: 'Long-press any event to enter selection mode. This allows you to delete multiple items at once.',
            color: Colors.blue.shade700,
          ),
          LegendItem(
            icon: Icons.image_outlined,
            label: 'Export Image',
            description: 'Convert a single event or an entire day into a professional branded image for social media.',
            color: Colors.orange.shade700,
          ),
          LegendItem(
            icon: Icons.history,
            label: 'History Tab',
            description: 'Events that are more than 2 hours past are automatically moved to the History tab.',
            color: Colors.grey.shade600,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedIds.length} Selected')
            : const Text('Schedule Organizer'),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleSelectionMode,
              )
            : null,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: () {
                setState(() {
                  final allIds = _events.map((e) => e.id).toSet();
                  if (_selectedIds.length == allIds.length) {
                    _selectedIds.clear();
                  } else {
                    _selectedIds.addAll(allIds);
                  }
                });
              },
              tooltip: 'Select All',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: _deleteSelected,
              tooltip: 'Delete Selected',
            ),
          ] else ...[
            ValueListenableBuilder<bool>(
              valueListenable: AppSettingsService.showHelpLegends,
              builder: (context, showHelp, _) {
                if (!showHelp) return const SizedBox.shrink();
                return IconButton(
                  icon: const Icon(Icons.help_outline),
                  onPressed: () => _showScheduleHelp(context),
                  tooltip: 'Show Help',
                );
              },
            ),
          ],
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 14),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_month),
                  const SizedBox(width: 6),
                  Text('Upcoming (${_upcomingEvents.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history),
                  const SizedBox(width: 6),
                  Text('History (${_historyEvents.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildTabContent(_upcomingEvents, isHistory: false),
              _buildTabContent(_historyEvents, isHistory: true),
            ],
          ),
          if (_isProcessing) _buildProcessingOverlay(),
        ],
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _isProcessing ? null : _pickAndProcessImage,
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_photo_alternate),
              label: Text('Add Event', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
    );
  }

  Widget _buildTabContent(List<ScheduleEvent> tabEvents, {required bool isHistory}) {
    final filteredEvents = _applyFilter(tabEvents);

    // Group by date for bundle export
    final Map<String, List<ScheduleEvent>> groupedByDate = {};
    for (final event in filteredEvents) {
      groupedByDate.putIfAbsent(event.date, () => []).add(event);
    }

    return Column(
      children: [
        _buildDayFilterBar(),
        Expanded(
          child: _isLoading
              ? _buildShimmer()
              : filteredEvents.isEmpty
                  ? _buildEmptyState(isHistory)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      children: [
                        ...groupedByDate.entries.map((dateEntry) {
                          final date = dateEntry.key;
                          final dateEvents = dateEntry.value;

                          if (isHistory) {
                            // History: Grouped Day ExpansionTile -> Grouped Event ExpansionTile
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                child: GestureDetector(
                                  onLongPress: () => _startSelection(dateEvents.first.id), // Date level selection
                                  child: ExpansionTile(
                                    leading: const Icon(Icons.history, color: Color(0xFF1B5E20)),
                                    title: Text(
                                      date,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: const Color(0xFF1B5E20),
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${dateEvents.length} event(s)',
                                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.download, size: 20, color: Color(0xFF1B5E20)),
                                      onPressed: () => _exportDayBundle(date, dateEvents),
                                      tooltip: 'Export Day',
                                    ),
                                    children: [
                                      const Divider(indent: 16, endIndent: 16),
                                      ...dateEvents.map((event) => Theme(
                                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                        child: GestureDetector(
                                          onLongPress: () => _startSelection(event.id),
                                          child: ExpansionTile(
                                            leading: const Padding(
                                              padding: EdgeInsets.only(left: 16),
                                              child: Icon(Icons.event_available, size: 18),
                                            ),
                                            title: Text(
                                              event.theme,
                                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                                            ),
                                            subtitle: Padding(
                                              padding: const EdgeInsets.only(left: 0),
                                              child: Text(event.time, style: GoogleFonts.poppins(fontSize: 12)),
                                            ),
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.fromLTRB(52, 0, 16, 16),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    _detailRow(Icons.location_on, 'Location', event.location),
                                                    if (event.fullDescription.isNotEmpty && event.fullDescription != event.theme)
                                                      _detailRow(Icons.description, 'Details', event.fullDescription),
                                                    const SizedBox(height: 8),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.end,
                                                      children: [
                                                        IconButton(
                                                          icon: const Icon(Icons.share, size: 18),
                                                          onPressed: () => _exportEventAsImage(event),
                                                          tooltip: 'Export Card',
                                                        ),
                                                        if (_isSelectionMode)
                                                          Checkbox(
                                                            value: _selectedIds.contains(event.id),
                                                            onChanged: (_) => _toggleSelect(event.id),
                                                            activeColor: const Color(0xFF1B5E20),
                                                          ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          } else {
                            // Upcoming: Card-based view with headers
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8, top: 8),
                                  child: Row(
                                    children: [
                                      Text(
                                        date,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: const Color(0xFF1B5E20),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (dateEvents.length > 1)
                                        TextButton.icon(
                                          onPressed: () => _exportDayBundle(date, dateEvents),
                                          icon: const Icon(Icons.download, size: 16),
                                          label: Text('Export Day', style: GoogleFonts.poppins(fontSize: 12)),
                                          style: TextButton.styleFrom(
                                            foregroundColor: const Color(0xFF1B5E20),
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                ...dateEvents.map((event) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: ScheduleEventCard(
                                    event: event,
                                    isSelectionMode: _isSelectionMode,
                                    isSelected: _selectedIds.contains(event.id),
                                    onToggleSelect: () => _toggleSelect(event.id),
                                    onLongPress: () => _startSelection(event.id),
                                    onExport: () => _exportEventAsImage(event),
                                  ),
                                )),
                              ],
                            );
                          }
                        }),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text('$label: ', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          Expanded(child: Text(value, style: GoogleFonts.poppins(fontSize: 11, color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildDayFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.filter_list, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text('Filter by Day: ', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E20).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1B5E20).withValues(alpha: 0.2)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterDay,
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1B5E20)),
                isDense: true,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1B5E20),
                ),
                items: _dayFilters.map((String day) {
                  return DropdownMenuItem<String>(
                    value: day,
                    child: Text(day),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() => _filterDay = newValue);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isHistory) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isHistory ? Icons.history : Icons.calendar_today,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            isHistory ? 'No past events' : 'No upcoming events',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Add events using the button below',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 16),
                Text(
                  'Processing...',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Extracting schedule events with AI',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
