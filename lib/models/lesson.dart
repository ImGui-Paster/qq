class Lesson {
  int? id;
  int day; // 1=Пн .. 6=Сб
  int num; // номер пары
  String subject;
  String teacher;
  String room;
  String timeStart;
  String timeEnd;
  String type;

  Lesson({
    this.id,
    required this.day,
    required this.num,
    required this.subject,
    this.teacher = '',
    this.room = '',
    this.timeStart = '',
    this.timeEnd = '',
    this.type = '',
  });

  String timeRange() {
    if (timeStart.isNotEmpty && timeEnd.isNotEmpty) {
      return '$timeStart – $timeEnd';
    }
    return '';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'day': day,
        'num': num,
        'subject': subject,
        'teacher': teacher,
        'room': room,
        't_start': timeStart,
        't_end': timeEnd,
        'type': type,
      };

  factory Lesson.fromMap(Map<String, dynamic> m) => Lesson(
        id: m['id'] as int?,
        day: m['day'] as int,
        num: m['num'] as int,
        subject: (m['subject'] ?? '') as String,
        teacher: (m['teacher'] ?? '') as String,
        room: (m['room'] ?? '') as String,
        timeStart: (m['t_start'] ?? '') as String,
        timeEnd: (m['t_end'] ?? '') as String,
        type: (m['type'] ?? '') as String,
      );
}
