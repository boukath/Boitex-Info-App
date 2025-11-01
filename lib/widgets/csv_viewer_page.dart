// lib/widgets/csv_viewer_page.dart

import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'dart:convert'; // For utf8

class CsvViewerPage extends StatefulWidget {
  final String csvData;
  final String title;
  final String? fieldDelimiter;
  final Encoding encoding;

  const CsvViewerPage({
    super.key,
    required this.csvData,
    this.title = 'Aperçu CSV',
    this.fieldDelimiter = ',', // Default is comma
    this.encoding = utf8,
  });

  @override
  State<CsvViewerPage> createState() => _CsvViewerPageState();
}

class _CsvViewerPageState extends State<CsvViewerPage> {
  List<List<dynamic>> _csvTable = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _parseCsv();
    });
  }

  /// Decodes and parses the CSV data
  Future<void> _parseCsv() async {
    try {
      // ✅ --- THE FIX ---
      // The CsvToListConverter expects a non-nullable String for the delimiter.
      // We now ensure that if widget.fieldDelimiter is null, we default to a comma.
      // Since your report page is sending ';', that is what will be used here.
      final converter = CsvToListConverter(
        fieldDelimiter: widget.fieldDelimiter ?? ',',
      );

      final List<List<dynamic>> table = converter.convert(widget.csvData);

      if (mounted) {
        setState(() {
          _csvTable = table;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de lecture du CSV: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF16A34A), // Green for CSV/Excel
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _csvTable.isEmpty
          ? const Center(child: Text('Le fichier CSV est vide.'))
          : _buildCsvTable(),
    );
  }

  Widget _buildCsvTable() {
    if (_csvTable.isEmpty) {
      return const Center(child: Text('Le fichier CSV est vide.'));
    }

    final headers = _csvTable[0];
    final rows = _csvTable.length > 1 ? _csvTable.sublist(1) : <List<dynamic>>[];

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: DataTable(
            columns: headers.map((header) {
              return DataColumn(
                label: Text(
                  header.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            }).toList(),
            rows: rows.map((row) {
              // Ensure row has same number of cells as header
              final rowCells = List.from(row);
              while (rowCells.length < headers.length) {
                rowCells.add('');
              }
              if (rowCells.length > headers.length) {
                rowCells.removeRange(headers.length, rowCells.length);
              }

              return DataRow(
                cells: rowCells.map((cell) {
                  return DataCell(
                    Text(cell.toString()),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}