// lib/screens/invoices/invoices_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:time_tracker/database/database.dart';
import 'package:drift/drift.dart';
import 'package:time_tracker/screens/invoices/invoice_edit_screen.dart';

class InvoicesScreen extends StatelessWidget {
  const InvoicesScreen({super.key});

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
          final invoices = snapshot.data ?? [];
          if (invoices.isEmpty && snapshot.connectionState == ConnectionState.active) {
            return const Center(child: Text("No invoices found. Click '+' to add one!"));
          }
          return ListView.builder(
            itemCount: invoices.length,
            itemBuilder: (context, index) {
              final row = invoices[index];
              final invoice = row.readTable(db.invoices);
              final client = row.readTable(db.clients);
              final currencyFormat = NumberFormat.simpleCurrency(name: client.currency);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(invoice.invoiceIdString),
                  subtitle: Text('${client.name} - Issued: ${DateFormat.yMd().format(invoice.issueDate)}'),
                  trailing: Text(currencyFormat.format(invoice.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    // Navigate to edit screen
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => InvoiceEditScreen(invoice: invoice),
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