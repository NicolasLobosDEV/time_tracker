// lib/screens/time_tracker/add_entry_dialog.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:time_tracker/database/database.dart';
import 'package:drift/drift.dart' as drift;

enum EntryMode { timer, manual }

class AddEntryDialog extends StatefulWidget {
  const AddEntryDialog({super.key});
  @override
  State<AddEntryDialog> createState() => _AddEntryDialogState();
}

class _AddEntryDialogState extends State<AddEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final List<String> _categories = [
    'Client Communication','Client Meetings','Client Operations','Freelancer Support',
    'Resource Management','Run Closure','Run Preparation','Test Management',
  ];

  late List<drift.TypedResult> _projectsWithClients;
  int? _selectedProjectId;
  String? _selectedCategory;
  bool _isBillable = true;
  bool _isLoading = true;
  EntryMode _entryMode = EntryMode.timer;

  DateTime _manualDate = DateTime.now();
  TimeOfDay _manualStartTime = TimeOfDay.now();
  TimeOfDay _manualEndTime = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1)));

  @override
  void initState() {
    super.initState();
    _projectsWithClients = [];
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final query = db.select(db.projects).join([
      drift.innerJoin(db.clients, db.clients.id.equalsExp(db.projects.clientId))
    ]);
    final results = await query.get();
    if (mounted) {
      setState(() {
        _projectsWithClients = results;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectManualDate() async {
    final date = await showDatePicker(context: context, initialDate: _manualDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (date != null) setState(() => _manualDate = date);
  }

  Future<void> _selectManualTime({required bool isStart}) async {
    final time = await showTimePicker(context: context, initialTime: isStart ? _manualStartTime : _manualEndTime);
    if (time != null) setState(() => isStart ? _manualStartTime = time : _manualEndTime = time);
  }

  // FIX 1: Make the save function async and more robust
  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;
    final db = Provider.of<AppDatabase>(context, listen: false);

    if (_entryMode == EntryMode.timer) {
      final newEntry = TimeEntriesCompanion(
        description: drift.Value(_descriptionController.text),
        projectId: drift.Value(_selectedProjectId!),
        category: drift.Value(_selectedCategory),
        isBillable: drift.Value(_isBillable),
        startTime: drift.Value(DateTime.now()),
      );
      await db.into(db.timeEntries).insert(newEntry);
    } else {
      final startTime = DateTime(_manualDate.year, _manualDate.month, _manualDate.day, _manualStartTime.hour, _manualStartTime.minute);
      final endTime = DateTime(_manualDate.year, _manualDate.month, _manualDate.day, _manualEndTime.hour, _manualEndTime.minute);

      if (startTime.isAfter(endTime)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Start time cannot be after end time.')));
        return;
      }
      final newEntry = TimeEntriesCompanion(
        description: drift.Value(_descriptionController.text),
        projectId: drift.Value(_selectedProjectId!),
        category: drift.Value(_selectedCategory),
        isBillable: drift.Value(_isBillable),
        startTime: drift.Value(startTime),
        endTime: drift.Value(endTime),
      );
      await db.into(db.timeEntries).insert(newEntry);
    }
    
    // Check if the widget is still mounted before popping the navigator
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context, listen: false);
    return AlertDialog(
      title: const Text('Add Time Entry'),
      // FIX 2: Wrap the content in a SizedBox to control width
      content: SizedBox(
        width: 500, // Set a comfortable width for the dialog
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ToggleButtons(
                        isSelected: [_entryMode == EntryMode.timer, _entryMode == EntryMode.manual],
                        onPressed: (index) => setState(() => _entryMode = index == 0 ? EntryMode.timer : EntryMode.manual),
                        borderRadius: BorderRadius.circular(8),
                        children: const [Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Timer')), Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Manual'))],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: _selectedProjectId,
                        decoration: const InputDecoration(labelText: 'Project'),
                        hint: const Text('Select a project'),
                        // FIX 3: Corrected the builder to use the 'db' variable already in scope
                        items: _projectsWithClients.map((result) {
                          final project = result.readTable(db.projects);
                          final client = result.readTable(db.clients);
                          return DropdownMenuItem<int>(
                            value: project.id,
                            child: Text('${project.name} (${client.name})'),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedProjectId = value),
                        validator: (value) => value == null ? 'Please select a project.' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: const InputDecoration(labelText: 'Category'),
                        hint: const Text('Select a category'),
                        items: _categories.map((category) {
                          return DropdownMenuItem<String>(value: category, child: Text(category));
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedCategory = value),
                        validator: (value) => value == null ? 'Please select a category.' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(labelText: 'Description / Task'),
                        maxLines: 3,
                        validator: (value) => value!.isEmpty ? 'Please enter a description.' : null,
                      ),
                      const SizedBox(height: 16),
                      if (_entryMode == EntryMode.manual) ...[
                        const Divider(),
                        ListTile(title: const Text('Date'), subtitle: Text(DateFormat.yMd().format(_manualDate)), trailing: const Icon(Icons.calendar_today), onTap: _selectManualDate),
                        ListTile(title: const Text('Start Time'), subtitle: Text(_manualStartTime.format(context)), trailing: const Icon(Icons.access_time), onTap: () => _selectManualTime(isStart: true)),
                        ListTile(title: const Text('End Time'), subtitle: Text(_manualEndTime.format(context)), trailing: const Icon(Icons.access_time), onTap: () => _selectManualTime(isStart: false)),
                        const Divider(),
                      ],
                      SwitchListTile(
                        title: const Text('Billable'),
                        value: _isBillable,
                        onChanged: (value) => setState(() => _isBillable = value),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saveEntry,
          child: Text(_entryMode == EntryMode.timer ? 'Start Timer' : 'Save Entry'),
        ),
      ],
    );
  }
}