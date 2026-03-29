import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/solicitation.dart';

class SolicitationCard extends StatelessWidget {
  final Solicitation solicitation;
  final VoidCallback? onMarkCompleted;
  final VoidCallback? onExport;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onLongPress;

  const SolicitationCard({
    super.key,
    required this.solicitation,
    this.onMarkCompleted,
    this.onExport,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onToggleSelect,
    this.onLongPress,
  });

  bool get isPending => solicitation.status == SolicitationStatus.pending;

  @override
  Widget build(BuildContext context) {
    final statusColor = isPending ? Colors.orange.shade700 : Colors.green.shade700;

    return GestureDetector(
      onLongPress: onLongPress,
      onTap: isSelectionMode ? onToggleSelect : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
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
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: checkbox (if selecting) + status badge + export
                Row(
                  children: [
                    if (isSelectionMode)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (_) => onToggleSelect?.call(),
                          activeColor: const Color(0xFF1B5E20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        isPending ? 'PENDING' : 'COMPLETED',
                        style: GoogleFonts.poppins(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
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
                const SizedBox(height: 16),

                // Organization / Person
                Text(
                  solicitation.organizationOrPerson,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),

                // Purpose
                Text(
                  solicitation.purpose,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),

                // Info Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.white.withValues(alpha: 0.05) 
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _infoRow(
                        context,
                        Icons.calendar_today_rounded,
                        'Target',
                        solicitation.targetDate.isNotEmpty
                            ? solicitation.targetDate
                            : 'Not specified',
                        Colors.blue.shade600,
                      ),
                      if (solicitation.contactPerson.isNotEmpty || solicitation.contactNumber.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: solicitation.contactNumber.isNotEmpty ? () {
                            Clipboard.setData(ClipboardData(text: solicitation.contactNumber));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Number copied!', style: GoogleFonts.poppins()),
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          } : null,
                          child: _infoRow(
                            context,
                            Icons.person_rounded,
                            'Contact',
                            '${solicitation.contactPerson}${solicitation.contactNumber.isNotEmpty ? " (${solicitation.contactNumber})" : ""}',
                            Colors.purple.shade600,
                            trailing: solicitation.contactNumber.isNotEmpty ? Icon(Icons.copy_rounded, size: 14, color: Colors.grey.shade400) : null,
                          ),
                        ),
                      ],
                      if (!isPending && solicitation.amountGiven != null) ...[
                        const SizedBox(height: 10),
                        _infoRow(
                          context,
                          Icons.payments_rounded,
                          'Given',
                          solicitation.amountGiven!,
                          Colors.green.shade600,
                        ),
                      ],
                    ],
                  ),
                ),

                if (onMarkCompleted != null && !isSelectionMode) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onMarkCompleted,
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: Text(
                        'Mark Completed',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color iconColor, {
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: GoogleFonts.poppins(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: GoogleFonts.poppins(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (trailing != null) ...[trailing],
      ],
    );
  }
}
