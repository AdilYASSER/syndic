// lib/models/idea_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class IdeaModel {
  final String id;
  final String numAppart;
  final DateTime date;
  final String ideeProposee;
  final String budgetPrevisionnel;
  final DateTime createdAt; // Supprimé echeanceExecution

  IdeaModel({
    required this.id,
    required this.numAppart,
    required this.date,
    required this.ideeProposee,
    required this.budgetPrevisionnel,
    required this.createdAt, // Supprimé echeanceExecution
  });

  Map<String, dynamic> toMap() {
    return {
      'numAppart': numAppart,
      'date': Timestamp.fromDate(date),
      'ideeProposee': ideeProposee,
      'budgetPrevisionnel': budgetPrevisionnel,
      'createdAt': Timestamp.fromDate(createdAt),
      // Supprimé 'echeanceExecution': Timestamp.fromDate(echeanceExecution),
    };
  }

  factory IdeaModel.fromMap(String id, Map<String, dynamic> map) {
    return IdeaModel(
      id: id,
      numAppart: map['numAppart'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      ideeProposee: map['ideeProposee'] ?? '',
      budgetPrevisionnel: map['budgetPrevisionnel'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      // Supprimé echeanceExecution: (map['echeanceExecution'] as Timestamp).toDate(),
    );
  }
}