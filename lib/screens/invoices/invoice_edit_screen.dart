// lib/screens/invoices/invoice_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:time_tracker/database/database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:time_tracker/models/line_item.dart';
import 'package:time_tracker/utils/pdf_generator.dart';
import 'package:intl/intl.dart';

class InvoiceEditScreen extends StatefulWidget {
  final Invoice? invoice;
  const InvoiceEditScreen({super.key, this.invoice});

  @override
  State<InvoiceEditScreen> createState() => _InvoiceEditScreenState();
}

class _InvoiceEditScreenState extends State<InvoiceEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceIdController = TextEditingController();
  final _notesController = TextEditingController();

  Client? _selectedClient;
  DateTime _issueDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  List<LineItem> _lineItems = [];
  String _status = 'Draft';

  bool get _isEditing => widget.invoice != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final inv = widget.invoice!;
      _invoiceIdController.text = inv.invoiceIdString;
      _notesController.text = inv.notes ?? '';
      _issueDate = inv.issueDate;
      _dueDate = inv.dueDate;
      _status = inv.status;
      if (inv.lineItemsJson != null) {
        _lineItems = lineItemsFromJson(inv.lineItemsJson!);
      }
      _loadClient();
    } else {
      _invoiceIdController.text =
          'INV-${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-001';
    }
  }

  Future<void> _loadClient() async {
    if (!_isEditing) return;
    final db = Provider.of<AppDatabase>(context, listen: false);
    final client = await (db.select(
      db.clients,
    )..where((c) => c.id.equals(widget.invoice!.clientId))).getSingle();
    setState(() {
      _selectedClient = client;
    });
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate() || _selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a client and fill all required fields.'),
        ),
      );
      return;
    }

    final db = Provider.of<AppDatabase>(context, listen: false);
    final total = _lineItems.fold<double>(0, (sum, item) => sum + item.total);

    final companion = InvoicesCompanion(
      id: _isEditing
          ? drift.Value(widget.invoice!.id)
          : const drift.Value.absent(),
      invoiceIdString: drift.Value(_invoiceIdController.text),
      clientId: drift.Value(_selectedClient!.id),
      issueDate: drift.Value(_issueDate),
      dueDate: drift.Value(_dueDate),
      notes: drift.Value(_notesController.text),
      status: drift.Value(_status),
      totalAmount: drift.Value(total),
      lineItemsJson: drift.Value(lineItemsToJson(_lineItems)),
    );

    if (_isEditing) {
      await db.update(db.invoices).replace(companion);
    } else {
      await db.into(db.invoices).insert(companion);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _fetchTimeEntries() async {
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a client first.')),
      );
      return;
    }

    final dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (dateRange == null) return;

    final db = Provider.of<AppDatabase>(context, listen: false);

    final clientProjects = await (db.select(
      db.projects,
    )..where((p) => p.clientId.equals(_selectedClient!.id))).get();
    if (clientProjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No projects found for this client.')),
      );
      return;
    }

    final query =
        db.select(db.timeEntries).join([
            drift.innerJoin(
              db.projects,
              db.projects.id.equalsExp(db.timeEntries.projectId),
            ),
          ])
          ..where(db.projects.clientId.equals(_selectedClient!.id))
          ..where(db.timeEntries.isBilled.equals(false))
          ..where(
            db.timeEntries.startTime.isBetweenValues(
              dateRange.start,
              dateRange.end.add(const Duration(days: 1)),
            ),
          );

    final results = await query.get();

    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No unbilled time entries found for this period.'),
        ),
      );
      return;
    }

    final Map<int, LineItem> projectSummaries = {};
    final List<int> entryIdsToUpdate = [];

    for (final row in results) {
      final entry = row.readTable(db.timeEntries);
      final project = row.readTable(db.projects);
      if (entry.endTime == null) continue;
      final duration = entry.endTime!.difference(entry.startTime);
      final hours = duration.inMinutes / 60.0;

      entryIdsToUpdate.add(entry.id);

      projectSummaries.update(
        project.id,
        (existing) => LineItem(
          description: existing.description,
          quantity: existing.quantity + hours,
          unitPrice: existing.unitPrice,
        ),
        ifAbsent: () => LineItem(
          description: 'Work on project: ${project.name}',
          quantity: hours,
          unitPrice: project.hourlyRate,
        ),
      );
    }

    await (db.update(db.timeEntries)..where((t) => t.id.isIn(entryIdsToUpdate)))
        .write(const TimeEntriesCompanion(isBilled: drift.Value(true)));

    setState(() {
      _lineItems.addAll(projectSummaries.values);
    });
  }

  Future<void> _fetchExpenses() async {
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a client first.')),
      );
      return;
    }

    final dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (dateRange == null) return;

    final db = Provider.of<AppDatabase>(context, listen: false);

    // Get project IDs for the selected client
    final projectIdsQuery = db.selectOnly(db.projects)
      ..where(db.projects.clientId.equals(_selectedClient!.id))
      ..addColumns([db.projects.id]);

    final projectIds = await projectIdsQuery
        .map((row) => row.read(db.projects.id)!)
        .get();

    // Build the where expression safely
    final drift.Expression<bool> expression = projectIds.isNotEmpty
        ? (db.expenses.clientId.equals(_selectedClient!.id) |
              db.expenses.projectId.isIn(projectIds))
        : db.expenses.clientId.equals(_selectedClient!.id);

    final query = db.select(db.expenses)
      ..where((e) => expression)
      ..where((e) => e.isBilled.equals(false))
      ..where(
        (e) => e.date.isBetweenValues(
          dateRange.start,
          dateRange.end.add(const Duration(days: 1)),
        ),
      );

    final results = await query.get();

    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No unbilled expenses found for this period.'),
        ),
      );
      return;
    }

    final List<LineItem> newItems = [];
    final List<int> expenseIdsToUpdate = [];

    for (final expense in results) {
      newItems.add(
        LineItem(
          description: expense.description,
          quantity: 1,
          unitPrice: expense.amount,
        ),
      );
      expenseIdsToUpdate.add(expense.id);
    }

    await (db.update(db.expenses)..where((t) => t.id.isIn(expenseIdsToUpdate)))
        .write(const ExpensesCompanion(isBilled: drift.Value(true)));

    setState(() {
      _lineItems.addAll(newItems);
    });
  }

  void _addManualItem() {
    final descriptionController = TextEditingController();
    final quantityController = TextEditingController();
    final rateController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Manual Line Item'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity / Hours',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: rateController,
                  decoration: const InputDecoration(
                    labelText: 'Unit Price / Rate',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  setState(() {
                    _lineItems.add(
                      LineItem(
                        description: descriptionController.text,
                        quantity: double.tryParse(quantityController.text) ?? 1,
                        unitPrice: double.tryParse(rateController.text) ?? 0,
                      ),
                    );
                  });
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _previewPdf() async {
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a client first.')),
      );
      return;
    }

    final db = Provider.of<AppDatabase>(context, listen: false);
    final settings = await (db.select(
      db.companySettings,
    )..where((s) => s.id.equals(1))).getSingleOrNull();

    if (settings == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please configure your company settings before creating a PDF.',
          ),
        ),
      );
      return;
    }

    final total = _lineItems.fold<double>(0, (sum, item) => sum + item.total);

    final invoiceData = Invoice(
      id: widget.invoice?.id ?? 0,
      invoiceIdString: _invoiceIdController.text,
      clientId: _selectedClient!.id,
      issueDate: _issueDate,
      dueDate: _dueDate,
      totalAmount: total,
      notes: _notesController.text,
      status: _status,
      lineItemsJson: lineItemsToJson(_lineItems),
    );

    await generateAndShowInvoice(
      invoice: invoiceData,
      client: _selectedClient!,
      settings: settings,
      items: _lineItems,
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Invoice' : 'New Invoice'),
        actions: [
          IconButton(
            tooltip: 'Preview PDF',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _previewPdf,
          ),
          IconButton(
            tooltip: 'Save Invoice',
            icon: const Icon(Icons.save),
            onPressed: _saveInvoice,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FutureBuilder<List<Client>>(
              future: db.select(db.clients).get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                return DropdownButtonFormField<Client>(
                  value: _selectedClient,
                  decoration: const InputDecoration(labelText: 'Client'),
                  items: snapshot.data!
                      .map(
                        (c) => DropdownMenuItem(value: c, child: Text(c.name)),
                      )
                      .toList(),
                  onChanged: (c) => setState(() => _selectedClient = c),
                  validator: (c) => c == null ? 'Please select a client' : null,
                );
              },
            ),
            TextFormField(
              controller: _invoiceIdController,
              decoration: const InputDecoration(labelText: 'Invoice ID'),
            ),
            const Divider(height: 40),
            Text('Line Items', style: Theme.of(context).textTheme.titleLarge),
            if (_lineItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No items added yet.')),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _lineItems.length,
                itemBuilder: (context, index) {
                  final item = _lineItems[index];
                  final currencyFormat = NumberFormat.simpleCurrency(
                    name: _selectedClient?.currency ?? 'USD',
                  );
                  return ListTile(
                    title: Text(item.description),
                    subtitle: Text(
                      '${item.quantity.toStringAsFixed(2)} x ${currencyFormat.format(item.unitPrice)}',
                    ),
                    trailing: Text(currencyFormat.format(item.total)),
                  );
                },
              ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Manual Item'),
                  onPressed: _addManualItem,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Fetch Expenses'),
                  onPressed: _fetchExpenses,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.timer),
                  label: const Text('Fetch Time'),
                  onPressed: _fetchTimeEntries,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
