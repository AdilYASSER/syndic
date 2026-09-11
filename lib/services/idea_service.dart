// lib/services/idea_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/idea_model.dart';

class IdeaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String COLLECTION = 'ideas';

  // ✅ Créer une idée (Admin ou Client)
  Future<void> createIdea(IdeaModel idea) async {
    try {
      await _firestore.collection(COLLECTION).add(idea.toMap());
    } catch (e) {
      print('❌ Erreur création idée: $e');
      rethrow;
    }
  }

  // ✅ Récupérer toutes les idées
  Stream<List<IdeaModel>> getAllIdeas() {
    return _firestore
        .collection(COLLECTION)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return IdeaModel.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  // ✅ Supprimer une idée (Admin)
  Future<void> deleteIdea(String id) async {
    try {
      await _firestore.collection(COLLECTION).doc(id).delete();
    } catch (e) {
      print('❌ Erreur suppression idée: $e');
      rethrow;
    }
  }

  // ✅ Supprimer TOUTES les idées (Admin)
  Future<void> deleteAllIdeas() async {
    try {
      final snapshot = await _firestore.collection(COLLECTION).get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
      print('✅ Toutes les idées supprimées');
    } catch (e) {
      print('❌ Erreur suppression toutes les idées: $e');
      rethrow;
    }
  }
}