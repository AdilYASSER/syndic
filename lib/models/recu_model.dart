// lib/models/recu_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RecuModel {
  final String id;
  final String numAppartement;
  final String nomPrenom;
  final double montant;
  final DateTime dateEmission;
  final int annee;
  final String periode; // 'S1', 'S2', 'S1+S2'
  final String modePaiement; // 'espece', 'virement', 'cheque'
  final String statut; // 'Total', 'Partiel', 'Non payé'
  final double? montantRestant;
  final String? numeroCheque;
  final String cotisationId;
  final String generatedBy;
  final DateTime dateCreation;
  final double montantAttendu;

  RecuModel({
    required this.id,
    required this.numAppartement,
    required this.nomPrenom,
    required this.montant,
    required this.dateEmission,
    required this.annee,
    required this.periode,
    required this.modePaiement,
    required this.statut,
    this.montantRestant,
    this.numeroCheque,
    required this.cotisationId,
    required this.generatedBy,
    required this.dateCreation,
    this.montantAttendu = 1800.0,
  });

  double get pourcentagePaye {
    if (montantAttendu <= 0) return 0;
    return (montant / montantAttendu) * 100;
  }

  String get statutTexte {
    switch (statut) {
      case 'Total': return '✅ Total';
      case 'Partiel': return '⚠️ Partiel';
      case 'Non payé': return '❌ Non payé';
      default: return statut;
    }
  }

  Color get statutCouleur {
    switch (statut) {
      case 'Total': return const Color(0xFF2E7D32);
      case 'Partiel': return const Color(0xFFE65100);
      case 'Non payé': return const Color(0xFFC62828);
      default: return Colors.grey;
    }
  }

  Map<String, dynamic> toJson() => {
    'numAppartement': numAppartement,
    'nomPrenom': nomPrenom,
    'montant': montant,
    'dateEmission': dateEmission.toIso8601String(),
    'annee': annee,
    'periode': periode,
    'modePaiement': modePaiement,
    'statut': statut,
    'montantRestant': montantRestant,
    'numeroCheque': numeroCheque,
    'cotisationId': cotisationId,
    'generatedBy': generatedBy,
    'dateCreation': FieldValue.serverTimestamp(),
    'montantAttendu': montantAttendu,
  };

  factory RecuModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RecuModel(
      id: doc.id,
      numAppartement: data['numAppartement'] ?? '',
      nomPrenom: data['nomPrenom'] ?? '',
      montant: (data['montant'] ?? 0).toDouble(),
      dateEmission: DateTime.parse(data['dateEmission']),
      annee: data['annee'] ?? 0,
      periode: data['periode'] ?? 'S1',
      modePaiement: data['modePaiement'] ?? 'espece',
      statut: data['statut'] ?? 'Partiel',
      montantRestant: (data['montantRestant'] as num?)?.toDouble(),
      numeroCheque: data['numeroCheque'],
      cotisationId: data['cotisationId'] ?? '',
      generatedBy: data['generatedBy'] ?? 'admin',
      dateCreation: (data['dateCreation'] as Timestamp).toDate(),
      montantAttendu: (data['montantAttendu'] as num?)?.toDouble() ?? 1800.0,
    );
  }
}