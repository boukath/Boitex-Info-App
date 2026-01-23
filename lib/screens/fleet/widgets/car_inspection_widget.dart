// lib/screens/fleet/widgets/car_inspection_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:boitex_info_app/models/inspection.dart';

class CarInspectionWidget extends StatefulWidget {
  final List<Defect> defects;
  // 🔹 UPDATED CALLBACK: Returns X, Y, and the View ID (e.g., 'front', 'left')
  final Function(double x, double y, String viewId) onTap;
  final Function(Defect defect) onPinTap;
  final bool isReadOnly;

  const CarInspectionWidget({
    super.key,
    required this.defects,
    required this.onTap,
    required this.onPinTap,
    this.isReadOnly = false,
  });

  @override
  State<CarInspectionWidget> createState() => _CarInspectionWidgetState();
}

class _CarInspectionWidgetState extends State<CarInspectionWidget> {
  // 🔹 1. CONFIGURATION: Define the 5 angles
  // Make sure these images exist in your assets/images/ folder!
  final Map<String, String> _views = {
    'front': 'assets/images/car_front.png',
    'left': 'assets/images/car_left.png',
    'right': 'assets/images/car_right.png',
    'back': 'assets/images/car_back.png',
    'top': 'assets/images/car_top.png',
  };

  final Map<String, String> _viewLabels = {
    'front': 'Avant',
    'left': 'Coté Gauche',
    'right': 'Coté Droit',
    'back': 'Arrière',
    'top': 'Toit',
  };

  String _currentView = 'front'; // Default view

  @override
  Widget build(BuildContext context) {
    // 🔹 2. FILTER: Only show defects that belong to the current view
    final currentDefects = widget.defects.where((d) => d.viewId == _currentView).toList();

    return Column(
      children: [
        // 🔹 3. VIEW SELECTOR (The Tabs)
        Container(
          height: 50,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _views.keys.length,
            itemBuilder: (context, index) {
              final key = _views.keys.elementAt(index);
              final isSelected = _currentView == key;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(_viewLabels[key]!),
                  selected: isSelected,
                  onSelected: (bool selected) {
                    if (selected) {
                      HapticFeedback.selectionClick();
                      setState(() => _currentView = key);
                    }
                  },
                  selectedColor: Colors.black, // Active Color
                  backgroundColor: Colors.grey.shade100, // Inactive Color
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: isSelected ? Colors.black : Colors.grey.shade300),
                  ),
                ),
              );
            },
          ),
        ),

        // 🔹 4. THE INTERACTIVE BLUEPRINT
        AspectRatio(
          // Use 16/9 for better fit of side profiles (Left/Right)
          aspectRatio: 16 / 10,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // A. The Car Image (Local Asset)
                      Image.asset(
                        _views[_currentView]!,
                        fit: BoxFit.contain, // Ensures the whole car is visible
                        errorBuilder: (ctx, err, stack) => const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, color: Colors.grey),
                              SizedBox(height: 8),
                              Text("Image manquante\nassets/images/...", textAlign: TextAlign.center, style: TextStyle(fontSize: 10))
                            ],
                          ),
                        ),
                      ),

                      // B. The Touch Layer (Invisible)
                      if (!widget.isReadOnly)
                        GestureDetector(
                          onTapUp: (details) {
                            // Calculate Percentage Position (0.0 - 1.0)
                            final dx = details.localPosition.dx / width;
                            final dy = details.localPosition.dy / height;

                            HapticFeedback.selectionClick();
                            // Pass x, y AND the current viewId
                            widget.onTap(dx, dy, _currentView);
                          },
                          child: Container(color: Colors.transparent),
                        ),

                      // C. The Pins (Filtered)
                      ...currentDefects.map((defect) {
                        return Positioned(
                          left: (defect.x * width) - 16, // Center the 32px icon
                          top: (defect.y * height) - 16,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.onPinTap(defect);
                            },
                            child: _buildDamagePin(defect),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Helper Text
        const Padding(
          padding: EdgeInsets.only(top: 8.0),
          child: Text(
            "Changez de vue pour inspecter les différentes parties du véhicule.",
            style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  // 🔹 5. PIN DESIGN (Red Dot + Label)
  Widget _buildDamagePin(Defect defect) {
    return Column(
      children: [
        // The Pin Head
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: defect.isRepaired ? Colors.green : const Color(0xFFFF2800), // Red if damaged
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Icon(
            defect.isRepaired ? Icons.check : Icons.close,
            color: Colors.white,
            size: 16,
          ),
        ),
        // The Label (e.g. "Rayure")
        if (defect.label.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              defect.label,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}