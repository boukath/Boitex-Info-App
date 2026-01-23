// lib/widgets/intervention_omnibar.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class OmnibarResult {
  final String id;
  final String title;
  final String subtitle;
  final String type; // 'client' or 'store'
  final Map<String, dynamic> data;

  OmnibarResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.data,
  });
}

class InterventionOmnibar extends StatefulWidget {
  final Function(OmnibarResult) onItemSelected;
  final VoidCallback onClear;

  const InterventionOmnibar({
    super.key,
    required this.onItemSelected,
    required this.onClear,
  });

  @override
  State<InterventionOmnibar> createState() => _InterventionOmnibarState();
}

class _InterventionOmnibarState extends State<InterventionOmnibar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  List<OmnibarResult> _options = [];
  bool _isLoading = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (query.length < 2) {
        setState(() => _options = []);
        _removeOverlay();
        return;
      }
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    final String cleanQuery = query.toLowerCase().trim();

    try {
      // 🚀 SMART SEARCH: Query Clients by 'search_keywords'
      // This finds "Azadea" when you type "Zara"
      final snapshot = await FirebaseFirestore.instance
          .collection('clients')
          .where('search_keywords', arrayContains: cleanQuery)
          .limit(10)
          .get();

      List<OmnibarResult> results = snapshot.docs.map((doc) {
        final data = doc.data();
        final List<dynamic> brands = data['brands'] ?? [];
        String subtitle = "Client";
        if (brands.isNotEmpty) {
          subtitle = "Marques: ${brands.take(3).join(', ')}";
        }

        return OmnibarResult(
          id: doc.id,
          title: data['name'] ?? 'Inconnu',
          subtitle: subtitle,
          type: 'client',
          data: data,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _options = results;
          _isLoading = false;
        });
        _showOverlay();
      }
    } catch (e) {
      debugPrint("Search Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showOverlay() {
    _removeOverlay();
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, size.height + 5.0),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _options.isEmpty ? 1 : _options.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (_options.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text("Aucun résultat trouvé.", style: TextStyle(color: Colors.grey)),
                    );
                  }

                  final option = _options[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      child: const Icon(Icons.business, color: Colors.blue),
                    ),
                    title: Text(option.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(option.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () {
                      _controller.text = option.title;
                      widget.onItemSelected(option);
                      _removeOverlay();
                      _focusNode.unfocus();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          labelText: 'Rechercher Client ou Marque (ex: Zara)',
          hintText: 'Tapez "Zara", "Azadea"...',
          prefixIcon: _isLoading
              ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.search),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _controller.clear();
              widget.onClear();
              setState(() => _options = []);
              _removeOverlay();
            },
          )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}