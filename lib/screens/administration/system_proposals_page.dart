// lib/screens/administration/system_proposals_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Data model to hold a calculated configuration proposal
class SystemProposal {
  final String systemName;
  final String configurationName;
  final int pedestalsRequired;
  final String technology;
  final Map<String, int> requiredComponents;
  final bool isInStock;

  SystemProposal({
    required this.systemName,
    required this.configurationName,
    required this.pedestalsRequired,
    required this.technology,
    required this.requiredComponents,
    required this.isInStock,
  });
}

class SystemProposalsPage extends StatefulWidget {
  final double entranceWidth;

  const SystemProposalsPage({super.key, required this.entranceWidth});

  @override
  State<SystemProposalsPage> createState() => _SystemProposalsPageState();
}

class _SystemProposalsPageState extends State<SystemProposalsPage> {
  late Future<List<SystemProposal>> _proposalsFuture;

  @override
  void initState() {
    super.initState();
    _proposalsFuture = _calculateProposals();
  }

  String _getConfigurationName(int pedestals) {
    switch (pedestals) {
      case 1: return 'Mono';
      case 2: return 'Dual';
      case 3: return 'Split';
      case 4: return 'Quad';
      default: return '$pedestals Poteaux';
    }
  }

  Future<List<SystemProposal>> _calculateProposals() async {
    final List<SystemProposal> proposals = [];
    final firestore = FirebaseFirestore.instance;

    // 1. Fetch all "System" products
    final systemsSnapshot = await firestore
        .collection('produits')
        .where('isSystem', isEqualTo: true)
        .get();

    // 2. Fetch all "Component" products to check stock later
    final componentsSnapshot = await firestore
        .collection('produits')
        .where('quantiteEnStock', isGreaterThanOrEqualTo: 0)
        .get();

    final Map<String, int> stockMap = {
      for (var doc in componentsSnapshot.docs)
        doc['nom']: doc['quantiteEnStock'] ?? 0
    };

    // 3. Loop through each system and calculate
    for (final systemDoc in systemsSnapshot.docs) {
      final systemData = systemDoc.data();
      final pedestalCoverage = (systemData['pedestalCoverage'] as num?)?.toDouble() ?? 1.0;

      // Calculate required pedestals and round up
      final requiredPedestals = (widget.entranceWidth / pedestalCoverage).ceil();
      final configName = _getConfigurationName(requiredPedestals);

      final configurations = systemData['configurations'] as Map<String, dynamic>?;
      if (configurations != null && configurations.containsKey(configName)) {
        final recipe = configurations[configName] as Map<String, dynamic>;
        final requiredComponents = recipe.map((key, value) => MapEntry(key, value as int));

        // Check stock for all required components
        bool allInStock = true;
        for (final component in requiredComponents.entries) {
          final componentName = component.key;
          final requiredQty = component.value;
          if ((stockMap[componentName] ?? 0) < requiredQty) {
            allInStock = false;
            break;
          }
        }

        proposals.add(SystemProposal(
          systemName: systemData['nom'],
          configurationName: configName,
          pedestalsRequired: requiredPedestals,
          technology: systemData['technology'] ?? 'N/A',
          requiredComponents: requiredComponents,
          isInStock: allInStock,
        ));
      }
    }

    return proposals;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Systèmes Recommandés'),
      ),
      body: FutureBuilder<List<SystemProposal>>(
        future: _proposalsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucun système compatible trouvé.'));
          }

          final proposals = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: proposals.length,
            itemBuilder: (context, index) {
              final proposal = proposals[index];
              final componentsText = proposal.requiredComponents.entries
                  .map((e) => '${e.key} (x${e.value})')
                  .join(', ');

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              proposal.systemName,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Chip(
                            label: Text(
                              proposal.isInStock ? 'En Stock' : 'Hors Stock',
                              style: const TextStyle(color: Colors.white),
                            ),
                            backgroundColor: proposal.isInStock ? Colors.green : Colors.red,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Configuration: ${proposal.configurationName} (${proposal.pedestalsRequired} Poteaux)',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                      ),
                      Text('Technologie: ${proposal.technology}'),
                      const Divider(height: 24),
                      Text('Composants requis:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(componentsText),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}