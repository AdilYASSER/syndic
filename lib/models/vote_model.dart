// lib/models/vote_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VoteModel {
  final String id;
  final String titre;
  final String description;
  final List<String> options;
  final Map<String, List<String>> votes;
  final DateTime dateDebut;
  final DateTime dateFin;
  final String statut;
  final String createdBy;
  final DateTime createdAt;
  final int totalVotes;

  VoteModel({
    required this.id,
    required this.titre,
    required this.description,
    required this.options,
    this.votes = const {},
    required this.dateDebut,
    required this.dateFin,
    required this.statut,
    required this.createdBy,
    required this.createdAt,
    this.totalVotes = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'titre': titre,
      'description': description,
      'options': options,
      'votes': votes,
      'dateDebut': Timestamp.fromDate(dateDebut),
      'dateFin': Timestamp.fromDate(dateFin),
      'statut': statut,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'totalVotes': totalVotes,
    };
  }

  factory VoteModel.fromMap(String id, Map<String, dynamic> map) {
    final optionsData = map['options'];
    List<String> optionsList = [];
    if (optionsData is List) {
      optionsList = optionsData.map((e) => e.toString()).toList();
    }

    final votesData = map['votes'];
    Map<String, List<String>> votesMap = {};
    if (votesData is Map) {
      votesData.forEach((key, value) {
        if (value is List) {
          votesMap[key.toString()] = value.map((e) => e.toString()).toList();
        } else {
          votesMap[key.toString()] = [];
        }
      });
    }

    return VoteModel(
      id: id,
      titre: map['titre']?.toString() ?? 'Sans titre',
      description: map['description']?.toString() ?? '',
      options: optionsList,
      votes: votesMap,
      dateDebut: (map['dateDebut'] as Timestamp).toDate(),
      dateFin: (map['dateFin'] as Timestamp).toDate(),
      // ✅ CORRECTION ICI : Utilisation de la fonction de normalisation
      statut: _normalizeStatut(map['statut']?.toString() ?? 'a_venir'),
      createdBy: map['createdBy']?.toString() ?? 'admin',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalVotes: (map['totalVotes'] as num?)?.toInt() ?? 0,
    );
  }

  // ✅ NOUVELLE FONCTION DE NORMALISATION
  static String _normalizeStatut(String rawStatut) {
    // Si c'est "En cours" (avec ou sans majuscule), on le transforme en "en_cours"
    if (rawStatut.toLowerCase() == 'en cours') return 'en_cours';
    // Si c'est "Terminé", on le transforme en "termine"
    if (rawStatut.toLowerCase() == 'terminé') return 'termine';
    // Sinon, on garde la valeur telle quelle (pour "a_venir", etc.)
    return rawStatut;
  }

  List<String> getVotersForOption(String option) {
    return votes[option] ?? [];
  }

  Map<String, String> getAllVotersWithChoice() {
    final Map<String, String> result = {};
    for (var option in options) {
      final voters = votes[option] ?? [];
      for (var voter in voters) {
        result[voter] = option;
      }
    }
    return result;
  }

  Map<String, double> getPourcentages() {
    if (totalVotes == 0) return {};
    final Map<String, double> result = {};
    for (var option in options) {
      final count = votes[option]?.length ?? 0;
      result[option] = (count / totalVotes) * 100;
    }
    return result;
  }

  int getVotesCount(String option) {
    return votes[option]?.length ?? 0;
  }

  bool hasVoted(String appartement) {
    for (var option in options) {
      if (votes[option]?.contains(appartement) ?? false) {
        return true;
      }
    }
    return false;
  }

  String? getVotedOption(String appartement) {
    for (var option in options) {
      if (votes[option]?.contains(appartement) ?? false) {
        return option;
      }
    }
    return null;
  }

  bool get isTermine => statut == 'termine';
  bool get isEnCours => statut == 'en_cours';
  bool get isAVenir => statut == 'a_venir';

  String get statutText {
    switch (statut) {
      case 'en_cours':
        return '🔄 En cours';
      case 'termine':
        return '✅ Terminé';
      case 'a_venir':
        return '⏳ À venir';
      default:
        return statut;
    }
  }

  Color get statutColor {
    switch (statut) {
      case 'en_cours':
        return Colors.green;
      case 'termine':
        return Colors.blue;
      case 'a_venir':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}