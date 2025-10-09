// lib/widgets/animated_truck_button.dart

import 'package:flutter/material.dart';

enum ButtonState { idle, loading, success }

class AnimatedTruckButton extends StatefulWidget {
  final Future<void> Function() onPressed;
  final String title;
  final String completedTitle;

  const AnimatedTruckButton({
    super.key,
    required this.onPressed,
    this.title = 'Créer le Bon de Livraison',
    this.completedTitle = 'Bon Créé !',
  });

  @override
  State<AnimatedTruckButton> createState() => _AnimatedTruckButtonState();
}

class _AnimatedTruckButtonState extends State<AnimatedTruckButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  ButtonState _state = ButtonState.idle;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePress() async {
    if (_state != ButtonState.idle) return;

    setState(() { _state = ButtonState.loading; });
    _controller.forward();

    try {
      await widget.onPressed();
      await Future.delayed(const Duration(milliseconds: 500)); // Ensure animation plays a bit
      setState(() { _state = ButtonState.success; });
    } catch (e) {
      // On error, reset the button
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      _controller.reset();
      setState(() { _state = ButtonState.idle; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handlePress,
      child: Container(
        height: 60,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _state == ButtonState.success ? Colors.green : Colors.brown,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Truck Animation
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final buttonWidth = MediaQuery.of(context).size.width - 32; // Page padding
                return Positioned(
                  left: _animation.value * (buttonWidth - 60), // 60 is icon width
                  child: Opacity(
                    opacity: _state == ButtonState.loading ? 1.0 : 0.0,
                    child: const Icon(Icons.local_shipping, color: Colors.white, size: 30),
                  ),
                );
              },
            ),
            // Text states
            AnimatedOpacity(
              opacity: _state == ButtonState.idle ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            AnimatedOpacity(
              opacity: _state == ButtonState.success ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(widget.completedTitle, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}