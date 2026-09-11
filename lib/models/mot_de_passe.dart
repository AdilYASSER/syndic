// lib/models/mot_de_passe.dart
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ AJOUTÉ

class MotDePasse {
  final String? id;
  final String numAppartement;   // ex: "A1", "B5", "C12"
  final String codeInitial;      // code attribué (1001, 1002, ...)
  final String motDePasseActuel; // mot de passe actuel (avec préfixe)
  final bool aChange;            // true si déjà changé
  final DateTime? dateChangement;
  final DateTime dateCreation;

  MotDePasse({
    this.id,
    required this.numAppartement,
    required this.codeInitial,
    required this.motDePasseActuel,
    this.aChange = false,
    this.dateChangement,
    DateTime? dateCreation,
  }) : dateCreation = dateCreation ?? DateTime.now();

  Map<String, dynamic> toFirestoreMap() {
    return {
      'numAppartement': numAppartement,
      'codeInitial': codeInitial,
      'motDePasseActuel': motDePasseActuel,
      'aChange': aChange,
      'dateChangement': dateChangement != null ? FieldValue.serverTimestamp() : null,
      'dateCreation': FieldValue.serverTimestamp(),
    };
  }

  factory MotDePasse.fromFirestore(Map<String, dynamic> map, String id) {
    return MotDePasse(
      id: id,
      numAppartement: map['numAppartement'] ?? '',
      codeInitial: map['codeInitial'] ?? '',
      motDePasseActuel: map['motDePasseActuel'] ?? '',
      aChange: map['aChange'] ?? false,
      dateChangement: (map['dateChangement'] as Timestamp?)?.toDate(),
      dateCreation: (map['dateCreation'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}