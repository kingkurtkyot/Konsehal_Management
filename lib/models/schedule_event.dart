class ScheduleEvent {
  final String id;
  final String date;
  final String time;
  final String dayOfWeek;
  final String theme;
  final String location;
  final String fullDescription;

  ScheduleEvent({
    required this.id,
    required this.date,
    required this.time,
    required this.dayOfWeek,
    required this.theme,
    required this.location,
    required this.fullDescription,
  });

  factory ScheduleEvent.fromJson(Map<String, dynamic> json) {
    final date = json['date'] ?? '';
    final dayOfWeek = json['dayOfWeek'] ?? '';
    
    // Auto-calculate dayOfWeek if missing or empty
    String computedDay = dayOfWeek;
    if (computedDay.isEmpty && date.isNotEmpty) {
      computedDay = _dayOfWeekFromDate(date);
    }

    return ScheduleEvent(
      id: json['id'] ?? 'evt_${DateTime.now().millisecondsSinceEpoch}',
      date: date,
      time: json['time'] ?? '',
      dayOfWeek: computedDay,
      theme: json['theme'] ?? '',
      location: json['location'] ?? '',
      fullDescription: json['fullDescription'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'time': time,
        'dayOfWeek': dayOfWeek,
        'theme': theme,
        'location': location,
        'fullDescription': fullDescription,
      };

  ScheduleEvent copyWith({
    String? id,
    String? date,
    String? time,
    String? dayOfWeek,
    String? theme,
    String? location,
    String? fullDescription,
  }) {
    return ScheduleEvent(
      id: id ?? this.id,
      date: date ?? this.date,
      time: time ?? this.time,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      theme: theme ?? this.theme,
      location: location ?? this.location,
      fullDescription: fullDescription ?? this.fullDescription,
    );
  }

  /// Parse date and get DateTime object
  DateTime? get parsedDate {
    try {
      final parts = date.split('/');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[2]),
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
      }
    } catch (_) {}
    return null;
  }

  /// Parse precise date and time for history auto-migration
  DateTime? get parsedDateTime {
    final tDate = parsedDate;
    if (tDate == null) return null;
    
    try {
      // Time format is typically "HH:MM AM/PM" or "HH:MM"
      final timeParts = time.trim().split(' ');
      if (timeParts.isEmpty) return tDate;
      
      final hhmm = timeParts[0].split(':');
      if (hhmm.length != 2) return tDate;
      
      int hour = int.tryParse(hhmm[0]) ?? 0;
      final int minute = int.tryParse(hhmm[1]) ?? 0;
      
      if (timeParts.length > 1) {
        final period = timeParts[1].toUpperCase();
        if (period == 'PM' && hour < 12) hour += 12;
        if (period == 'AM' && hour == 12) hour = 0;
      }
      
      return DateTime(tDate.year, tDate.month, tDate.day, hour, minute);
    } catch (_) {
      return tDate;
    }
  }

  /// Auto-calculate day of week from date string (MM/DD/YYYY)
  static String _dayOfWeekFromDate(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final dt = DateTime(
          int.parse(parts[2]),
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
        const days = [
          'Monday', 'Tuesday', 'Wednesday', 'Thursday',
          'Friday', 'Saturday', 'Sunday'
        ];
        return days[dt.weekday - 1];
      }
    } catch (_) {}
    return '';
  }
}
