// lib/screens/clients/client_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:time_tracker/database/database.dart';
import 'package:drift/drift.dart' as drift;

class ClientEditScreen extends StatefulWidget {
  // This screen can be used for both adding and editing.
  // If a client is passed, we are in "edit" mode. Otherwise, "add" mode.
  final Client? client;

  const ClientEditScreen({super.key, this.client});

  @override
  State<ClientEditScreen> createState() => _ClientEditScreenState();
}

class _ClientEditScreenState extends State<ClientEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _currencyController;

  bool get _isEditing => widget.client != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.client?.name ?? '');
    _emailController = TextEditingController(text: widget.client?.email ?? '');
    _addressController = TextEditingController(
      text: widget.client?.address ?? '',
    );
    _currencyController = TextEditingController(
      text: widget.client?.currency ?? 'USD',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final db = Provider.of<AppDatabase>(context, listen: false);
      final entity = ClientsCompanion(
        id: _isEditing
            ? drift.Value(widget.client!.id)
            : const drift.Value.absent(),
        name: drift.Value(_nameController.text),
        email: drift.Value(_emailController.text),
        address: drift.Value(_addressController.text),
        currency: drift.Value(_currencyController.text),
      );

      if (_isEditing) {
        db.update(db.clients).replace(entity);
      } else {
        db.into(db.clients).insert(entity);
      }

      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Client' : 'Add Client'),
        actions: [IconButton(icon: const Icon(Icons.save), onPressed: _save)],
      ),
      body: _buildClientForm(),
    );
  }

  Widget _buildClientForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Client Name'),
              validator: (name) {
                if (name == null || name.isEmpty) {
                  return 'Please enter a name.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _currencyController,
              decoration: const InputDecoration(
                labelText: 'Currency (e.g., USD, BRL)',
              ),
              validator: (currency) {
                if (currency == null || currency.isEmpty) {
                  return 'Please enter a currency code.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}
