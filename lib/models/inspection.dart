// lib/models/inspection.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Inspection {
  final String id;
  final String vehicleId;
  final DateTime date;
  final String inspectorId; // The ID of the driver/tech doing the check
  final String type; // 'DEPART' (Check-out) or 'RETOUR' (Check-in)
  final List<Defect> defects;
  final String? signatureUrl; // Optional: Driver's signature
  final bool isCompleted;

  Inspection({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.inspectorId,
    this.type = 'ROUTINE',
    required this.defects,
    this.signatureUrl,
    this.isCompleted = false,
  });

  // 🔹 Create empty session
  factory Inspection.start(String vehicleId, String type) {
    return Inspection(
      id: '',
      vehicleId: vehicleId,
      date: DateTime.now(),
      inspectorId: 'CURRENT_USER', // Replace with actual Auth ID later
      type: type,
      defects: [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vehicleId': vehicleId,
      'date': Timestamp.fromDate(date),
      'inspectorId': inspectorId,
      'type': type,
      'defects': defects.map((x) => x.toMap()).toList(),
      'signatureUrl': signatureUrl,
      'isCompleted': isCompleted,
    };
  }

  factory Inspection.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Inspection(
      id: doc.id,
      vehicleId: data['vehicleId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      inspectorId: data['inspectorId'] ?? '',
      type: data['type'] ?? 'ROUTINE',
      defects: List<Defect>.from(
        (data['defects'] as List<dynamic>? ?? []).map<Defect>(
              (x) => Defect.fromMap(x as Map<String, dynamic>),
        ),
      ),
      signatureUrl: data['signatureUrl'],
      isCompleted: data['isCompleted'] ?? false,
    );
  }

  Inspection copyWith({List<Defect>? defects, bool? isCompleted}) {
    return Inspection(
      id: id,
      vehicleId: vehicleId,
      date: date,
      inspectorId: inspectorId,
      type: type,
      defects: defects ?? this.defects,
      signatureUrl: signatureUrl,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

// -----------------------------------------------------------------------------
// 🔴 THE DAMAGE PIN (The "Red Dot")
// -----------------------------------------------------------------------------
class Defect {
  final String id;
  final double x; // Horizontal Position (0.0 = Left Edge, 1.0 = Right Edge)
  final double y; // Vertical Position (0.0 = Top, 1.0 = Bottom)
  final String label; // e.g., "Rayure Profonde", "Impact Pare-brise"
  final String? photoUrl; // Proof
  final bool isRepaired;

  Defect({
    required this.id,
    required this.x,
    required this.y,
    required this.label,
    this.photoUrl,
    this.isRepaired = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'x': x,
      'y': y,
      'label': label,
      'photoUrl': photoUrl,
      'isRepaired': isRepaired,
    };
  }

  factory Defect.fromMap(Map<String, dynamic> map) {
    return Defect(
      id: map['id'] ?? '',
      x: (map['x'] ?? 0).toDouble(),
      y: (map['y'] ?? 0).toDouble(),
      label: map['label'] ?? 'Dommage',
      photoUrl: map['photoUrl'],
      isRepaired: map['isRepaired'] ?? false,
    );
  }
}