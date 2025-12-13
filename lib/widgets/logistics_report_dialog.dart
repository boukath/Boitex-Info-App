// lib/widgets/logistics_report_dialog.dart

import 'package:flutter/material.dart';
import 'package:boitex_info_app/services/logistics_pdf_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class LogisticsReportDialog extends StatefulWidget {
  const LogisticsReportDialog({super.key});

  @override
  State<LogisticsReportDialog> createState() => _LogisticsReportDialogState();
}

class _LogisticsReportDialogState extends State<LogisticsReportDialog> {
  String _selectedPeriod = 'Ce mois'; // Ce mois, Cette semaine, Aujourd'hui, Personnalisé
  DateTimeRange? _customRange;
  String? _selectedType; // null, Entrée, Sortie
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667EEA).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF667EEA)),
                ),
                const SizedBox(width: 16),
                Text(
                  "Générer un Rapport",
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 1. Période
            Text("Période", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedPeriod,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: ['Aujourd\'hui', 'Cette semaine', 'Ce mois', 'Cette année', 'Personnalisé']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) {
                setState(() => _selectedPeriod = val!);
                if (val == 'Personnalisé') _pickDateRange();
              },
            ),

            if (_selectedPeriod == 'Personnalisé' && _customRange != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      "${DateFormat('dd/MM/yy').format(_customRange!.start)} - ${DateFormat('dd/MM/yy').format(_customRange!.end)}",
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // 2. Type de Flux
            Text("Type de mouvement", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildTypeChip("Tout", null),
                const SizedBox(width: 8),
                _buildTypeChip("Entrées", "Entrée"),
                const SizedBox(width: 8),
                _buildTypeChip("Sorties", "Sortie"),
              ],
            ),

            const SizedBox(height: 30),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _generatePdf,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667EEA),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text("Télécharger le PDF", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, String? value) {
    final isSelected = _selectedType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF667EEA) : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF667EEA) : Colors.grey[300]!,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF667EEA)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _customRange = picked);
    }
  }

  Future<void> _generatePdf() async {
    // Calculate Dates
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (_selectedPeriod) {
      case 'Aujourd\'hui':
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'Cette semaine':
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        break;
      case 'Ce mois':
        start = DateTime(now.year, now.month, 1);
        break;
      case 'Cette année':
        start = DateTime(now.year, 1, 1);
        break;
      case 'Personnalisé':
        if (_customRange == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Veuillez choisir une plage de dates")));
          return;
        }
        start = _customRange!.start;
        end = DateTime(_customRange!.end.year, _customRange!.end.month, _customRange!.end.day, 23, 59, 59);
        break;
      default:
        start = DateTime(now.year, now.month, 1);
    }

    setState(() => _isLoading = true);

    try {
      final service = LogisticsPdfService();
      await service.generateAndOpenReport(LogisticsReportFilter(
        startDate: start,
        endDate: end,
        type: _selectedType,
      ));
      if (mounted) Navigator.pop(context); // Close dialog on success
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}