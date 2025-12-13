// lib/screens/home/widgets/animated_service_card.dart

import 'package:flutter/material.dart';

class AnimatedServiceCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const AnimatedServiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  State<AnimatedServiceCard> createState() => _AnimatedServiceCardState();
}

class _AnimatedServiceCardState extends State<AnimatedServiceCard> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails details) {
    setState(() { _isPressed = true; });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() { _isPressed = false; });
    // Navigate after a short delay to allow the animation to reverse
    Future.delayed(const Duration(milliseconds: 150), widget.onTap);
  }

  void _onTapCancel() {
    setState(() { _isPressed = false; });
  }

  @override
  Widget build(BuildContext context) {
    final Duration duration = const Duration(milliseconds: 200);

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedContainer(
        duration: duration,
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: _isPressed ? widget.color : Colors.white,
          borderRadius: BorderRadius.circular(24.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: duration,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: _isPressed ? Colors.white.withOpacity(0.2) : widget.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: AnimatedTheme(
                data: ThemeData(
                  iconTheme: IconThemeData(
                    color: _isPressed ? Colors.white : widget.color,
                    size: 28,
                  ),
                ),
                child: Icon(widget.icon),
              ),
            ),
            const SizedBox(width: 20),
            AnimatedDefaultTextStyle(
              duration: duration,
              style: TextStyle(
                color: _isPressed ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              child: Text(widget.title),
            ),
            const Spacer(),
            AnimatedTheme(
              data: ThemeData(
                iconTheme: IconThemeData(
                  color: _isPressed ? Colors.white : Colors.grey.shade400,
                ),
              ),
              child: const Icon(Icons.arrow_forward_ios, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}