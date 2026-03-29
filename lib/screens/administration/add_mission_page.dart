// lib/screens/administration/add_mission_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // 🚀 REQUIRED FOR IOS WIDGETS
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart'; // 🚀 PREMIUM FONTS
import 'package:boitex_info_app/models/mission.dart';
import 'package:boitex_info_app/models/vehicle.dart';

// User view model with role
class UserViewModel {
  final String id;
  final String name;
  final String role;
  UserViewModel({required this.id, required this.name, required this.role});
}

// --- GLASSMORPHISM HELPER WIDGET ---
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double opacity;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 24.0,
    this.opacity = 0.65,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                spreadRadius: -5,
              )
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// 🚀 NEW: CUSTOM ANIMATED GRADIENT SEGMENTED CONTROL 🚀
class AnimatedGradientSegmentedControl extends StatelessWidget {
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;
  final List<Color> activeGradient;

  const AnimatedGradientSegmentedControl({
    Key? key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.activeGradient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final keys = items.keys.toList();
    final selectedIndex = keys.indexOf(value);

    return Container(
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / keys.length;

          return Stack(
            children: [
              // Animated Gradient Thumb
              AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.fastLinearToSlowEaseIn,
                left: selectedIndex * itemWidth,
                top: 0,
                bottom: 0,
                width: itemWidth,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: activeGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: activeGradient.first.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              // Clickable Text Areas
              Row(
                children: keys.map((key) {
                  final isSelected = value == key;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(key),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.black54,
                            letterSpacing: 0.3,
                          ),
                          child: Text(items[key]!),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AddMissionPage extends StatefulWidget {
  final Mission? missionToEdit;
  const AddMissionPage({super.key, this.missionToEdit});

  @override
  State<AddMissionPage> createState() => _AddMissionPageState();
}

class _AddMissionPageState extends State<AddMissionPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // ✨ PREMIUM COLORS
  static const Color kPrimaryColor = Color(0xFF9C27B0); // Purple
  static const Color kSecondaryColor = Color(0xFF00BCD4); // Cyan
  static const Color kTextPrimary = Color(0xFF1E293B);
  static const Color kTextSecondary = Color(0xFF64748B);

  static const roleBadgeColors = {
    'Technicien': CupertinoColors.activeBlue,
    'Manager': CupertinoColors.systemPurple,
    'Admin': CupertinoColors.activeGreen
  };

  // 🇩🇿 ALGERIA WILAYAS (UPDATED WITH ALL 58)
  final List<String> _wilayas = [
    "01 Adrar", "02 Chlef", "03 Laghouat", "04 Oum El Bouaghi", "05 Batna", "06 Béjaïa", "07 Biskra",
    "08 Béchar", "09 Blida", "10 Bouira", "11 Tamanrasset", "12 Tébessa", "13 Tlemcen", "14 Tiaret",
    "15 Tizi Ouzou", "16 Alger", "17 Djelfa", "18 Jijel", "19 Sétif", "20 Saïda", "21 Skikda",
    "22 Sidi Bel Abbès", "23 Annaba", "24 Guelma", "25 Constantine", "26 Médéa", "27 Mostaganem",
    "28 M'Sila", "29 Mascara", "30 Ouargla", "31 Oran", "32 El Bayadh", "33 Illizi", "34 Bordj Bou Arréridj",
    "35 Boumerdès", "36 El Tarf", "37 Tindouf", "38 Tissemsilt", "39 El Oued", "40 Khenchela",
    "41 Souk Ahras", "42 Tipaza", "43 Mila", "44 Aïn Defla", "45 Naâma", "46 Aïn Témouchent",
    "47 Ghardaïa", "48 Relizane", "49 Timimoun", "50 Bordj Badji Mokhtar", "51 Ouled Djellal",
    "52 Béni Abbès", "53 In Salah", "54 In Guezzam", "55 Touggourt", "56 Djanet", "57 El M'Ghair",
    "58 El Meniaa", "59 Aflou", "60 El Abiodh Sidi Cheikh", "61 El Aricha", "62 El Kantara", "63 Barika",
    "64 Bou Saâda", "65 Bir el-Ater", "66 Ksar El Boukhari", "67 Ksar Chellala", "68 Aïn Oussera", "69 Messaad"
  ];

  // STATE
  String? _selectedServiceType = 'Service Technique';
  final _titleController = TextEditingController();
  final List<String> _destinations = [];
  DateTime? _startDate, _endDate;
  List<UserViewModel> _selectedTechnicians = [], _allUsers = [];
  final _taskController = TextEditingController();
  final List<MissionTask> _tasks = [];
  final Map<String, TextEditingController> _perPersonBudgetControllers = {};
  final _fuelBudgetController = TextEditingController(text: '0');
  final _hotelBudgetController = TextEditingController(text: '0');
  final _purchaseBudgetController = TextEditingController(text: '0');
  Vehicle? _selectedVehicle;
  List<Vehicle> _availableVehicles = [];
  String? _vehicleAvailabilityStatus;
  final List<String> _equipment = [];
  final _equipmentController = TextEditingController();
  final List<PurchaseItem> _preMissionPurchases = [];
  final _purchaseNotesController = TextEditingController();

  late Future<void> _loadDataFuture;
  late AnimationController _bgAnimationController;

  bool get _isEditMode => widget.missionToEdit != null;

  @override
  void initState() {
    super.initState();
    _loadDataFuture = _loadData();
    if (_isEditMode) {
      _initializeForEdit();
    }
    _bgAnimationController = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    )..repeat(reverse: true);
  }

  void _initializeForEdit() {
    final mission = widget.missionToEdit!;
    _selectedServiceType = mission.serviceType;
    _titleController.text = mission.title;
    _destinations.addAll(mission.destinations);

    _startDate = mission.startDate;
    _endDate = mission.endDate;

    _tasks.addAll(mission.tasks.map((t) => MissionTask.fromJson(t.toJson())));

    _fuelBudgetController.text = mission.expenseReport.fuel.budget.toString();
    _hotelBudgetController.text = mission.expenseReport.hotel.budget.toString();
    _purchaseBudgetController.text = mission.expenseReport.purchases.budget.toString();

    if (mission.resources != null) {
      _equipment.addAll(mission.resources!.equipment);
      _preMissionPurchases.addAll(mission.resources!.preMissionPurchases.map((p) => PurchaseItem.fromJson(p.toJson())));
      _purchaseNotesController.text = mission.resources!.purchaseNotes;
    }
  }

  Future<void> _loadData() async {
    try {
      await Future.wait([
        _fetchUsers(),
        _fetchVehicles(),
      ]);

      if (_isEditMode) {
        final mission = widget.missionToEdit!;
        if (mounted) {
          setState(() {
            _selectedTechnicians = _allUsers
                .where((u) => mission.assignedTechniciansIds.contains(u.id))
                .toList();

            for (var tech in _selectedTechnicians) {
              final savedBudget = mission.expenseReport.dailyAllowancesPerTechnician[tech.name]?.budget.toString() ?? '0';
              if (!_perPersonBudgetControllers.containsKey(tech.id)) {
                _perPersonBudgetControllers[tech.id] = TextEditingController(text: savedBudget);
              } else {
                _perPersonBudgetControllers[tech.id]!.text = savedBudget;
              }
            }

            if (mission.resources?.vehicleId != null) {
              try {
                _selectedVehicle = _availableVehicles.firstWhere(
                      (v) => v.id == mission.resources!.vehicleId,
                );
              } catch (_) {}
            }
            _checkVehicleAvailability();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      rethrow;
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
          _availableVehicles =
              snap.docs.map((doc) => Vehicle.fromFirestore(doc)).toList();
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

    final currentMissionId = _isEditMode ? widget.missionToEdit!.id : null;

    final conflicting = await FirebaseFirestore.instance
        .collection('missions')
        .where('resources.vehicleId', isEqualTo: _selectedVehicle!.id)
        .where('status', whereIn: ['Planifiée', 'En Cours'])
        .get();

    bool hasConflict = false;
    for (var mission in conflicting.docs) {
      if (currentMissionId != null && mission.id == currentMissionId) continue;

      final data = mission.data();
      final existingStart = (data['startDate'] as Timestamp).toDate();
      final existingEnd = (data['endDate'] as Timestamp).toDate();
      if (_startDate!.isBefore(existingEnd) &&
          _endDate!.isAfter(existingStart)) {
        hasConflict = true;
        break;
      }
    }
    setState(() => _vehicleAvailabilityStatus = hasConflict ? 'conflict' : 'available');
  }

  // --- ACTIONS ---

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

  // --- SUBMIT ---
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_destinations.isEmpty) {
      _showSnack('Ajoutez au moins une destination', Colors.orange);
      return;
    }
    if (_startDate == null || _endDate == null) {
      _showSnack('Sélectionnez les dates', Colors.orange);
      return;
    }
    if (_selectedTechnicians.isEmpty) {
      _showSnack('Sélectionnez au moins un membre', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dailyAllowances = <String, ExpenseCategory>{};
      final existingExpenseReport = _isEditMode ? widget.missionToEdit!.expenseReport : null;

      for (var tech in _selectedTechnicians) {
        final budget = double.tryParse(_perPersonBudgetControllers[tech.id]?.text ?? '0') ?? 0.0;
        final spent = existingExpenseReport?.dailyAllowancesPerTechnician[tech.name]?.spent ?? 0.0;
        final billUrls = existingExpenseReport?.dailyAllowancesPerTechnician[tech.name]?.billUrls;

        dailyAllowances[tech.name] = ExpenseCategory(budget: budget, spent: spent, billUrls: billUrls);
      }

      final expenseReport = ExpenseReport(
        dailyAllowancesPerTechnician: dailyAllowances,
        fuel: ExpenseCategory(
          budget: double.tryParse(_fuelBudgetController.text) ?? 0.0,
          spent: existingExpenseReport?.fuel.spent ?? 0.0,
          billUrls: existingExpenseReport?.fuel.billUrls,
        ),
        purchases: ExpenseCategory(
          budget: double.tryParse(_purchaseBudgetController.text) ?? 0.0,
          spent: existingExpenseReport?.purchases.spent ?? 0.0,
          billUrls: existingExpenseReport?.purchases.billUrls,
        ),
        hotel: ExpenseCategory(
          budget: double.tryParse(_hotelBudgetController.text) ?? 0.0,
          spent: existingExpenseReport?.hotel.spent ?? 0.0,
          billUrls: existingExpenseReport?.hotel.billUrls,
        ),
      );

      final resources = MissionResources(
        vehicleId: _selectedVehicle?.id,
        vehicleModel: _selectedVehicle?.model,
        vehiclePlate: _selectedVehicle?.plateNumber,
        equipment: _equipment,
        preMissionPurchases: _preMissionPurchases,
        purchaseNotes: _purchaseNotesController.text.trim(),
      );

      if (_isEditMode) {
        if (widget.missionToEdit!.id == null) throw Exception("Mission ID is missing for update.");
        final missionId = widget.missionToEdit!.id!;

        final updatedData = {
          'serviceType': _selectedServiceType!,
          'title': _titleController.text.trim(),
          'destinations': _destinations,
          'startDate': Timestamp.fromDate(_startDate!),
          'endDate': Timestamp.fromDate(_endDate!),
          'assignedTechniciansIds': _selectedTechnicians.map((t) => t.id).toList(),
          'assignedTechniciansNames': _selectedTechnicians.map((t) => t.name).toList(),
          'assignedTechniciansRoles': _selectedTechnicians.map((t) => t.role).toList(),
          'tasks': _tasks.map((task) => task.toJson()).toList(),
          'expenseReport': expenseReport.toJson(),
          'resources': resources.toJson(),
        };

        await FirebaseFirestore.instance.collection('missions').doc(missionId).update(updatedData);

        if (mounted) {
          _showSnack('Mission mise à jour avec succès!', Colors.green);
          Navigator.pop(context);
        }
      } else {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final currentYear = DateTime.now().year;
          final counterRef = FirebaseFirestore.instance.collection('counters').doc('mission_counter_$currentYear');
          final counterSnap = await transaction.get(counterRef);
          final newCount = ((counterSnap.data()?['count'] as int?) ?? 0) + 1;
          final missionCode = 'MISS-$newCount/$currentYear';

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
          _showSnack('Mission créée avec succès!', Colors.green);
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) _showSnack('Erreur: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ----------------------------------------------------------------------
  // 🚀 IOS NATIVE SHEETS & PICKERS
  // ----------------------------------------------------------------------

  // 🇩🇿 NEW: IOS DESTINATION SELECTOR
  void _openIOSDestinationSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setStateSB) {
            final filteredItems = _wilayas.where((w) {
              return w.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return FractionallySizedBox(
              heightFactor: 0.88,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 8),
                          width: 40, height: 5,
                          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text('Sélectionner une Wilaya', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: kTextPrimary)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: CupertinoSearchTextField(
                            placeholder: 'Rechercher une Wilaya ou Ville...',
                            onChanged: (val) => setStateSB(() => searchQuery = val),
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: filteredItems.length + 1,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                            itemBuilder: (context, index) {
                              if (index == filteredItems.length) {
                                return ListTile(
                                  leading: const Icon(CupertinoIcons.location_solid, color: kPrimaryColor),
                                  title: Text('Autre destination : "$searchQuery"', style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
                                  onTap: () {
                                    if (searchQuery.trim().isNotEmpty) {
                                      setState(() => _destinations.add(searchQuery.trim()));
                                      Navigator.pop(context);
                                    }
                                  },
                                );
                              }
                              final item = filteredItems[index];
                              return ListTile(
                                title: Text(item, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                                trailing: const Icon(CupertinoIcons.add_circled, color: CupertinoColors.activeBlue),
                                onTap: () {
                                  setState(() => _destinations.add(item));
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _selectDate({required bool isStart}) async {
    DateTime initialDate = (isStart ? _startDate : _endDate) ?? DateTime.now();
    DateTime firstDate = isStart
        ? (_isEditMode ? DateTime(initialDate.year - 1) : DateTime.now())
        : (_startDate ?? DateTime.now());

    if (initialDate.isBefore(firstDate)) initialDate = firstDate;

    DateTime tempPickedDate = initialDate;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext builder) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: 320,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Annuler', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
                      ),
                      Text(isStart ? 'Date de Début' : 'Date de Fin', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: kTextPrimary)),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            if (isStart) {
                              _startDate = tempPickedDate;
                              if (_endDate != null && _endDate!.isBefore(_startDate!)) {
                                _endDate = _startDate;
                              }
                            } else {
                              _endDate = tempPickedDate;
                            }
                          });
                          _checkVehicleAvailability();
                          Navigator.of(context).pop();
                        },
                        child: const Text('Confirmer', style: TextStyle(color: CupertinoColors.activeBlue, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: tempPickedDate,
                    minimumDate: firstDate,
                    maximumDate: DateTime(2030),
                    onDateTimeChanged: (DateTime newDate) {
                      tempPickedDate = newDate;
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openIOSTechnicianSelector() {
    List<UserViewModel> tempSelected = List.from(_selectedTechnicians);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return FractionallySizedBox(
              heightFactor: 0.75,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 8),
                          width: 40, height: 5,
                          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: Colors.redAccent, fontSize: 16))),
                              Text('Équipe Mission', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: kTextPrimary)),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedTechnicians = tempSelected;
                                    for (var tech in _selectedTechnicians) {
                                      if (!_perPersonBudgetControllers.containsKey(tech.id)) {
                                        _perPersonBudgetControllers[tech.id] = TextEditingController(text: '2000');
                                      }
                                    }
                                  });
                                  Navigator.pop(context);
                                },
                                child: const Text('Valider', style: TextStyle(color: CupertinoColors.activeBlue, fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: _allUsers.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                            itemBuilder: (context, index) {
                              final tech = _allUsers[index];
                              final isSelected = tempSelected.any((t) => t.id == tech.id);

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: (roleBadgeColors[tech.role] ?? Colors.grey).withOpacity(0.1),
                                  child: Icon(CupertinoIcons.person_fill, color: roleBadgeColors[tech.role] ?? Colors.grey),
                                ),
                                title: Text(tech.name, style: TextStyle(color: isSelected ? kPrimaryColor : kTextPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600)),
                                subtitle: Text(tech.role, style: TextStyle(color: kTextSecondary, fontSize: 12)),
                                trailing: isSelected ? const Icon(CupertinoIcons.checkmark_alt, color: kPrimaryColor) : null,
                                onTap: () {
                                  setStateSB(() {
                                    if (isSelected) {
                                      tempSelected.removeWhere((t) => t.id == tech.id);
                                    } else {
                                      tempSelected.add(tech);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openIOSVehicleSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.6,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40, height: 5,
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Sélectionner un Véhicule', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: kTextPrimary)),
                    ),
                    Expanded(
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _availableVehicles.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                        itemBuilder: (context, index) {
                          final v = _availableVehicles[index];
                          final isSelected = _selectedVehicle?.id == v.id;
                          return ListTile(
                            leading: const Icon(CupertinoIcons.car_detailed, color: CupertinoColors.activeBlue),
                            title: Text(v.displayName, style: TextStyle(color: isSelected ? CupertinoColors.activeBlue : kTextPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600)),
                            trailing: isSelected ? const Icon(CupertinoIcons.checkmark_alt, color: CupertinoColors.activeBlue) : null,
                            onTap: () {
                              setState(() {
                                _selectedVehicle = v;
                              });
                              _checkVehicleAvailability();
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  // ----------------------------------------------------------------------
  // 🖥️ UI BUILDERS
  // ----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.white.withOpacity(0.4)),
          ),
        ),
        foregroundColor: kTextPrimary,
        centerTitle: true,
        title: Text(
          _isEditMode ? 'Modifier Mission' : 'Créer une Mission',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 22, letterSpacing: -0.5),
        ),
      ),
      body: Stack(
        children: [
          // 🚀 4K ANIMATED GRADIENT BACKGROUND
          AnimatedBuilder(
            animation: _bgAnimationController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(const Color(0xFFF3E5F5), const Color(0xFFE0F7FA), _bgAnimationController.value)!,
                      Color.lerp(const Color(0xFFE0F7FA), const Color(0xFFFCE4EC), _bgAnimationController.value)!,
                      Color.lerp(const Color(0xFFFCE4EC), const Color(0xFFF3E5F5), _bgAnimationController.value)!,
                    ],
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: FutureBuilder<void>(
              future: _loadDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 850),
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSectionTitle("Informations Générales", CupertinoIcons.doc_text_fill),
                            _buildMissionInfoSection(),
                            const SizedBox(height: 24),

                            _buildSectionTitle("Équipe & Assignations", CupertinoIcons.person_2_fill),
                            _buildTeamSection(),
                            const SizedBox(height: 24),

                            _buildSectionTitle("Budget Prévisionnel", CupertinoIcons.money_euro_circle_fill),
                            _buildBudgetSection(),
                            const SizedBox(height: 24),

                            _buildSectionTitle("Ressources & Logistique", CupertinoIcons.car_detailed),
                            _buildResourcesSection(),
                            const SizedBox(height: 24),

                            _buildSectionTitle("Tâches à Réaliser", CupertinoIcons.check_mark_circled_solid),
                            _buildTasksSection(),
                            const SizedBox(height: 40),

                            _buildSubmitButton(),
                            const SizedBox(height: 60),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- SECTION WIDGETS ---

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 8),
      child: Row(
        children: [
          Icon(icon, color: kPrimaryColor, size: 20),
          const SizedBox(width: 10),
          Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: kTextPrimary)),
        ],
      ),
    );
  }

  Widget _buildMissionInfoSection() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedGradientSegmentedControl(
            value: _selectedServiceType ?? 'Service Technique',
            items: const {
              'Service Technique': 'Technique',
              'Service IT': 'IT',
            },
            activeGradient: const [Color(0xFF9C27B0), Color(0xFF00BCD4)], // Purple to Cyan
            onChanged: (value) {
              setState(() => _selectedServiceType = value);
            },
          ),
          const SizedBox(height: 16),
          _buildGlassTextField(controller: _titleController, labelText: 'Titre de la Mission', icon: CupertinoIcons.tag, isRequired: true),
          const SizedBox(height: 20),

          Text('Destinations', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kTextPrimary)),
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
                return Container(
                  key: ValueKey(_destinations[index]),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(CupertinoIcons.bars, color: Colors.black26),
                        const SizedBox(width: 8),
                        CircleAvatar(radius: 14, backgroundColor: kPrimaryColor.withOpacity(0.2), child: Text('${index + 1}', style: const TextStyle(color: kPrimaryColor, fontSize: 12, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    title: Text(_destinations[index], style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    trailing: IconButton(icon: const Icon(CupertinoIcons.minus_circle_fill, color: Colors.redAccent), onPressed: () => setState(() => _destinations.removeAt(index))),
                  ),
                );
              },
            ),

          // 🚀 FIX: iOS Wilaya Auto-Complete Input
          GestureDetector(
            onTap: _openIOSDestinationSelector,
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.location_solid, color: Colors.black54),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Ajouter une Wilaya ou Destination',
                      style: GoogleFonts.inter(color: kTextSecondary, fontSize: 16),
                    ),
                  ),
                  const Icon(CupertinoIcons.add_circled_solid, color: kPrimaryColor, size: 22),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectDate(isStart: true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Départ', style: GoogleFonts.inter(color: kTextSecondary, fontSize: 12)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(CupertinoIcons.calendar, size: 18, color: kPrimaryColor),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _startDate == null ? 'Sélectionner' : DateFormat("EEEE dd MMMM", "fr").format(_startDate!),
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectDate(isStart: false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Retour', style: GoogleFonts.inter(color: kTextSecondary, fontSize: 12)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(CupertinoIcons.calendar, size: 18, color: kSecondaryColor),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _endDate == null ? 'Sélectionner' : DateFormat("EEEE dd MMMM", "fr").format(_endDate!),
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamSection() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _openIOSTechnicianSelector,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.person_2_fill, color: kPrimaryColor),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _selectedTechnicians.isEmpty ? 'Assigner des Membres' : '${_selectedTechnicians.length} Membre(s) Assigné(s)',
                      style: GoogleFonts.inter(color: _selectedTechnicians.isEmpty ? kTextSecondary : kPrimaryColor, fontSize: 16, fontWeight: _selectedTechnicians.isEmpty ? FontWeight.normal : FontWeight.bold),
                    ),
                  ),
                  const Icon(CupertinoIcons.chevron_down, color: Colors.black54, size: 18),
                ],
              ),
            ),
          ),
          if (_selectedTechnicians.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedTechnicians.map((tech) {
                return Chip(
                  avatar: const Icon(CupertinoIcons.person_fill, size: 16, color: Colors.white),
                  label: Text(tech.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  backgroundColor: roleBadgeColors[tech.role] ?? Colors.grey,
                  deleteIcon: const Icon(CupertinoIcons.clear_circled_solid, color: Colors.white, size: 18),
                  onDeleted: () => setState(() => _selectedTechnicians.remove(tech)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                );
              }).toList(),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildBudgetSection() {
    return GlassCard(
      child: Column(
        children: [
          if (_selectedTechnicians.isNotEmpty) ...[
            ..._selectedTechnicians.map((tech) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildGlassTextField(
                  controller: _perPersonBudgetControllers[tech.id]!,
                  labelText: 'Frais Mission - ${tech.name} (DZD)',
                  icon: CupertinoIcons.money_dollar,
                  keyboardType: TextInputType.number
              ),
            )),
            const Divider(height: 24),
          ],
          _buildGlassTextField(controller: _fuelBudgetController, labelText: 'Budget Carburant (DZD)', icon: CupertinoIcons.drop_fill, keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          _buildGlassTextField(controller: _hotelBudgetController, labelText: 'Budget Hôtel (DZD)', icon: CupertinoIcons.bed_double_fill, keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          _buildGlassTextField(controller: _purchaseBudgetController, labelText: 'Budget Achats (DZD)', icon: CupertinoIcons.cart_fill, keyboardType: TextInputType.number),
        ],
      ),
    );
  }

  Widget _buildResourcesSection() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Véhicule', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kTextPrimary)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _openIOSVehicleSelector,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.car_detailed, color: CupertinoColors.activeBlue),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _selectedVehicle == null ? 'Sélectionner un Véhicule' : _selectedVehicle!.displayName,
                      style: GoogleFonts.inter(color: _selectedVehicle == null ? kTextSecondary : CupertinoColors.activeBlue, fontSize: 16, fontWeight: _selectedVehicle == null ? FontWeight.normal : FontWeight.bold),
                    ),
                  ),
                  const Icon(CupertinoIcons.chevron_down, color: Colors.black54, size: 18),
                ],
              ),
            ),
          ),
          if (_vehicleAvailabilityStatus != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(_vehicleAvailabilityStatus == 'available' ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.exclamationmark_triangle_fill,
                    color: _vehicleAvailabilityStatus == 'available' ? CupertinoColors.activeGreen : CupertinoColors.systemOrange, size: 18),
                const SizedBox(width: 8),
                Text(
                  _vehicleAvailabilityStatus == 'available' ? 'Disponible pour ces dates' : 'Conflit de dates possible',
                  style: GoogleFonts.inter(color: _vehicleAvailabilityStatus == 'available' ? CupertinoColors.activeGreen : CupertinoColors.systemOrange, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),

          Text('Équipement Requis', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kTextPrimary)),
          const SizedBox(height: 8),
          if (_equipment.isNotEmpty)
            ..._equipment.map((eq) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(CupertinoIcons.cube_box_fill, color: Colors.teal),
                title: Text(eq, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                trailing: IconButton(icon: const Icon(CupertinoIcons.minus_circle_fill, color: Colors.redAccent), onPressed: () => setState(() => _equipment.remove(eq))),
              ),
            )),
          Row(
            children: [
              Expanded(child: _buildGlassTextField(controller: _equipmentController, labelText: 'Ajouter équipement', icon: CupertinoIcons.cube_box)),
              const SizedBox(width: 8),
              Container(decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(16)), child: IconButton(icon: const Icon(CupertinoIcons.add, color: Colors.white), onPressed: _addEquipment)),
            ],
          ),
          const SizedBox(height: 24),

          Text('Achats Pré-Mission', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kTextPrimary)),
          const SizedBox(height: 8),
          ..._preMissionPurchases.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black12)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Article #${index + 1}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: kPrimaryColor)),
                      GestureDetector(onTap: () => setState(() => _preMissionPurchases.removeAt(index)), child: const Icon(CupertinoIcons.delete_solid, color: Colors.redAccent, size: 20)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: item.item,
                    decoration: const InputDecoration(labelText: 'Nom de l\'article', border: UnderlineInputBorder(), isDense: true),
                    onChanged: (val) => item.item = val,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: item.estimatedBudget.toString(),
                    decoration: const InputDecoration(labelText: 'Budget estimé (DZD)', border: UnderlineInputBorder(), isDense: true),
                    keyboardType: TextInputType.number,
                    onChanged: (val) => item.estimatedBudget = double.tryParse(val) ?? 0,
                  ),
                ],
              ),
            );
          }),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addPurchaseItem,
              icon: const Icon(CupertinoIcons.add, size: 18),
              label: const Text('Ajouter un achat'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kPrimaryColor,
                side: const BorderSide(color: kPrimaryColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildGlassTextField(controller: _purchaseNotesController, labelText: 'Notes pour les achats', icon: CupertinoIcons.text_alignleft),
        ],
      ),
    );
  }

  Widget _buildTasksSection() {
    return GlassCard(
      child: Column(
        children: [
          if (_tasks.isNotEmpty)
            ..._tasks.map((task) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(CupertinoIcons.check_mark_circled_solid, color: kSecondaryColor),
                title: Text(task.description, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                trailing: IconButton(icon: const Icon(CupertinoIcons.minus_circle_fill, color: Colors.redAccent), onPressed: () => setState(() => _tasks.remove(task))),
              ),
            )),
          Row(
            children: [
              Expanded(child: _buildGlassTextField(controller: _taskController, labelText: 'Nouvelle tâche', icon: CupertinoIcons.pencil)),
              const SizedBox(width: 8),
              Container(decoration: BoxDecoration(color: kSecondaryColor, borderRadius: BorderRadius.circular(16)), child: IconButton(icon: const Icon(CupertinoIcons.add, color: Colors.white), onPressed: _addTask)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 65,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [kPrimaryColor, kSecondaryColor],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(color: kPrimaryColor.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        icon: _isLoading ? const SizedBox.shrink() : const Icon(CupertinoIcons.paperplane_fill, size: 28, color: Colors.white),
        label: _isLoading
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            : Flexible(
          child: Text(
            _isEditMode ? "ENREGISTRER LES MODIFICATIONS" : "CRÉER LA MISSION",
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType? keyboardType,
    bool isRequired = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(color: Colors.black87, fontSize: 16),
        validator: isRequired ? (v) => v!.isEmpty ? 'Requis' : null : null,
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: GoogleFonts.inter(color: Colors.black54),
          prefixIcon: Icon(icon, color: Colors.black54),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        ),
      ),
    );
  }
}