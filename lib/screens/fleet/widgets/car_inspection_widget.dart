// lib/screens/fleet/widgets/car_inspection_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:boitex_info_app/models/inspection.dart';

class CarInspectionWidget extends StatelessWidget {
  final List<Defect> defects;
  final Function(double x, double y) onTap;
  final Function(Defect defect) onPinTap;
  final bool isReadOnly;

  // 🔹 Use a generic blueprint.
  final String blueprintUrl = "https://upload.wikimedia.org/wikipedia/commons/thumb/9/91/Car_outline_top_view.svg/1024px-Car_outline_top_view.svg.png";

  const CarInspectionWidget({
    super.key,
    required this.defects,
    required this.onTap,
    required this.onPinTap,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4, // Typical car aspect ratio (Top Down)
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
                  // 1. THE BLUEPRINT (Background)
                  Image.network(
                    blueprintUrl,
                    fit: BoxFit.contain,
                    color: Colors.grey.shade300, // Tint it grey for subtle look
                    colorBlendMode: BlendMode.modulate,
                    loadingBuilder: (ctx, child, loading) {
                      if (loading == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (ctx, err, stack) => const Center(
                      child: Icon(Icons.car_repair, size: 60, color: Colors.grey),
                    ),
                  ),

                  // 2. THE TOUCH LAYER (Invisible Grid)
                  if (!isReadOnly)
                    GestureDetector(
                      onTapUp: (details) {
                        // 🧮 MATH: Convert Pixels to Percentage (0.0 - 1.0)
                        final dx = details.localPosition.dx / width;
                        final dy = details.localPosition.dy / height;

                        HapticFeedback.selectionClick();
                        onTap(dx, dy);
                      },
                      child: Container(color: Colors.transparent),
                    ),

                  // 3. THE DAMAGE PINS (Red Dots)
                  ...defects.map((defect) {
                    return Positioned(
                      left: (defect.x * width) - 16, // -16 to center the 32px icon
                      top: (defect.y * height) - 16,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onPinTap(defect);
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
    );
  }

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
            // ✅ FIX: Use EdgeInsets.only(top: 4) instead of EdgeInsets.top(4)
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              defect.label,
              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}