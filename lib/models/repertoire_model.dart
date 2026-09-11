// lib/models/repertoire_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// 👤 PERSONNE
// ============================================================
class Personne {
  final String id;
  final String nom;
  final String prenom;
  final String telephone;
  final String adresse;
  final int satisfaits;
  final int insatisfaits;
  final List<String> commentaires;
  final String sousCategorie;
  final String categorie;
  final DateTime dateAjout;
  final String ajoutePar;

  Personne({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.telephone,
    required this.adresse,
    this.satisfaits = 0,
    this.insatisfaits = 0,
    this.commentaires = const [],
    required this.sousCategorie,
    required this.categorie,
    required this.dateAjout,
    required this.ajoutePar,
  });

  double get tauxSatisfaction {
    final total = satisfaits + insatisfaits;
    if (total == 0) return 0.0;
    return (satisfaits / total) * 100;
  }

  String get nomComplet => '$prenom $nom';

  Map<String, dynamic> toJson() => {
    'id': id,
    'nom': nom,
    'prenom': prenom,
    'telephone': telephone,
    'adresse': adresse,
    'satisfaits': satisfaits,
    'insatisfaits': insatisfaits,
    'commentaires': commentaires,
    'sousCategorie': sousCategorie,
    'categorie': categorie,
    'dateAjout': FieldValue.serverTimestamp(),
    'ajoutePar': ajoutePar,
  };

  factory Personne.fromJson(Map<String, dynamic> json) {
    return Personne(
      id: json['id'] ?? '',
      nom: json['nom'] ?? '',
      prenom: json['prenom'] ?? '',
      telephone: json['telephone'] ?? '',
      adresse: json['adresse'] ?? '',
      satisfaits: (json['satisfaits'] as num?)?.toInt() ?? 0,
      insatisfaits: (json['insatisfaits'] as num?)?.toInt() ?? 0,
      commentaires: List<String>.from(json['commentaires'] ?? []),
      sousCategorie: json['sousCategorie'] ?? '',
      categorie: json['categorie'] ?? '',
      dateAjout: (json['dateAjout'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ajoutePar: json['ajoutePar'] ?? 'admin',
    );
  }

  factory Personne.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Personne(
      id: doc.id,
      nom: data['nom'] ?? '',
      prenom: data['prenom'] ?? '',
      telephone: data['telephone'] ?? '',
      adresse: data['adresse'] ?? '',
      satisfaits: (data['satisfaits'] as num?)?.toInt() ?? 0,
      insatisfaits: (data['insatisfaits'] as num?)?.toInt() ?? 0,
      commentaires: List<String>.from(data['commentaires'] ?? []),
      sousCategorie: data['sousCategorie'] ?? '',
      categorie: data['categorie'] ?? '',
      dateAjout: (data['dateAjout'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ajoutePar: data['ajoutePar'] ?? 'admin',
    );
  }
}

// ============================================================
// 📁 SOUS-CATÉGORIE
// ============================================================
class SousCategorie {
  final String nom;
  final List<String> personnes;  // IDs des personnes

  SousCategorie({
    required this.nom,
    this.personnes = const [],
  });

  Map<String, dynamic> toJson() => {
    'nom': nom,
    'personnes': personnes,
  };

  factory SousCategorie.fromJson(Map<String, dynamic> json) {
    return SousCategorie(
      nom: json['nom'] ?? '',
      personnes: List<String>.from(json['personnes'] ?? []),
    );
  }

  factory SousCategorie.fromFirestore(Map<String, dynamic> data) {
    return SousCategorie(
      nom: data['nom'] ?? '',
      personnes: List<String>.from(data['personnes'] ?? []),
    );
  }
}

// ============================================================
// 📂 CATÉGORIE
// ============================================================
class Categorie {
  final String nom;
  final List<SousCategorie> sousCategories;

  Categorie({
    required this.nom,
    this.sousCategories = const [],
  });

  Map<String, dynamic> toJson() => {
    'nom': nom,
    'sousCategories': sousCategories.map((s) => s.toJson()).toList(),
  };

  factory Categorie.fromJson(Map<String, dynamic> json) {
    return Categorie(
      nom: json['nom'] ?? '',
      sousCategories: (json['sousCategories'] as List?)
          ?.map((s) => SousCategorie.fromJson(s))
          .toList() ?? [],
    );
  }

  factory Categorie.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final sousCategoriesData = List<Map<String, dynamic>>.from(data['sousCategories'] ?? []);
    final sousCategories = sousCategoriesData.map((s) => SousCategorie.fromJson(s)).toList();
    
    return Categorie(
      nom: doc.id,
      sousCategories: sousCategories,
    );
  }
}