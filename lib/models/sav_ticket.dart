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
  final String serviceType;
  final String savCode;
  final String clientId;
  final String clientName;
  final String? storeId;
  final String? storeName;
  final DateTime pickupDate;
  final List<String> pickupTechnicianIds;
  final List<String> pickupTechnicianNames;
  final String productName;
  final String serialNumber;
  final String problemDescription;
  final List<String> itemPhotoUrls;
  final String storeManagerName;
  final String? storeManagerEmail; // ✅ ADDED: Email field
  final String storeManagerSignatureUrl;
  final String status;
  final String? technicianReport;
  final String createdBy;
  final DateTime createdAt;
  final List<BrokenPart> brokenParts;

  // ✅ 1. Add the variable at the top of the class
  final String ticketType;

  // ✅ ADDED: New fields for the enhanced workflow
  final String? billingStatus;
  final String? invoiceUrl;
  final String? returnClientName;
  final String? returnSignatureUrl;
  final String? returnPhotoUrl;


  SavTicket({
    this.id,
    required this.serviceType,
    required this.savCode,
    required this.clientId,
    required this.clientName,
    this.storeId,
    this.storeName,
    required this.pickupDate,
    required this.pickupTechnicianIds,
    required this.pickupTechnicianNames,
    required this.productName,
    required this.serialNumber,
    required this.problemDescription,
    required this.itemPhotoUrls,
    required this.storeManagerName,
    this.storeManagerEmail, // ✅ ADDED: Constructor parameter
    required this.storeManagerSignatureUrl,
    required this.status,
    this.technicianReport,
    required this.createdBy,
    required this.createdAt,
    List<BrokenPart>? brokenParts,
    // ✅ Initialize default value so existing code doesn't break
    this.ticketType = 'standard',
    // ✅ ADDED: New fields to the constructor
    this.billingStatus,
    this.invoiceUrl,
    this.returnClientName,
    this.returnSignatureUrl,
    this.returnPhotoUrl,
  }) : brokenParts = brokenParts ?? [];

  Map<String, dynamic> toJson() {
    return {
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
      'storeManagerEmail': storeManagerEmail, // ✅ ADDED: To JSON
      'storeManagerSignatureUrl': storeManagerSignatureUrl,
      'status': status,
      'technicianReport': technicianReport,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'brokenParts': brokenParts.map((part) => part.toJson()).toList(),
      // ✅ 3. Update toMap (toJson) method
      'ticketType': ticketType,
      // ✅ ADDED: Saving new fields to Firestore
      'billingStatus': billingStatus,
      'invoiceUrl': invoiceUrl,
      'returnClientName': returnClientName,
      'returnSignatureUrl': returnSignatureUrl,
      'returnPhotoUrl': returnPhotoUrl,
    };
  }

  // ⭐️ FIXED: The factory method now accepts only one argument (doc)
  // and reads the doc.id internally, resolving the compile error
  // in sav_list_page.dart.
  factory SavTicket.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final brokenPartsData = data['brokenParts'] as List<dynamic>? ?? [];
    final brokenPartsList = brokenPartsData
        .map((partJson) => BrokenPart.fromJson(partJson as Map<String, dynamic>))
        .toList();

    return SavTicket(
      id: doc.id, // ⭐️ FIXED: Reads the document ID here
      serviceType: data['serviceType'] as String? ?? 'Service Technique',
      savCode: data['savCode'] as String,
      clientId: data['clientId'] as String,
      clientName: data['clientName'] as String,
      storeId: data['storeId'] as String?,
      storeName: data['storeName'] as String?,
      pickupDate: (data['pickupDate'] as Timestamp).toDate(),
      pickupTechnicianIds: List<String>.from(data['pickupTechnicianIds'] ?? []),
      pickupTechnicianNames: List<String>.from(data['pickupTechnicianNames'] ?? []),
      productName: data['productName'] as String,
      serialNumber: data['serialNumber'] as String,
      problemDescription: data['problemDescription'] as String,
      itemPhotoUrls: List<String>.from(data['itemPhotoUrls'] ?? []),
      storeManagerName: data['storeManagerName'] as String,
      storeManagerEmail: data['storeManagerEmail'] as String?, // ✅ ADDED: From Firestore
      storeManagerSignatureUrl: data['storeManagerSignatureUrl'] as String,
      status: data['status'] as String,
      technicianReport: data['technicianReport'] as String?,
      createdBy: data['createdBy'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      brokenParts: brokenPartsList,
      // ✅ 2. Update fromFirestore factory
      ticketType: data['ticketType'] as String? ?? 'standard',
      // ✅ ADDED: Reading new fields from Firestore
      billingStatus: data['billingStatus'] as String?,
      invoiceUrl: data['invoiceUrl'] as String?,
      returnClientName: data['returnClientName'] as String?,
      returnSignatureUrl: data['returnSignatureUrl'] as String?,
      returnPhotoUrl: data['returnPhotoUrl'] as String?,
    );
  }
}