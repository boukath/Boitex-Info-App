// lib/models/sav_ticket.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ NEW CLASS: Holds details for individual items in a grouped ticket
class SavProductItem {
  final String productId;
  final String productName;
  final String serialNumber;
  final String problemDescription;

  SavProductItem({
    required this.productId,
    required this.productName,
    required this.serialNumber,
    required this.problemDescription,
  });

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'serialNumber': serialNumber,
    'problemDescription': problemDescription,
  };

  factory SavProductItem.fromJson(Map<String, dynamic> json) {
    return SavProductItem(
      productId: json['productId'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      serialNumber: json['serialNumber'] as String? ?? '',
      problemDescription: json['problemDescription'] as String? ?? '',
    );
  }
}

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

  // These top-level fields will act as "Global Summaries" for grouped tickets
  final String productName;
  final String serialNumber;
  final String problemDescription;

  final List<String> itemPhotoUrls;
  final String storeManagerName;
  final String? storeManagerEmail;
  final String storeManagerSignatureUrl;
  final String status;
  final String? technicianReport;
  final String createdBy;
  final DateTime createdAt;
  final List<BrokenPart> brokenParts;

  final String ticketType;

  // Enhanced workflow fields
  final String? billingStatus;
  final String? invoiceUrl;
  final String? returnClientName;
  final String? returnSignatureUrl;
  final String? returnPhotoUrl;

  // ✅ NEW FIELD: List of products for grouped tickets
  final List<SavProductItem> multiProducts;

  // ✅ NEW FIELD: URL for the specific uploaded file
  final String? uploadedFileUrl;

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
    this.storeManagerEmail,
    required this.storeManagerSignatureUrl,
    required this.status,
    this.technicianReport,
    required this.createdBy,
    required this.createdAt,
    List<BrokenPart>? brokenParts,
    this.ticketType = 'standard',
    this.billingStatus,
    this.invoiceUrl,
    this.returnClientName,
    this.returnSignatureUrl,
    this.returnPhotoUrl,
    // ✅ Initialize new list
    List<SavProductItem>? multiProducts,
    // ✅ Add to Constructor
    this.uploadedFileUrl,
  }) : brokenParts = brokenParts ?? [],
        multiProducts = multiProducts ?? [];

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
      'storeManagerEmail': storeManagerEmail,
      'storeManagerSignatureUrl': storeManagerSignatureUrl,
      'status': status,
      'technicianReport': technicianReport,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'brokenParts': brokenParts.map((part) => part.toJson()).toList(),
      'ticketType': ticketType,
      'billingStatus': billingStatus,
      'invoiceUrl': invoiceUrl,
      'returnClientName': returnClientName,
      'returnSignatureUrl': returnSignatureUrl,
      'returnPhotoUrl': returnPhotoUrl,
      // ✅ Save the multi-products list
      'multiProducts': multiProducts.map((item) => item.toJson()).toList(),
      // ✅ Save to JSON
      'uploadedFileUrl': uploadedFileUrl,
    };
  }

  factory SavTicket.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    // Parse Broken Parts
    final brokenPartsData = data['brokenParts'] as List<dynamic>? ?? [];
    final brokenPartsList = brokenPartsData
        .map((partJson) => BrokenPart.fromJson(partJson as Map<String, dynamic>))
        .toList();

    // ✅ Parse Multi Products
    final multiProductsData = data['multiProducts'] as List<dynamic>? ?? [];
    final multiProductsList = multiProductsData
        .map((itemJson) => SavProductItem.fromJson(itemJson as Map<String, dynamic>))
        .toList();

    return SavTicket(
      id: doc.id,
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
      storeManagerEmail: data['storeManagerEmail'] as String?,
      storeManagerSignatureUrl: data['storeManagerSignatureUrl'] as String,
      status: data['status'] as String,
      technicianReport: data['technicianReport'] as String?,
      createdBy: data['createdBy'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      brokenParts: brokenPartsList,
      ticketType: data['ticketType'] as String? ?? 'standard',
      billingStatus: data['billingStatus'] as String?,
      invoiceUrl: data['invoiceUrl'] as String?,
      returnClientName: data['returnClientName'] as String?,
      returnSignatureUrl: data['returnSignatureUrl'] as String?,
      returnPhotoUrl: data['returnPhotoUrl'] as String?,
      // ✅ Assign the parsed list
      multiProducts: multiProductsList,
      // ✅ Read from Firestore
      uploadedFileUrl: data['uploadedFileUrl'] as String?,
    );
  }
}