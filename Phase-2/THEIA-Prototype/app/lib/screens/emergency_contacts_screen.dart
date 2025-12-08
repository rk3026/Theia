import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/emergency_contact.dart';
import '../services/storage_service.dart';
import '../services/validation_service.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  late final StorageService _storageService;
  final Uuid _uuid = const Uuid();
  List<EmergencyContact> _contacts = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _storageService = context.read<StorageService>();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _loading = true;
    });
    final contacts = await _storageService.getEmergencyContacts();
    if (mounted) {
      setState(() {
        _contacts = contacts;
        _loading = false;
      });
    }
  }

  Future<void> _showContactDialog({EmergencyContact? existing}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existing?.name ?? '');
    final phoneController = TextEditingController(text: existing?.phoneNumber ?? '');
    final relationshipController = TextEditingController(text: existing?.relationship ?? '');
    final emailController = TextEditingController(text: existing?.email ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');
    var isPrimary = existing?.isPrimary ?? _contacts.isEmpty;

    final result = await showDialog<EmergencyContact>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existing == null ? 'Add Emergency Contact' : 'Edit Emergency Contact'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) => ValidationService.validateRequired(value, fieldName: 'Name'),
                  ),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone Number'),
                    keyboardType: TextInputType.phone,
                    validator: ValidationService.validatePhone,
                  ),
                  TextFormField(
                    controller: relationshipController,
                    decoration: const InputDecoration(labelText: 'Relationship'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email (optional)'),
                    keyboardType: TextInputType.emailAddress,
                    validator: ValidationService.validateEmail,
                  ),
                  TextFormField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Notes (optional)'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  StatefulBuilder(
                    builder: (context, setLocalState) {
                      return CheckboxListTile(
                        value: isPrimary,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Primary contact'),
                        subtitle: const Text('Will be contacted first during emergencies'),
                        onChanged: (value) {
                          setLocalState(() {
                            isPrimary = value ?? false;
                          });
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  final contact = EmergencyContact(
                    id: existing?.id ?? _uuid.v4(),
                    name: nameController.text.trim(),
                    phoneNumber: phoneController.text.trim(),
                    isPrimary: isPrimary,
                    relationship: relationshipController.text.trim().isEmpty
                        ? 'Emergency contact'
                        : relationshipController.text.trim(),
                    email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                    notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                  );
                  Navigator.pop(context, contact);
                }
              },
              child: Text(existing == null ? 'Add Contact' : 'Save Changes'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      if (existing == null) {
        await _storageService.saveEmergencyContact(result);
      } else {
        await _storageService.updateEmergencyContact(result);
      }
      await _loadContacts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existing == null
                ? 'Added ${result.name} to emergency contacts.'
                : 'Updated ${result.name}.'),
          ),
        );
      }
    }

    nameController.dispose();
    phoneController.dispose();
    relationshipController.dispose();
    emailController.dispose();
    notesController.dispose();
  }

  Future<void> _setPrimary(EmergencyContact contact) async {
    final updated = contact.copyWith(isPrimary: true);
    await _storageService.updateEmergencyContact(updated);
    await _loadContacts();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${contact.name} set as primary contact.')),
      );
    }
  }

  Future<void> _deleteContact(EmergencyContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove Contact'),
          content: Text('Remove ${contact.name} from emergency contacts?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _storageService.deleteEmergencyContact(contact.id);
      await _loadContacts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed ${contact.name}.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showContactDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Contact'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _contacts.length,
                  itemBuilder: (context, index) {
                    final contact = _contacts[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(
                          contact.isPrimary ? Icons.star : Icons.person_outline,
                          color: contact.isPrimary ? Colors.amber : Colors.blueGrey,
                        ),
                        title: Text(contact.name),
                        subtitle: _buildContactDetails(contact),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'primary':
                                if (!contact.isPrimary) {
                                  _setPrimary(contact);
                                }
                                break;
                              case 'edit':
                                _showContactDialog(existing: contact);
                                break;
                              case 'delete':
                                _deleteContact(contact);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            if (!contact.isPrimary)
                              const PopupMenuItem(
                                value: 'primary',
                                child: Text('Set as Primary'),
                              ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Remove'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildContactDetails(EmergencyContact contact) {
    final details = <Widget>[
      Text(contact.phoneNumber, style: const TextStyle(fontWeight: FontWeight.w600)),
      if (contact.relationship.isNotEmpty)
        Text(contact.relationship, style: TextStyle(color: Colors.blueGrey.shade700)),
    ];

    if (contact.email != null && contact.email!.isNotEmpty) {
      details.add(Text(contact.email!, style: TextStyle(color: Colors.blueGrey.shade700)));
    }
    if (contact.notes != null && contact.notes!.isNotEmpty) {
      details.add(Text(contact.notes!, style: TextStyle(color: Colors.blueGrey.shade700)));
    }
    if (contact.isPrimary) {
      details.add(
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Chip(
            label: const Text('Primary'),
            backgroundColor: Colors.blue.shade100,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: details,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 96, color: Colors.blueGrey.shade400),
            const SizedBox(height: 24),
            const Text(
              'No emergency contacts yet',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Add trusted contacts who should be notified during emergencies.',
              style: TextStyle(fontSize: 16, color: Colors.blueGrey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _showContactDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Contact'),
            ),
          ],
        ),
      ),
    );
  }
}
