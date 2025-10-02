// lib/screens/invoices/invoices_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:time_tracker/database/database.dart';
import 'package:drift/drift.dart';
import 'package:time_tracker/screens/invoices/invoice_edit_screen.dart';

class InvoicesScreen extends StatelessWidget {
  const InvoicesScreen({super.key});

  // Method to show a confirmation dialog before deleting
  void _deleteInvoice(BuildContext context, Invoice invoice, Client client) {
    final db = Provider.of<AppDatabase>(context, listen: false);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Invoice'),
          content: Text(
              'Are you sure you want to delete invoice ${invoice.invoiceIdString} for ${client.name}? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: Text('Delete',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onPressed: () {
                // Perform the deletion
                (db.delete(db.invoices)..where((i) => i.id.equals(invoice.id)))
                    .go();
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
    final query = db.select(db.invoices).join([
      innerJoin(db.clients, db.clients.id.equalsExp(db.invoices.clientId)),
    ])
      ..orderBy([OrderingTerm.desc(db.invoices.issueDate)]);

    return Scaffold(
      body: StreamBuilder(
        stream: query.watch(),
        builder: (context, snapshot) {
          final invoicesWithClients = snapshot.data ?? [];
          if (invoicesWithClients.isEmpty &&
              snapshot.connectionState == ConnectionState.active) {
            return const Center(
                child: Text("No invoices found. Click '+' to add one!"));
          }
          return ListView.builder(
            itemCount: invoicesWithClients.length,
            itemBuilder: (context, index) {
              final row = invoicesWithClients[index];
              final invoice = row.readTable(db.invoices);
              final client = row.readTable(db.clients);
              final currencyFormat =
                  NumberFormat.simpleCurrency(name: client.currency);

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Dismissible(
                  key: Key(invoice.id.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.redAccent,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  // We show the dialog in onDismissed to allow the animation to complete
                  onDismissed: (direction) {
                    _deleteInvoice(context, invoice, client);
                  },
                  child: ListTile(
                    title: Text(invoice.invoiceIdString),
                    subtitle: Text(
                        '${client.name} - Issued: ${DateFormat.yMd().format(invoice.issueDate)}'),
                    trailing: Text(currencyFormat.format(invoice.totalAmount),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () {
                      // Navigate to edit screen
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) =>
                            InvoiceEditScreen(invoice: invoice),
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
          // Navigate to edit screen to create a new invoice
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const InvoiceEditScreen(),
          ));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
