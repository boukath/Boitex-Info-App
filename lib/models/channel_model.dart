import 'package:cloud_firestore/cloud_firestore.dart';

class ChannelModel {
  final String id;
  final String name;
  final String? description; // Optional description

  ChannelModel({
    required this.id,
    required this.name,
    this.description,
  });

  // Factory constructor to create a ChannelModel from a Firestore document
  factory ChannelModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return ChannelModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
    );
  }
}