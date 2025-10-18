// lib/models/antivol_system.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Représente un seul composant requis pour une configuration.
class SystemComponent {
  final String productRef; // Chemin vers le produit (ex: '/produits/xyz123')
  final int quantity;

  SystemComponent({
    required this.productRef,
    required this.quantity,
  });

  factory SystemComponent.fromMap(Map<String, dynamic> data) {
    return SystemComponent(
      productRef: data['productRef'] as String,
      quantity: (data['quantity'] as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productRef': productRef,
      'quantity': quantity,
    };
  }
}

/// Représente une option de configuration (ex: "Dual", "Split").
class AntivolConfiguration {
  final String name;
  final String description;
  final List<SystemComponent> components;

  AntivolConfiguration({
    required this.name,
    required this.description,
    required this.components,
  });

  factory AntivolConfiguration.fromMap(Map<String, dynamic> data) {
    final componentsList = (data['components'] as List<dynamic>? ?? [])
        .map((compData) => SystemComponent.fromMap(compData as Map<String, dynamic>))
        .toList();

    return AntivolConfiguration(
      name: data['name'] as String,
      description: data['description'] as String? ?? '',
      components: componentsList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'components': components.map((comp) => comp.toMap()).toList(),
    };
  }
}

/// Modèle principal pour un système antivol complet (ex: "UP6").
class AntivolSystem {
  final String id;
  final String systemName;
  final String supplier;
  final String technology; // "AM" ou "RF"
  final List<AntivolConfiguration> configurations;

  AntivolSystem({
    required this.id,
    required this.systemName,
    required this.supplier,
    required this.technology,
    required this.configurations,
  });

  factory AntivolSystem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    final configList = (data['configurations'] as List<dynamic>? ?? [])
        .map((configData) => AntivolConfiguration.fromMap(configData as Map<String, dynamic>))
        .toList();

    return AntivolSystem(
      id: doc.id,
      systemName: data['systemName'] as String,
      supplier: data['supplier'] as String,
      technology: data['technology'] as String,
      configurations: configList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'systemName': systemName,
      'supplier': supplier,
      'technology': technology,
      'configurations': configurations.map((config) => config.toMap()).toList(),
    };
  }
}