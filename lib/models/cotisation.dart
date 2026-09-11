// lib/models/cotisation.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Cotisation {
  String? id;
  String numAppartement;
  String nomPrenom;
  DateTime? dateVersement;
  String modeVersement;
  double montant;
  bool periode1;
  bool periode2;
  int annee;
  int synced;
  String? justificatifUrl;
  String? statut;
  DateTime? dateCreation;
  String? appartement;

  Cotisation({
    this.id,
    required this.numAppartement,
    required this.nomPrenom,
    this.dateVersement,
    required this.modeVersement,
    required this.montant,
    required this.periode1,
    required this.periode2,
    required this.annee,
    required this.synced,
    this.justificatifUrl,
    this.statut,
    this.dateCreation,
    this.appartement,
  });

  // ✅ Conversion vers Map pour Firestore
  Map<String, dynamic> toFirestoreMap() {
    final map = <String, dynamic>{
      'numAppartement': numAppartement,
      'nomPrenom': nomPrenom,
      'modeVersement': modeVersement,
      'montant': montant,
      'periode1': periode1,
      'periode2': periode2,
      'annee': annee,
      'statut': statut ?? 'En attente',
    };

    if (dateVersement != null) {
      map['dateVersement'] = Timestamp.fromDate(dateVersement!);
    }

    if (dateCreation != null) {
      map['dateCreation'] = Timestamp.fromDate(dateCreation!);
    }

    if (justificatifUrl != null && justificatifUrl!.isNotEmpty) {
      map['justificatifUrl'] = justificatifUrl;
    }
    if (appartement != null && appartement!.isNotEmpty) {
      map['appartement'] = appartement;
    }
    if (synced != 0) {
      map['synced'] = synced;
    }

    return map;
  }

  // ✅ Conversion depuis Map (Firestore)
  factory Cotisation.fromFirestore(Map<String, dynamic> data, String id) {
    DateTime? parseDate(dynamic dateValue) {
      if (dateValue == null) return null;
      if (dateValue is Timestamp) {
        return dateValue.toDate();
      } else if (dateValue is DateTime) {
        return dateValue;
      } else if (dateValue is String) {
        try {
          return DateTime.parse(dateValue);
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    double parseMontant(dynamic value) {
      if (value == null) return 0.0;
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    bool parseBool(dynamic value) {
      if (value == null) return false;
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) return value.toLowerCase() == 'true';
      return false;
    }

    int parseInt(dynamic value) {
      if (value == null) return DateTime.now().year;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? DateTime.now().year;
      return DateTime.now().year;
    }

    return Cotisation(
      id: id,
      numAppartement: data['numAppartement']?.toString() ?? '',
      appartement: data['appartement']?.toString() ?? data['numAppartement']?.toString() ?? '',
      nomPrenom: data['nomPrenom']?.toString() ?? '',
      dateVersement: parseDate(data['dateVersement']),
      modeVersement: data['modeVersement']?.toString() ?? 'espece',
      montant: parseMontant(data['montant']),
      periode1: parseBool(data['periode1']),
      periode2: parseBool(data['periode2']),
      annee: parseInt(data['annee']),
      synced: data['synced'] is int ? data['synced'] : 0,
      justificatifUrl: data['justificatifUrl']?.toString(),
      statut: data['statut']?.toString() ?? 'En attente',
      dateCreation: parseDate(data['dateCreation']),
    );
  }

  // ✅ Conversion depuis Map (pour SQLite)
  factory Cotisation.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return null;
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        return null;
      }
    }

    return Cotisation(
      id: map['id']?.toString(),
      numAppartement: map['numAppartement']?.toString() ?? '',
      appartement: map['appartement']?.toString() ?? map['numAppartement']?.toString() ?? '',
      nomPrenom: map['nomPrenom']?.toString() ?? '',
      dateVersement: parseDate(map['dateVersement']),
      modeVersement: map['modeVersement']?.toString() ?? 'espece',
      montant: (map['montant'] ?? 0).toDouble(),
      periode1: map['periode1'] == 1 || map['periode1'] == true,
      periode2: map['periode2'] == 1 || map['periode2'] == true,
      annee: map['annee'] ?? DateTime.now().year,
      synced: map['synced'] ?? 0,
      justificatifUrl: map['justificatifUrl']?.toString(),
      statut: map['statut']?.toString() ?? 'En attente',
      dateCreation: parseDate(map['dateCreation']),
    );
  }

  // ✅ Conversion vers Map (pour SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'numAppartement': numAppartement,
      'appartement': appartement ?? numAppartement,
      'nomPrenom': nomPrenom,
      'dateVersement': dateVersement?.toIso8601String(),
      'modeVersement': modeVersement,
      'montant': montant,
      'periode1': periode1 ? 1 : 0,
      'periode2': periode2 ? 1 : 0,
      'annee': annee,
      'synced': synced,
      'justificatifUrl': justificatifUrl,
      'statut': statut,
      'dateCreation': dateCreation?.toIso8601String(),
    };
  }

  // ✅ Copie avec modifications
  Cotisation copyWith({
    String? id,
    String? numAppartement,
    String? nomPrenom,
    DateTime? dateVersement,
    String? modeVersement,
    double? montant,
    bool? periode1,
    bool? periode2,
    int? annee,
    int? synced,
    String? justificatifUrl,
    String? statut,
    DateTime? dateCreation,
    String? appartement,
  }) {
    return Cotisation(
      id: id ?? this.id,
      numAppartement: numAppartement ?? this.numAppartement,
      nomPrenom: nomPrenom ?? this.nomPrenom,
      dateVersement: dateVersement ?? this.dateVersement,
      modeVersement: modeVersement ?? this.modeVersement,
      montant: montant ?? this.montant,
      periode1: periode1 ?? this.periode1,
      periode2: periode2 ?? this.periode2,
      annee: annee ?? this.annee,
      synced: synced ?? this.synced,
      justificatifUrl: justificatifUrl ?? this.justificatifUrl,
      statut: statut ?? this.statut,
      dateCreation: dateCreation ?? this.dateCreation,
      appartement: appartement ?? this.appartement,
    );
  }

  // ✅ Méthodes statiques pour les statuts
  static Color getStatutColor(String statut) {
    switch (statut) {
      case 'Payé':
        return Colors.green;
      case 'En attente':
        return Colors.orange;
      case 'Annulée':
        return Colors.red;
      case 'Impayé':
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }

  static IconData getStatutIcon(String statut) {
    switch (statut) {
      case 'Payé':
        return Icons.check_circle;
      case 'En attente':
        return Icons.pending;
      case 'Annulée':
        return Icons.cancel;
      case 'Impayé':
        return Icons.warning;
      default:
        return Icons.help;
    }
  }

  static List<Map<String, dynamic>> get statutsList {
    return [
      {'value': 'Payé', 'label': '✅ Payé', 'color': Colors.green},
      {'value': 'En attente', 'label': '⏳ En attente', 'color': Colors.orange},
      {'value': 'Annulée', 'label': '❌ Annulée', 'color': Colors.red},
      {'value': 'Impayé', 'label': '⚠️ Impayé', 'color': Colors.red.shade700},
    ];
  }

  static String getStatutLabel(String statut) {
    switch (statut) {
      case 'Payé':
        return '✅ Payé';
      case 'En attente':
        return '⏳ En attente';
      case 'Annulée':
        return '❌ Annulée';
      case 'Impayé':
        return '⚠️ Impayé';
      default:
        return '❓ Inconnu';
    }
  }
}