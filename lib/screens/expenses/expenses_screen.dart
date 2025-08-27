// lib/screens/expenses/expenses_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:time_tracker/database/database.dart';
import 'package:drift/drift.dart';
import 'package:time_tracker/screens/expenses/expense_edit_screen.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    
    final query = db.select(db.expenses).join([
      leftOuterJoin(db.projects, db.projects.id.equalsExp(db.expenses.projectId)),
      // --- THIS IS THE FIX ---
      // The two 'equalsExp' conditions are now wrapped in Expression.or([])
      leftOuterJoin(db.clients, Expression.or([
        db.clients.id.equalsExp(db.expenses.clientId),
        db.clients.id.equalsExp(db.projects.clientId)
      ])),
    ])..orderBy([OrderingTerm.desc(db.expenses.date)]);

    return Scaffold(
      body: StreamBuilder(
        stream: query.watch(),
        builder: (context, snapshot) {
          final expenses = snapshot.data ?? [];
          if (expenses.isEmpty && snapshot.connectionState == ConnectionState.active) {
            return const Center(child: Text("No expenses found. Click '+' to add one!"));
          }
          return ListView.builder(
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              final row = expenses[index];
              final expense = row.readTable(db.expenses);
              final project = row.readTableOrNull(db.projects);
              final client = row.readTableOrNull(db.clients);

              final currencyFormat = NumberFormat.simpleCurrency(name: client?.currency ?? 'USD');
              String subtitle = project?.name ?? client?.name ?? 'No client/project';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Dismissible(
                  key: Key(expense.id.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(color: Colors.redAccent, alignment: Alignment.centerRight, padding: const EdgeInsets.symmetric(horizontal: 20), child: const Icon(Icons.delete, color: Colors.white)),
                  onDismissed: (_) => (db.delete(db.expenses)..where((e) => e.id.equals(expense.id))).go(),
                  child: ListTile(
                    title: Text(expense.description),
                    subtitle: Text('$subtitle on ${DateFormat.yMd().format(expense.date)}'),
                    trailing: Text(currencyFormat.format(expense.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => ExpenseEditScreen(expense: expense),
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
            builder: (context) => const ExpenseEditScreen(),
          ));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}