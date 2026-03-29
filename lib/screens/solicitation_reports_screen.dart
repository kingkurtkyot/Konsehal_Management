import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../services/settings_service.dart';
import '../widgets/help_legend_dialog.dart';
import '../models/schedule_event.dart';
import '../models/solicitation.dart';
import '../services/storage_service.dart';

class SolicitationReportsScreen extends StatefulWidget {
  const SolicitationReportsScreen({super.key});

  @override
  State<SolicitationReportsScreen> createState() => _SolicitationReportsScreenState();
}

class _SolicitationReportsScreenState extends State<SolicitationReportsScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  List<Solicitation> _allSolicitations = [];
  List<ScheduleEvent> _allEvents = [];
  bool _isLoading = true;
  late TabController _tabController;
  String _selectedYear = DateTime.now().year.toString();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final solicitations = await StorageService.loadSolicitations();
    final events = await StorageService.loadScheduleEvents();
    if (!mounted) return;
    setState(() {
      _allSolicitations = solicitations;
      _allEvents = events;
      _isLoading = false;
    });
  }

  // ─── SOLICITATION ANALYTICS ─────────────────────────────────────────────────

  int get _totalSolicitations => _allSolicitations.length;
  int get _pendingSolicitations => _allSolicitations.where((s) => s.status == SolicitationStatus.pending).length;
  int get _completedSolicitations => _allSolicitations.where((s) => s.status == SolicitationStatus.completed).length;

  double get _completionRate {
    if (_totalSolicitations == 0) return 0;
    return (_completedSolicitations / _totalSolicitations) * 100;
  }

  // ─── YEARLY BREAKDOWN ────────────────────────────────────────────────────────

  Map<int, Map<String, dynamic>> get _yearlyBreakdown {
    final result = <int, Map<String, dynamic>>{};
    
    for (final s in _allSolicitations) {
      final date = s.parsedTargetDate;
      if (date == null) continue;
      final year = date.year;
      result.putIfAbsent(year, () => {'pending': 0, 'completed': 0, 'requested': 0.0, 'given': 0.0});
      
      if (s.status == SolicitationStatus.pending) {
        result[year]!['pending'] = (result[year]!['pending'] ?? 0) + 1;
      } else {
        result[year]!['completed'] = (result[year]!['completed'] ?? 0) + 1;
        // Financials
        result[year]!['requested'] = (result[year]!['requested'] ?? 0.0) + s.numericAmountRequested;
        result[year]!['given'] = (result[year]!['given'] ?? 0.0) + s.numericAmountGiven;
      }
    }
    return result;
  }

  // ─── MONTHLY BREAKDOWN ──────────────────────────────────────────────────────

  Map<int, Map<String, dynamic>> get _monthlyBreakdown {
    final result = <int, Map<String, dynamic>>{};
    final year = int.tryParse(_selectedYear) ?? DateTime.now().year;
    
    for (final s in _allSolicitations) {
      final date = s.parsedTargetDate;
      if (date == null || date.year != year) continue;
      final month = date.month;
      result.putIfAbsent(month, () => {'pending': 0, 'completed': 0, 'requested': 0.0, 'given': 0.0});
      
      if (s.status == SolicitationStatus.pending) {
        result[month]!['pending'] = (result[month]!['pending'] ?? 0) + 1;
      } else {
        result[month]!['completed'] = (result[month]!['completed'] ?? 0) + 1;
        // Financials (Only including completed for performance tracking)
        result[month]!['requested'] = (result[month]!['requested'] ?? 0.0) + s.numericAmountRequested;
        result[month]!['given'] = (result[month]!['given'] ?? 0.0) + s.numericAmountGiven;
      }
    }
    return result;
  }

  // ─── EVENT ANALYTICS ────────────────────────────────────────────────────────

  int get _totalEvents => _allEvents.length;
  
  Map<String, int> get _eventsByDay {
    final result = <String, int>{};
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    for (final day in days) {
      result[day] = _allEvents.where((e) => e.dayOfWeek.toLowerCase() == day.toLowerCase()).length;
    }
    return result;
  }

  // ─── EXPORT FUNCTIONALITY ───────────────────────────────────────────────────

  Future<void> _exportMasterpieceReport() async {
    try {
      // Generate comprehensive report text
      final now = DateTime.now();
      final reportDate = DateFormat('MMMM d, yyyy - h:mm a').format(now);
      final year = int.tryParse(_selectedYear) ?? now.year;
      
      final StringBuffer report = StringBuffer();
      report.writeln('═' * 70);
      report.writeln('BARANGAY ORGANIZER - MASTERPIECE REPORT');
      report.writeln('═' * 70);
      report.writeln('Prepared for: Konsehal Matthew Lagaya');
      report.writeln('Report Date: $reportDate');
      report.writeln('Analysis Period: Year $year');
      report.writeln('');
      
      // Executive Summary
      report.writeln('EXECUTIVE SUMMARY');
      report.writeln('─' * 70);
      report.writeln('Total Solicitations: $_totalSolicitations');
      report.writeln('  └─ Completed: $_completedSolicitations');
      report.writeln('  └─ Pending: $_pendingSolicitations');
      report.writeln('Completion Rate: ${_completionRate.toStringAsFixed(1)}%');
      report.writeln('Total Events Scheduled: $_totalEvents');
      report.writeln('');
      
      // Year Overview
      report.writeln('YEAR-BY-YEAR OVERVIEW');
      report.writeln('─' * 70);
      final yearlyData = _yearlyBreakdown;
      final sortedYearlyEntries = yearlyData.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
      for (final entry in sortedYearlyEntries) {
        final completed = entry.value['completed'] ?? 0;
        final pending = entry.value['pending'] ?? 0;
        final requested = entry.value['requested'] ?? 0.0;
        final given = entry.value['given'] ?? 0.0;
        report.writeln('${entry.key}: ${completed + pending} total ($completed completed, $pending pending)');
        if (completed > 0) {
          report.writeln('  └─ Financials: ₱${given.toStringAsFixed(2)} provided of ₱${requested.toStringAsFixed(2)} requested');
          report.writeln('  └─ Gap/Discrepancy: ₱${(requested - given).toStringAsFixed(2)}');
        }
      }
      report.writeln('');
      
      // Monthly Details for Selected Year
      report.writeln('MONTHLY BREAKDOWN & DISCREPANCIES - YEAR $year');
      report.writeln('─' * 70);
      const months = ['January', 'February', 'March', 'April', 'May', 'June',
                      'July', 'August', 'September', 'October', 'November', 'December'];
      final monthlyData = _monthlyBreakdown;
      for (int i = 1; i <= 12; i++) {
        final completed = monthlyData[i]?['completed'] ?? 0;
        final pending = monthlyData[i]?['pending'] ?? 0;
        final total = completed + pending;
        final requested = monthlyData[i]?['requested'] ?? 0.0;
        final given = monthlyData[i]?['given'] ?? 0.0;
        
        if (total > 0) {
          report.writeln('${months[i - 1]}: $total requests ($completed completed)');
          if (completed > 0) {
            report.writeln('  └─ Financial Performance: ₱${given.toStringAsFixed(2)} given / ₱${requested.toStringAsFixed(2)} requested');
            report.writeln('  └─ Current Gap: ₱${(requested - given).toStringAsFixed(2)}');
          }
        }
      }
      report.writeln('');
      
      // Event Distribution
      report.writeln('SCHEDULED EVENTS BY DAY OF WEEK');
      report.writeln('─' * 70);
      final eventsByDay = _eventsByDay;
      eventsByDay.forEach((day, count) {
        if (count > 0) {
          report.writeln('$day: $count events');
        }
      });
      report.writeln('');
      
      // Key Insights
      report.writeln('KEY INSIGHTS & OBSERVATIONS');
      report.writeln('─' * 70);
      report.writeln('• Community engagement through solicitation management');
      report.writeln('• Consistent scheduling of events for community benefit');
      report.writeln('• Track record of fulfilling community requests');
      report.writeln('• Strong organizational capacity demonstrated');
      report.writeln('');
      
      // Footer
      report.writeln('═' * 70);
      report.writeln('SERBISYONG TAPAT PARA SA LAHAT');
      report.writeln('Konsehal Matthew Lagaya');
      report.writeln('═' * 70);
      
      // Save and share
      final textReport = report.toString();
      
      // Share directly without saving to file (web compatible)
      await Share.share(
        textReport,
        subject: 'Barangay Organizer Masterpiece Report - Year $year',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Report shared successfully!'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _showReportsHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => HelpLegendDialog(
        title: 'Masterpiece Reports',
        items: [
          LegendItem(
            icon: Icons.dashboard,
            label: 'Executive Overview',
            description: 'Quick snapshot of total solicitations, completion status, and event counts.',
            color: const Color(0xFF1B5E20),
          ),
          LegendItem(
            icon: Icons.assessment,
            label: 'Yearly Performance',
            description: 'Tracks service volume and success rates (percentage of completed requests) annually.',
            color: Colors.blue.shade700,
          ),
          LegendItem(
            icon: Icons.calendar_month,
            label: 'Monthly Trend',
            description: 'Visualizes workload distribution across months to identify peak service periods.',
            color: Colors.orange.shade700,
          ),
          LegendItem(
            icon: Icons.event_note,
            label: 'Event Distribution',
            description: 'Analyzes which days of the week are busiest for community activities.',
            color: Colors.purple.shade700,
          ),
          LegendItem(
            icon: Icons.file_download,
            label: 'Export Report',
            description: 'Generates a professional text-based report for sharing via official channels.',
            color: const Color(0xFF1B5E20),
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
        title: const Text('Masterpiece Reports'),
        elevation: 0,
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: AppSettingsService.showHelpLegends,
            builder: (context, showHelp, _) {
              if (!showHelp) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.help_outline),
                onPressed: () => _showReportsHelp(context),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard, size: 18)),
            Tab(text: 'Year Graph', icon: Icon(Icons.assessment, size: 18)),
            Tab(text: 'Monthly', icon: Icon(Icons.calendar_month, size: 18)),
            Tab(text: 'Events', icon: Icon(Icons.event_note, size: 18)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildYearGraphTab(),
                _buildMonthlyTab(),
                _buildEventsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Executive KPIs
          Row(
            children: [
              Expanded(child: _buildKPICard('Total\nSolicitations', _totalSolicitations.toString(), const Color(0xFF1B5E20))),
              const SizedBox(width: 10),
              Expanded(child: _buildKPICard('Completed', _completedSolicitations.toString(), const Color(0xFF27AE60))),
              const SizedBox(width: 10),
              Expanded(child: _buildKPICard('Pending', _pendingSolicitations.toString(), const Color(0xFF52B788))),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Completion Rate
          _buildCompletionRateCard(),
          
          const SizedBox(height: 20),
          
          // Events Overview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Events Overview',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF1B5E20)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildKPICard('Total Events', _totalEvents.toString(), const Color(0xFF2D6A4F), compact: true),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildKPICard('This Month', _allEvents.where((e) => e.parsedDate?.month == DateTime.now().month).length.toString(), const Color(0xFF40916C), compact: true),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Export & Share
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _exportMasterpieceReport,
              icon: const Icon(Icons.file_download),
              label: const Text('Export Masterpiece Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildYearGraphTab() {
    final yearlyData = _yearlyBreakdown;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Year-Over-Year Analysis',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF1B5E20)),
          ),
          const SizedBox(height: 16),
          
          // Year Selection
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Text('View: ', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: yearlyData.keys
                          .map((year) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(year.toString()),
                              selected: _selectedYear == year.toString(),
                              onSelected: (selected) => setState(() => _selectedYear = year.toString()),
                              selectedColor: const Color(0xFF1B5E20),
                              labelStyle: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: _selectedYear == year.toString() ? Colors.white : Colors.grey.shade700,
                              ),
                            ),
                          ))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Simplified Yearly Summary Cards
          if (yearlyData.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    'Yearly Performance',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: const Color(0xFF1B5E20)),
                  ),
                  const SizedBox(height: 16),
                  // Render each year as a clean, wide masterpiece card
                  ...yearlyData.entries
                      .toList()
                      .reversed
                      .map((entry) {
                    final completed = entry.value['completed'] ?? 0;
                    final pending = entry.value['pending'] ?? 0;
                    final total = completed + pending;
                    final rate = total == 0 ? 0 : (completed / total);
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF1B5E20).withValues(alpha: 0.1)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${entry.key}',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 22, color: const Color(0xFF1B5E20)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${(rate * 100).toStringAsFixed(0)}% Success',
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1B5E20)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMiniStat('Total', '$total', Colors.blue.shade800),
                              ),
                              Expanded(
                                child: _buildMiniStat('Done', '$completed', Colors.green.shade800),
                              ),
                              Expanded(
                                child: _buildMiniStat('Pending', '$pending', Colors.orange.shade800),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: rate.toDouble(),
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: const AlwaysStoppedAnimation(Color(0xFF1B5E20)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMonthlyTab() {
    final monthlyData = _monthlyBreakdown;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Year $_selectedYear - Monthly Breakdown',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: const Color(0xFF1B5E20)),
          ),
          const SizedBox(height: 16),
          
          // Clean Monthly List with Micro-Progress Bars
          ...List.generate(
            12,
            (i) {
              final month = i + 1;
              final completed = monthlyData[month]?['completed'] ?? 0;
              final pending = monthlyData[month]?['pending'] ?? 0;
              final requested = monthlyData[month]?['requested'] ?? 0.0;
              final given = monthlyData[month]?['given'] ?? 0.0;
              final total = completed + pending;
              final rate = total == 0 ? 0.0 : (completed / total);
              
              if (total == 0) return const SizedBox.shrink();
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          months[i],
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black87),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$completed / $total Fulfilled',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 13, color: const Color(0xFF1B5E20)),
                            ),
                            if (requested > 0)
                              Text(
                                'Gap: ₱${(requested - given).toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: rate,
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade100,
                              valueColor: const AlwaysStoppedAnimation(Color(0xFF1B5E20)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('₱${given.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildEventsTab() {
    final eventsByDay = _eventsByDay;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scheduled Events Distribution',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF1B5E20)),
          ),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Events by Day of Week', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 16),
                
                ...eventsByDay.entries.map((entry) {
                  final colors = {
                    'Monday': const Color(0xFF1B5E20),
                    'Tuesday': const Color(0xFF2D6A4F),
                    'Wednesday': const Color(0xFF40916C),
                    'Thursday': const Color(0xFF52B788),
                    'Friday': const Color(0xFF74C69D),
                    'Saturday': const Color(0xFF95D5B2),
                    'Sunday': const Color(0xFFB7E4C7),
                  };
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.key, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                            Text('${entry.value}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: entry.value == 0 ? 0 : (entry.value / eventsByDay.values.reduce((a, b) => a > b ? a : b)),
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation(colors[entry.key] ?? Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Event Statistics
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Statistics', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Total Events', _totalEvents.toString()),
                    _buildStatItem('Busiest Day', eventsByDay.entries.isEmpty ? 'N/A' : eventsByDay.entries.reduce((a, b) => a.value > b.value ? a : b).key),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 18, color: color),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ─── HELPER WIDGETS ──────────────────────────────────────────────────────────

  Widget _buildKPICard(String label, String value, Color color, {bool compact = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w800,
              fontSize: compact ? 20 : 24,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: compact ? 11 : 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionRateCard() {
    final percentage = _completionRate;
    final color = percentage >= 80 ? Colors.green : percentage >= 50 ? Colors.orange : Colors.red;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Completion Rate', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
              Text('${percentage.toStringAsFixed(1)}%',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 10,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 20, color: const Color(0xFF1B5E20))),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}
