// lib/screens/administration/add_mission_page.dart

// ✨ BEAUTIFUL COLORFUL MISSION CREATION PAGE
// Features: Multi-destinations, Vehicle selection, Equipment, Shopping list, Per-person budgets

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:boitex_info_app/models/mission.dart';
import 'package:boitex_info_app/models/vehicle.dart';

// User view model with role
class UserViewModel {
  final String id;
  final String name;
  final String role;
  UserViewModel({required this.id, required this.name, required this.role});
}

class AddMissionPage extends StatefulWidget {
  const AddMissionPage({super.key});

  @override
  State<AddMissionPage> createState() => _AddMissionPageState();
}

class _AddMissionPageState extends State<AddMissionPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // ✨ COLORS
  static const gradientColors = [Color(0xFF9C27B0), Color(0xFF00BCD4)];
  static const sectionColors = {
    'mission': Color(0xFFF3E5F5),
    'team': Color(0xFFE3F2FD),
    'budget': Color(0xFFE8F5E9),
    'resources': Color(0xFFFFF3E0),
    'tasks': Color(0xFFFCE4EC),
  };
  static const roleBadgeColors = {
    'Technicien': Colors.blue,
    'Manager': Colors.purple,
    'Admin': Colors.green
  };

  // STATE
  String? _selectedServiceType;
  final _titleController = TextEditingController();
  final List<String> _destinations = [];
  final _destinationController = TextEditingController();
  DateTime? _startDate, _endDate;
  List<UserViewModel> _selectedTechnicians = [], _allUsers = [];
  final _taskController = TextEditingController();
  final List<MissionTask> _tasks = [];
  final Map<String, TextEditingController> _perPersonBudgetControllers = {};
  final _fuelBudgetController = TextEditingController(text: '0');
  final _hotelBudgetController = TextEditingController(text: '0');
  Vehicle? _selectedVehicle;
  List<Vehicle> _availableVehicles = [];
  String? _vehicleAvailabilityStatus;
  final List<String> _equipment = [];
  final _equipmentController = TextEditingController();
  final List<PurchaseItem> _preMissionPurchases = [];
  final _purchaseNotesController = TextEditingController();

  // ✅ OPTIMIZED: Async initialization
  late Future<void> _loadDataFuture;

  @override
  void initState() {
    super.initState();
    _loadDataFuture = _loadData();
  }

  // ✅ Load data in parallel
  Future<void> _loadData() async {
    try {
      await Future.wait([
        _fetchUsers(),
        _fetchVehicles(),
      ]);
    } catch (e) {
      debugPrint('Error loading data: $e');
      rethrow; // Allow FutureBuilder to catch error
    }
  }

  Future<void> _fetchUsers() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isNotEqualTo: 'PDG')
          .get();

      if (mounted) {
        setState(() {
          _allUsers = snap.docs
              .map((doc) => UserViewModel(
            id: doc.id,
            name: doc['displayName'] as String? ?? 'Unknown',
            role: doc['role'] as String? ?? 'Technicien',
          ))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
      rethrow;
    }
  }

  Future<void> _fetchVehicles() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('vehicles')
          .where('status', whereIn: ['available', 'in_use'])
          .get();

      if (mounted) {
        setState(() {
          _availableVehicles = snap.docs
              .map((doc) => Vehicle.fromFirestore(doc))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching vehicles: $e');
      rethrow;
    }
  }

  Future<void> _checkVehicleAvailability() async {
    if (_selectedVehicle == null || _startDate == null || _endDate == null) {
      setState(() => _vehicleAvailabilityStatus = null);
      return;
    }

    final conflicting = await FirebaseFirestore.instance
        .collection('missions')
        .where('resources.vehicleId', isEqualTo: _selectedVehicle!.id)
        .where('status', whereIn: ['Planifiée', 'En Cours'])
        .get();

    bool hasConflict = false;
    for (var mission in conflicting.docs) {
      final data = mission.data();
      final existingStart = (data['startDate'] as Timestamp).toDate();
      final existingEnd = (data['endDate'] as Timestamp).toDate();
      if (_startDate!.isBefore(existingEnd) && _endDate!.isAfter(existingStart)) {
        hasConflict = true;
        break;
      }
    }
    setState(() => _vehicleAvailabilityStatus = hasConflict ? 'conflict' : 'available');
  }

  // ACTIONS
  void _addDestination() {
    if (_destinationController.text.trim().isEmpty) return;
    setState(() {
      _destinations.add(_destinationController.text.trim());
      _destinationController.clear();
    });
  }

  void _addTask() {
    if (_taskController.text.trim().isEmpty) return;
    setState(() {
      _tasks.add(MissionTask(description: _taskController.text.trim()));
      _taskController.clear();
    });
  }

  void _addEquipment() {
    if (_equipmentController.text.trim().isEmpty) return;
    setState(() {
      _equipment.add(_equipmentController.text.trim());
      _equipmentController.clear();
    });
  }

  void _addPurchaseItem() {
    setState(() {
      _preMissionPurchases.add(PurchaseItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        item: '',
      ));
    });
  }

  void _onTeamSelected(List<UserViewModel> selected) {
    setState(() {
      _selectedTechnicians = selected;
      // Create budget controllers for new members
      for (var tech in selected) {
        if (!_perPersonBudgetControllers.containsKey(tech.id)) {
          _perPersonBudgetControllers[tech.id] = TextEditingController(text: '2000');
        }
      }
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_destinations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins une destination')),
      );
      return;
    }
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez les dates')),
      );
      return;
    }
    if (_selectedTechnicians.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez au moins un membre')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final currentYear = DateTime.now().year;
        final counterRef = FirebaseFirestore.instance
            .collection('counters')
            .doc('mission_counter_$currentYear');
        final counterSnap = await transaction.get(counterRef);
        final newCount = ((counterSnap.data()?['count'] as int?) ?? 0) + 1;
        final missionCode = 'MISS-$newCount/$currentYear';

        // Build expense report with per-person budgets
        final dailyAllowances = <String, ExpenseCategory>{};
        for (var tech in _selectedTechnicians) {
          final budget = double.tryParse(_perPersonBudgetControllers[tech.id]?.text ?? '0') ?? 0.0;
          dailyAllowances[tech.name] = ExpenseCategory(budget: budget);
        }

        final expenseReport = ExpenseReport(
          dailyAllowancesPerTechnician: dailyAllowances,
          fuel: ExpenseCategory(budget: double.tryParse(_fuelBudgetController.text) ?? 0.0),
          purchases: ExpenseCategory(budget: 0.0),
          hotel: ExpenseCategory(budget: double.tryParse(_hotelBudgetController.text) ?? 0.0),
        );

        // Build resources
        final resources = MissionResources(
          vehicleId: _selectedVehicle?.id,
          vehicleModel: _selectedVehicle?.model,
          vehiclePlate: _selectedVehicle?.plateNumber,
          equipment: _equipment,
          preMissionPurchases: _preMissionPurchases,
          purchaseNotes: _purchaseNotesController.text.trim(),
        );

        final mission = Mission(
          missionCode: missionCode,
          serviceType: _selectedServiceType!,
          title: _titleController.text.trim(),
          destinations: _destinations,
          startDate: _startDate!,
          endDate: _endDate!,
          assignedTechniciansIds: _selectedTechnicians.map((t) => t.id).toList(),
          assignedTechniciansNames: _selectedTechnicians.map((t) => t.name).toList(),
          assignedTechniciansRoles: _selectedTechnicians.map((t) => t.role).toList(),
          tasks: _tasks,
          status: 'Planifiée',
          expenseReport: expenseReport,
          resources: resources,
          createdAt: DateTime.now(),
          createdBy: 'Admin',
        );

        final missionRef = FirebaseFirestore.instance.collection('missions').doc();
        transaction.set(missionRef, mission.toJson());
        transaction.set(counterRef, {'count': newCount}, SetOptions(merge: true));
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mission créée avec succès!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('✨ Créer une Mission'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: FutureBuilder<void>(
        future: _loadDataFuture,
        builder: (context, snapshot) {
          // ✅ LOADING STATE
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Chargement des données...',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          // ✅ ERROR STATE
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Erreur de chargement',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _loadDataFuture = _loadData());
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // ✅ SUCCESS - SHOW FORM
          return _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildMissionInfoSection(),
                const SizedBox(height: 16),
                _buildTeamSection(),
                const SizedBox(height: 16),
                _buildBudgetSection(),
                const SizedBox(height: 16),
                _buildResourcesSection(),
                const SizedBox(height: 16),
                _buildTasksSection(),
                const SizedBox(height: 24),
                _buildSubmitButton(),
              ],
            ),
          );
        },
      ),
    );
  }

  // SECTION BUILDERS
  Widget _buildMissionInfoSection() {
    return _buildSection(
      title: '📋 INFORMATIONS MISSION',
      color: sectionColors['mission']!,
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _selectedServiceType,
            decoration: const InputDecoration(
              labelText: 'Type de Service',
              border: OutlineInputBorder(),
            ),
            items: ['Service Technique', 'Service IT']
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (val) => setState(() => _selectedServiceType = val),
            validator: (v) => v == null ? 'Requis' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Titre de la Mission',
              border: OutlineInputBorder(),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
          ),
          const SizedBox(height: 12),
          const Text(
            'DESTINATIONS (glissez pour réordonner):',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_destinations.isNotEmpty)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _destinations.length,
              onReorder: (oldIdx, newIdx) {
                setState(() {
                  if (newIdx > oldIdx) newIdx--;
                  final item = _destinations.removeAt(oldIdx);
                  _destinations.insert(newIdx, item);
                });
              },
              itemBuilder: (context, index) {
                return Card(
                  key: ValueKey(_destinations[index]),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.drag_handle, color: Colors.grey),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          child: Text('${index + 1}'),
                          backgroundColor: Colors.purple.shade100,
                        ),
                      ],
                    ),
                    title: Text(_destinations[index]),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => setState(() => _destinations.removeAt(index)),
                    ),
                  ),
                );
              },
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _destinationController,
                  decoration: const InputDecoration(
                    labelText: 'Nouvelle destination',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.purple),
                onPressed: _addDestination,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListTile(
            title: Text(_startDate == null
                ? 'Date de Début'
                : 'Début: ${DateFormat("dd/MM/yyyy").format(_startDate!)}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime(2030),
              );
              if (date != null) {
                setState(() => _startDate = date);
                _checkVehicleAvailability();
              }
            },
          ),
          ListTile(
            title: Text(_endDate == null
                ? 'Date de Fin'
                : 'Fin: ${DateFormat("dd/MM/yyyy").format(_endDate!)}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _startDate ?? DateTime.now(),
                firstDate: _startDate ?? DateTime.now(),
                lastDate: DateTime(2030),
              );
              if (date != null) {
                setState(() => _endDate = date);
                _checkVehicleAvailability();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTeamSection() {
    return _buildSection(
      title: '👥 ÉQUIPE MISSION',
      color: sectionColors['team']!,
      child: Column(
        children: [
          MultiSelectDialogField<UserViewModel>(
            items: _allUsers.map((u) => MultiSelectItem(u, u.name)).toList(),
            title: const Text('Sélectionner Membres'),
            selectedColor: Colors.purple,
            buttonText: const Text('Sélectionner Techniciens'),
            onConfirm: _onTeamSelected,
            chipDisplay: MultiSelectChipDisplay.none(),
          ),
          if (_selectedTechnicians.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Membres sélectionnés:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ..._selectedTechnicians.map(
                  (tech) => ListTile(
                leading: Icon(Icons.person, color: roleBadgeColors[tech.role] ?? Colors.grey),
                title: Text(tech.name),
                trailing: Chip(
                  label: Text(tech.role,
                      style: const TextStyle(color: Colors.white, fontSize: 11)),
                  backgroundColor: roleBadgeColors[tech.role] ?? Colors.grey,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBudgetSection() {
    return _buildSection(
      title: '💰 BUDGET PRÉVISIONNEL',
      color: sectionColors['budget']!,
      child: Column(
        children: [
          if (_selectedTechnicians.isNotEmpty)
            ..._selectedTechnicians.map(
                  (tech) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _perPersonBudgetControllers[tech.id],
                  decoration: InputDecoration(
                    labelText: 'Frais Mission - ${tech.name} (DZD)',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ),
          TextFormField(
            controller: _fuelBudgetController,
            decoration: const InputDecoration(
              labelText: 'Budget Carburant (DZD)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _hotelBudgetController,
            decoration: const InputDecoration(
              labelText: 'Budget Hôtel (DZD)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  Widget _buildResourcesSection() {
    return _buildSection(
      title: '🚗 RESSOURCES REQUISES',
      color: sectionColors['resources']!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('── VÉHICULE ──', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<Vehicle>(
            value: _selectedVehicle,
            decoration: const InputDecoration(
              labelText: 'Sélectionner Véhicule',
              border: OutlineInputBorder(),
            ),
            items: _availableVehicles
                .map((v) => DropdownMenuItem(value: v, child: Text(v.displayName)))
                .toList(),
            onChanged: (val) {
              setState(() => _selectedVehicle = val);
              _checkVehicleAvailability();
            },
          ),
          if (_vehicleAvailabilityStatus != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _vehicleAvailabilityStatus == 'available'
                      ? Icons.check_circle
                      : Icons.warning,
                  color: _vehicleAvailabilityStatus == 'available'
                      ? Colors.green
                      : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  _vehicleAvailabilityStatus == 'available'
                      ? 'Disponible ✓'
                      : 'Conflit de dates ⚠',
                  style: TextStyle(
                    color: _vehicleAvailabilityStatus == 'available'
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Text('── ÉQUIPEMENT ──', style: TextStyle(fontWeight: FontWeight.bold)),
          if (_equipment.isNotEmpty)
            ..._equipment.map(
                  (eq) => ListTile(
                leading: const Icon(Icons.check_box, color: Colors.green),
                title: Text(eq),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _equipment.remove(eq)),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _equipmentController,
                  decoration: const InputDecoration(
                    labelText: 'Ajouter équipement',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.orange),
                onPressed: _addEquipment,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('── ACHATS PRÉ-MISSION ──',
              style: TextStyle(fontWeight: FontWeight.bold)),
          ..._preMissionPurchases.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Article',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => item.item = val,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => item.description = val,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Budget estimé (DZD)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (val) => item.estimatedBudget = double.tryParse(val) ?? 0,
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => setState(() => _preMissionPurchases.removeAt(index)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Ajouter achat'),
            onPressed: _addPurchaseItem,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _purchaseNotesController,
            decoration: const InputDecoration(
              labelText: 'Notes d\'achat',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildTasksSection() {
    return _buildSection(
      title: '✅ TÂCHES MISSION',
      color: sectionColors['tasks']!,
      child: Column(
        children: [
          if (_tasks.isNotEmpty)
            ..._tasks.map(
                  (task) => ListTile(
                leading: const Icon(Icons.task_alt, color: Colors.pink),
                title: Text(task.description),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => setState(() => _tasks.remove(task)),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _taskController,
                  decoration: const InputDecoration(
                    labelText: 'Nouvelle tâche',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.pink),
                onPressed: _addTask,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple, Colors.pink],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: ElevatedButton(
        onPressed: _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: const Text(
          '✨ Créer la Mission ✨',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Color color,
    required Widget child,
  }) {
    return Card(
      color: color,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _destinationController.dispose();
    _taskController.dispose();
    _fuelBudgetController.dispose();
    _hotelBudgetController.dispose();
    _equipmentController.dispose();
    _purchaseNotesController.dispose();
    for (var controller in _perPersonBudgetControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
