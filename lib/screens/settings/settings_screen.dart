// lib/screens/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:time_tracker/database/database.dart';
import 'package:drift/drift.dart' as drift;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController, _addressController, _cnpjController,
      _letterheadController, _weeklyGoalController, _monthlyGoalController, _yAxisMaxController;
  
  String? _logoPath;
  String? _letterheadImagePath; // State for letterhead image
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _cnpjController = TextEditingController();
    _letterheadController = TextEditingController();
    _weeklyGoalController = TextEditingController();
    _monthlyGoalController = TextEditingController();
    _yAxisMaxController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final settings = await (db.select(db.companySettings)..where((tbl) => tbl.id.equals(1))).getSingleOrNull();
    
    if (settings != null) {
      _nameController.text = settings.companyName ?? '';
      _addressController.text = settings.companyAddress ?? '';
      _cnpjController.text = settings.cnpj ?? '';
      _letterheadController.text = settings.invoiceLetterhead ?? '';
      _logoPath = settings.companyLogoPath;
      _letterheadImagePath = settings.invoiceLetterheadImagePath; // Load path
      _weeklyGoalController.text = settings.weeklyHoursGoal?.toString() ?? '';
      _monthlyGoalController.text = settings.monthlyHoursGoal?.toString() ?? '';
      _yAxisMaxController.text = settings.reportsYAxisMax?.toString() ?? '12';
    }
    
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    // dispose all controllers
    super.dispose();
  }

  Future<void> _pickImage({required bool isLogo}) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() {
        if (isLogo) {
          _logoPath = result.files.single.path;
        } else {
          _letterheadImagePath = result.files.single.path;
        }
      });
    }
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final db = Provider.of<AppDatabase>(context, listen: false);
      final settingsCompanion = CompanySettingsCompanion(
        id: const drift.Value(1),
        companyName: drift.Value(_nameController.text),
        companyAddress: drift.Value(_addressController.text),
        cnpj: drift.Value(_cnpjController.text),
        companyLogoPath: drift.Value(_logoPath),
        invoiceLetterhead: drift.Value(_letterheadController.text),
        invoiceLetterheadImagePath: drift.Value(_letterheadImagePath), // Save path
        weeklyHoursGoal: drift.Value(int.tryParse(_weeklyGoalController.text)),
        monthlyHoursGoal: drift.Value(int.tryParse(_monthlyGoalController.text)),
        reportsYAxisMax: drift.Value(double.tryParse(_yAxisMaxController.text) ?? 12.0),
      );
      await db.into(db.companySettings).insertOnConflictUpdate(settingsCompanion);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved successfully!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Company Settings'), actions: [IconButton(icon: const Icon(Icons.save), onPressed: _saveSettings)]),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // ... Company Details, Goals, Report Settings sections ...
                  Text('Company Details', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Company Name'), validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 16),
                  TextFormField(controller: _addressController, decoration: const InputDecoration(labelText: 'Company Address')),
                  const SizedBox(height: 16),
                  TextFormField(controller: _cnpjController, decoration: const InputDecoration(labelText: 'CNPJ / Tax ID')),
                  const Divider(height: 40),

                  // --- ADDED INVOICE ASSETS SECTION ---
                  Text('Invoice Assets', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.business),
                    title: const Text('Company Logo'),
                    subtitle: Text(_logoPath ?? 'No logo selected'),
                    trailing: ElevatedButton(child: const Text('Upload'), onPressed: () => _pickImage(isLogo: true)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.image),
                    title: const Text('Invoice Letterhead'),
                    subtitle: Text(_letterheadImagePath ?? 'No image selected'),
                    trailing: ElevatedButton(child: const Text('Upload'), onPressed: () => _pickImage(isLogo: false)),
                  ),
                  const Divider(height: 40),

                  Text('Hour Goals', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  TextFormField(controller: _weeklyGoalController, decoration: const InputDecoration(labelText: 'Weekly Hours Goal'), keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                  TextFormField(controller: _monthlyGoalController, decoration: const InputDecoration(labelText: 'Monthly Hours Goal'), keyboardType: TextInputType.number),
                  const Divider(height: 40),
                  
                  Text('Report Settings', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  TextFormField(controller: _yAxisMaxController, decoration: const InputDecoration(labelText: 'Chart Y-Axis Maximum (hours)'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                  const Divider(height: 40),

                  Text('Invoice Details', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  TextFormField(controller: _letterheadController, decoration: const InputDecoration(labelText: 'Invoice Footer Text'), maxLines: 3),
                ],
              ),
            ),
    );
  }
}