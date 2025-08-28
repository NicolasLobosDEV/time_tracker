// lib/screens/settings/settings_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:time_tracker/database/database.dart';
import 'package:drift/drift.dart' as drift;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  File? _logo;
  bool _showLetterhead = true; // Default value

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final settings = await (db.select(db.companySettings)..where((s) => s.id.equals(1))).getSingleOrNull();
    if (settings != null) {
      _nameController.text = settings.companyName;
      _addressController.text = settings.companyAddress;
      if (settings.logoPath != null) {
        _logo = File(settings.logoPath!);
      }
      _showLetterhead = settings.showLetterhead; // Load the new setting
      setState(() {});
    }
  }

  Future<void> _pickLogo() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _logo = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final db = Provider.of<AppDatabase>(context, listen: false);
    final companion = CompanySettingsCompanion(
      id: const drift.Value(1),
      companyName: drift.Value(_nameController.text),
      companyAddress: drift.Value(_addressController.text),
      logoPath: _logo != null ? drift.Value(_logo!.path) : const drift.Value.absent(),
      showLetterhead: drift.Value(_showLetterhead), // Save the new setting
    );

    await db.into(db.companySettings).insertOnConflictUpdate(companion);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved successfully.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Company Name'),
              validator: (value) => value!.isEmpty ? 'Please enter your company name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Company Address'),
              maxLines: 3,
              validator: (value) => value!.isEmpty ? 'Please enter your company address' : null,
            ),
            const SizedBox(height: 24),
            ListTile(
              title: const Text('Company Logo'),
              subtitle: _logo == null ? const Text('No logo selected') : Text(_logo!.path.split('/').last),
              trailing: const Icon(Icons.image),
              onTap: _pickLogo,
            ),
            if (_logo != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Image.file(_logo!, height: 100),
              ),
            // THE NEW SWITCH
            SwitchListTile(
              title: const Text('Show Letterhead on Invoices'),
              subtitle: const Text('Includes your logo and company details at the top.'),
              value: _showLetterhead,
              onChanged: (bool value) {
                setState(() {
                  _showLetterhead = value;
                });
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveSettings,
              child: const Text('Save Settings'),
            ),
          ],
        ),
      ),
    );
  }
}