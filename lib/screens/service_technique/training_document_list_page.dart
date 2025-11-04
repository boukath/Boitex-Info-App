// lib/screens/service_technique/training_document_list_page.dart
import 'package:boitex_info_app/utils/user_roles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TrainingDocumentListPage extends StatefulWidget {
  final String categoryId;
  final String systemId;
  final String subSystemId;
  final String subSystemName;

  const TrainingDocumentListPage({
    super.key,
    required this.categoryId,
    required this.systemId,
    required this.subSystemId,
    required this.subSystemName,
  });

  @override
  State<TrainingDocumentListPage> createState() =>
      _TrainingDocumentListPageState();
}

class _TrainingDocumentListPageState extends State<TrainingDocumentListPage> {
  bool _isManager = false;
  final TextEditingController _docNameController = TextEditingController();
  late final CollectionReference _documentsCollection;

  @override
  void initState() {
    super.initState();
    // Définit le chemin de la sous-collection finale
    _documentsCollection = FirebaseFirestore.instance
        .collection('training_categories')
        .doc(widget.categoryId)
        .collection('training_systems')
        .doc(widget.systemId)
        .collection('training_sub_systems') // <-- Nouvelle sous-collection
        .doc(widget.subSystemId)
        .collection('training_documents'); // <-- Collection finale

    _fetchUserRole();
  }

  @override
  void dispose() {
    _docNameController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserRole() async {
    final role = await UserRoles.getCurrentUserRole();
    if (mounted) {
      setState(() {
        _isManager = _checkIsManager(role);
      });
    }
  }

  bool _checkIsManager(String? role) {
    if (role == null) return false;
    final managerRoles = <String>{
      UserRoles.pdg,
      UserRoles.admin,
      UserRoles.responsableAdministratif,
      UserRoles.responsableCommercial,
      UserRoles.responsableTechnique,
      UserRoles.responsableIT,
      UserRoles.chefDeProjet,
    };
    return managerRoles.contains(role);
  }

  void _showAddDocumentDialog() {
    _docNameController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nouveau Document'),
          content: TextField(
            controller: _docNameController,
            decoration: const InputDecoration(
              labelText: 'Nom du document (ex: PDF, lien...)',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text('Ajouter'),
              onPressed: () {
                final name = _docNameController.text.trim();
                if (name.isNotEmpty) {
                  _addDocument(name);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _addDocument(String name) async {
    try {
      await _documentsCollection.add({
        'name': name,
        'type': 'pdf', // Type par défaut
        'createdAt': FieldValue.serverTimestamp(),
        // 'url': '...'
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  void _showDeleteConfirmDialog(String docId, String docName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer le Document'),
          content: Text(
              'Êtes-vous sûr de vouloir supprimer le document "$docName" ?'),
          actions: [
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Supprimer'),
              onPressed: () {
                _deleteDocument(docId);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteDocument(String docId) async {
    try {
      await _documentsCollection.doc(docId).delete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subSystemName), // Titre (ex: "Synergy")
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      floatingActionButton: _isManager
          ? FloatingActionButton(
        onPressed: _showAddDocumentDialog,
        child: const Icon(Icons.note_add), // Icône corrigée
        tooltip: 'Ajouter un document',
      )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: _documentsCollection.orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
                child: Text('Erreur de chargement des documents.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
                child:
                Text('Aucun document trouvé pour ${widget.subSystemName}.'));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final docName = data['name'] ?? 'Sans nom';

              return ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text(docName),
                onTap: () {
                  // TODO: Ouvrir le visualiseur de PDF/document
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Action: Ouvre le document $docName')),
                  );
                },
                trailing: _isManager
                    ? IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.red),
                  tooltip: 'Supprimer le document',
                  onPressed: () {
                    _showDeleteConfirmDialog(doc.id, docName);
                  },
                )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}