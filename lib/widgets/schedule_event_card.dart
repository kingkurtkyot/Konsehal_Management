import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/schedule_event.dart';

class ScheduleEventCard extends StatelessWidget {
  final ScheduleEvent event;
  final VoidCallback? onExport;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onLongPress;

  const ScheduleEventCard({
    super.key,
    required this.event,
    this.onExport,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onToggleSelect,
    this.onLongPress,
  });

  Color _getDayColor(String day) {
    switch (day.toLowerCase()) {
      case 'monday': return const Color(0xFF2E86C1);
      case 'tuesday': return const Color(0xFF1A9644);
      case 'wednesday': return const Color(0xFF8E44AD);
      case 'thursday': return const Color(0xFFD35400);
      case 'friday': return const Color(0xFFC0392B);
      case 'saturday': return const Color(0xFF1B5E20);
      case 'sunday': return const Color(0xFFB7950B);
      default: return const Color(0xFF5D6D7E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayColor = _getDayColor(event.dayOfWeek);

    return GestureDetector(
      onLongPress: onLongPress,
      onTap: isSelectionMode ? onToggleSelect : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: isSelected
              ? Border.all(color: const Color(0xFF1B5E20), width: 2.5)
              : Border.all(color: Colors.transparent, width: 2.5),
        ),
        child: Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Color sidebar
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: dayColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),

                // Selection checkbox
                if (isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (_) => onToggleSelect?.call(),
                      activeColor: const Color(0xFF1B5E20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Row(
                          children: [
                            // Date chip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: dayColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: dayColor.withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                event.date,
                                style: GoogleFonts.poppins(
                                  color: dayColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Day chip
                            Text(
                              event.dayOfWeek.toUpperCase(),
                              style: GoogleFonts.poppins(
                                color: dayColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                                letterSpacing: 1,
                              ),
                            ),
                            const Spacer(),
                            // Export button
                            if (onExport != null && !isSelectionMode)
                              InkWell(
                                onTap: onExport,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.download_rounded, size: 18, color: Colors.blue.shade700),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Theme / Title
                        Text(
                          event.theme,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Info Section
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Colors.white.withValues(alpha: 0.05) 
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade600),
                                  const SizedBox(width: 8),
                                  Text(
                                    event.time,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).textTheme.bodySmall?.color,
                                    ),
                                  ),
                                ],
                              ),
                              if (event.location.isNotEmpty && event.location != 'Not specified') ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.location_on_rounded, size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        event.location,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Theme.of(context).textTheme.bodySmall?.color,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
