import 'package:flutter/material.dart';
import '../logic/db.dart';
import '../models/exam.dart';

class ExamsScreen extends StatefulWidget {
  const ExamsScreen({super.key});
  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  final DB _db = DB();
  List<Exam> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _db.allExams();
    setState(() => _items = items);
  }

  Future<void> _addExam() async {
    final subj = TextEditingController();
    final type = TextEditingController(text: 'Экзамен');
    final date = TextEditingController();
    final time = TextEditingController();
    final room = TextEditingController();
    final note = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новое событие'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: subj, decoration: const InputDecoration(labelText: 'Предмет')),
              TextField(controller: type, decoration: const InputDecoration(labelText: 'Тип')),
              TextField(controller: date, decoration: const InputDecoration(labelText: 'Дата (ГГГГ-ММ-ДД)')),
              TextField(controller: time, decoration: const InputDecoration(labelText: 'Время')),
              TextField(controller: room, decoration: const InputDecoration(labelText: 'Аудитория')),
              TextField(controller: note, decoration: const InputDecoration(labelText: 'Заметка')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () async {
              if (subj.text.trim().isNotEmpty && date.text.trim().isNotEmpty) {
                await _db.saveExam(Exam(
                  subject: subj.text.trim(),
                  type: type.text.trim(),
                  date: date.text.trim(),
                  time: time.text.trim(),
                  room: room.text.trim(),
                  note: note.text.trim(),
                ));
                _load();
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Экзамены')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addExam,
        child: const Icon(Icons.add),
      ),
      body: _items.isEmpty
          ? const Center(child: Text('Событий нет'))
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final e = _items[i];
                final days = e.daysUntil();
                final daysLabel = days == 0
                    ? 'сегодня'
                    : days > 0
                        ? 'через $days дн.'
                        : 'прошло';
                return Dismissible(
                  key: ValueKey(e.id),
                  background: Container(color: Colors.red),
                  onDismissed: (_) async {
                    await _db.deleteExam(e.id!);
                    _load();
                  },
                  child: ListTile(
                    title: Text('${e.subject} · ${e.type}'),
                    subtitle: Text(
                        '${Exam.fmtDate(e.date)} ${e.time} ${e.room.isNotEmpty ? "· ауд. ${e.room}" : ""} · $daysLabel'),
                  ),
                );
              },
            ),
    );
  }
}
