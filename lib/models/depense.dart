// lib/models/depense.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Depense {
  final String? id;
  final String titre;
  final double montant;
  final DateTime date;
  final String categorie;
  final String? sousCategorie;
  final String beneficiaire;
  final String description;
  final String? justificatifUrl;
  final List<String>? justificatifUrls; // ✅ AJOUTÉ
  final String createdBy;
  final DateTime createdAt;
  final String statut;
  final String modePaiement;
  final String? numeroCheque;

  Depense({
    this.id,
    required this.titre,
    required this.montant,
    required this.date,
    required this.categorie,
    this.sousCategorie,
    required this.beneficiaire,
    this.description = '',
    this.justificatifUrl,
    this.justificatifUrls,
    this.createdBy = 'admin',
    DateTime? createdAt,
    this.statut = 'en_attente',
    this.modePaiement = 'espece',
    this.numeroCheque,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toFirestoreMap() {
    return {
      'titre': titre,
      'montant': montant,
      'date': Timestamp.fromDate(date),
      'categorie': categorie,
      'sousCategorie': sousCategorie,
      'beneficiaire': beneficiaire,
      'description': description,
      'justificatifUrl': justificatifUrl,
      'justificatifUrls': justificatifUrls,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'statut': statut,
      'modePaiement': modePaiement,
      'numeroCheque': numeroCheque,
    };
  }

  factory Depense.fromFirestore(Map<String, dynamic> map, String id) {
    // ✅ Récupérer justificatifUrls si présent
    List<String>? urls;
    if (map['justificatifUrls'] != null) {
      urls = List<String>.from(map['justificatifUrls']);
    }
    
    return Depense(
      id: id,
      titre: map['titre'] ?? '',
      montant: (map['montant'] ?? 0).toDouble(),
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      categorie: map['categorie'] ?? 'Autre',
      sousCategorie: map['sousCategorie'],
      beneficiaire: map['beneficiaire'] ?? '',
      description: map['description'] ?? '',
      justificatifUrl: map['justificatifUrl'],
      justificatifUrls: urls,
      createdBy: map['createdBy'] ?? 'admin',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      statut: map['statut'] ?? 'en_attente',
      modePaiement: map['modePaiement'] ?? 'espece',
      numeroCheque: map['numeroCheque'],
    );
  }

  factory Depense.fromMap(String id, Map<String, dynamic> map) {
    return Depense(
      id: id,
      titre: map['titre'] ?? '',
      montant: (map['montant'] ?? 0).toDouble(),
      date: DateTime.parse(map['date']),
      categorie: map['categorie'] ?? 'Autre',
      sousCategorie: map['sousCategorie'],
      beneficiaire: map['beneficiaire'] ?? '',
      description: map['description'] ?? '',
      justificatifUrl: map['justificatifUrl'],
      justificatifUrls: map['justificatifUrls'] != null 
          ? List<String>.from(map['justificatifUrls']) 
          : null,
      createdBy: map['createdBy'] ?? 'admin',
      createdAt: DateTime.parse(map['createdAt']),
      statut: map['statut'] ?? 'en_attente',
      modePaiement: map['modePaiement'] ?? 'espece',
      numeroCheque: map['numeroCheque'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titre': titre,
      'montant': montant,
      'date': date.toIso8601String(),
      'categorie': categorie,
      'sousCategorie': sousCategorie,
      'beneficiaire': beneficiaire,
      'description': description,
      'justificatifUrl': justificatifUrl,
      'justificatifUrls': justificatifUrls,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'statut': statut,
      'modePaiement': modePaiement,
      'numeroCheque': numeroCheque,
    };
  }

  Depense copyWith({
    String? id,
    String? titre,
    double? montant,
    DateTime? date,
    String? categorie,
    String? sousCategorie,
    String? beneficiaire,
    String? description,
    String? justificatifUrl,
    List<String>? justificatifUrls,
    String? createdBy,
    DateTime? createdAt,
    String? statut,
    String? modePaiement,
    String? numeroCheque,
  }) {
    return Depense(
      id: id ?? this.id,
      titre: titre ?? this.titre,
      montant: montant ?? this.montant,
      date: date ?? this.date,
      categorie: categorie ?? this.categorie,
      sousCategorie: sousCategorie ?? this.sousCategorie,
      beneficiaire: beneficiaire ?? this.beneficiaire,
      description: description ?? this.description,
      justificatifUrl: justificatifUrl ?? this.justificatifUrl,
      justificatifUrls: justificatifUrls ?? this.justificatifUrls,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      statut: statut ?? this.statut,
      modePaiement: modePaiement ?? this.modePaiement,
      numeroCheque: numeroCheque ?? this.numeroCheque,
    );
  }

  @override
  String toString() {
    return 'Depense(id: $id, titre: $titre, montant: $montant, categorie: $categorie)';
  }
}