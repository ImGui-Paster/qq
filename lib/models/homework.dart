class Homework {
  int? id;
  String subject;
  String text;
  String dueDate; // YYYY-MM-DD
  bool done;

  Homework({
    this.id,
    required this.subject,
    required this.text,
    this.dueDate = '',
    this.done = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'subject': subject,
        'text': text,
        'due_date': dueDate,
        'done': done ? 1 : 0,
      };

  factory Homework.fromMap(Map<String, dynamic> m) => Homework(
        id: m['id'] as int?,
        subject: (m['subject'] ?? '') as String,
        text: (m['text'] ?? '') as String,
        dueDate: (m['due_date'] ?? '') as String,
        done: (m['done'] as int? ?? 0) == 1,
      );
}
