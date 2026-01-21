import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/models/maintenance_log.dart';

// 🏎️ SCUDERIA THEME CONSTANTS (Reused for consistency)
const Color kRacingRed = Color(0xFFFF2800);
const Color kCarbonBlack = Color(0xFF1C1C1C);
const Color kAsphaltGrey = Color(0xFFF2F3F5);
const Color kMechanicBlue = Color(0xFF2962FF);

class MaintenanceDetailsSheet extends StatelessWidget {
  final MaintenanceLog log;

  const MaintenanceDetailsSheet({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    // Generate a "Flight Recorder" style ID
    final String shortId = log.id.length > 8 ? log.id.substring(0, 8).toUpperCase() : log.id.toUpperCase();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85, // 85% Height
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          // 1. DRAG HANDLE & HEADER
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(CupertinoIcons.doc_text_search, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      "MISSION LOG #$shortId",
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                // EXPORT BUTTON
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: kCarbonBlack,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: const [
                      Icon(CupertinoIcons.share, color: Colors.white, size: 12),
                      SizedBox(width: 6),
                      Text(
                        "EXPORT PDF",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 2. SCROLLABLE CONTENT
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- A. HERO METRICS ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat('dd MMM yyyy', 'fr_FR').format(log.date).toUpperCase(),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.grey),
                      ),
                      const Spacer(),
                      const Icon(CupertinoIcons.speedometer, size: 20, color: kRacingRed),
                      const SizedBox(width: 8),
                      Text(
                        "${NumberFormat('#,###').format(log.mileage)} KM",
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: kCarbonBlack, height: 1.0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // --- B. TECHNICIAN SIGNATURE ---
                  _buildSectionHeader("TECHNICIEN"),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kAsphaltGrey,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Colors.white,
                          child: Icon(CupertinoIcons.person_fill, color: kCarbonBlack, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.technicianId == 'CURRENT_USER_ID' ? "Moi (Connecté)" : "Technicien Certifié", // Replace with real name fetch
                              style: const TextStyle(fontWeight: FontWeight.bold, color: kCarbonBlack),
                            ),
                            const Text(
                              "Opération Validée",
                              style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Icon(Icons.verified, color: Colors.green),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // --- C. MANIFEST (PARTS & OPS) ---
                  _buildSectionHeader("MANIFESTE TECHNIQUE"),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...log.performedItems.map((item) => _buildStandardChip(item)),
                      ...log.customParts.map((part) => _buildCustomChip(part)),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // --- D. CONTEXT (NOTES) ---
                  if (log.notes != null && log.notes!.isNotEmpty) ...[
                    _buildSectionHeader("OBSERVATIONS"),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.grey.shade100, blurRadius: 10, offset: const Offset(0, 5)),
                        ],
                      ),
                      child: Text(
                        log.notes!,
                        style: const TextStyle(
                          fontFamily: 'Courier', // Monospace for technical feel
                          fontSize: 13,
                          color: kCarbonBlack,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],

                  // --- E. PROOF (INVOICE) ---
                  if (log.invoiceUrl != null) ...[
                    _buildSectionHeader("JUSTIFICATIF"),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _showFullInvoice(context, log.invoiceUrl!),
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: kAsphaltGrey,
                          borderRadius: BorderRadius.circular(16),
                          image: DecorationImage(
                            image: NetworkImage(log.invoiceUrl!),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: const Icon(CupertinoIcons.zoom_in, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],

                  // --- F. FINANCIALS (BOTTOM LINE) ---
                  const Divider(),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "COÛT TOTAL",
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.grey),
                      ),
                      Text(
                        log.cost != null ? "${NumberFormat('#,###').format(log.cost)} DA" : "N/A",
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                          color: kRacingRed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🧩 HELPER WIDGETS
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.grey.shade400,
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.0,
      ),
    );
  }

  Widget _buildStandardChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kCarbonBlack,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kCarbonBlack),
      ),
      child: Text(
        MaintenanceItems.getLabel(label), // Assuming you have this helper or use literal
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildCustomChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kMechanicBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kMechanicBlue),
      ),
      child: Text(
        label,
        style: const TextStyle(color: kMechanicBlue, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  void _showFullInvoice(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(url),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }
}