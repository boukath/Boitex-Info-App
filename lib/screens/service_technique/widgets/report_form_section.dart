import 'package:flutter/material.dart';

class ReportFormSection extends StatelessWidget {
  final TextEditingController managerNameController;
  final TextEditingController managerPhoneController;
  final TextEditingController diagnosticController;
  final TextEditingController workDoneController;
  final TimeOfDay? arrivalTime;
  final TimeOfDay? departureTime;
  final bool isReadOnly;
  final Function(bool) onSelectTime;

  const ReportFormSection({
    super.key,
    required this.managerNameController,
    required this.managerPhoneController,
    required this.diagnosticController,
    required this.workDoneController,
    this.arrivalTime,
    this.departureTime,
    required this.isReadOnly,
    required this.onSelectTime,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Rapport d\'Intervention', style: Theme.of(context).textTheme.titleLarge),
        const Divider(),
        const SizedBox(height: 16),
        TextFormField(controller: managerNameController, readOnly: isReadOnly, decoration: const InputDecoration(labelText: 'Nom du responsable du magasin', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        TextFormField(controller: managerPhoneController, readOnly: isReadOnly, decoration: const InputDecoration(labelText: 'Numéro du responsable', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ListTile(
                title: const Text('Heure d\'arrivée'),
                subtitle: Text(arrivalTime?.format(context) ?? 'Non définie'),
                trailing: const Icon(Icons.access_time),
                onTap: isReadOnly ? null : () => onSelectTime(true),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: Colors.grey.shade400)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ListTile(
                title: const Text('Heure de départ'),
                subtitle: Text(departureTime?.format(context) ?? 'Non définie'),
                trailing: const Icon(Icons.access_time),
                onTap: isReadOnly ? null : () => onSelectTime(false),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: Colors.grey.shade400)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(controller: diagnosticController, readOnly: isReadOnly, decoration: const InputDecoration(labelText: 'Diagnostic', border: OutlineInputBorder(), alignLabelWithHint: true), maxLines: 4),
        const SizedBox(height: 16),
        TextFormField(controller: workDoneController, readOnly: isReadOnly, decoration: const InputDecoration(labelText: 'Travaux effectués', border: OutlineInputBorder(), alignLabelWithHint: true), maxLines: 4),
      ],
    );
  }
}