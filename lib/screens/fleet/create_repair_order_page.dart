// lib/screens/fleet/create_repair_order_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/models/vehicle.dart';
import 'package:boitex_info_app/models/inspection.dart';
import 'package:boitex_info_app/models/repair_order.dart';

class CreateRepairOrderPage extends StatefulWidget {
  final Vehicle vehicle;

  const CreateRepairOrderPage({super.key, required this.vehicle});

  @override
  State<CreateRepairOrderPage> createState() => _CreateRepairOrderPageState();
}

class _CreateRepairOrderPageState extends State<CreateRepairOrderPage> {
  final _formKey = GlobalKey<FormState>();

  // 📋 FORM CONTROLLERS
  final TextEditingController _garageNameCtrl = TextEditingController();
  final TextEditingController _garagePhoneCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  // 📅 SCHEDULING
  DateTime? _appointmentDate;

  // 🛠️ REPAIR ITEMS (The "Cart")
  List<RepairItem> _selectedItems = [];
  bool _isLoadingDefects = true;

  @override
  void initState() {
    super.initState();
    _fetchSuggestedDefects();
  }

  // 🔎 1. FETCH DEFECTS FROM LAST INSPECTION
  Future<void> _fetchSuggestedDefects() async {
    try {
      // Get the most recent inspection for this vehicle
      final snapshot = await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(widget.vehicle.id)
          .collection('inspections')
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final inspection = Inspection.fromFirestore(snapshot.docs.first);

        // Convert unresolved defects into potential Repair Items
        final suggested = inspection.defects
            .where((d) => !d.isRepaired) // Only open issues
            .map((d) => RepairItem(
          title: d.label,
          description: "Signalé le ${DateFormat('dd/MM').format(inspection.date)} (Vue: ${d.viewId})",
          photoUrl: d.photoUrl,
          isDone: false,
        ))
            .toList();

        setState(() {
          _selectedItems = suggested; // Auto-select all by default
        });
      }
    } catch (e) {
      debugPrint("Error fetching defects: $e");
    } finally {
      setState(() => _isLoadingDefects = false);
    }
  }

  // 💾 2. SAVE THE ORDER
  Future<void> _createOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ajoutez au moins une réparation à effectuer.")),
      );
      return;
    }

    try {
      final order = RepairOrder(
        id: '', // Firestore generates this
        vehicleId: widget.vehicle.id!,
        vehicleName: "${widget.vehicle.model} (${widget.vehicle.plateNumber})",
        createdAt: DateTime.now(),
        appointmentDate: _appointmentDate,
        garageName: _garageNameCtrl.text,
        garagePhone: _garagePhoneCtrl.text,
        items: _selectedItems,
        status: _appointmentDate != null ? RepairStatus.scheduled : RepairStatus.draft,
        managerNotes: _notesCtrl.text,
      );

      // Save to root collection 'repair_orders'
      await FirebaseFirestore.instance.collection('repair_orders').add(order.toMap());

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ordre de réparation créé avec succès !"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    }
  }

  // ➕ 3. MANUAL ITEM ADDER (e.g. "Vidange")
  void _addManualItem() {
    TextEditingController taskCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ajouter une tâche"),
        content: TextField(
          controller: taskCtrl,
          decoration: const InputDecoration(hintText: "Ex: Vidange, Changement pneus..."),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              if (taskCtrl.text.isNotEmpty) {
                setState(() {
                  _selectedItems.add(RepairItem(
                    title: taskCtrl.text,
                    description: "Ajouté manuellement",
                    isDone: false,
                  ));
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text("Ajouter"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("NOUVEL ORDRE DE RÉPARATION", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // 🚙 VEHICLE HEADER
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.directions_car, size: 30, color: Colors.black),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.vehicle.model, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(widget.vehicle.plateNumber, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 🛠️ SECTION 1: TASKS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("LISTE DES TRAVAUX", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.grey)),
                      TextButton.icon(
                        onPressed: _addManualItem,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text("Ajouter Tâche"),
                        style: TextButton.styleFrom(foregroundColor: Colors.blue),
                      )
                    ],
                  ),

                  if (_isLoadingDefects)
                    const Center(child: Padding(padding: EdgeInsets.all(20), child: CupertinoActivityIndicator())),

                  if (!_isLoadingDefects && _selectedItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(12)
                      ),
                      child: const Text("Aucun défaut détecté.\nAjoutez une tâche manuellement.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    ),

                  ..._selectedItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.black, radius: 14, child: Icon(Icons.build, size: 14, color: Colors.white)),
                        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(item.description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () => setState(() => _selectedItems.removeAt(index)),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 24),

                  // 🏢 SECTION 2: GARAGE INFO
                  const Text("INFOS GARAGE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _garageNameCtrl,
                    decoration: _inputDecoration("Nom du Garage", Icons.store),
                    validator: (v) => v!.isEmpty ? "Nom requis" : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _garagePhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDecoration("Téléphone", Icons.phone),
                  ),

                  const SizedBox(height: 24),

                  // 📅 SECTION 3: APPOINTMENT
                  const Text("PLANIFICATION", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030));
                      if (d != null) setState(() => _appointmentDate = d);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F3F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _appointmentDate != null ? Colors.black : Colors.transparent),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 20, color: _appointmentDate != null ? Colors.black : Colors.grey),
                          const SizedBox(width: 12),
                          Text(
                            _appointmentDate == null ? "Sélectionner une date (Optionnel)" : "Rendez-vous : ${DateFormat('dd/MM/yyyy').format(_appointmentDate!)}",
                            style: TextStyle(fontWeight: FontWeight.bold, color: _appointmentDate != null ? Colors.black : Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 📝 NOTES
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: _inputDecoration("Notes pour le mécanicien...", Icons.note),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),

            // 💾 FOOTER BUTTON
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _createOrder,
                    child: Text(
                      _appointmentDate == null ? "ENREGISTRER BROUILLON" : "CONFIRMER RENDEZ-VOUS",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.grey, size: 20),
      filled: true,
      fillColor: const Color(0xFFF2F3F5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}