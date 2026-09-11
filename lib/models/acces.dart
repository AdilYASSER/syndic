// lib/models/acces.dart
import 'package:cloud_firestore/cloud_firestore.dart'; // ⬅️ AJOUT

class Acces {
  final String? id;
  final String numAppartement;
  final String role;
  final DateTime dateAcces;
  final String? ipAdresse;
  final String? navigateur;

  Acces({
    this.id,
    required this.numAppartement,
    required this.role,
    required this.dateAcces,
    this.ipAdresse,
    this.navigateur,
  });

  Map<String, dynamic> toMap() {
    return {
      'numAppartement': numAppartement,
      'role': role,
      'dateAcces': dateAcces.millisecondsSinceEpoch,
      'ipAdresse': ipAdresse,
      'navigateur': navigateur,
    };
  }

  factory Acces.fromMap(Map<String, dynamic> map) {
    return Acces(
      id: map['id'],
      numAppartement: map['numAppartement'] ?? '',
      role: map['role'] ?? 'client',
      dateAcces: DateTime.fromMillisecondsSinceEpoch(map['dateAcces']),
      ipAdresse: map['ipAdresse'],
      navigateur: map['navigateur'],
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'numAppartement': numAppartement,
      'role': role,
      'dateAcces': FieldValue.serverTimestamp(), // ✅ Maintenant FieldValue est accessible
      'ipAdresse': ipAdresse,
      'navigateur': navigateur,
    };
  }

  factory Acces.fromFirestore(Map<String, dynamic> map, String id) {
    return Acces(
      id: id,
      numAppartement: map['numAppartement'] ?? '',
      role: map['role'] ?? 'client',
      dateAcces: (map['dateAcces'] as Timestamp?)?.toDate() ?? DateTime.now(), // ✅ Timestamp est accessible
      ipAdresse: map['ipAdresse'],
      navigateur: map['navigateur'],
    );
  }
}