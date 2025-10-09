import 'package:flutter/material.dart';

// **MODIFIED**: Added a required color property
class ActionButtonModel {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  ActionButtonModel({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });
}

class ActionButtonsGrid extends StatelessWidget {
  final List<ActionButtonModel> buttons;

  const ActionButtonsGrid({
    super.key,
    required this.buttons,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: buttons.length,
      itemBuilder: (context, index) {
        final button = buttons[index];
        return _buildActionButton(
          icon: button.icon,
          label: button.label,
          onTap: button.onTap,
          // **MODIFIED**: Pass the color to the builder
          color: button.color,
        );
      },
    );
  }

  // **MODIFIED**: This widget now uses the color property
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              // Use a light shade of the color for the background
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            // Use the main color for the icon
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}