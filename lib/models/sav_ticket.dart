// lib/models/sav_ticket.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class BrokenPart {
  final String productId;
  final String productName;
  final String status;

  BrokenPart({
    required this.productId,
    required this.productName,
    required this.status,
  });

  Map<String, dynamic> toJson() => {'productId': productId, 'productName': productName, 'status': status};

  factory BrokenPart.fromJson(Map<String, dynamic> json) {
    return BrokenPart(
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      status: json['status'] as String,
    );
  }
}

class SavTicket {
  final String? id;
  // ADDED: The new service type field
  final String serviceType;
  final String savCode;
  final String clientId;
  final String clientName;
  final String storeId;
  final String storeName;
  final DateTime pickupDate;
  final List<String> pickupTechnicianIds;
  final List<String> pickupTechnicianNames;
  final String productName;
  final String serialNumber;
  final String problemDescription;
  final List<String> itemPhotoUrls;
  final String storeManagerName;
  final String storeManagerSignatureUrl;
  final String status;
  final String? technicianReport;
  final String createdBy;
  final DateTime createdAt;
  final List<BrokenPart> brokenParts;

  SavTicket({
    this.id,
    // ADDED: New required parameter in the constructor
    required this.serviceType,
    required this.savCode,
    required this.clientId,
    required this.clientName,
    required this.storeId,
    required this.storeName,
    required this.pickupDate,
    required this.pickupTechnicianIds,
    required this.pickupTechnicianNames,
    required this.productName,
    required this.serialNumber,
    required this.problemDescription,
    required this.itemPhotoUrls,
    required this.storeManagerName,
    required this.storeManagerSignatureUrl,
    required this.status,
    this.technicianReport,
    required this.createdBy,
    required this.createdAt,
    List<BrokenPart>? brokenParts,
  }) : brokenParts = brokenParts ?? [];

  Map<String, dynamic> toJson() {
    return {
      // ADDED: Save service type to Firestore
      'serviceType': serviceType,
      'savCode': savCode,
      'clientId': clientId,
      'clientName': clientName,
      'storeId': storeId,
      'storeName': storeName,
      'pickupDate': Timestamp.fromDate(pickupDate),
      'pickupTechnicianIds': pickupTechnicianIds,
      'pickupTechnicianNames': pickupTechnicianNames,
      'productName': productName,
      'serialNumber': serialNumber,
      'problemDescription': problemDescription,
      'itemPhotoUrls': itemPhotoUrls,
      'storeManagerName': storeManagerName,
      'storeManagerSignatureUrl': storeManagerSignatureUrl,
      'status': status,
      'technicianReport': technicianReport,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'brokenParts': brokenParts.map((part) => part.toJson()).toList(),
    };
  }

  factory SavTicket.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final brokenPartsData = data['brokenParts'] as List<dynamic>? ?? [];
    final brokenPartsList = brokenPartsData
        .map((partJson) => BrokenPart.fromJson(partJson as Map<String, dynamic>))
        .toList();

    return SavTicket(
      id: doc.id,
      // ADDED: Read service type from Firestore, with a default for old tickets
      serviceType: data['serviceType'] as String? ?? 'Service Technique',
      savCode: data['savCode'] as String,
      clientId: data['clientId'] as String,
      clientName: data['clientName'] as String,
      storeId: data['storeId'] as String,
      storeName: data['storeName'] as String,
      pickupDate: (data['pickupDate'] as Timestamp).toDate(),
      pickupTechnicianIds: List<String>.from(data['pickupTechnicianIds'] ?? []),
      pickupTechnicianNames: List<String>.from(data['pickupTechnicianNames'] ?? []),
      productName: data['productName'] as String,
      serialNumber: data['serialNumber'] as String,
      problemDescription: data['problemDescription'] as String,
      itemPhotoUrls: List<String>.from(data['itemPhotoUrls'] ?? []),
      storeManagerName: data['storeManagerName'] as String,
      storeManagerSignatureUrl: data['storeManagerSignatureUrl'] as String,
      status: data['status'] as String,
      technicianReport: data['technicianReport'] as String?,
      createdBy: data['createdBy'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      brokenParts: brokenPartsList,
    );
  }
}