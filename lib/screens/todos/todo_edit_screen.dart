// lib/screens/todos/todo_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:time_tracker/database/database.dart';
import 'package:drift/drift.dart' as drift;

class TodoEditScreen extends StatefulWidget {
  final Todo? todo;
  const TodoEditScreen({super.key, this.todo});

  @override
  State<TodoEditScreen> createState() => _TodoEditScreenState();
}

class _TodoEditScreenState extends State<TodoEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _estimateController = TextEditingController();

  final List<String> _priorities = ['P1', 'P2', 'P3'];
  final List<String> _categories = ['Client Communication','Client Meetings','Client Operations','Freelancer Support','Resource Management','Run Closure','Run Preparation','Test Management'];
  
  String? _selectedPriority;
  String? _selectedCategory;
  int? _selectedProjectId;
  DateTime _startTime = DateTime.now();
  DateTime _deadline = DateTime.now().add(const Duration(days: 1));

  List<Project> _projects = [];
  bool _isLoading = true;
  bool get _isEditing => widget.todo != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final t = widget.todo!;
      _titleController.text = t.title;
      _descriptionController.text = t.description ?? '';
      _estimateController.text = t.estimatedHours?.toString() ?? '';
      _selectedPriority = t.priority;
      _selectedCategory = t.category;
      _selectedProjectId = t.projectId;
      _startTime = t.startTime;
      _deadline = t.deadline;
    }
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final projects = await db.select(db.projects).get();
    if (mounted) {
      setState(() {
        _projects = projects;
        _isLoading = false;
      });
    }
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _estimateController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime({required bool isStart}) async {
    final initialDate = isStart ? _startTime : _deadline;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null) return;

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null) return;

    if (mounted) {
      setState(() {
        final newDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        if (isStart) {
          _startTime = newDateTime;
        } else {
          _deadline = newDateTime;
        }
      });
    }
  }

  Future<void> _saveTodo() async {
    if (_formKey.currentState!.validate()) {
      final navigator = Navigator.of(context);
      final db = Provider.of<AppDatabase>(context, listen: false);
      
      final companion = TodosCompanion(
        id: _isEditing ? drift.Value(widget.todo!.id) : const drift.Value.absent(),
        title: drift.Value(_titleController.text),
        description: drift.Value(_descriptionController.text),
        priority: drift.Value(_selectedPriority!),
        category: drift.Value(_selectedCategory!),
        projectId: drift.Value(_selectedProjectId!),
        startTime: drift.Value(_startTime),
        deadline: drift.Value(_deadline),
        estimatedHours: drift.Value(double.tryParse(_estimateController.text)),
      );

      if (_isEditing) {
        await db.update(db.todos).replace(companion);
      } else {
        await db.into(db.todos).insert(companion);
      }
      
      if (mounted) {
        navigator.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Task' : 'New Task'),
        actions: [IconButton(icon: const Icon(Icons.save), onPressed: _saveTodo)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  TextFormField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title'), validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 16),
                  TextFormField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: DropdownButtonFormField<String>(initialValue: _selectedPriority, decoration: const InputDecoration(labelText: 'Priority'), items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(), onChanged: (v) => setState(() => _selectedPriority = v), validator: (v) => v == null ? 'Required' : null)),
                    const SizedBox(width: 16),
                    Expanded(child: DropdownButtonFormField<String>(initialValue: _selectedCategory, decoration: const InputDecoration(labelText: 'Category'), items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => _selectedCategory = v), validator: (v) => v == null ? 'Required' : null)),
                  ]),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(initialValue: _selectedProjectId, decoration: const InputDecoration(labelText: 'Project'), items: _projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(), onChanged: (v) => setState(() => _selectedProjectId = v), validator: (v) => v == null ? 'Required' : null),
                  const SizedBox(height: 16),
                  ListTile(title: const Text('Start Time'), subtitle: Text(DateFormat.yMd().add_jm().format(_startTime)), trailing: const Icon(Icons.calendar_today), onTap: () => _selectDateTime(isStart: true)),
                  ListTile(title: const Text('Deadline'), subtitle: Text(DateFormat.yMd().add_jm().format(_deadline)), trailing: const Icon(Icons.calendar_today), onTap: () => _selectDateTime(isStart: false)),
                  const SizedBox(height: 16),
                  TextFormField(controller: _estimateController, decoration: const InputDecoration(labelText: 'Time Estimate (e.g., 2.5 hours)'), keyboardType: TextInputType.number),
                ],
              ),
            ),
    );
  }
}

