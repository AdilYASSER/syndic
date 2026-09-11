// lib/services/demande_aide_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/demande_aide_model.dart';

class DemandeAideService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'demandes_aide';

  // ✅ Créer une demande
  Future<String> ajouterDemande(DemandeAideModel demande) async {
    final docRef =
        await _firestore.collection(_collection).add(demande.toJson());
    return docRef.id;
  }

  // ✅ Toutes les demandes (admin + client)
  Stream<List<DemandeAideModel>> getAllDemandes() {
    return _firestore
        .collection(_collection)
        .orderBy('dateCreation', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => DemandeAideModel.fromFirestore(doc))
            .toList());
  }

  // ✅ Mettre à jour (statut + réponse)
  Future<void> updateDemande(
    String id, {
    String? statut,
    String? reponse,
    String? objet,
    String? description,
    String? urgence,
  }) async {
    final data = <String, dynamic>{};
    if (statut != null) data['statut'] = statut;
    if (reponse != null) {
      data['reponse'] = reponse;
      data['dateReponse'] = Timestamp.now();
    }
    if (objet != null) data['objet'] = objet;
    if (description != null) data['description'] = description;
    if (urgence != null) data['urgence'] = urgence;

    if (data.isEmpty) return;
    await _firestore.collection(_collection).doc(id).update(data);
  }

  // ✅ Supprimer
  Future<void> supprimerDemande(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  // ✅ Marquer comme LU par un utilisateur (ajoute userId dans luPar)
  Future<void> marquerCommeLu(String id, String userId) async {
    await _firestore.collection(_collection).doc(id).update({
      'luPar': FieldValue.arrayUnion([userId]),
    });
  }

  // ✅ Compter les non-lues pour un user
  Future<int> countNonLues(String userId) async {
    final snap = await _firestore.collection(_collection).get();
    return snap.docs.where((d) {
      final data = d.data();
      final lu = List<String>.from(data['luPar'] ?? []);
      return !lu.contains(userId);
    }).length;
  }
}