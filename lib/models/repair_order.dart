// lib/models/repair_order.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// 🚦 STATUS FLOW
enum RepairStatus {
  draft,       // Created by Manager, not sent yet
  scheduled,   // Appointment booked with Garage
  inProgress,  // Car is at the garage being worked on
  completed,   // Work done, waiting for payment/verification
  archived     // Closed and paid
}

class RepairOrder {
  final String id;
  final String vehicleId;
  final String vehicleName; // e.g. "Toyota Hilux (VEH-01)" - Snapshot for easier display
  final DateTime createdAt;
  final DateTime? appointmentDate;

  // 🏢 GARAGE INFO
  final String? garageName;
  final String? garagePhone;
  final String? garageAddress;

  // 🛠️ THE WORK LIST
  final List<RepairItem> items;

  // 💰 FINANCIALS
  final double estimatedCost;
  final double finalCost;

  // 📎 DOCUMENTS (Photos of Quotes, Invoices)
  final List<String> attachmentUrls;

  final RepairStatus status;
  final String? managerNotes;
  final String? mechanicNotes; // "Found extra issue with brake pads"

  RepairOrder({
    required this.id,
    required this.vehicleId,
    required this.vehicleName,
    required this.createdAt,
    this.appointmentDate,
    this.garageName,
    this.garagePhone,
    this.garageAddress,
    required this.items,
    this.estimatedCost = 0.0,
    this.finalCost = 0.0,
    this.attachmentUrls = const [],
    this.status = RepairStatus.draft,
    this.managerNotes,
    this.mechanicNotes,
  });

  // 🔹 HELPER: Color for Status
  Color get statusColor {
    switch (status) {
      case RepairStatus.draft: return Colors.grey;
      case RepairStatus.scheduled: return Colors.orange;
      case RepairStatus.inProgress: return Colors.blue;
      case RepairStatus.completed: return Colors.green;
      case RepairStatus.archived: return Colors.black;
    }
  }

  String get statusLabel {
    switch (status) {
      case RepairStatus.draft: return "BROUILLON";
      case RepairStatus.scheduled: return "RENDEZ-VOUS";
      case RepairStatus.inProgress: return "EN ATELIER";
      case RepairStatus.completed: return "TERMINÉ";
      case RepairStatus.archived: return "ARCHIVÉ";
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'vehicleId': vehicleId,
      'vehicleName': vehicleName,
      'createdAt': Timestamp.fromDate(createdAt),
      'appointmentDate': appointmentDate != null ? Timestamp.fromDate(appointmentDate!) : null,
      'garageName': garageName,
      'garagePhone': garagePhone,
      'garageAddress': garageAddress,
      'items': items.map((x) => x.toMap()).toList(),
      'estimatedCost': estimatedCost,
      'finalCost': finalCost,
      'attachmentUrls': attachmentUrls,
      'status': status.name, // Saves as string 'draft', 'scheduled'...
      'managerNotes': managerNotes,
      'mechanicNotes': mechanicNotes,
    };
  }

  factory RepairOrder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RepairOrder(
      id: doc.id,
      vehicleId: data['vehicleId'] ?? '',
      vehicleName: data['vehicleName'] ?? 'Véhicule Inconnu',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      appointmentDate: data['appointmentDate'] != null ? (data['appointmentDate'] as Timestamp).toDate() : null,
      garageName: data['garageName'],
      garagePhone: data['garagePhone'],
      garageAddress: data['garageAddress'],
      items: List<RepairItem>.from(
        (data['items'] as List<dynamic>? ?? []).map((x) => RepairItem.fromMap(x)),
      ),
      estimatedCost: (data['estimatedCost'] ?? 0.0).toDouble(),
      finalCost: (data['finalCost'] ?? 0.0).toDouble(),
      attachmentUrls: List<String>.from(data['attachmentUrls'] ?? []),
      status: RepairStatus.values.firstWhere(
            (e) => e.name == (data['status'] ?? 'draft'),
        orElse: () => RepairStatus.draft,
      ),
      managerNotes: data['managerNotes'],
      mechanicNotes: data['mechanicNotes'],
    );
  }
}

// -----------------------------------------------------------------------------
// 🔧 REPAIR ITEM (A single task in the order)
// -----------------------------------------------------------------------------
class RepairItem {
  final String title; // e.g. "Pare-chocs avant"
  final String description; // e.g. "Rayure profonde, à repeindre"
  final String? photoUrl; // The original defect photo
  final bool isDone;
  final double cost; // Individual cost if available

  RepairItem({
    required this.title,
    required this.description,
    this.photoUrl,
    this.isDone = false,
    this.cost = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'photoUrl': photoUrl,
      'isDone': isDone,
      'cost': cost,
    };
  }

  factory RepairItem.fromMap(Map<String, dynamic> map) {
    return RepairItem(
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      photoUrl: map['photoUrl'],
      isDone: map['isDone'] ?? false,
      cost: (map['cost'] ?? 0.0).toDouble(),
    );
  }
}