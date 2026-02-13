// lib/screens/service_technique/widgets/image_markup_page.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_painter/image_painter.dart';

class ImageMarkupPage extends StatefulWidget {
  final File imageFile;

  const ImageMarkupPage({super.key, required this.imageFile});

  @override
  State<ImageMarkupPage> createState() => _ImageMarkupPageState();
}

class _ImageMarkupPageState extends State<ImageMarkupPage> {
  // ✅ NEW: We now use the ImagePainterController instead of a GlobalKey
  late final ImagePainterController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // ✅ NEW: We define our thick red line settings inside the controller
    _controller = ImagePainterController(
      color: Colors.red,
      strokeWidth: 4,
      mode: PaintMode.freeStyle,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveAndReturn() async {
    setState(() => _isSaving = true);

    try {
      // ✅ NEW: We ask the controller to export the flattened image
      final Uint8List? imageBytes = await _controller.exportImage();

      if (imageBytes != null && mounted) {
        Navigator.pop(context, imageBytes);
      } else {
        throw Exception("Failed to export image bytes.");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la sauvegarde.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark pro theme for the editor
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text("Annotation", style: TextStyle(fontSize: 18)),
        actions: [
          _isSaving
              ? const Padding(
            padding: EdgeInsets.all(16.0),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.green, strokeWidth: 2)),
          )
              : TextButton.icon(
            onPressed: _saveAndReturn,
            icon: const Icon(Icons.check_circle, color: Colors.green),
            label: const Text("Valider", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
      body: SafeArea(
        child: ImagePainter.file(
          widget.imageFile,
          controller: _controller, // ✅ NEW: Feed the controller to the UI
          scalable: true, // Allows zooming in to draw accurately
        ),
      ),
    );
  }
}