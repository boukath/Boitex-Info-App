// lib/models/mission.dart
// ✅ COMPLETE VERSION with multi-destinations, resources, and mission codes

import 'package:cloud_firestore/cloud_firestore.dart';

class MissionTask {
  String description;
  bool isCompleted;

  MissionTask({
    required this.description,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'isCompleted': isCompleted,
    };
  }

  factory MissionTask.fromJson(Map<String, dynamic> json) {
    return MissionTask(
      description: json['description'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}

class ExpenseCategory {
  final double budget;
  final double spent;
  final List<String> billUrls;

  ExpenseCategory({
    required this.budget,
    this.spent = 0.0,
    List<String>? billUrls,
  }) : billUrls = billUrls ?? [];

  Map<String, dynamic> toJson() {
    return {
      'budget': budget,
      'spent': spent,
      'billUrls': billUrls,
    };
  }

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    return ExpenseCategory(
      budget: (json['budget'] as num).toDouble(),
      spent: (json['spent'] as num? ?? 0.0).toDouble(),
      billUrls: List<String>.from(json['billUrls'] ?? []),
    );
  }
}

class ExpenseReport {
  final Map<String, ExpenseCategory> dailyAllowancesPerTechnician;
  final ExpenseCategory fuel;
  final ExpenseCategory purchases;
  final ExpenseCategory hotel;

  ExpenseReport({
    required this.dailyAllowancesPerTechnician,
    required this.fuel,
    required this.purchases,
    required this.hotel,
  });

  double get totalBudget {
    final allowancesTotal = dailyAllowancesPerTechnician.values.fold(0.0, (sum, item) => sum + item.budget);
    return allowancesTotal + fuel.budget + purchases.budget + hotel.budget;
  }

  double get totalSpent {
    final allowancesSpent = dailyAllowancesPerTechnician.values.fold(0.0, (sum, item) => sum + item.spent);
    return allowancesSpent + fuel.spent + purchases.spent + hotel.spent;
  }

  double get totalRemaining => totalBudget - totalSpent;

  Map<String, dynamic> toJson() {
    return {
      'dailyAllowancesPerTechnician': dailyAllowancesPerTechnician.map((key, value) => MapEntry(key, value.toJson())),
      'fuel': fuel.toJson(),
      'purchases': purchases.toJson(),
      'hotel': hotel.toJson(),
      'totalBudget': totalBudget,
      'totalSpent': totalSpent,
    };
  }

  factory ExpenseReport.fromJson(Map<String, dynamic> json) {
    return ExpenseReport(
      dailyAllowancesPerTechnician: (json['dailyAllowancesPerTechnician'] as Map<String, dynamic>).map(
            (key, value) => MapEntry(key, ExpenseCategory.fromJson(value as Map<String, dynamic>)),
      ),
      fuel: ExpenseCategory.fromJson(json['fuel']),
      purchases: ExpenseCategory.fromJson(json['purchases']),
      hotel: ExpenseCategory.fromJson(json['hotel']),
    );
  }
}

// ✅ NEW: Purchase item for pre-mission shopping list
class PurchaseItem {
  final String id;
  String item;
  String description;
  double estimatedBudget;
  bool purchased;

  PurchaseItem({
    required this.id,
    required this.item,
    this.description = '',
    this.estimatedBudget = 0.0,
    this.purchased = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'item': item,
      'description': description,
      'estimatedBudget': estimatedBudget,
      'purchased': purchased,
    };
  }

  factory PurchaseItem.fromJson(Map<String, dynamic> json) {
    return PurchaseItem(
      id: json['id'] as String,
      item: json['item'] as String,
      description: json['description'] as String? ?? '',
      estimatedBudget: (json['estimatedBudget'] as num?)?.toDouble() ?? 0.0,
      purchased: json['purchased'] as bool? ?? false,
    );
  }
}

// ✅ NEW: Mission resources (vehicle, equipment, purchases)
class MissionResources {
  final String? vehicleId;
  final String? vehicleModel;
  final String? vehiclePlate;
  final List<String> equipment;
  final List<PurchaseItem> preMissionPurchases;
  final String purchaseNotes;

  MissionResources({
    this.vehicleId,
    this.vehicleModel,
    this.vehiclePlate,
    List<String>? equipment,
    List<PurchaseItem>? preMissionPurchases,
    this.purchaseNotes = '',
  })  : equipment = equipment ?? [],
        preMissionPurchases = preMissionPurchases ?? [];

  Map<String, dynamic> toJson() {
    return {
      'vehicleId': vehicleId,
      'vehicleModel': vehicleModel,
      'vehiclePlate': vehiclePlate,
      'equipment': equipment,
      'preMissionPurchases': preMissionPurchases.map((p) => p.toJson()).toList(),
      'purchaseNotes': purchaseNotes,
    };
  }

  factory MissionResources.fromJson(Map<String, dynamic> json) {
    return MissionResources(
      vehicleId: json['vehicleId'] as String?,
      vehicleModel: json['vehicleModel'] as String?,
      vehiclePlate: json['vehiclePlate'] as String?,
      equipment: List<String>.from(json['equipment'] ?? []),
      preMissionPurchases: (json['preMissionPurchases'] as List<dynamic>?)
          ?.map((item) => PurchaseItem.fromJson(item as Map<String, dynamic>))
          .toList() ??
          [],
      purchaseNotes: json['purchaseNotes'] as String? ?? '',
    );
  }
}

class Mission {
  final String? id;
  final String missionCode;
  final String serviceType;
  final String title;

  // ✅ CHANGED: Multi-destination support
  final List<String> destinations;  // Ordered list: ["Oran", "Mostaganem", "Chlef"]

  final DateTime startDate;
  final DateTime endDate;
  final List<String> assignedTechniciansIds;
  final List<String> assignedTechniciansNames;

  // ✅ NEW: Store roles for team members
  final List<String> assignedTechniciansRoles;

  final List<MissionTask> tasks;
  final String status;
  final String createdBy;
  final DateTime createdAt;
  final ExpenseReport expenseReport;

  // ✅ NEW: Mission resources
  final MissionResources? resources;

  Mission({
    this.id,
    required this.missionCode,
    required this.serviceType,
    required this.title,
    required this.destinations,  // ✅ Multi-destination
    required this.startDate,
    required this.endDate,
    required this.assignedTechniciansIds,
    required this.assignedTechniciansNames,
    required this.assignedTechniciansRoles,  // ✅ NEW
    required this.tasks,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.expenseReport,
    this.resources,  // ✅ NEW
  });

  Map<String, dynamic> toJson() {
    return {
      'missionCode': missionCode,
      'serviceType': serviceType,
      'title': title,
      'destinations': destinations,  // ✅ Multi-destination
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'assignedTechniciansIds': assignedTechniciansIds,
      'assignedTechniciansNames': assignedTechniciansNames,
      'assignedTechniciansRoles': assignedTechniciansRoles,  // ✅ NEW
      'tasks': tasks.map((task) => task.toJson()).toList(),
      'status': status,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'expenseReport': expenseReport.toJson(),
      'resources': resources?.toJson(),  // ✅ NEW
    };
  }

  factory Mission.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle legacy single destination field
    List<String> destinations = [];
    if (data.containsKey('destinations') && data['destinations'] is List) {
      destinations = List<String>.from(data['destinations']);
    } else if (data.containsKey('destination')) {
      // Legacy: single destination
      destinations = [data['destination'] as String];
    }

    return Mission(
      id: doc.id,
      missionCode: data['missionCode'] as String? ?? 'N/A',
      serviceType: data['serviceType'] as String? ?? 'Service Technique',
      title: data['title'] as String,
      destinations: destinations,  // ✅ Multi-destination
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      assignedTechniciansIds: List<String>.from(data['assignedTechniciansIds'] ?? []),
      assignedTechniciansNames: List<String>.from(data['assignedTechniciansNames'] ?? []),
      assignedTechniciansRoles: List<String>.from(data['assignedTechniciansRoles'] ?? []),  // ✅ NEW
      tasks: (data['tasks'] as List<dynamic>)
          .map((taskJson) => MissionTask.fromJson(taskJson as Map<String, dynamic>))
          .toList(),
      status: data['status'] as String,
      createdBy: data['createdBy'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expenseReport: data.containsKey('expenseReport') && data['expenseReport'] != null
          ? ExpenseReport.fromJson(data['expenseReport'])
          : ExpenseReport(
        dailyAllowancesPerTechnician: {},
        fuel: ExpenseCategory(budget: 0),
        purchases: ExpenseCategory(budget: 0),
        hotel: ExpenseCategory(budget: 0),
      ),
      resources: data.containsKey('resources') && data['resources'] != null
          ? MissionResources.fromJson(data['resources'])
          : null,  // ✅ NEW
    );
  }

  // ✅ Helper: Get formatted destination string
  String get destinationsDisplay {
    if (destinations.isEmpty) return 'N/A';
    if (destinations.length == 1) return destinations[0];
    return destinations.join(' → ');
  }
}
