// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:time_tracker/database/database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:time_tracker/screens/todos/todo_edit_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Method to start a timer from a task
  void _startTimerFromTodo(BuildContext context, Todo todo) async {
    final db = Provider.of<AppDatabase>(context, listen: false);

    // Check if another timer is already running
    final activeTimers = await (db.select(db.timeEntries)..where((t) => t.endTime.isNull())).get();
    if (activeTimers.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Another timer is already running. Please stop it first.')),
      );
      return;
    }

    // Create a new time entry from the todo
    final newEntry = TimeEntriesCompanion(
      description: drift.Value(todo.title),
      projectId: drift.Value(todo.projectId),
      category: drift.Value(todo.category),
      isBillable: const drift.Value(true), // Default to billable
      startTime: drift.Value(DateTime.now()),
    );

    await db.into(db.timeEntries).insert(newEntry);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Timer for "${todo.title}" has started!')),
    );
    
    // TODO: Consider navigating to the Time Tracker tab
    // This requires a more complex state management setup to control the BottomNavigationBar index from here.
  }
  
  // Method to clear all completed tasks
  void _clearCompletedTasks(BuildContext context) {
    final db = Provider.of<AppDatabase>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear Completed Tasks'),
          content: const Text('Are you sure you want to delete all completed tasks? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onPressed: () {
                (db.delete(db.todos)..where((t) => t.isCompleted.equals(true))).go();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Completed tasks have been cleared.')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(
                        label: Text(
                          todo.priority,
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: _getPriorityColor(todo.priority),
                      ),
                      const SizedBox(width: 8),
                      // The new Start Timer button
                      IconButton(
                        icon: const Icon(Icons.play_circle_outline),
                        tooltip: 'Start Timer for this Task',
                        onPressed: () => _startTimerFromTodo(context, todo),
                      ),
                    ],
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
      // Use a Row for multiple FloatingActionButtons
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: () => _clearCompletedTasks(context),
            label: const Text('Clear Completed'),
            icon: const Icon(Icons.delete_sweep),
            heroTag: 'clear_tasks', // Hero tags must be unique
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const TodoEditScreen(),
              ));
            },
            heroTag: 'add_task',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

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