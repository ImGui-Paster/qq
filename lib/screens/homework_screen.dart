import 'package:flutter/material.dart';
import '../logic/db.dart';
import '../models/homework.dart';

class HomeworkScreen extends StatefulWidget {
  const HomeworkScreen({super.key});
  @override
  State<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends State<HomeworkScreen> {
  final DB _db = DB();
  List<Homework> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _db.allHomework();
    setState(() => _items = items);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Домашние задания')),
      body: _items.isEmpty
          ? const Center(child: Text('Заданий нет'))
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final h = _items[i];
                return Dismissible(
                  key: ValueKey(h.id),
                  background: Container(color: Colors.red),
                  onDismissed: (_) async {
                    await _db.deleteHomework(h.id!);
                    _load();
                  },
                  child: CheckboxListTile(
                    value: h.done,
                    onChanged: (v) async {
                      await _db.toggleHomework(h.id!, v ?? false);
                      _load();
                    },
                    title: Text(h.text,
                        style: TextStyle(
                            decoration: h.done ? TextDecoration.lineThrough : null)),
                    subtitle: Text('${h.subject}${h.dueDate.isNotEmpty ? " · ${h.dueDate}" : ""}'),
                  ),
                );
              },
            ),
    );
  }
}
