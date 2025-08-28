// lib/screens/projects/project_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:time_tracker/database/database.dart';
import 'package:drift/drift.dart' as drift;

class ProjectEditScreen extends StatefulWidget {
  final Project? project;

  const ProjectEditScreen({super.key, this.project});

  @override
  State<ProjectEditScreen> createState() => _ProjectEditScreenState();
}

class _ProjectEditScreenState extends State<ProjectEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _rateController;
  late TextEditingController _limitController;

  List<Client> _clients = [];
  int? _selectedClientId;
  bool _didChangeDependencies = false; // Flag to run the fetch only once

  bool get _isEditing => widget.project != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project?.name ?? '');
    _rateController = TextEditingController(text: widget.project?.hourlyRate.toString() ?? '');
    // FIX: Use correct field name from Project class
    _limitController = TextEditingController(text: widget.project?.monthlyTimeLimit?.toString() ?? '');
    _selectedClientId = widget.project?.clientId;
    // REMOVED _fetchClients() call from here
  }

  // Use didChangeDependencies to safely access the Provider context
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure this runs only once
    if (!_didChangeDependencies) {
      _fetchClients();
      _didChangeDependencies = true;
    }
  }

  Future<void> _fetchClients() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final clients = await db.select(db.clients).get();
    if (mounted) { // Check if the widget is still in the tree
      setState(() {
        _clients = clients;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rateController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  void _saveProject() {
    if (_formKey.currentState!.validate()) {
      final db = Provider.of<AppDatabase>(context, listen: false);

      final entity = ProjectsCompanion(
        id: _isEditing ? drift.Value(widget.project!.id) : const drift.Value.absent(),
        name: drift.Value(_nameController.text),
        clientId: drift.Value(_selectedClientId!),
        hourlyRate: drift.Value(double.tryParse(_rateController.text) ?? 0.0),
        // FIX: Use correct field name from ProjectsCompanion
        monthlyTimeLimit: drift.Value(int.tryParse(_limitController.text)),
      );

      if (_isEditing) {
        db.update(db.projects).replace(entity);
      } else {
        db.into(db.projects).insert(entity);
      }

      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Project' : 'Add Project'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveProject,
          ),
        ],
      ),
      // If there are no clients, show a helpful message instead of the form
      body: _clients.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'You must create a client before you can add a project.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: _selectedClientId,
                      decoration: const InputDecoration(labelText: 'Client'),
                      hint: const Text('Select a client'),
                      items: _clients.map((client) {
                        return DropdownMenuItem<int>(
                          value: client.id,
                          child: Text(client.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedClientId = value;
                        });
                      },
                      validator: (value) => value == null ? 'Please select a client.' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Project Name'),
                      validator: (value) => value == null || value.isEmpty ? 'Please enter a name.' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _rateController,
                      decoration: const InputDecoration(labelText: 'Hourly Rate'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter a rate.';
                        if (double.tryParse(value) == null) return 'Please enter a valid number.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _limitController,
                      decoration: const InputDecoration(labelText: 'Monthly Time Limit (in hours, optional)'),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}