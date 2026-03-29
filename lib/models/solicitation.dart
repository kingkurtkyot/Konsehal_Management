enum SolicitationStatus { pending, completed }

class Solicitation {
  final String id;
  final String organizationOrPerson;
  final String purpose;
  final String targetDate;
  final String contactPerson;
  final String contactNumber;
  final SolicitationStatus status;
  final String? amountRequested;
  final String? amountGiven;
  final String? additionalNotes;
  final String? completedDate;

  Solicitation({
    required this.id,
    required this.organizationOrPerson,
    required this.purpose,
    required this.targetDate,
    required this.contactPerson,
    required this.contactNumber,
    required this.status,
    this.amountRequested,
    this.amountGiven,
    this.additionalNotes,
    this.completedDate,
  });

  factory Solicitation.fromJson(Map<String, dynamic> json) {
    return Solicitation(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      organizationOrPerson: json['organizationOrPerson'] ?? '',
      purpose: json['purpose'] ?? '',
      targetDate: json['targetDate'] ?? '',
      contactPerson: json['contactPerson'] ?? '',
      contactNumber: json['contactNumber'] ?? '',
      status: json['status'] == 'completed'
          ? SolicitationStatus.completed
          : SolicitationStatus.pending,
      amountRequested: json['amountRequested'],
      amountGiven: json['amountGiven'],
      additionalNotes: json['additionalNotes'],
      completedDate: json['completedDate'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'organizationOrPerson': organizationOrPerson,
        'purpose': purpose,
        'targetDate': targetDate,
        'contactPerson': contactPerson,
        'contactNumber': contactNumber,
        'status': status == SolicitationStatus.completed ? 'completed' : 'pending',
        'amountRequested': amountRequested,
        'amountGiven': amountGiven,
        'additionalNotes': additionalNotes,
        'completedDate': completedDate,
      };

  Solicitation copyWith({
    SolicitationStatus? status,
    String? amountRequested,
    String? amountGiven,
    String? additionalNotes,
    String? completedDate,
  }) {
    return Solicitation(
      id: id,
      organizationOrPerson: organizationOrPerson,
      purpose: purpose,
      targetDate: targetDate,
      contactPerson: contactPerson,
      contactNumber: contactNumber,
      status: status ?? this.status,
      amountRequested: amountRequested ?? this.amountRequested,
      amountGiven: amountGiven ?? this.amountGiven,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      completedDate: completedDate ?? this.completedDate,
    );
  }

  double get numericAmountRequested => _parseAmount(amountRequested);
  double get numericAmountGiven => _parseAmount(amountGiven);

  double _parseAmount(String? value) {
    if (value == null) return 0.0;
    try {
      // Clean string: remove ₱, commas, and other non-numeric chars (except decimal point)
      final clean = value.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(clean) ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  /// Parse target date to DateTime for sorting and reporting
  DateTime? get parsedTargetDate {
    try {
      final s = targetDate.trim();
      if (s.isEmpty || s.toUpperCase() == 'ASAP') return null;

      // 1. Try ISO format or similar
      try {
        return DateTime.parse(s);
      } catch (_) {}

      // 2. Try MM/DD/YYYY or M/D/YYYY or MM-DD-YYYY
      final dateRegex = RegExp(r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})');
      final match = dateRegex.firstMatch(s);
      if (match != null) {
        int m = int.parse(match.group(1)!);
        int d = int.parse(match.group(2)!);
        int y = int.parse(match.group(3)!);
        if (y < 100) y += 2000;
        return DateTime(y, m, d);
      }

      // 3. Try "Month DD, YYYY" or "Month YYYY"
      const months = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
        'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
        'january': 1, 'february': 2, 'march': 3, 'april': 4, 'june': 6,
        'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11, 'december': 12,
      };

      String lowerS = s.toLowerCase();
      for (final entry in months.entries) {
        if (lowerS.contains(entry.key)) {
          final yearMatch = RegExp(r'\d{4}').firstMatch(s);
          final year = yearMatch != null ? int.parse(yearMatch.group(0)!) : DateTime.now().year;

          // Look for a day (1 or 2 digits not part of the year)
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
