// lib/screens/administration/rappel_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/utils/user_roles.dart';

class RappelPage extends StatefulWidget {
  const RappelPage({super.key});

  @override
  State<RappelPage> createState() => _RappelPageState();
}

class _RappelPageState extends State<RappelPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Roles that will be notified.
  final List<String> _targetRoles = [
    UserRoles.admin,
    UserRoles.responsableAdministratif,
    UserRoles.responsableCommercial,
  ];

  // 🔔 NEW: Helper function to convert role names to valid FCM topic names
  String _roleToTopic(String role) {
    // Replace spaces with underscores to make valid FCM topic names
    return role.replaceAll(' ', '_');
  }

  Future<void> _showCreateReminderDialog() async {
    final _formKey = GlobalKey<FormState>();
    final _titleController = TextEditingController();
    DateTime? _selectedDate;
    TimeOfDay? _selectedTime;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nouveau Rappel',
                      style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Titre du rappel (ex: "Chèque Azadea")',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un titre';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today),
                            label: Text(_selectedDate == null
                                ? 'Date'
                                : DateFormat('dd/MM/yyyy')
                                .format(_selectedDate!)),
                            onPressed: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2101),
                              );
                              if (pickedDate != null) {
                                setModalState(() {
                                  _selectedDate = pickedDate;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time),
                            label: Text(_selectedTime == null
                                ? 'Heure'
                                : _selectedTime!.format(context)),
                            onPressed: () async {
                              final pickedTime = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (pickedTime != null) {
                                setModalState(() {
                                  _selectedTime = pickedTime;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () => _saveReminder(
                          _formKey,
                          _titleController.text,
                          _selectedDate,
                          _selectedTime,
                        ),
                        child: const Text('Enregistrer le Rappel'),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveReminder(
      GlobalKey<FormState> formKey,
      String title,
      DateTime? date,
      TimeOfDay? time,
      ) async {
    if (!formKey.currentState!.validate()) return;
    if (date == null || time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une date et une heure')),
      );
      return;
    }

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final dueAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);

      // 🔔 MODIFIED: Convert role names to valid FCM topic names
      final targetRolesForTopics = _targetRoles.map((role) => _roleToTopic(role)).toList();

      // Create the reminder document in Firestore
      await _firestore.collection('reminders').add({
        'title': title,
        'dueAt': Timestamp.fromDate(dueAt),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.displayName ?? 'Utilisateur Inconnu',
        'creatorUid': user.uid,
        'status': 'pending',
        'targetRoles': targetRolesForTopics, // 🔔 Using converted topic names
      });

      Navigator.of(context).pop(); // Close the bottom sheet
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rappel enregistré!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rappels'),
        backgroundColor: const Color(0xFF1E3A8A),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('reminders')
            .where('status', isEqualTo: 'pending')
            .orderBy('dueAt')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Aucun rappel en attente.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final reminders = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: reminders.length,
            itemBuilder: (context, index) {
              final reminder = reminders[index];
              final data = reminder.data() as Map<String, dynamic>;
              final dueAt = (data['dueAt'] as Timestamp).toDate();

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: ListTile(
                  leading: const Icon(Icons.notifications_active,
                      color: Color(0xFF1E3A8A)),
                  title: Text(
                    data['title'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Date: ${DateFormat('dd/MM/yyyy \'à\' HH:mm').format(dueAt)}',
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.check, color: Colors.green[700]),
                    tooltip: 'Marquer comme "envoyé" (manuel)',
                    onPressed: () {
                      reminder.reference.update({'status': 'sent'});
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateReminderDialog,
        backgroundColor: const Color(0xFF1E3A8A),
        child: const Icon(Icons.add),
      ),
    );
  }
}
