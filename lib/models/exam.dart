class Exam {
  int? id;
  String subject;
  String type; // Экзамен / Зачёт / Контрольная
  String date; // YYYY-MM-DD
  String time; // HH:mm
  String room;
  String note;

  Exam({
    this.id,
    required this.subject,
    required this.type,
    required this.date,
    this.time = '',
    this.room = '',
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'subject': subject,
        'type': type,
        'date': date,
        'time': time,
        'room': room,
        'note': note,
      };

  factory Exam.fromMap(Map<String, dynamic> m) => Exam(
        id: m['id'] as int?,
        subject: (m['subject'] ?? '') as String,
        type: (m['type'] ?? '') as String,
        date: (m['date'] ?? '') as String,
        time: (m['time'] ?? '') as String,
        room: (m['room'] ?? '') as String,
        note: (m['note'] ?? '') as String,
      );

  /// Дней до даты (отрицательное = прошла).
  int daysUntil() {
    if (date.isEmpty) return 0;
    try {
      final p = date.split('-');
      final d = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return d.difference(today).inDays;
    } catch (_) {
      return 0;
    }
  }

  static String fmtDate(String yyyymmdd) {
    if (yyyymmdd.isEmpty) return '';
    try {
      final p = yyyymmdd.split('-');
      return '${p[2]}.${p[1]}.${p[0]}';
    } catch (_) {
      return yyyymmdd;
    }
  }
}
