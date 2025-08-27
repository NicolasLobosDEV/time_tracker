// lib/screens/time_tracker/edit_entry_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:time_tracker/database/database.dart';
import 'package:drift/drift.dart' as drift;

class EditEntryScreen extends StatefulWidget {
  final TimeEntry entry;
  const EditEntryScreen({super.key, required this.entry});

  @override
  State<EditEntryScreen> createState() => _EditEntryScreenState();
}

class _EditEntryScreenState extends State<EditEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descriptionController;
  late int _selectedProjectId;
  late String _selectedCategory;
  late bool _isBillable;
  late DateTime _startTime;
  late DateTime _endTime;
  late bool _isBilled; // <-- 1. ADD STATE VARIABLE FOR BILLED STATUS

  final List<String> _categories = [
    'Client Communication','Client Meetings','Client Operations','Freelancer Support',
    'Resource Management','Run Closure','Run Preparation','Test Management',
  ];

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _descriptionController = TextEditingController(text: entry.description);
    _selectedProjectId = entry.projectId;
    _selectedCategory = entry.category ?? _categories.first;
    _isBillable = entry.isBillable;
    _startTime = entry.startTime;
    _endTime = entry.endTime!;
    _isBilled = entry.isBilled; // <-- 2. INITIALIZE THE BILLED STATUS
  }

  Future<void> _selectDateTime(BuildContext context, {required bool isStart}) async {
    final initialDate = isStart ? _startTime : _endTime;
    final date = await showDatePicker(context: context, initialDate: initialDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (date == null) return;

    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initialDate));
    if (time == null) return;

    setState(() {
      final newDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (isStart) {
        _startTime = newDateTime;
      } else {
        _endTime = newDateTime;
      }
    });
  }

  void _saveEntry() {
    if (_formKey.currentState!.validate()) {
      if (_startTime.isAfter(_endTime)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Start time cannot be after end time.')));
        return;
      }
      final db = Provider.of<AppDatabase>(context, listen: false);
      final updatedEntry = TimeEntriesCompanion(
        id: drift.Value(widget.entry.id),
        projectId: drift.Value(_selectedProjectId),
        category: drift.Value(_selectedCategory),
        description: drift.Value(_descriptionController.text),
        isBillable: drift.Value(_isBillable),
        startTime: drift.Value(_startTime),
        endTime: drift.Value(_endTime),
        isBilled: drift.Value(_isBilled), // <-- 3. SAVE THE BILLED STATUS
      );
      db.update(db.timeEntries).replace(updatedEntry);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Time Entry'),
        actions: [IconButton(icon: const Icon(Icons.save), onPressed: _saveEntry)],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            FutureBuilder<List<Project>>(
              future: db.select(db.projects).get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                return DropdownButtonFormField<int>(
                  value: _selectedProjectId,
                  items: snapshot.data!.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                  onChanged: (v) => setState(() => _selectedProjectId = v!),
                  decoration: const InputDecoration(labelText: 'Project'),
                );
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _selectedCategory = v!),
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 16),
            TextFormField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Start Time'),
              subtitle: Text(DateFormat.yMd().add_jm().format(_startTime)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectDateTime(context, isStart: true),
            ),
            ListTile(
              title: const Text('End Time'),
              subtitle: Text(DateFormat.yMd().add_jm().format(_endTime)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectDateTime(context, isStart: false),
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Billable'),
              subtitle: const Text('Can this entry be charged to a client?'),
              value: _isBillable,
              onChanged: (v) => setState(() => _isBillable = v),
            ),
            // <-- 4. ADD THE NEW "BILLED" TOGGLE
            SwitchListTile(
              title: const Text('Billed'),
              subtitle: const Text('Has this entry been logged?'),
              value: _isBilled,
              onChanged: (v) => setState(() => _isBilled = v),
            ),
          ],
        ),
      ),
    );
  }
}