// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:time_tracker/database/database.dart';
import 'package:drift/drift.dart';
import 'package:time_tracker/screens/todos/todo_edit_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // This function starts a new time entry based on a to-do item
  Future<void> _startTimerFromTodo(BuildContext context, Todo todo, Project project) async {
    final db = Provider.of<AppDatabase>(context, listen: false);

    // Check if another timer is already running
    final runningTimer = await (db.select(db.timeEntries)..where((t) => t.endTime.isNull())).getSingleOrNull();
    if (runningTimer != null) {
      final stopCurrent = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Timer Already Running'),
          content: const Text('Another task is currently being timed. Do you want to stop it and start this new one?'),
          actions: [
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)),
            TextButton(child: const Text('Stop and Start New'), onPressed: () => Navigator.of(context).pop(true)),
          ],
        ),
      );
      if (stopCurrent == true) {
        await (db.update(db.timeEntries)..where((t) => t.id.equals(runningTimer.id))).write(TimeEntriesCompanion(endTime: Value(DateTime.now())));
      } else {
        return; // User cancelled
      }
    }

    // Create the new time entry
    final newEntry = TimeEntriesCompanion(
      description: Value(todo.title),
      projectId: Value(todo.projectId),
      category: Value(todo.category),
      startTime: Value(DateTime.now()),
    );
    await db.into(db.timeEntries).insert(newEntry);
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Timer started for "${todo.title}"')));
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final query = db.select(db.todos).join([
      innerJoin(db.projects, db.projects.id.equalsExp(db.todos.projectId))
    ])
    // Sort by completion status, then priority, then deadline
    ..orderBy([
      OrderingTerm.asc(db.todos.isCompleted),
      OrderingTerm.asc(db.todos.priority),
      OrderingTerm.asc(db.todos.deadline),
    ]);

    return Scaffold(
      body: StreamBuilder(
        stream: query.watch(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          if (items.isEmpty && snapshot.connectionState == ConnectionState.active) {
            return const Center(child: Text("No tasks found. Click '+' to add one!"));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final row = items[index];
              final todo = row.readTable(db.todos);
              final project = row.readTable(db.projects);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: Checkbox(
                    value: todo.isCompleted,
                    onChanged: (isCompleted) {
                      final updated = todo.copyWith(isCompleted: isCompleted!);
                      db.update(db.todos).replace(updated);
                    },
                  ),
                  title: Text(todo.title, style: TextStyle(decoration: todo.isCompleted ? TextDecoration.lineThrough : TextDecoration.none)),
                  subtitle: Text('${project.name}\nDeadline: ${DateFormat.yMd().add_jm().format(todo.deadline)}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.play_circle_fill_outlined, color: Colors.greenAccent),
                    tooltip: 'Start Timer for this Task',
                    onPressed: todo.isCompleted ? null : () => _startTimerFromTodo(context, todo, project),
                  ),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => TodoEditScreen(todo: todo)));
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => TodoEditScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}
