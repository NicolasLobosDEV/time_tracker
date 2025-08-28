// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:time_tracker/database/database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:time_tracker/screens/todos/todo_edit_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);

    // Query that joins todos with projects and orders them by the deadline
    final query = (db.select(db.todos)
          ..orderBy([(t) => drift.OrderingTerm(expression: t.deadline)]))
        .join([
      drift.innerJoin(
          db.projects, db.projects.id.equalsExp(db.todos.projectId))
    ]);

    return Scaffold(
      body: StreamBuilder(
        stream: query.watch(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final todosWithProjects = snapshot.data ?? [];

          if (todosWithProjects.isEmpty &&
              snapshot.connectionState == ConnectionState.active) {
            return const Center(
              child: Text("No tasks found. Click '+' to plan your work!"),
            );
          }

          return ListView.builder(
            itemCount: todosWithProjects.length,
            itemBuilder: (context, index) {
              final result = todosWithProjects[index];
              final todo = result.readTable(db.todos);
              final project = result.readTable(db.projects);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: Checkbox(
                    value: todo.isCompleted,
                    onChanged: (bool? value) {
                      db.update(db.todos).replace(
                            todo.copyWith(isCompleted: value ?? false),
                          );
                    },
                  ),
                  title: Text(
                    todo.title,
                    style: TextStyle(
                      decoration: todo.isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  subtitle: Text(
                    '${project.name} - Deadline: ${DateFormat.yMd().add_jm().format(todo.deadline)}',
                  ),
                  trailing: Chip(
                    label: Text(
                      todo.priority,
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: _getPriorityColor(todo.priority),
                  ),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => TodoEditScreen(todo: todo),
                    ));
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const TodoEditScreen(),
          ));
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // Helper function to assign a color based on task priority
  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'P1':
        return Colors.red.shade700;
      case 'P2':
        return Colors.orange.shade700;
      case 'P3':
        return Colors.blue.shade700;
      default:
        return Colors.grey.shade700;
    }
  }
}