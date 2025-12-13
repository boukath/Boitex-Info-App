// lib/models/prospect.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Prospect {
  final String id;
  final String companyName;      // Enseigne (Burger King, Zara...)
  final String contactName;      // Nom du gérant/contact
  final String role;             // Rôle (Gérant, Propriétaire...)
  final String serviceType;      // Type d'activité (Fast Food, Magasin...)

  final String phoneNumber;
  final String email;

  // ⚡ IMPROVEMENT: Store commune separately for fast filtering
  final String commune;
  final String address;          // Adresse complète (Commune - Détails)

  final double? latitude;        // GPS Lat
  final double? longitude;       // GPS Long

  final List<String> photoUrls;  // Photos du magasin
  final List<String> videoUrls;  // Vidéos

  final String notes;            // Notes générales
  final DateTime createdAt;
  final String createdBy;        // L'ID du commercial qui a créé la fiche

  // ⚡ NEW: Store the name so we can display "Commercial: John Doe" easily
  final String authorName;

  // ⚡ NEW: Sales Pipeline Status
  final String status;

  Prospect({
    required this.id,
    required this.companyName,
    required this.contactName,
    required this.role,
    required this.serviceType,
    required this.phoneNumber,
    required this.email,
    required this.commune,
    required this.address,
    this.latitude,
    this.longitude,
    required this.photoUrls,
    required this.videoUrls,
    required this.notes,
    required this.createdAt,
    required this.createdBy,
    required this.authorName,
    required this.status, // ⚡ Required now
  });

  // Convertir en Map pour Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companyName': companyName,
      'contactName': contactName,
      'role': role,
      'serviceType': serviceType,
      'phoneNumber': phoneNumber,
      'email': email,
      'commune': commune,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'photoUrls': photoUrls,
      'videoUrls': videoUrls,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'authorName': authorName,
      'status': status, // ⚡ Saved to Firestore
    };
  }

  // Créer un Prospect depuis Firebase
  factory Prospect.fromMap(Map<String, dynamic> map) {
    // ⚡ Backward Compatibility: Helper to extract commune if missing in old docs
    String extractCommune(String fullAddress) {
      if (fullAddress.contains(' - ')) {
        return fullAddress.split(' - ')[0].trim();
      }
      return fullAddress;
    }

    final address = map['address'] ?? '';
    final commune = map['commune'] ?? extractCommune(address);

    return Prospect(
      id: map['id'] ?? '',
      companyName: map['companyName'] ?? '',
      contactName: map['contactName'] ?? '',
      role: map['role'] ?? '',
      serviceType: map['serviceType'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      email: map['email'] ?? '',
      commune: commune,
      address: address,
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      photoUrls: List<String>.from(map['photoUrls'] ?? []),
      videoUrls: List<String>.from(map['videoUrls'] ?? []),
      notes: map['notes'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      createdBy: map['createdBy'] ?? '',
      authorName: map['authorName'] ?? 'Commercial',
      // ⚡ Default to 'Nouveau' if status doesn't exist yet
      status: map['status'] ?? 'Nouveau',
    );
  }
}