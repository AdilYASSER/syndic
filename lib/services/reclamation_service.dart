// lib/services/reclamation_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reclamation_model.dart';

class ReclamationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ CRÉER UNE RÉCLAMATION
  Future<void> createReclamation(ReclamationModel reclamation) async {
    try {
      await _firestore.collection('reclamations').add(reclamation.toMap());
      print('✅ Réclamation créée avec succès');
    } catch (e) {
      print('❌ Erreur création réclamation: $e');
      throw Exception('Erreur création réclamation: $e');
    }
  }

  // ✅ RÉCUPÉRER TOUTES LES RÉCLAMATIONS
  Future<List<ReclamationModel>> getAllReclamations() async {
    try {
      final snapshot = await _firestore
          .collection('reclamations')
          .orderBy('dateCreation', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        return ReclamationModel.fromFirestore(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      print('❌ Erreur récupération réclamations: $e');
      throw Exception('Erreur récupération réclamations: $e');
    }
  }

  // ✅ RÉCUPÉRER LES RÉCLAMATIONS D'UN APPARTEMENT
  Future<List<ReclamationModel>> getReclamationsByAppartement(String appartement) async {
    try {
      final snapshot = await _firestore
          .collection('reclamations')
          .where('appartement', isEqualTo: appartement)
          .orderBy('dateCreation', descending: true)
          .get();
      
      final List<ReclamationModel> list = [];
      for (var doc in snapshot.docs) {
        list.add(ReclamationModel.fromFirestore(doc.data(), doc.id));
      }
      return list;
    } catch (e) {
      print('❌ Erreur récupération réclamations par appartement: $e');
      throw Exception('Erreur récupération réclamations par appartement: $e');
    }
  }

  // ✅ RÉCUPÉRER LES RÉCLAMATIONS D'UN UTILISATEUR
  Future<List<ReclamationModel>> getReclamationsByUser(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('reclamations')
          .where('utilisateurId', isEqualTo: userId)
          .orderBy('dateCreation', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        return ReclamationModel.fromFirestore(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      print('❌ Erreur récupération réclamations par utilisateur: $e');
      throw Exception('Erreur récupération réclamations par utilisateur: $e');
    }
  }

  // ✅ RÉCUPÉRER UNE RÉCLAMATION PAR ID
  Future<ReclamationModel?> getReclamationById(String id) async {
    try {
      final doc = await _firestore.collection('reclamations').doc(id).get();
      if (doc.exists) {
        return ReclamationModel.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('❌ Erreur récupération réclamation par ID: $e');
      throw Exception('Erreur récupération réclamation par ID: $e');
    }
  }

  // ✅ METTRE À JOUR UNE RÉCLAMATION
  Future<void> updateReclamation(String id, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('reclamations').doc(id).update(data);
      print('✅ Réclamation mise à jour avec succès');
    } catch (e) {
      print('❌ Erreur mise à jour réclamation: $e');
      throw Exception('Erreur mise à jour réclamation: $e');
    }
  }

  // ✅ SUPPRIMER UNE RÉCLAMATION
  Future<void> deleteReclamation(String id) async {
    try {
      await _firestore.collection('reclamations').doc(id).delete();
      print('✅ Réclamation supprimée avec succès');
    } catch (e) {
      print('❌ Erreur suppression réclamation: $e');
      throw Exception('Erreur suppression réclamation: $e');
    }
  }

  // ✅ RÉPONDRE À UNE RÉCLAMATION
  Future<void> repondreReclamation(String id, String reponse) async {
    try {
      await _firestore.collection('reclamations').doc(id).update({
        'reponseAdmin': reponse,
        'dateReponse': Timestamp.now(),
        'statut': 'en_cours',
      });
      print('✅ Réponse ajoutée avec succès');
    } catch (e) {
      print('❌ Erreur réponse réclamation: $e');
      throw Exception('Erreur réponse réclamation: $e');
    }
  }

  // ✅ RÉSOUDRE UNE RÉCLAMATION
  Future<void> resoudreReclamation(String id) async {
    try {
      await _firestore.collection('reclamations').doc(id).update({
        'statut': 'resolue',
        'dateResolution': Timestamp.now(),
      });
      print('✅ Réclamation résolue avec succès');
    } catch (e) {
      print('❌ Erreur résolution réclamation: $e');
      throw Exception('Erreur résolution réclamation: $e');
    }
  }
}