// lib/models/habitant.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Habitant {
  String? id; // ✅ CHANGÉ en String pour accepter les IDs Firestore
  String nom;
  String prenom;
  String numAppartement;
  String telephone;
  String statut; // 'proprietaire' ou 'locataire'
  String rib;
  String? cinPath;
  String? cinUrl;
  String cin;
  String? locataireNom;
  String? locatairePrenom;
  String? locataireTelephone;
  String? locataireCin;
  String? locataireEmail;
  String? locataireAdresse;
  DateTime dateCreation;
  int synced;

  Habitant({
    this.id,
    required this.nom,
    required this.prenom,
    required this.numAppartement,
    required this.telephone,
    required this.statut,
    required this.rib,
    this.cinPath,
    this.cinUrl,
    this.cin = '',
    this.locataireNom,
    this.locatairePrenom,
    this.locataireTelephone,
    this.locataireCin,
    this.locataireEmail,
    this.locataireAdresse,
    DateTime? dateCreation,
    this.synced = 0,
  }) : dateCreation = dateCreation ?? DateTime.now();

  // Conversion en Map pour SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'prenom': prenom,
      'numAppartement': numAppartement,
      'telephone': telephone,
      'statut': statut,
      'rib': rib,
      'cinPath': cinPath,
      'cinUrl': cinUrl,
      'cin': cin,
      'locataireNom': locataireNom,
      'locatairePrenom': locatairePrenom,
      'locataireTelephone': locataireTelephone,
      'locataireCin': locataireCin,
      'locataireEmail': locataireEmail,
      'locataireAdresse': locataireAdresse,
      'dateCreation': dateCreation.millisecondsSinceEpoch,
      'synced': synced,
    };
  }

  // Depuis Map SQLite
  factory Habitant.fromMap(Map<String, dynamic> map) {
    return Habitant(
      id: map['id']?.toString(),
      nom: map['nom'] ?? '',
      prenom: map['prenom'] ?? '',
      numAppartement: map['numAppartement'] ?? '',
      telephone: map['telephone'] ?? '',
      statut: map['statut'] ?? 'proprietaire',
      rib: map['rib'] ?? '',
      cinPath: map['cinPath'],
      cinUrl: map['cinUrl'],
      cin: map['cin'] ?? '',
      locataireNom: map['locataireNom'],
      locatairePrenom: map['locatairePrenom'],
      locataireTelephone: map['locataireTelephone'],
      locataireCin: map['locataireCin'],
      locataireEmail: map['locataireEmail'],
      locataireAdresse: map['locataireAdresse'],
      dateCreation: DateTime.fromMillisecondsSinceEpoch(map['dateCreation'] ?? DateTime.now().millisecondsSinceEpoch),
      synced: map['synced'] ?? 0,
    );
  }

  // Conversion pour Firestore
  Map<String, dynamic> toFirestoreMap() {
    return {
      'nom': nom,
      'prenom': prenom,
      'numAppartement': numAppartement,
      'telephone': telephone,
      'statut': statut,
      'rib': rib,
      'cinUrl': cinUrl,
      'cin': cin,
      'locataireNom': locataireNom,
      'locatairePrenom': locatairePrenom,
      'locataireTelephone': locataireTelephone,
      'locataireCin': locataireCin,
      'locataireEmail': locataireEmail,
      'locataireAdresse': locataireAdresse,
      'synced': 1,
    };
  }

  // Depuis Firestore
  factory Habitant.fromFirestore(Map<String, dynamic> map, String id) {
    return Habitant(
      id: id,
      nom: map['nom'] ?? '',
      prenom: map['prenom'] ?? '',
      numAppartement: map['numAppartement'] ?? '',
      telephone: map['telephone'] ?? '',
      statut: map['statut'] ?? 'proprietaire',
      rib: map['rib'] ?? '',
      cinUrl: map['cinUrl'],
      cin: map['cin'] ?? '',
      locataireNom: map['locataireNom'],
      locatairePrenom: map['locatairePrenom'],
      locataireTelephone: map['locataireTelephone'],
      locataireCin: map['locataireCin'],
      locataireEmail: map['locataireEmail'],
      locataireAdresse: map['locataireAdresse'],
      dateCreation: DateTime.now(),
      synced: map['synced'] ?? 1,
    );
  }

  // CopyWith
  Habitant copyWith({
    String? id,
    String? nom,
    String? prenom,
    String? numAppartement,
    String? telephone,
    String? statut,
    String? rib,
    String? cinPath,
    String? cinUrl,
    String? cin,
    String? locataireNom,
    String? locatairePrenom,
    String? locataireTelephone,
    String? locataireCin,
    String? locataireEmail,
    String? locataireAdresse,
    DateTime? dateCreation,
    int? synced,
  }) {
    return Habitant(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      numAppartement: numAppartement ?? this.numAppartement,
      telephone: telephone ?? this.telephone,
      statut: statut ?? this.statut,
      rib: rib ?? this.rib,
      cinPath: cinPath ?? this.cinPath,
      cinUrl: cinUrl ?? this.cinUrl,
      cin: cin ?? this.cin,
      locataireNom: locataireNom ?? this.locataireNom,
      locatairePrenom: locatairePrenom ?? this.locatairePrenom,
      locataireTelephone: locataireTelephone ?? this.locataireTelephone,
      locataireCin: locataireCin ?? this.locataireCin,
      locataireEmail: locataireEmail ?? this.locataireEmail,
      locataireAdresse: locataireAdresse ?? this.locataireAdresse,
      dateCreation: dateCreation ?? this.dateCreation,
      synced: synced ?? this.synced,
    );
  }

  // Getters
  String get nomComplet => '$prenom $nom';
  
  String get locataireNomComplet {
    if (locatairePrenom != null && locataireNom != null) {
      return '$locatairePrenom $locataireNom';
    }
    return 'Non renseigné';
  }

  bool get estProprietaire => statut == 'proprietaire';
  bool get estLocataire => statut == 'locataire';
  String get statutTexte => statut == 'proprietaire' ? 'Propriétaire' : 'Locataire';
}