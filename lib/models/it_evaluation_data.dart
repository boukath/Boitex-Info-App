// lib/models/it_evaluation_data.dart

import 'dart:io';
import 'package:flutter/material.dart';
// ✅ REMOVED: import 'package:firebase_storage/firebase_storage.dart';
// ✅ REMOVED: import 'package:path/path.dart' as path;

/// A helper class to store data for each individual endpoint (TPV, Printer, etc.)
class EndpointData {
  String name;
  bool hasPriseElectrique = false;
  final TextEditingController quantityPriseElectriqueController = TextEditingController(text: '1');
  bool hasPriseRJ45 = false;
  final TextEditingController quantityPriseRJ45Controller = TextEditingController(text: '1');
  final TextEditingController notesController = TextEditingController();

  EndpointData({required this.name});

  void dispose() {
    quantityPriseElectriqueController.dispose();
    quantityPriseRJ45Controller.dispose();
    notesController.dispose();
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'hasPriseElectrique': hasPriseElectrique,
      'quantityPriseElectrique': int.tryParse(quantityPriseElectriqueController.text) ?? 1,
      'hasPriseRJ45': hasPriseRJ45,
      'quantityPriseRJ45': int.tryParse(quantityPriseRJ45Controller.text) ?? 1,
      'notes': notesController.text,
    };
  }
}

/// A new helper class to store data for the client's existing hardware
class ClientDeviceData {
  String? deviceType;
  String? osType;
  final TextEditingController brandController = TextEditingController();
  final TextEditingController modelController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  ClientDeviceData(); // Constructor

  void dispose() {
    brandController.dispose();
    modelController.dispose();
    notesController.dispose();
  }

  Map<String, dynamic> toMap() {
    return {
      'deviceType': deviceType,
      'osType': osType,
      'brand': brandController.text,
      'model': modelController.text,
      'notes': notesController.text,
    };
  }
}


/// Main data class for the IT Evaluation
class ItEvaluationData {
  // 1. Réseau Existant
  bool? networkExists;
  bool? isMultiFloor;
  final TextEditingController networkNotesController = TextEditingController();

  // 2. Environnement
  bool? hasHighVoltage;
  final TextEditingController highVoltageNotesController = TextEditingController();

  // 3. Baie de Brassage
  bool? hasNetworkRack;
  final TextEditingController rackLocationController = TextEditingController();
  bool? hasRackSpace;
  bool? hasUPS;

  // 4. Câblage
  String? cableShieldType; // UTP, FTP, STP
  String? cableCategoryType; // CAT 5e, CAT 6, CAT 6a
  bool? hasCablePaths;
  final TextEditingController cableDistanceController = TextEditingController();

  // 5. Accès Internet
  String? internetAccessType; // Fibre, ADSL, 4G
  final TextEditingController internetProviderController = TextEditingController();
  final TextEditingController modemLocationController = TextEditingController();

  // 6. Wi-Fi
  bool? needsWifi;
  final TextEditingController wifiZonesController = TextEditingController();
  bool? hasExistingWifi;

  // 7. Équipements
  bool? hasExistingSwitch;
  bool? hasPoePorts;
  final TextEditingController switchModelController = TextEditingController();

  // 8. Endpoints (Prises)
  List<EndpointData> tpvList = [];
  List<EndpointData> printerList = [];
  List<EndpointData> kioskList = [];
  List<EndpointData> screenList = [];

  // 9. Client Hardware Inventory
  List<ClientDeviceData> clientDeviceList = [];

  // 10. Photos
  List<File> photos = []; // Local files are still stored here

  void dispose() {
    networkNotesController.dispose();
    highVoltageNotesController.dispose();
    rackLocationController.dispose();
    cableDistanceController.dispose();
    internetProviderController.dispose();
    modemLocationController.dispose();
    wifiZonesController.dispose();
    switchModelController.dispose();

    // Dispose all endpoint controllers
    for (var item in tpvList) { item.dispose(); }
    for (var item in printerList) { item.dispose(); }
    for (var item in kioskList) { item.dispose(); }
    for (var item in screenList) { item.dispose(); }
    for (var item in clientDeviceList) { item.dispose(); }
  }

  // ✅ CHANGED: This function no longer uploads files and is not async.
  // It just prepares the data map.
  Map<String, dynamic> getDataMap() {
    // ✅ REMOVED: File upload loop

    // Convert all controllers and bools to a map
    return {
      'networkExists': networkExists,
      'isMultiFloor': isMultiFloor,
      'networkNotes': networkNotesController.text,
      'hasHighVoltage': hasHighVoltage,
      'highVoltageNotes': highVoltageNotesController.text,
      'hasNetworkRack': hasNetworkRack,
      'rackLocation': rackLocationController.text,
      'hasRackSpace': hasRackSpace,
      'hasUPS': hasUPS,
      'cableShieldType': cableShieldType,
      'cableCategoryType': cableCategoryType,
      'hasCablePaths': hasCablePaths,
      'cableDistance': cableDistanceController.text,
      'internetAccessType': internetAccessType,
      'internetProvider': internetProviderController.text,
      'modemLocation': modemLocationController.text,
      'needsWifi': needsWifi,
      'wifiZones': wifiZonesController.text,
      'hasExistingWifi': hasExistingWifi,
      'hasExistingSwitch': hasExistingSwitch,
      'hasPoePorts': hasPoePorts,
      'switchModel': switchModelController.text,

      // Save the endpoint lists
      'tpvList': tpvList.map((e) => e.toMap()).toList(),
      'printerList': printerList.map((e) => e.toMap()).toList(),
      'kioskList': kioskList.map((e) => e.toMap()).toList(),
      'screenList': screenList.map((e) => e.toMap()).toList(),

      'clientDeviceList': clientDeviceList.map((e) => e.toMap()).toList(),

      // ✅ REMOVED: 'photos' key. Will be added in _saveEvaluation
      'evaluatedAt': DateTime.now(),
    };
  }
}