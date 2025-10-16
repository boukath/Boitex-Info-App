// lib/screens/administration/mission_details_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ✅ ADDED: For user roles
import 'package:boitex_info_app/models/mission.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

class MissionDetailsPage extends StatefulWidget {
  final Mission mission;

  const MissionDetailsPage({super.key, required this.mission});

  @override
  State<MissionDetailsPage> createState() => _MissionDetailsPageState();
}

class _MissionDetailsPageState extends State<MissionDetailsPage> {
  late Mission _currentMission;
  bool _isUpdatingStatus = false;
  String? _userRole; // ✅ ADDED: To store user role

  @override
  void initState() {
    super.initState();
    _currentMission = widget.mission;
    _fetchUserRole(); // ✅ ADDED: Fetch role on init
  }

  // ✅ NEW: Fetches the current user's role from Firestore
  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (mounted) {
      setState(() {
        _userRole = userDoc.data()?['role'] as String?;
      });
    }
  }

  // Toggles the completion status of a mission task
  Future<void> _toggleTaskStatus(int taskIndex, bool isCompleted) async {
    setState(() {
      _currentMission.tasks[taskIndex].isCompleted = isCompleted;
    });

    final List<Map<String, dynamic>> updatedTasks =
    _currentMission.tasks.map((task) => task.toJson()).toList();

    try {
      if (_currentMission.id == null) return;
      await FirebaseFirestore.instance
          .collection('missions')
          .doc(_currentMission.id)
          .update({'tasks': updatedTasks});
    } catch (e) {
      // Revert state if update fails
      setState(() {
        _currentMission.tasks[taskIndex].isCompleted = !isCompleted;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la mise à jour: $e')),
        );
      }
    }
  }

  // Updates the overall status of the mission
  Future<void> _updateMissionStatus(String newStatus) async {
    setState(() { _isUpdatingStatus = true; });

    try {
      if (_currentMission.id == null) return;
      await FirebaseFirestore.instance
          .collection('missions')
          .doc(_currentMission.id)
          .update({'status': newStatus});

      final updatedDoc = await FirebaseFirestore.instance.collection('missions').doc(_currentMission.id!).get();
      if (mounted) {
        setState(() {
          _currentMission = Mission.fromFirestore(updatedDoc);
        });
      }

    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) {
        setState(() { _isUpdatingStatus = false; });
      }
    }
  }

  // ✅ NEW: Shows a dialog to edit mission dates
  Future<void> _showEditDatesDialog() async {
    DateTime? newStartDate = _currentMission.startDate;
    DateTime? newEndDate = _currentMission.endDate;

    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Modifier les dates de la mission'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text('Début: ${DateFormat("dd/MM/yyyy").format(newStartDate!)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: newStartDate!,
                        firstDate: DateTime.now().subtract(const Duration(days: 30)), // Allow past dates for correction
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setDialogState(() => newStartDate = date);
                      }
                    },
                  ),
                  ListTile(
                    title: Text('Fin: ${DateFormat("dd/MM/yyyy").format(newEndDate!)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: newEndDate!,
                        firstDate: newStartDate!,
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setDialogState(() => newEndDate = date);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {'start': newStartDate!, 'end': newEndDate!});
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      await _updateMissionDates(result['start']!, result['end']!);
    }
  }

  // ✅ NEW: Updates mission dates after checking vehicle availability
  Future<void> _updateMissionDates(DateTime newStartDate, DateTime newEndDate) async {
    if (_currentMission.resources?.vehicleId == null) {
      // If no vehicle, just update the dates
      _performDateUpdate(newStartDate, newEndDate);
      return;
    }

    // Check for vehicle conflict
    final conflictingMissions = await FirebaseFirestore.instance
        .collection('missions')
        .where('resources.vehicleId', isEqualTo: _currentMission.resources!.vehicleId)
        .where('status', whereIn: ['Planifiée', 'En Cours'])
        .where(FieldPath.documentId, isNotEqualTo: _currentMission.id) // Exclude current mission
        .get();

    bool hasConflict = false;
    for (var missionDoc in conflictingMissions.docs) {
      final missionData = missionDoc.data();
      final existingStart = (missionData['startDate'] as Timestamp).toDate();
      final existingEnd = (missionData['endDate'] as Timestamp).toDate();

      if (newStartDate.isBefore(existingEnd) && newEndDate.isAfter(existingStart)) {
        hasConflict = true;
        break;
      }
    }

    if (hasConflict) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CONFLIT: Le véhicule est déjà réservé pour ces dates.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      // No conflict, proceed with update
      _performDateUpdate(newStartDate, newEndDate);
    }
  }

  // ✅ NEW: Helper function to perform the Firestore update
  Future<void> _performDateUpdate(DateTime startDate, DateTime endDate) async {
    try {
      await FirebaseFirestore.instance.collection('missions').doc(_currentMission.id!).update({
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
      });

      final updatedDoc = await FirebaseFirestore.instance.collection('missions').doc(_currentMission.id!).get();
      if (mounted) {
        setState(() {
          _currentMission = Mission.fromFirestore(updatedDoc);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dates de mission mises à jour.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }


  // Shows a dialog to add an expense with file attachments
  Future<void> _showAddExpenseDialog(String categoryName, String categoryKey) async {
    final amountController = TextEditingController();
    List<File> pickedFiles = [];
    bool isUploading = false;
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Ajouter une dépense pour $categoryName'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Montant Dépensé (DZD)'),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer un montant';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Veuillez entrer un nombre valide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.attach_file),
                        label: Text('Joindre Justificatifs (${pickedFiles.length})'),
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                            allowMultiple: true,
                          );
                          if (result != null) {
                            setDialogState(() {
                              pickedFiles = result.paths.map((path) => File(path!)).toList();
                            });
                          }
                        },
                      ),
                      if (isUploading) const Padding(
                        padding: EdgeInsets.only(top: 16.0),
                        child: CircularProgressIndicator(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Annuler'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: const Text('Enregistrer'),
                  onPressed: isUploading ? null : () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    setDialogState(() { isUploading = true; });

                    try {
                      List<String> uploadedUrls = [];
                      for (var file in pickedFiles) {
                        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
                        final storageRef = FirebaseStorage.instance
                            .ref()
                            .child('missions/${_currentMission.id}/$categoryKey/$fileName');
                        await storageRef.putFile(file);
                        final url = await storageRef.getDownloadURL();
                        uploadedUrls.add(url);
                      }

                      final double amount = double.tryParse(amountController.text) ?? 0.0;

                      await FirebaseFirestore.instance
                          .collection('missions')
                          .doc(_currentMission.id)
                          .update({
                        'expenseReport.$categoryKey.spent': FieldValue.increment(amount),
                        'expenseReport.$categoryKey.billUrls': FieldValue.arrayUnion(uploadedUrls)
                      });

                      final updatedDoc = await FirebaseFirestore.instance.collection('missions').doc(_currentMission.id!).get();

                      if (mounted) {
                        setState(() {
                          _currentMission = Mission.fromFirestore(updatedDoc);
                        });
                        Navigator.of(context).pop();
                      }

                    } catch (e) {
                      if(mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                      }
                    } finally {
                      if(mounted) {
                        setDialogState(() { isUploading = false; });
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Shows a dialog with the list of bills (justificatifs)
  void _showBillsDialog(String categoryName, ExpenseCategory category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Justificatifs pour $categoryName'),
        content: SizedBox(
          width: double.maxFinite,
          child: category.billUrls.isEmpty
              ? const Center(child: Text('Aucun justificatif ajouté.'))
              : ListView.builder(
            shrinkWrap: true,
            itemCount: category.billUrls.length,
            itemBuilder: (context, index) {
              final url = category.billUrls[index];
              return ListTile(
                leading: const Icon(Icons.image, color: Colors.blue),
                title: Text('Justificatif ${index + 1}'),
                onTap: () async {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Impossible d\'ouvrir le lien: $url')),
                      );
                    }
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_currentMission.title),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Theme.of(context).primaryColor, Colors.cyan],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.info_outline), text: 'Détails'),
              Tab(icon: Icon(Icons.monetization_on_outlined), text: 'Dépenses'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDetailsTab(context),
            _buildExpensesTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Techniciens Assignés', Icons.people_outline),
          const SizedBox(height: 8),
          _buildTechniciansCard(),
          const SizedBox(height: 24),
          _buildResourcesCard(),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Liste des Tâches', Icons.check_circle_outline),
          const SizedBox(height: 8),
          _buildTasksCard(),
          const SizedBox(height: 24),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildExpensesTab(BuildContext context) {
    final report = _currentMission.expenseReport;
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'DA', decimalDigits: 2);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Budget Total:', style: TextStyle(fontSize: 16)),
                      Text(currencyFormat.format(report.totalBudget), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Dépensé:', style: TextStyle(fontSize: 16, color: Colors.red)),
                      Text(currencyFormat.format(report.totalSpent), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Restant:', style: TextStyle(fontSize: 18, color: Colors.green)),
                      Text(currencyFormat.format(report.totalRemaining), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ...report.dailyAllowancesPerTechnician.entries.map((entry) {
            final techName = entry.key;
            final category = entry.value;
            final categoryKey = 'dailyAllowancesPerTechnician.$techName';
            return _buildExpenseCategoryCard(
              'Frais de Mission ($techName)',
              category,
              Icons.person_outline,
              currencyFormat,
              categoryKey,
            );
          }).toList(),
          _buildExpenseCategoryCard('Carburant', report.fuel, Icons.local_gas_station_outlined, currencyFormat, 'fuel'),
          _buildExpenseCategoryCard('Achats', report.purchases, Icons.shopping_cart_outlined, currencyFormat, 'purchases'),
          _buildExpenseCategoryCard('Hôtel', report.hotel, Icons.hotel_outlined, currencyFormat, 'hotel'),
        ],
      ),
    );
  }

  Widget _buildExpenseCategoryCard(String title, ExpenseCategory category, IconData icon, NumberFormat format, String categoryKey) {
    final double progress = category.budget > 0 ? (category.spent / category.budget).clamp(0, 1) : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Dépensé: ${format.format(category.spent)}'),
                Text('Budget: ${format.format(category.budget)}'),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(progress > 0.8 ? Colors.red : Colors.blue),
              ),
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showBillsDialog(title, category),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: Text('Justificatifs (${category.billUrls.length})'),
                ),
                ElevatedButton(
                  onPressed: () => _showAddExpenseDialog(title, categoryKey),
                  child: const Text('Ajouter Dépense'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildResourcesCard() {
    final resources = _currentMission.resources;
    if (resources == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Ressources Requises', Icons.construction),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Véhicule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.directions_car, color: Colors.blue),
                  title: Text(resources.vehicleModel ?? 'Non spécifié'),
                  subtitle: Text(resources.vehiclePlate ?? 'Aucun véhicule assigné'),
                ),

                if (resources.equipment.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Équipement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(),
                  ...resources.equipment.map((item) => ListTile(
                    leading: const Icon(Icons.build, color: Colors.orange),
                    title: Text(item),
                  )),
                ],

                if (resources.preMissionPurchases.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Achats Pré-Mission', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(),
                  ...resources.preMissionPurchases.map((item) {
                    return Card(
                      color: Colors.grey[100],
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.shopping_cart, color: Colors.green),
                        title: Text(item.item, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(item.description.isEmpty ? 'Aucune description' : item.description),
                        trailing: Text(
                          '~${NumberFormat.currency(locale: 'fr_FR', symbol: 'DZD', decimalDigits: 0).format(item.estimatedBudget)}',
                          style: const TextStyle(color: Colors.green),
                        ),
                      ),
                    );
                  }),
                  if (resources.purchaseNotes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 16, right: 16),
                      child: Text('Notes: ${resources.purchaseNotes}', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black54)),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    final formattedStartDate = DateFormat('dd MMM yyyy', 'fr_FR').format(_currentMission.startDate);
    final formattedEndDate = DateFormat('dd MMM yyyy', 'fr_FR').format(_currentMission.endDate);
    // ✅ CHANGED: Determine if the edit button should be visible
    final bool canEdit = (_userRole == 'Responsable Administratif' || _userRole == 'Admin') &&
        (_currentMission.status == 'Planifiée' || _currentMission.status == 'En Cours');


    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Service'),
            subtitle: Text(_currentMission.serviceType, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Destination(s)'),
            subtitle: Text(_currentMission.destinationsDisplay, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('Dates'),
            subtitle: Text('Du $formattedStartDate au $formattedEndDate', style: const TextStyle(fontSize: 16)),
            // ✅ CHANGED: Show edit button based on role and status
            trailing: canEdit
                ? IconButton(
              icon: const Icon(Icons.edit_calendar_outlined, color: Colors.blue),
              onPressed: _showEditDatesDialog,
            )
                : null,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Statut'),
            subtitle: Text(_currentMission.status, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _getStatusColor(_currentMission.status))),
          ),
        ],
      ),
    );
  }

  Widget _buildTechniciansCard() {
    return Card(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _currentMission.assignedTechniciansNames.length,
        itemBuilder: (context, index) {
          final techName = _currentMission.assignedTechniciansNames[index];
          final techRole = _currentMission.assignedTechniciansRoles.length > index
              ? _currentMission.assignedTechniciansRoles[index]
              : 'N/A';
          return ListTile(
            leading: CircleAvatar(child: Text(techName.substring(0,1))),
            title: Text(techName),
            subtitle: Text(techRole),
          );
        },
      ),
    );
  }

  Widget _buildTasksCard() {
    if (_currentMission.tasks.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: Text("Aucune tâche définie pour cette mission.")),
        ),
      );
    }
    return Card(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _currentMission.tasks.length,
        itemBuilder: (context, index) {
          final task = _currentMission.tasks[index];
          return ListTile(
            leading: Checkbox(
              value: task.isCompleted,
              onChanged: (bool? newValue) {
                if (newValue != null) {
                  _toggleTaskStatus(index, newValue);
                }
              },
            ),
            title: Text(
              task.description,
              style: TextStyle(
                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                color: task.isCompleted ? Colors.grey : null,
              ),
            ),
            onTap: () {
              _toggleTaskStatus(index, !task.isCompleted);
            },
          );
        },
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_isUpdatingStatus) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_currentMission.status) {
      case 'Planifiée':
        return Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.flight_takeoff),
            label: const Text('Démarrer la Mission'),
            onPressed: () => _updateMissionStatus('En Cours'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          ),
        );
      case 'En Cours':
        return Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_circle),
            label: const Text('Terminer la Mission'),
            onPressed: () => _updateMissionStatus('Terminée'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        );
      case 'Terminée':
        return Center(
          child: Text(
            'Cette mission est terminée.',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'En Cours':
        return Colors.orange;
      case 'Terminée':
        return Colors.green;
      case 'Annulée':
        return Colors.red;
      case 'Planifiée':
      default:
        return Colors.blue;
    }
  }
}