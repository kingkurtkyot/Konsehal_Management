import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../services/settings_service.dart';
import '../widgets/help_legend_dialog.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import '../models/scheduled_post.dart';
import '../models/schedule_event.dart';

class ContentPostingScreen extends StatefulWidget {
  const ContentPostingScreen({super.key});

  @override
  State<ContentPostingScreen> createState() => _ContentPostingScreenState();
}

class _ContentPostingScreenState extends State<ContentPostingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey _cardKey = GlobalKey();

  // Content types for each day - MASTERPIECE DAYS
  static const Map<String, Map<String, dynamic>> _dayContent = {
    'Monday': {
      'type': 'did_you_know',
      'label': 'Trivia - Alam Mo Ba?',
      'icon': Icons.lightbulb_outline,
      'emoji': '💡',
      'color': Color(0xFF1B5E20),
    },
    'Saturday': {
      'type': 'inspirational',
      'label': 'Inspirational & Leadership',
      'icon': Icons.format_quote,
      'emoji': '✨',
      'color': Color(0xFF1B5E20),
    },
    'Sunday': {
      'type': 'bible_verse',
      'label': 'Bible Verse & Reflection',
      'icon': Icons.menu_book_outlined,
      'emoji': '📖',
      'color': Color(0xFF1B5E20),
    },
  };

  String _selectedDay = 'Monday';
  String _generatedTitle = '';
  String _generatedContent = '';
  String _contentBody = "";
  String _bibleVerse = "";
  String _reflection = "";
  String _question = "";
  bool _isGenerating = false;
  bool _isSaving = false;
  int _designVariant = 0; // The 9-variant selector
  String _selectedSize = 'Post'; // 'Post' (4:5) or 'Story' (9:16)

  // Calendar & Context Data
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedCalendarDay;
  List<ScheduledPost> _scheduledPosts = [];
  List<ScheduleEvent> _scheduleEvents = [];
  DateTime? _targetSchedulingDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadScheduledPosts();
    _loadScheduleEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadScheduledPosts() async {
    final posts = await StorageService.loadScheduledPosts();
    if (!mounted) return;
    setState(() {
      _scheduledPosts = posts;
    });
  }

  Future<void> _loadScheduleEvents() async {
    final events = await StorageService.loadScheduleEvents();
    if (!mounted) return;
    setState(() {
      _scheduleEvents = events;
    });
  }

  List<ScheduledPost> _getEventsForDay(DateTime day) {
    return _scheduledPosts.where((p) => isSameDay(p.scheduledDate, day)).toList();
  }

  // --- AUTO SCHEDULING ENGINE ---
  DateTime _calculateNextAvailableDate(String dayName, {DateTime? fromDate}) {
    int targetWeekday;
    switch (dayName) {
      case 'Monday': targetWeekday = DateTime.monday; break;
      case 'Saturday': targetWeekday = DateTime.saturday; break;
      case 'Sunday': targetWeekday = DateTime.sunday; break;
      default: targetWeekday = DateTime.monday;
    }
    
    // Start from provided date OR first of next month (Advance Rule)
    DateTime nextDate;
    if (fromDate != null) {
      nextDate = fromDate;
    } else {
      final now = DateTime.now();
      // If we are at the end of the month, jump to next
      nextDate = DateTime(now.year, now.month + 1, 1);
    }

    // Fast forward to nearest weekday
    while (nextDate.weekday != targetWeekday) {
      nextDate = nextDate.add(const Duration(days: 1));
    }
    
    // Check conflicts and jump weeks if necessary
    while (true) {
      bool isBooked = _scheduledPosts.any((post) {
        return isSameDay(post.scheduledDate, nextDate);
      });
      if (!isBooked) return nextDate;
      nextDate = nextDate.add(const Duration(days: 7));
    }
  }

  Future<void> _generateContent() async {
    setState(() {
      _isGenerating = true;
      _designVariant = Random().nextInt(3); // Reset variant on fresh generation
      // Determine the target date FIRST
      _targetSchedulingDate = _calculateNextAvailableDate(_selectedDay);
    });
    
    try {
      final targetDate = _targetSchedulingDate!;
      final weekStart = targetDate.subtract(Duration(days: targetDate.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));
      
      // Build Context string from real community events taking place that week!
      final eventsThatWeek = _scheduleEvents.where((e) {
        final d = e.parsedDateTime;
        if (d == null) return false;
        return d.isAfter(weekStart.subtract(const Duration(days: 1))) && d.isBefore(weekEnd.add(const Duration(days: 1)));
      }).toList();
      
      String communityContext = "No specific events scheduled.";
      if (eventsThatWeek.isNotEmpty) {
        communityContext = eventsThatWeek.map((e) => "- ${e.theme} at ${e.location} on ${e.dayOfWeek}").join("\n");
      }

      String prompt;
      String category = _selectedDay;
      
      // If there's an event, we might want to prioritize it, but staying with selected day flow for now.
      // However, we added an 'Event' category in GeminiService just in case.
      
      switch (_selectedDay) {
        case 'Monday':
          prompt = '''
Generate a "Konsi's Trivia" (Angono Heritage & Trivia) post for the people of Angono.
Date: ${DateFormat('EEEE, MMM d, yyyy').format(targetDate)}
Community Context: $communityContext

Subject: Angono history, landmarks, legends, or current local triumphs.
Style: Short, punchy, and objective (Third Person). 
Focus: Include a clear educational lesson or "did you know" fact.
''';
          break;
        case 'Saturday':
          prompt = '''
Generate a "Saturday Strength" inspirational post. 
Date: ${DateFormat('EEEE, MMM d, yyyy').format(targetDate)}
Community Context: $communityContext

Subject: Famous quotes from world leaders, pioneers, philosophers, or successful figures (e.g., Gandhi, MLK, Steve Jobs, Seneca, etc.).
Style: Objective Quote (Third Person). 
Focus: The quote must provide a universal leadership or service lesson.
''';
          break;
        case 'Sunday':
          final targetMonth = DateFormat('MMMM').format(targetDate);
          prompt = '''
Generate a "Sunday Blessing" post.
Date: ${DateFormat('EEEE, MMM d, yyyy').format(targetDate)}
Community Context: $communityContext

Subject: A spiritually uplifting Bible Verse.
Style: Objective and formal (Third Person). Correlate with the current season of $targetMonth.
Focus: The core message of the verse and its universal lesson.
''';
          break;
        default:
          throw Exception('Invalid day selected');
      }

      final result = await GeminiService.generateContentPost(prompt, category, targetDate: targetDate);
      if (!mounted) return;
      
      setState(() {
        _generatedTitle = result['title'] ?? _selectedDay;
        _contentBody = result['body'] ?? "";
        _bibleVerse = result['verse'] ?? "";
        _reflection = result['reflection'] ?? "";
        _question = result['question'] ?? "";
        
        // Final combined content for easy copying if needed, though variants will use parts
        _generatedContent = "$_contentBody\n\n${_bibleVerse.isNotEmpty ? 'Verse: $_bibleVerse\n\n' : ''}Reflection: $_reflection\n\n$_question";
        
        _designVariant = Random().nextInt(3); 
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating content: $e'), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _scheduleAndSavePost() async {
    if (_generatedContent.isEmpty || _targetSchedulingDate == null) return;
    
    final selectedDate = _targetSchedulingDate!;
    
    setState(() => _isSaving = true);

    try {
      final bytes = await _captureCard();
      if (bytes == null) throw Exception('Could not capture image');

      // Save to temp directory first
      final tempDir = await getTemporaryDirectory();
      final fileName = 'post_${DateTime.now().millisecondsSinceEpoch}.png';
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);
      
      // Save to gallery
      await Gal.putImage(tempFile.path);

      // Save to persistent app storage
      final appDir = await getApplicationDocumentsDirectory();
      final galleryDir = Directory('${appDir.path}/konsi_gallery');
      if (!await galleryDir.exists()) {
        await galleryDir.create(recursive: true);
      }
      
      final persistentFile = File('${galleryDir.path}/$fileName');
      await persistentFile.writeAsBytes(bytes);
      
      final newPost = ScheduledPost(
        id: 'sp_${DateTime.now().millisecondsSinceEpoch}',
        imagePath: persistentFile.path,
        scheduledDate: selectedDate,
        category: _selectedDay,
        title: _generatedTitle,
        body: _contentBody,
        verse: _bibleVerse,
        reflection: _reflection,
        question: _question,
        designVariant: _designVariant,
      );
      
      await StorageService.addScheduledPost(newPost);
      await _loadScheduledPosts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Masterpiece automatically scheduled for ${DateFormat('EEEE, MMM d, yyyy').format(selectedDate)}'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
        // Switch to calendar tab
        _tabController.animateTo(1);
        setState(() => _selectedCalendarDay = selectedDate);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving post: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _sharePost() async {
    if (_generatedContent.isEmpty) return;
    try {
      setState(() => _isSaving = true);
      final bytes = await _captureCard();
      if (bytes == null) throw Exception('Could not capture image');
      
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/share_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '#SerbisyongTapat #KonsehalLagaya\\n$_generatedTitle',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sharing: $e'), backgroundColor: Colors.red.shade700));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<List<int>?> _captureCard() async {
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 4.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Capture error: $e');
      return null;
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  void _showMasterpieceHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => HelpLegendDialog(
        title: 'Masterpiece Creator',
        items: [
          LegendItem(
            icon: Icons.auto_awesome,
            label: 'AI Content Generation',
            description: 'Generates professional social media posts based on the day of the week and your previous activities.',
            color: const Color(0xFF1B5E20),
          ),
          LegendItem(
            icon: Icons.palette_outlined,
            label: 'Cycle Layout',
            description: 'Instantly switch between different professional design variants without regenerating content.',
            color: Colors.blue.shade700,
          ),
          LegendItem(
            icon: Icons.event_available,
            label: 'Auto-Scheduler',
            description: 'Finds the next available time slot in your calendar and saves the post for future publication.',
            color: Colors.green.shade700,
          ),
          LegendItem(
            icon: Icons.lightbulb_outline,
            label: 'Monday Theme',
            description: 'Trivia - "Alam Mo Ba?". Engaging community facts and educational snippets.',
            color: Colors.orange.shade700,
          ),
          LegendItem(
            icon: Icons.format_quote,
            label: 'Saturday Theme',
            description: 'Inspiration & Leadership. Motivational quotes and public service values.',
            color: Colors.purple.shade700,
          ),
          LegendItem(
            icon: Icons.menu_book_outlined,
            label: 'Sunday Theme',
            description: 'Bible Verse & Reflection. Spiritual guidance and weekend blessings.',
            color: Colors.blue.shade400,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Masterpiece Creator'),
        elevation: 0,
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: AppSettingsService.showHelpLegends,
            builder: (context, showHelp, _) {
              if (!showHelp) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.help_outline),
                onPressed: () => _showMasterpieceHelp(context),
                tooltip: 'Show Help',
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Create', icon: Icon(Icons.auto_awesome, size: 20)),
            Tab(text: 'Schedule', icon: Icon(Icons.calendar_month, size: 20)),
          ],
        ),
      ),
      body: Stack(
        children: [
          // ── GHOST CAPTURE LAYER (Always rendered, but invisible) ──
          // This allows us to capture the card even from the Schedule/Calendar tab
          IgnorePointer(
            child: Opacity(
              opacity: 0,
              child: UnconstrainedBox(
                child: SizedBox(
                   // We render it at a fixed large size for high-quality capture
                  width: _selectedSize == 'Post' ? 1000 : 1080,
                  height: _selectedSize == 'Post' ? 1250 : 1920,
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: _getDaySpecificDesign(),
                  ),
                ),
              ),
            ),
          ),
          
          // ── ACTUAL UI LAYER ──
          TabBarView(
            controller: _tabController,
            children: [
              _buildCreateTab(),
              _buildScheduleTab(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day Selection
          Text('Select Content Day', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ..._dayContent.entries.map((entry) {
                final isSelected = _selectedDay == entry.key;
                final config = entry.value;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDay = entry.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? config['color'] : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: config['color'] as Color, width: isSelected ? 2.5 : 1.5),
                      boxShadow: isSelected ? [BoxShadow(color: (config['color'] as Color).withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))] : [],
                    ),
                    child: Column(
                      children: [
                        Text(config['emoji'] as String, style: const TextStyle(fontSize: 32)),
                        const SizedBox(height: 6),
                        Text(
                          entry.key,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, color: isSelected ? Colors.white : (config['color'] as Color)),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Size Selection
          Text('Choose Masterpiece Size', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSizeOption('Post', 'Feed Post (4:5)', Icons.grid_view),
              const SizedBox(width: 12),
              _buildSizeOption('Story', 'Full Story (9:16)', Icons.stay_current_portrait),
            ],
          ),
          
          const SizedBox(height: 28),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateContent,
                  icon: _isGenerating
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Icon(Icons.auto_awesome, size: 22),
                  label: Text(
                    _isGenerating ? 'Generating...' : '✨ Create for Bayan',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _dayContent[_selectedDay]?['color'] as Color?,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : () {
                    // Cost-free API re-design button! Cycles through 0, 1, and 2.
                    setState(() {
                      _designVariant = (_designVariant + 1) % 3;
                    });
                  },
                  icon: const Icon(Icons.refresh, size: 22),
                  label: Text(
                    '🎨 Cycle Layout',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 28),
          
          // Preview Section
          if (_generatedContent.isNotEmpty) ...[
            Text('Preview Your Masterpiece (Variant ${_designVariant + 1})', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF1B5E20))),
            const SizedBox(height: 14),
            
            // Preview Card (Visual Only)
            AspectRatio(
              aspectRatio: _selectedSize == 'Post' ? 4 / 5 : 9 / 16,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20)],
                ),
                clipBehavior: Clip.antiAlias,
                child: _getDaySpecificDesign(),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Scheduling Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _scheduleAndSavePost,
                    icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.event_available),
                    label: Text(_isSaving ? 'Saving...' : 'Schedule for Bayan', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _sharePost,
                    icon: const Icon(Icons.share),
                    label: Text('Share', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSizeOption(String value, String label, IconData icon) {
    final isSelected = _selectedSize == value;
    final color = _dayContent[_selectedDay]?['color'] as Color;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSize = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: isSelected ? 2 : 1),
            boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: isSelected ? Colors.white : color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getDaySpecificDesign() {
    switch (_selectedDay) {
      case 'Monday': return _mondayVariants();
      case 'Saturday': return _saturdayVariants();
      case 'Sunday': return _sundayVariants();
      default: return const SizedBox();
    }
  }

  // 1️⃣ MONDAY (ALAM MO BA - TRIVIA) - Konsi's Trivia
  Widget _mondayVariants() {
    final bgColor = const Color(0xFF11381E); // Deeper Premium Green
    final paperColor = const Color(0xFFF9F6E5);
    final isStory = _selectedSize == 'Story';

    if (_designVariant == 0) {
      // THE "TORN TRIVIA"
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [const Color(0xFF0A2E16), bgColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Stack(
          children: [
            Positioned(right: -70, bottom: -70, child: Opacity(opacity: 0.08, child: Image.asset('assets/seal.png', width: 400))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 25, vertical: isStory ? 70 : 40),
              child: ClipPath(
                clipper: TornPaperClipper(),
                child: Container(
                  color: paperColor,
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text('KONSI\'S TRIVIA', style: GoogleFonts.cinzel(fontSize: isStory ? 36 : 28, fontWeight: FontWeight.w900, color: bgColor, letterSpacing: 2))),
                          Image.asset('assets/seal.png', width: 60),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Divider(color: bgColor.withValues(alpha: 0.2), thickness: 2),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: 400, // Normalized width for scaling
                              child: Text(
                                _contentBody, 
                                style: GoogleFonts.libreBaskerville(
                                  fontSize: isStory ? 24 : 20, 
                                  color: Colors.black87, 
                                  height: 1.6, 
                                  fontWeight: FontWeight.w600
                                ),
                                textAlign: TextAlign.start,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildSectionBoundary(title: "The Reflection", content: _reflection, color: bgColor),
                      _buildSectionBoundary(title: "Thinking Point", content: _question, color: Colors.orange.shade900),
                      const SizedBox(height: 15),
                      Text('KONSI MATTHEW LAGAYA', style: GoogleFonts.oswald(fontSize: 14, fontWeight: FontWeight.bold, color: bgColor, letterSpacing: 4)),
                      _buildHashtagFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } 
    else if (_designVariant == 1) {
      // THE "SIDE RIP"
      return Container(
        width: double.infinity,
        color: bgColor,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(isStory ? 90 : 75, 30, 0, 30),
              child: ClipPath(
                clipper: SideTearClipper(),
                child: Container(
                  color: paperColor,
                  padding: const EdgeInsets.fromLTRB(60, 50, 40, 50),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('KONSI MATTHEW LAGAYA', style: GoogleFonts.oswald(fontSize: 13, color: Colors.grey.shade600, letterSpacing: 5)),
                      const SizedBox(height: 10),
                      Text('KAALAMAN MULA KAY KONSI', style: GoogleFonts.montserrat(fontSize: isStory ? 38 : 28, fontWeight: FontWeight.w900, color: bgColor, height: 1.1)),
                      const SizedBox(height: 20),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 350,
                            child: Text(
                              _contentBody, 
                              style: GoogleFonts.poppins(
                                fontSize: isStory ? 22 : 18, 
                                color: Colors.black87, 
                                height: 1.6, 
                                fontWeight: FontWeight.w500
                              )
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionBoundary(title: "Ang Aking Nilay", content: _reflection, color: bgColor),
                      _buildSectionBoundary(title: "Kayo naman sa comments!", content: _question, color: const Color(0xFF1565C0)),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Image.asset('assets/seal.png', width: 70),
                          _buildHashtagFooter(),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(left: 20, top: isStory ? 150 : 80, child: RotatedBox(quarterTurns: 3, child: Text('KONSI\'S TRIVIA', style: GoogleFonts.oswald(color: Colors.white60, letterSpacing: 8, fontSize: 16)))),
          ],
        ),
      );
    } 
    else {
      // THE "PREMIUM RESOLUTION" - REFOCUSED GREEN VERSION
      return LayoutBuilder(
        builder: (context, constraints) {
          double scale = constraints.maxWidth / 400; // Normalizing scale
          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8E9), // Lightest Mint Green instead of pure white
              border: Border.all(color: bgColor.withValues(alpha: 0.1), width: 10 * scale),
            ),
            child: Column(
              children: [
                ClipPath(
                  clipper: BottomTearClipper(),
                  child: Container(
                    height: isStory ? 320 * scale : 200 * scale,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFF051D0D), bgColor], 
                        begin: Alignment.topCenter, 
                        end: Alignment.bottomCenter
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/seal.png', width: 90 * scale),
                        SizedBox(height: 12 * scale),
                        Text(
                          'TRIVIA HUB', 
                          style: GoogleFonts.bebasNeue(
                            fontSize: isStory ? 74 * scale : 62 * scale, 
                            color: Colors.white, 
                            letterSpacing: 8 * scale
                          )
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 35 * scale, vertical: 30 * scale),
                    child: Column(
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.amber, size: 45 * scale),
                        const Spacer(),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: constraints.maxWidth - (70 * scale),
                            child: Text(
                              _contentBody, 
                              textAlign: TextAlign.center, 
                              style: GoogleFonts.playfairDisplay(
                                fontSize: isStory ? 24 : 20, // Let scale handled by FittedBox mostly
                                height: 1.6, 
                                fontWeight: FontWeight.bold, 
                                color: bgColor.withValues(alpha: 0.9)
                              )
                            ),
                          ),
                        ),
                        const Spacer(),
                        _buildSectionBoundary(title: "Tandaan natin", content: _reflection, color: bgColor),
                        _buildSectionBoundary(title: "Anong masasabi niyo?", content: _question, color: Colors.teal.shade900),
                        const Spacer(),
                        Text(
                          'KONSI MATTHEW LAGAYA', 
                          style: GoogleFonts.oswald(
                            fontSize: 18 * scale, 
                            fontWeight: FontWeight.bold, 
                            letterSpacing: 4 * scale, 
                            color: bgColor
                          )
                        ),
                        _buildHashtagFooter(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      );
    }
  }

  // 2️⃣ SATURDAY (INSPIRATIONAL - QUOTES) - Unique Aesthetic
  Widget _saturdayVariants() {
    final bgColor = const Color(0xFF1B5E20);
    final deepForest = const Color(0xFF0A2E16);
    final goldAccent = const Color(0xFFC5A059); // Gold
    final isStory = _selectedSize == 'Story';

    if (_designVariant == 0) {
      // THE "GOLDEN QUOTE" - GREEN DOMINANT GOLD ACCENT
      return LayoutBuilder(
        builder: (context, constraints) {
          double scale = constraints.maxWidth / 400;
          return Container(
            padding: EdgeInsets.all(35 * scale),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: goldAccent.withValues(alpha: 0.4), width: 12 * scale),
            ),
            child: Column(
              children: [
                Icon(Icons.format_quote_rounded, color: goldAccent, size: isStory ? 80 * scale : 60 * scale),
                SizedBox(height: 20 * scale),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: 350,
                        child: Text(
                          '“$_contentBody”', 
                          textAlign: TextAlign.center, 
                          style: GoogleFonts.merriweather(
                            fontSize: isStory ? 32 : 26, 
                            color: Colors.white, 
                            fontWeight: FontWeight.w900, 
                            height: 1.5, 
                            fontStyle: FontStyle.italic
                          )
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20 * scale),
                Container(height: 2 * scale, width: 80 * scale, color: goldAccent),
                SizedBox(height: 20 * scale),
                _buildSectionBoundary(title: "Leadership Lesson", content: _reflection, color: goldAccent, textColor: Colors.white70),
                _buildSectionBoundary(title: "Community Mission", content: _question, color: Colors.lightGreen.shade200, textColor: Colors.white70),
                const Spacer(),
                Text('SATURDAY STRENGTH', style: GoogleFonts.montserrat(fontSize: 12 * scale, color: goldAccent, fontWeight: FontWeight.bold, letterSpacing: 6 * scale)),
                SizedBox(height: 8 * scale),
                Text('KONSI MATTHEW LAGAYA', style: GoogleFonts.oswald(fontSize: 18 * scale, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2 * scale)),
                _buildHashtagFooter(color: Colors.white38),
              ],
            ),
          );
        }
      );
    } 
    else if (_designVariant == 1) {
      // THE "MODERN SIDEBAR"
      return Container(
        width: double.infinity,
        color: const Color(0xFFFAFDFB),
        child: Row(
          children: [
            Container(width: isStory ? 25 : 15, decoration: BoxDecoration(gradient: LinearGradient(colors: [deepForest, bgColor], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(isStory ? 40 : 30, isStory ? 60 : 45, isStory ? 40 : 30, isStory ? 60 : 45),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('SATURDAY STRENGTH', style: GoogleFonts.oswald(fontSize: 12, color: bgColor, letterSpacing: 4, fontWeight: FontWeight.bold)),
                        Image.asset('assets/seal.png', width: isStory ? 70 : 50, height: isStory ? 70 : 50, errorBuilder: (c, e, s) => const SizedBox()),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 350,
                          child: Text(
                            '“$_contentBody”', 
                            style: GoogleFonts.libreBaskerville(
                              fontSize: isStory ? 26 : 21, 
                              color: deepForest, 
                              height: 1.6, 
                              fontWeight: FontWeight.bold
                            )
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildSectionBoundary(title: "KONSI'S VISION", content: _reflection, color: bgColor),
                    _buildSectionBoundary(title: "COMMUNITY PULSE", content: _question, color: Colors.blueGrey),
                    const SizedBox(height: 15),
                    _buildHashtagFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    else {
      // THE "AUTHORITY OVERLAY" - GREEN DOMINANT
      return LayoutBuilder(
        builder: (context, constraints) {
          double scale = constraints.maxWidth / 400;
          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [deepForest, bgColor], 
                begin: Alignment.bottomLeft, 
                end: Alignment.topRight
              ),
            ),
            padding: EdgeInsets.all(isStory ? 50 * scale : 40 * scale),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight, 
                  child: Image.asset('assets/seal.png', width: isStory ? 80 * scale : 65 * scale, height: isStory ? 80 * scale : 65 * scale, errorBuilder: (c, e, s) => const SizedBox())
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.all(isStory ? 45 * scale : 35 * scale),
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    borderRadius: BorderRadius.circular(isStory ? 30 * scale : 20 * scale), 
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 30)]
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.format_quote_rounded, color: bgColor, size: isStory ? 60 * scale : 40 * scale),
                      SizedBox(height: 15 * scale),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: 300,
                          child: Text(
                            '“$_contentBody”', 
                            textAlign: TextAlign.center, 
                            style: GoogleFonts.poppins(
                              fontSize: isStory ? 24 : 18, 
                              color: deepForest, 
                              fontWeight: FontWeight.w800, 
                              height: 1.5
                            )
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isStory) const Spacer(),
                SizedBox(height: 15 * scale),
                _buildSectionBoundary(title: "Leadership Note", content: _reflection, color: Colors.white, textColor: Colors.white),
                _buildSectionBoundary(title: "Share your thoughts", content: _question, color: Colors.lightGreenAccent, textColor: Colors.white),
                const Spacer(),
                Text(
                  'KONSI MATTHEW LAGAYA', 
                  style: GoogleFonts.oswald(
                    fontSize: 14 * scale, 
                    color: Colors.white54, 
                    letterSpacing: 4 * scale
                  )
                ),
                _buildHashtagFooter(color: Colors.white38),
              ],
            ),
          );
        }
      );
    }
  }


  // 3️⃣ SUNDAY (BIBLE VERSE)
  Widget _sundayVariants() {
    final bgColor = const Color(0xFF1B5E20);
    final isStory = _selectedSize == 'Story';

    if (_designVariant == 0) {
      // THE "SACRED HEADER" - GREEN PULSE
      return LayoutBuilder(
        builder: (context, constraints) {
          double scale = constraints.maxWidth / 400;
          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, 
                end: Alignment.bottomCenter, 
                colors: [const Color(0xFF2E7D32), const Color(0xFF0A2E16), bgColor]
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: isStory ? 130 * scale : 110 * scale,
                  padding: EdgeInsets.only(bottom: 25 * scale),
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(50 * scale), 
                      bottomRight: Radius.circular(50 * scale)
                    )
                  ),
                  child: Center(child: Image.asset('assets/seal.png', width: 65 * scale)),
                ),
                SizedBox(height: 30 * scale),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40 * scale),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: 400,
                          child: Column(
                            children: [
                              Text(
                                _bibleVerse, 
                                textAlign: TextAlign.center, 
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: isStory ? 32 : 26, 
                                  fontWeight: FontWeight.w900, 
                                  color: const Color(0xFFFFD700), 
                                  height: 1.5,
                                  shadows: [BoxShadow(color: Colors.black45, blurRadius: 10)]
                                )
                              ),
                              SizedBox(height: 35 * scale),
                              _buildSectionBoundary(title: "Reflection", content: _reflection, color: Colors.white, textColor: Colors.white),
                              _buildSectionBoundary(title: "Community Prayer", content: _question, color: Colors.lightGreenAccent, textColor: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 25 * scale),
                Text(
                  'SUNDAY BLESSING', 
                  style: GoogleFonts.oswald(
                    fontSize: 14 * scale, 
                    color: Colors.white70, 
                    letterSpacing: 4 * scale, 
                    fontWeight: FontWeight.bold
                  )
                ),
                _buildHashtagFooter(color: Colors.white30),
                SizedBox(height: 40 * scale),
              ],
            ),
          );
        }
      );
    } 
    else if (_designVariant == 1) {
      // THE "GOLDEN CROSS"
      return Container(
        width: double.infinity,
        color: const Color(0xFFFAF9F6),
        padding: EdgeInsets.all(isStory ? 60 : 45),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Image.asset('assets/seal.png', width: 60),
                Text('SUNDAY LIGHT', style: GoogleFonts.oswald(fontWeight: FontWeight.w800, fontSize: 13, color: bgColor, letterSpacing: 3)),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: SizedBox(
                  width: 380,
                  child: Text(
                    _bibleVerse, 
                    textAlign: TextAlign.center, 
                    style: GoogleFonts.cinzel(
                      fontSize: isStory ? 26 : 20, 
                      fontWeight: FontWeight.w900, 
                      color: bgColor, 
                      height: 1.6
                    )
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionBoundary(title: "Konsi's Reflection", content: _reflection, color: bgColor),
            _buildSectionBoundary(title: "Pagnilayan natin", content: _question, color: Colors.blueGrey),
            const Spacer(),
            Text('KONSI MATTHEW LAGAYA', style: GoogleFonts.oswald(fontSize: 14, color: Colors.grey, letterSpacing: 4)),
            _buildHashtagFooter(),
          ],
        ),
      );
    }
    else {
      // THE "DIVINE BOX" - FULL GREEN SACRED
      return LayoutBuilder(
        builder: (context, constraints) {
          double scale = constraints.maxWidth / 400;
          return Container(
            width: double.infinity,
            color: bgColor,
            padding: EdgeInsets.all(30 * scale),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 4 * scale)
              ),
              padding: EdgeInsets.all(40 * scale),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/seal.png', width: 90 * scale),
                  SizedBox(height: 25 * scale),
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: 400,
                          child: Text(
                            _bibleVerse, 
                            textAlign: TextAlign.center, 
                            style: GoogleFonts.bebasNeue(
                              fontSize: isStory ? 54 : 42, 
                              color: const Color(0xFFFFD700), 
                              letterSpacing: 4 * scale
                            )
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20 * scale),
                  _buildSectionBoundary(title: "Para sa ating Bayan", content: _reflection, color: Colors.white, textColor: Colors.white),
                  _buildSectionBoundary(title: "Share your thoughts", content: _question, color: Colors.white, textColor: Colors.white),
                  SizedBox(height: 15 * scale),
                  _buildHashtagFooter(color: Colors.white30),
                ],
              ),
            ),
          );
        }
      );
    }
  }


  Widget _buildSectionBoundary({required String title, required String content, required Color color, Color textColor = Colors.black87}) {
    final isStory = _selectedSize == 'Story';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.oswald(
              fontSize: 11, 
              fontWeight: FontWeight.bold, 
              color: color, 
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: isStory ? 14 : 12, 
              color: textColor, 
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
            maxLines: isStory ? 4 : 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildHashtagFooter({Color? color}) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Text(
          '#SerbisyongTapat #KeepMovingAngono #SerbisyongMaePuso',
          textAlign: TextAlign.center,
          style: GoogleFonts.oswald(
            fontSize: 9, 
            color: color ?? Colors.grey.shade500, 
            letterSpacing: 1,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

   Future<void> _deleteScheduledPost(ScheduledPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Masterpiece?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove this scheduled post for ${DateFormat('MMM d').format(post.scheduledDate)}?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await StorageService.deleteScheduledPost(post.id);
      await _loadScheduledPosts();
      _showSnackbar('Post deleted successfully');
    }
  }

  Widget _buildScheduleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Content Calendar', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: const Color(0xFF1B5E20))),
          const SizedBox(height: 16),
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2027, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedCalendarDay, day),
            onDaySelected: (selectedDay, focusedDay) => setState(() {
              _selectedCalendarDay = selectedDay;
              _focusedDay = focusedDay;
            }),
            calendarFormat: CalendarFormat.month,
            eventLoader: _getEventsForDay,
            headerStyle: HeaderStyle(formatButtonVisible: false, titleCentered: true, titleTextStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF1B5E20))),
            calendarStyle: const CalendarStyle(
              selectedDecoration: BoxDecoration(color: Color(0xFF1B5E20), shape: BoxShape.circle),
              todayDecoration: BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
              markerDecoration: BoxDecoration(color: Color(0xFF1B5E20), shape: BoxShape.circle),
            ),
          ),
          const SizedBox(height: 24),
          if (_selectedCalendarDay != null) ...[
            Text('Posts on ${DateFormat('MMM d, yyyy').format(_selectedCalendarDay!)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF1B5E20))),
            const SizedBox(height: 12),
            if (_getEventsForDay(_selectedCalendarDay!).isEmpty) Text('No posts scheduled.')
            else ..._getEventsForDay(_selectedCalendarDay!).map((p) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(8),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(p.imagePath), width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => const Icon(Icons.image)),
                ),
                title: Text('Scheduled Post', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text(DateFormat('h:mm a').format(p.scheduledDate), style: GoogleFonts.poppins(fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.download, size: 20, color: Color(0xFF1B5E20)),
                      onPressed: () => _downloadScheduledPost(p),
                      tooltip: 'Save to Gallery',
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, size: 20, color: Colors.purple),
                      onPressed: () => _shareScheduledPost(p),
                      tooltip: 'Share',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      onPressed: () => _deleteScheduledPost(p),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }

  Future<void> _downloadScheduledPost(ScheduledPost post) async {
    await _showDownloadPicker(post, isShare: false);
  }

  Future<void> _shareScheduledPost(ScheduledPost post) async {
    await _showDownloadPicker(post, isShare: true);
  }

  Future<void> _showDownloadPicker(ScheduledPost post, {required bool isShare}) async {
    if (post.category == null) {
      if (isShare) {
        await Share.shareXFiles([XFile(post.imagePath)]);
      } else {
        await Gal.putImage(post.imagePath);
        _showSnackbar('Masterpiece saved to gallery');
      }
      return;
    }

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose Mastery Size', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF1B5E20))),
            const SizedBox(height: 8),
            Text('Existing scheduled post will be re-rendered in your selected size.', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildPickerOption(context, 'Post', 'Feed Post (4:5)', Icons.grid_view_rounded),
                const SizedBox(width: 16),
                _buildPickerOption(context, 'Story', 'Full Story (9:16)', Icons.stay_current_portrait_rounded),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() => _isSaving = true);
      try {
        final oldDay = _selectedDay;
        final oldTitle = _generatedTitle;
        final oldBody = _contentBody;
        final oldVerse = _bibleVerse;
        final oldReflection = _reflection;
        final oldQuestion = _question;
        final oldVariant = _designVariant;
        final oldSize = _selectedSize;

        setState(() {
          _selectedDay = post.category!;
          _generatedTitle = post.title ?? "";
          _contentBody = post.body ?? "";
          _bibleVerse = post.verse ?? "";
          _reflection = post.reflection ?? "";
          _question = post.question ?? "";
          _designVariant = post.designVariant ?? 0;
          _selectedSize = result;
        });

        await Future.delayed(const Duration(milliseconds: 100));
        final bytes = await _captureCard();
        
        setState(() {
          _selectedDay = oldDay;
          _generatedTitle = oldTitle;
          _contentBody = oldBody;
          _bibleVerse = oldVerse;
          _reflection = oldReflection;
          _question = oldQuestion;
          _designVariant = oldVariant;
          _selectedSize = oldSize;
        });

        if (bytes == null) throw Exception('Capture failed');

        final tempDir = await getTemporaryDirectory();
        final fileName = 'redownload_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes);

        if (isShare) {
          await Share.shareXFiles([XFile(file.path)]);
        } else {
          await Gal.putImage(file.path);
          _showSnackbar('Masterpiece ($result) saved to gallery');
        }
      } catch (e) {
        _showSnackbar('Error: $e');
      } finally {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildPickerOption(BuildContext context, String value, String label, IconData icon) {
    return Expanded(
      child: GestureDetector(
        onTap: () => Navigator.pop(context, value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F8E9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1B5E20), width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFF1B5E20), size: 32),
              const SizedBox(height: 12),
              Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF1B5E20))),
            ],
          ),
        ),
      ),
    );
  }
}

// ============== CUSTOM CLIPPERS (Specialized Designs) ============== 

/// Natural torn paper effect for Monday
class TornPaperClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(15, 0);
    double step = 8;
    for (double i = 0; i <= size.height; i += step) {
      double x = (i / step).floor() % 2 == 0 ? 8 : 0;
      path.lineTo(x, i);
    }
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// Extreme side tear for Monday Variant 1
class SideTearClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.moveTo(size.width, 0);
    path.lineTo(0, 0);
    double step = 12;
    for (double i = 0; i <= size.height; i += step) {
      double x = (i / step).floor() % 2 == 0 ? 15 : 0;
      path.lineTo(x, i);
    }
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// Bottom tear for Monday Variant 2
class BottomTearClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 20);
    double step = 10;
    for (double i = 0; i <= size.width; i += step) {
      double y = (i / step).floor() % 2 == 0 ? size.height : size.height - 15;
      path.lineTo(i, y);
    }
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
