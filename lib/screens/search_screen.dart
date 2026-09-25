import 'package:flutter/material.dart';
import '../logic/clock_logic.dart';
import '../logic/db.dart';
import '../models/lesson.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final DB _db = DB();
  List<Lesson> _results = [];
  final _controller = TextEditingController();

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    final r = await _db.searchLessons(q.trim());
    setState(() => _results = r);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Предмет, преподаватель, аудитория…',
            border: InputBorder.none,
          ),
          onChanged: _search,
        ),
      ),
      body: _results.isEmpty
          ? const Center(child: Text('Ничего не найдено'))
          : ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, i) {
                final l = _results[i];
                return ListTile(
                  title: Text(l.subject),
                  subtitle: Text(
                      '${ClockLogic.dayName(l.day)} · пара ${l.num} · ${l.teacher} ${l.room.isNotEmpty ? "· ауд. ${l.room}" : ""}'),
                );
              },
            ),
    );
  }
}
