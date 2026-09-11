// lib/models/reclamation_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // ✅ AJOUT OBLIGATOIRE

class ReclamationModel {
  final String id;
  final String titre;
  final String description;
  final String categorie;
  final String statut;
  final String priorite;
  final String appartement;
  final String utilisateurId;
  final String utilisateurNom;
  final DateTime dateCreation;
  final DateTime? dateResolution;
  final DateTime? dateReponse;
  final String? reponseAdmin;
  final String? photoUrl;
  final String? reponsePhotoUrl;
  final List<String> imageUrls;
  final bool isGhost;

  ReclamationModel({
    required this.id,
    required this.titre,
    required this.description,
    required this.categorie,
    required this.statut,
    required this.priorite,
    required this.appartement,
    required this.utilisateurId,
    required this.utilisateurNom,
    required this.dateCreation,
    this.dateResolution,
    this.dateReponse,
    this.reponseAdmin,
    this.photoUrl,
    this.reponsePhotoUrl,
    this.imageUrls = const [],
    this.isGhost = false,
  });

  // ✅ GETTERS POUR LE STATUT
  Color get statutColor {
    switch (statut) {
      case 'en_attente':
        return Colors.orange;
      case 'en_cours':
        return Colors.blue;
      case 'resolu':
        return Colors.green;
      case 'refuse':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String get statutText {
    switch (statut) {
      case 'en_attente':
        return '⏳ En attente';
      case 'en_cours':
        return '🔄 En cours';
      case 'resolu':
        return '✅ Résolu';
      case 'refuse':
        return '❌ Refusé';
      default:
        return statut;
    }
  }

  // ✅ GETTERS POUR LA PRIORITÉ
  Color get prioriteColor {
    switch (priorite) {
      case 'basse':
        return Colors.green;
      case 'moyenne':
        return Colors.orange;
      case 'haute':
        return Colors.orange.shade700;
      case 'urgente':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String get prioriteText {
    switch (priorite) {
      case 'basse':
        return '🟢 Basse';
      case 'moyenne':
        return '🟡 Moyenne';
      case 'haute':
        return '🟠 Haute';
      case 'urgente':
        return '🔴 Urgente';
      default:
        return priorite;
    }
  }

  factory ReclamationModel.fromFirestore(Map<String, dynamic> data, String id) {
    return ReclamationModel(
      id: id,
      titre: data['titre'] ?? '',
      description: data['description'] ?? '',
      categorie: data['categorie'] ?? 'AUTRE',
      statut: data['statut'] ?? 'en_attente',
      priorite: data['priorite'] ?? 'moyenne',
      appartement: data['appartement'] ?? 'N/A',
      utilisateurId: data['utilisateurId'] ?? '',
      utilisateurNom: data['utilisateurNom'] ?? 'Inconnu',
      dateCreation: (data['dateCreation'] as Timestamp).toDate(),
      dateResolution: data['dateResolution'] != null ? (data['dateResolution'] as Timestamp).toDate() : null,
      dateReponse: data['dateReponse'] != null ? (data['dateReponse'] as Timestamp).toDate() : null,
      reponseAdmin: data['reponseAdmin'],
      photoUrl: data['photoUrl'],
      reponsePhotoUrl: data['reponsePhotoUrl'],
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      isGhost: data['isGhost'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'titre': titre,
      'description': description,
      'categorie': categorie,
      'statut': statut,
      'priorite': priorite,
      'appartement': appartement,
      'utilisateurId': utilisateurId,
      'utilisateurNom': utilisateurNom,
      'dateCreation': Timestamp.fromDate(dateCreation),
      'dateResolution': dateResolution != null ? Timestamp.fromDate(dateResolution!) : null,
      'dateReponse': dateReponse != null ? Timestamp.fromDate(dateReponse!) : null,
      'reponseAdmin': reponseAdmin,
      'photoUrl': photoUrl,
      'reponsePhotoUrl': reponsePhotoUrl,
      'imageUrls': imageUrls,
      'isGhost': isGhost,
    };
  }

  ReclamationModel copyWith({
    String? id,
    String? titre,
    String? description,
    String? categorie,
    String? statut,
    String? priorite,
    String? appartement,
    String? utilisateurId,
    String? utilisateurNom,
    DateTime? dateCreation,
    DateTime? dateResolution,
    DateTime? dateReponse,
    String? reponseAdmin,
    String? photoUrl,
    String? reponsePhotoUrl,
    List<String>? imageUrls,
    bool? isGhost,
  }) {
    return ReclamationModel(
      id: id ?? this.id,
      titre: titre ?? this.titre,
      description: description ?? this.description,
      categorie: categorie ?? this.categorie,
      statut: statut ?? this.statut,
      priorite: priorite ?? this.priorite,
      appartement: appartement ?? this.appartement,
      utilisateurId: utilisateurId ?? this.utilisateurId,
      utilisateurNom: utilisateurNom ?? this.utilisateurNom,
      dateCreation: dateCreation ?? this.dateCreation,
      dateResolution: dateResolution ?? this.dateResolution,
      dateReponse: dateReponse ?? this.dateReponse,
      reponseAdmin: reponseAdmin ?? this.reponseAdmin,
      photoUrl: photoUrl ?? this.photoUrl,
      reponsePhotoUrl: reponsePhotoUrl ?? this.reponsePhotoUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      isGhost: isGhost ?? this.isGhost,
    );
  }
}