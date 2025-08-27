// lib/screens/projects/projects_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:time_tracker/database/database.dart';
import 'package:drift/drift.dart';
import 'package:time_tracker/screens/projects/project_edit_screen.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  void _deleteProject(BuildContext context, Project project) {
    final db = Provider.of<AppDatabase>(context, listen: false);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Project'),
          content: Text('Are you sure you want to delete ${project.name}? This will also delete all associated time entries and expenses.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onPressed: () {
                db.delete(db.projects).where((p) => p.id.equals(project.id));
                Navigator.of(context).pop();
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
    final query = db.select(db.projects).join([
      innerJoin(db.clients, db.clients.id.equalsExp(db.projects.clientId))
    ]);

    return Scaffold(
      body: StreamBuilder(
        stream: query.watch(),
        builder: (context, snapshot) {
          final projectsWithClients = snapshot.data ?? [];
          if (projectsWithClients.isEmpty && snapshot.connectionState == ConnectionState.active) {
            return const Center(child: Text("No projects found. Click '+' to add one!"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.builder(
            itemCount: projectsWithClients.length,
            itemBuilder: (context, index) {
              final result = projectsWithClients[index];
              final project = result.readTable(db.projects);
              final client = result.readTable(db.clients);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Dismissible(
                  key: Key(project.id.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.redAccent,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _deleteProject(context, project),
                  child: ListTile(
                    title: Text(project.name),
                    subtitle: Text(client.name),
                    trailing: Text('\$${project.hourlyRate.toStringAsFixed(2)}/hr'),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => ProjectEditScreen(project: project),
                      ));
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const ProjectEditScreen(),
          ));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}