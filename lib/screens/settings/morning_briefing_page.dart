// lib/screens/settings/morning_briefing_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boitex_info_app/utils/user_roles.dart';

class MorningBriefingPage extends StatefulWidget {
  const MorningBriefingPage({super.key});

  @override
  State<MorningBriefingPage> createState() => _MorningBriefingPageState();
}

class _MorningBriefingPageState extends State<MorningBriefingPage> {
  bool _isLoading = true;

  // 1. Time Selection
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);

  // 2. Days Selection
  final List<String> _allDays = [
    'Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'
  ];
  List<String> _selectedDays = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi'];

  // 3. Recipients (Global List - Who receives the email?)
  final List<String> _allRoles = [
    UserRoles.admin,
    UserRoles.pdg,
    UserRoles.responsableAdministratif,
    UserRoles.responsableCommercial,
    UserRoles.responsableTechnique,
    UserRoles.responsableIT,
    UserRoles.chefDeProjet,
    UserRoles.technicienST,
    UserRoles.technicienIT,
  ];
  List<String> _selectedRecipients = [UserRoles.admin, UserRoles.pdg];

  // 4. Content Configuration (Who sees what?)
  // Key: ContentType, Value: List of allowed roles
  final Map<String, String> _contentTypeLabels = {
    'pending_interventions': 'Interventions en attente',
    'active_sav': 'SAV & Tickets en cours',
    'todays_livraisons': 'Livraisons du jour / prévues',
    'pending_billing': 'Facturation en attente',
    'pending_requisitions': 'Achats à valider (Réquisitions)',
  };

  // Stores the specific visibility for each content type
  // If a key is missing, it is disabled.
  // If the list is empty, it is enabled but visible to NO ONE (effectively disabled).
  // If list contains 'ALL', it is visible to everyone in _selectedRecipients.
  Map<String, List<String>> _contentVisibility = {};

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('morning_briefing')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            // Parse Time
            final timeMap = data['time'] as Map<String, dynamic>?;
            if (timeMap != null) {
              _selectedTime = TimeOfDay(
                hour: timeMap['hour'] ?? 8,
                minute: timeMap['minute'] ?? 0,
              );
            }

            // Parse Days
            if (data['days'] != null) {
              _selectedDays = List<String>.from(data['days']);
            }

            // Parse Global Recipients
            if (data['roles'] != null) {
              _selectedRecipients = List<String>.from(data['roles']);
            }

            // ✅ Parse Content Visibility Map
            if (data['content_visibility'] != null) {
              final Map<String, dynamic> rawMap = data['content_visibility'];
              _contentVisibility = rawMap.map((key, value) => MapEntry(key, List<String>.from(value)));
            } else if (data['contentTypes'] != null) {
              // Migration for old format (simple list) -> Convert to "All Roles"
              final oldList = List<String>.from(data['contentTypes']);
              for (var type in oldList) {
                _contentVisibility[type] = List.from(_allRoles); // Default to all
              }
            }
          });
        }
      } else {
        // Init default settings if fresh
        setState(() {
          _contentVisibility = {
            'pending_interventions': List.from(_allRoles),
            'active_sav': List.from(_allRoles),
            'pending_requisitions': [UserRoles.pdg], // Example default
          };
        });
      }
    } catch (e) {
      print("Error fetching settings: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('morning_briefing')
          .set({
        'enabled': true,
        'time': {
          'hour': _selectedTime.hour,
          'minute': _selectedTime.minute,
          'formatted': _selectedTime.format(context),
        },
        'days': _selectedDays,
        'roles': _selectedRecipients, // Who gets the email
        'content_visibility': _contentVisibility, // Who sees what section
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration avancée enregistrée !'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickTime() async {
    final newTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (newTime != null) {
      setState(() => _selectedTime = newTime);
    }
  }

  // Helper to show role selection dialog for a specific content type
  Future<void> _showRoleFilterDialog(String contentType, String label) async {
    // Current allowed roles for this specific content
    List<String> currentAllowed = List.from(_contentVisibility[contentType] ?? []);

    // If empty but the key exists, it means "No one".
    // If key doesn't exist, we shouldn't be here (toggle handles that).

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isAllSelected = currentAllowed.length == _allRoles.length;

            return AlertDialog(
              title: Text('Visibilité: $label'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        title: const Text("Tout le monde (Tous les rôles)"),
                        leading: Checkbox(
                          value: isAllSelected,
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                currentAllowed = List.from(_allRoles);
                              } else {
                                currentAllowed = [];
                              }
                            });
                          },
                        ),
                      ),
                      const Divider(),
                      ..._allRoles.map((role) {
                        final isSelected = currentAllowed.contains(role);
                        return CheckboxListTile(
                          title: Text(role),
                          value: isSelected,
                          dense: true,
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                currentAllowed.add(role);
                              } else {
                                currentAllowed.remove(role);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _contentVisibility[contentType] = currentAllowed;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Valider'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Config. Morning Briefing'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECTION 1: TIME ---
            _buildSectionTitle('1. Heure d\'envoi'),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.access_time, color: Colors.blue),
                title: Text(
                  _selectedTime.format(context),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Heure locale du serveur'),
                trailing: TextButton(
                  onPressed: _pickTime,
                  child: const Text('MODIFIER'),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- SECTION 2: DAYS ---
            _buildSectionTitle('2. Jours d\'activité'),
            Wrap(
              spacing: 8.0,
              children: _allDays.map((day) {
                final isSelected = _selectedDays.contains(day);
                return FilterChip(
                  label: Text(day),
                  selected: isSelected,
                  selectedColor: Colors.orange.withOpacity(0.2),
                  checkmarkColor: Colors.orange,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.deepOrange : Colors.black,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedDays.add(day);
                      } else {
                        _selectedDays.remove(day);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // --- SECTION 3: GLOBAL RECIPIENTS ---
            _buildSectionTitle('3. Destinataires (Qui reçoit l\'email ?)'),
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0, left: 4),
              child: Text("Sélectionnez les rôles qui recevront le briefing.", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            Wrap(
              spacing: 8.0,
              children: _allRoles.map((role) {
                final isSelected = _selectedRecipients.contains(role);
                return FilterChip(
                  label: Text(role),
                  selected: isSelected,
                  selectedColor: Colors.blue.withOpacity(0.2),
                  checkmarkColor: Colors.blue,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.blue[800] : Colors.black,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedRecipients.add(role);
                      } else {
                        _selectedRecipients.remove(role);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // --- SECTION 4: CONTENT & VISIBILITY ---
            _buildSectionTitle('4. Contenu et Permissions'),
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0, left: 4),
              child: Text("Personnalisez qui voit quoi dans son rapport.", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: _contentTypeLabels.entries.map((entry) {
                  final key = entry.key;
                  final label = entry.value;

                  // Is this content type enabled? (Exists in map)
                  final isEnabled = _contentVisibility.containsKey(key);

                  // How many roles can see it?
                  final allowedRoles = _contentVisibility[key] ?? [];
                  String roleSummary;
                  if (!isEnabled) {
                    roleSummary = "Désactivé";
                  } else if (allowedRoles.length == _allRoles.length) {
                    roleSummary = "Visible par tous";
                  } else if (allowedRoles.isEmpty) {
                    roleSummary = "Visible par personne";
                  } else {
                    // Show first 2 roles + count
                    final firstTwo = allowedRoles.take(2).join(", ");
                    if (allowedRoles.length > 2) {
                      roleSummary = "$firstTwo (+${allowedRoles.length - 2})";
                    } else {
                      roleSummary = firstTwo;
                    }
                  }

                  IconData icon;
                  Color color;
                  // Assign icons based on type
                  if (key == 'pending_interventions') {
                    icon = Icons.build_circle_outlined; color = Colors.orange;
                  } else if (key == 'active_sav') {
                    icon = Icons.confirmation_number_outlined; color = Colors.red;
                  } else if (key == 'todays_livraisons') {
                    icon = Icons.local_shipping_outlined; color = Colors.blue;
                  } else if (key == 'pending_billing') {
                    icon = Icons.receipt_long_rounded; color = Colors.purple;
                  } else {
                    icon = Icons.shopping_cart_outlined; color = Colors.teal;
                  }

                  return Column(
                    children: [
                      SwitchListTile(
                        value: isEnabled,
                        activeColor: color,
                        title: Row(
                          children: [
                            Icon(icon, color: isEnabled ? color : Colors.grey),
                            const SizedBox(width: 12),
                            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
                          ],
                        ),
                        subtitle: Text(
                          roleSummary,
                          style: TextStyle(color: isEnabled ? Colors.black54 : Colors.grey.shade400, fontSize: 12),
                        ),
                        onChanged: (bool value) {
                          setState(() {
                            if (value) {
                              // Enable it (default to all selected recipients or all roles)
                              _contentVisibility[key] = List.from(_allRoles);
                            } else {
                              // Disable it (remove key)
                              _contentVisibility.remove(key);
                            }
                          });
                        },
                      ),
                      if (isEnabled)
                        Padding(
                          padding: const EdgeInsets.only(left: 56, bottom: 12, right: 16),
                          child: InkWell(
                            onTap: () => _showRoleFilterDialog(key, label),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.visibility, size: 16, color: Colors.grey.shade700),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Modifier la visibilité",
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const Divider(height: 1),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 40),

            // --- SAVE BUTTON ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save),
                label: const Text('ENREGISTRER LA CONFIGURATION'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }
}