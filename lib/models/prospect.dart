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
  final String address;          // Adresse manuelle

  final double? latitude;        // GPS Lat
  final double? longitude;       // GPS Long

  final List<String> photoUrls;  // Photos du magasin
  final List<String> videoUrls;  // Vidéos

  final String notes;            // Notes générales
  final DateTime createdAt;
  final String createdBy;        // L'ID du commercial qui a créé la fiche

  Prospect({
    required this.id,
    required this.companyName,
    required this.contactName,
    required this.role,
    required this.serviceType,
    required this.phoneNumber,
    required this.email,
    required this.address,
    this.latitude,
    this.longitude,
    required this.photoUrls,
    required this.videoUrls,
    required this.notes,
    required this.createdAt,
    required this.createdBy,
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
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'photoUrls': photoUrls,
      'videoUrls': videoUrls,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  // Créer un Prospect depuis Firebase
  factory Prospect.fromMap(Map<String, dynamic> map) {
    return Prospect(
      id: map['id'] ?? '',
      companyName: map['companyName'] ?? '',
      contactName: map['contactName'] ?? '',
      role: map['role'] ?? '',
      serviceType: map['serviceType'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      email: map['email'] ?? '',
      address: map['address'] ?? '',
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      photoUrls: List<String>.from(map['photoUrls'] ?? []),
      videoUrls: List<String>.from(map['videoUrls'] ?? []),
      notes: map['notes'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      createdBy: map['createdBy'] ?? '',
    );
  }
}