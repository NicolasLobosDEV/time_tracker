// lib/screens/clients/clients_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:time_tracker/database/database.dart';
import 'package:time_tracker/screens/clients/client_edit_screen.dart';

class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  void _deleteClient(BuildContext context, Client client) {
    final db = Provider.of<AppDatabase>(context, listen: false);
    // Show a confirmation dialog before deleting
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Client'),
          content: Text('Are you sure you want to delete ${client.name}? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onPressed: () {
                // Perform the deletion
                (db.delete(db.clients)..where((c) => c.id.equals(client.id))).go();
                Navigator.of(context).pop(); // Close the dialog
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

    return Scaffold(
      body: StreamBuilder<List<Client>>(
        stream: db.select(db.clients).watch(),
        builder: (context, snapshot) {
          final clients = snapshot.data ?? [];
          if (clients.isEmpty && snapshot.connectionState == ConnectionState.active) {
            return const Center(child: Text("No clients found. Click '+' to add one!"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.builder(
            itemCount: clients.length,
            itemBuilder: (context, index) {
              final client = clients[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Dismissible(
                  key: Key(client.id.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.redAccent,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  // We show the dialog in onDismissed to allow the animation to complete
                  onDismissed: (direction) {
                     _deleteClient(context, client);
                  },
                  child: ListTile(
                    title: Text(client.name),
                    subtitle: Text(client.email ?? 'No email'),
                    trailing: Text(client.currency),
                    onTap: () {
                      // Navigate to the edit screen, passing the existing client
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => ClientEditScreen(client: client),
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
          // Navigate to the edit screen without a client to add a new one
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const ClientEditScreen(),
          ));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}