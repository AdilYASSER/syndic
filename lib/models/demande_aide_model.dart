// lib/models/demande_aide_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class DemandeAideModel {
  final String id;
  final String objet;
  final String description;
  final String urgence; // 'faible' | 'moyenne' | 'eleve' | 'critique'
  final String appartement;
  final String nomPrenom;
  final String telephone;
  final String createdBy;
  final DateTime dateCreation;
  final String statut; // 'en_attente' | 'en_cours' | 'resolu'
  final String? reponse;
  final DateTime? dateReponse;
  final List<String> luPar;

  DemandeAideModel({
    required this.id,
    required this.objet,
    required this.description,
    required this.urgence,
    required this.appartement,
    required this.nomPrenom,
    required this.telephone,
    required this.createdBy,
    required this.dateCreation,
    this.statut = 'en_attente',
    this.reponse,
    this.dateReponse,
    this.luPar = const [],
  });

  String get urgenceLabel {
    switch (urgence) {
      case 'critique':
        return '🚨 CRITIQUE';
      case 'eleve':
        return '🔴 Élevé';
      case 'moyenne':
        return '🟠 Moyenne';
      default:
        return '🟢 Faible';
    }
  }

  String get statutLabel {
    switch (statut) {
      case 'en_cours':
        return '⏳ En cours';
      case 'resolu':
        return '✅ Résolu';
      default:
        return '📩 En attente';
    }
  }

  Map<String, dynamic> toJson() => {
        'objet': objet,
        'description': description,
        'urgence': urgence,
        'appartement': appartement,
        'nomPrenom': nomPrenom,
        'telephone': telephone,
        'createdBy': createdBy,
        'dateCreation': Timestamp.fromDate(dateCreation),
        'statut': statut,
        'reponse': reponse,
        'dateReponse':
            dateReponse != null ? Timestamp.fromDate(dateReponse!) : null,
        'luPar': luPar,
      };

  factory DemandeAideModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DemandeAideModel(
      id: doc.id,
      objet: data['objet'] ?? '',
      description: data['description'] ?? '',
      urgence: data['urgence'] ?? 'faible',
      appartement: data['appartement'] ?? '',
      nomPrenom: data['nomPrenom'] ?? '',
      telephone: data['telephone'] ?? '',
      createdBy: data['createdBy'] ?? '',
      dateCreation:
          (data['dateCreation'] as Timestamp?)?.toDate() ?? DateTime.now(),
      statut: data['statut'] ?? 'en_attente',
      reponse: data['reponse'],
      dateReponse: (data['dateReponse'] as Timestamp?)?.toDate(),
      luPar: List<String>.from(data['luPar'] ?? []),
    );
  }
}