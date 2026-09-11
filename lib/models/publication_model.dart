// lib/models/publication_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class PublicationModel {
  final String id;
  final String titre;
  final String message;
  final String? imageUrl;
  final DateTime datePublication;
  final DateTime createdAt;
  final String createdBy;

  PublicationModel({
    required this.id,
    required this.titre,
    required this.message,
    this.imageUrl,
    required this.datePublication,
    required this.createdAt,
    required this.createdBy,
  });

  // ✅ Existant
  Map<String, dynamic> toMap() {
    return {
      'titre': titre,
      'message': message,
      'imageUrl': imageUrl,
      'datePublication': Timestamp.fromDate(datePublication),
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  // ✅ Existant
  factory PublicationModel.fromMap(String id, Map<String, dynamic> map) {
    return PublicationModel(
      id: id,
      titre: map['titre'] ?? 'Sans titre',
      message: map['message'] ?? '',
      imageUrl: map['imageUrl'],
      datePublication: (map['datePublication'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] ?? 'admin',
    );
  }

  // ✅ NOUVEAU : alias pour le service (fromFirestore)
  factory PublicationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PublicationModel.fromMap(doc.id, data);
  }

  // ✅ NOUVEAU : alias pour le service (toJson → toMap)
  Map<String, dynamic> toJson() => toMap();
}