// lib/screens/expenses/expense_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:time_tracker/database/database.dart';
import 'package:drift/drift.dart' as drift;

class ExpenseEditScreen extends StatefulWidget {
  final Expense? expense;
  const ExpenseEditScreen({super.key, this.expense});

  @override
  State<ExpenseEditScreen> createState() => _ExpenseEditScreenState();
}

class _ExpenseEditScreenState extends State<ExpenseEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _distanceController = TextEditingController();
  final _costPerUnitController = TextEditingController();

  final List<String> _categories = ['Day Rate', 'Lodging', 'Meals', 'Mileage', 'Other'];
  String? _selectedCategory;

  DateTime _selectedDate = DateTime.now();
  int? _selectedProjectId;
  int? _selectedClientId;

  List<Project> _projects = [];
  List<Client> _clients = [];
  bool _isLoading = true;

  bool get _isEditing => widget.expense != null;
  bool get _isMileage => _selectedCategory == 'Mileage';

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final e = widget.expense!;
      _descriptionController.text = e.description;
      _amountController.text = e.amount.toString();
      _distanceController.text = e.distance?.toString() ?? '';
      _costPerUnitController.text = e.costPerUnit?.toString() ?? '';
      _selectedCategory = e.category;
      _selectedDate = e.date;
      _selectedProjectId = e.projectId;
      _selectedClientId = e.clientId;
    }
    _fetchData();
  }

  Future<void> _fetchData() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    _projects = await db.select(db.projects).get();
    _clients = await db.select(db.clients).get();
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _distanceController.dispose();
    _costPerUnitController.dispose();
    super.dispose();
  }

  void _calculateMileageTotal() {
    final distance = double.tryParse(_distanceController.text) ?? 0;
    final costPerUnit = double.tryParse(_costPerUnitController.text) ?? 0;
    _amountController.text = (distance * costPerUnit).toStringAsFixed(2);
  }

  Future<void> _saveExpense() async {
    if (_formKey.currentState!.validate()) {
      final db = Provider.of<AppDatabase>(context, listen: false);

      final entity = ExpensesCompanion(
        id: _isEditing ? drift.Value(widget.expense!.id) : const drift.Value.absent(),
        description: drift.Value(_descriptionController.text),
        date: drift.Value(_selectedDate),
        category: drift.Value(_selectedCategory!),
        amount: drift.Value(double.tryParse(_amountController.text) ?? 0.0),
        projectId: _selectedProjectId == null ? const drift.Value.absent() : drift.Value(_selectedProjectId),
        clientId: _selectedClientId == null ? const drift.Value.absent() : drift.Value(_selectedClientId),
        distance: _isMileage ? drift.Value(double.tryParse(_distanceController.text)) : const drift.Value.absent(),
        costPerUnit: _isMileage ? drift.Value(double.tryParse(_costPerUnitController.text)) : const drift.Value.absent(),
      );

      if (_isEditing) {
        await db.update(db.expenses).replace(entity);
      } else {
        await db.into(db.expenses).insert(entity);
      }
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Expense' : 'Add Expense'),
        actions: [IconButton(icon: const Icon(Icons.save), onPressed: _saveExpense)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Date Picker
                  ListTile(
                    title: const Text('Date of Expense'),
                    subtitle: Text(DateFormat.yMMMEd().format(_selectedDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Description
                  TextFormField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Description'), validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 16),

                  // Category Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Conditional UI for Mileage
                  if (_isMileage) ...[
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: _distanceController, decoration: const InputDecoration(labelText: 'Distance (km/miles)'), keyboardType: TextInputType.number, onChanged: (_) => _calculateMileageTotal())),
                        const SizedBox(width: 16),
                        Expanded(child: TextFormField(controller: _costPerUnitController, decoration: const InputDecoration(labelText: 'Cost per Unit'), keyboardType: TextInputType.number, onChanged: (_) => _calculateMileageTotal())),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Amount (read-only for mileage)
                  TextFormField(controller: _amountController, decoration: InputDecoration(labelText: 'Total Amount', prefixText: 'USD '), readOnly: _isMileage, keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 16),

                  // Project and Client selectors
                  DropdownButtonFormField<int>(
                    initialValue: _selectedProjectId,
                    decoration: const InputDecoration(labelText: 'Associate with Project (optional)'),
                    items: _projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                    onChanged: (v) => setState(() { _selectedProjectId = v; _selectedClientId = null; }),
                  ),
                  const SizedBox(height: 8),
                  const Center(child: Text('OR')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedClientId,
                    decoration: const InputDecoration(labelText: 'Associate with Client (optional)'),
                    items: _clients.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                    onChanged: (v) => setState(() { _selectedClientId = v; _selectedProjectId = null; }),
                  ),
                ],
              ),
            ),
    );
  }
}