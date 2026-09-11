// lib/models/categorie.dart
class Categorie {
  final String nom;
  final List<SousCategorie> sousCategories;

  Categorie({
    required this.nom,
    required this.sousCategories,
  });

  factory Categorie.fromFirestore(Map<String, dynamic> data, String documentId) {
    final sousCategoriesData = List<Map<String, dynamic>>.from(data['sousCategories'] ?? []);
    final sousCategories = sousCategoriesData.map((s) => SousCategorie.fromFirestore(s)).toList();

    return Categorie(
      nom: documentId,
      sousCategories: sousCategories,
    );
  }
}

class SousCategorie {
  final String nom;
  final List<String> personnes;

  SousCategorie({
    required this.nom,
    this.personnes = const [],
  });

  factory SousCategorie.fromFirestore(Map<String, dynamic> data) {
    return SousCategorie(
      nom: data['nom'] ?? '',
      personnes: List<String>.from(data['personnes'] ?? []),
    );
  }
}