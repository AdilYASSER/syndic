// lib/services/depense_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/depense.dart';

class DepenseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String COLLECTION = 'depenses';

  // ✅ Récupérer toutes les dépenses
  Future<List<Depense>> getDepenses() async {
    try {
      final snapshot = await _firestore
          .collection(COLLECTION)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return Depense.fromFirestore(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      print('❌ Erreur récupération dépenses: $e');
      return [];
    }
  }

  // ✅ Récupérer les dépenses par catégorie
  Future<List<Depense>> getDepensesByCategorie(String categorie) async {
    try {
      final snapshot = await _firestore
          .collection(COLLECTION)
          .where('categorie', isEqualTo: categorie)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return Depense.fromFirestore(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      print('❌ Erreur récupération dépenses par catégorie: $e');
      return [];
    }
  }

  // ✅ Récupérer une dépense par ID
  Future<Depense?> getDepenseById(String id) async {
    try {
      final doc = await _firestore.collection(COLLECTION).doc(id).get();
      if (doc.exists) {
        return Depense.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('❌ Erreur récupération dépense: $e');
      return null;
    }
  }

  // ✅ Sauvegarder une dépense (création ou mise à jour)
  Future<String> saveDepense(Depense depense) async {
    try {
      final data = depense.toFirestoreMap();
      
      if (depense.id != null && depense.id!.isNotEmpty) {
        // ✅ Mise à jour
        await _firestore.collection(COLLECTION).doc(depense.id!).update(data);
        return depense.id!;
      } else {
        // ✅ Création
        final docRef = await _firestore.collection(COLLECTION).add(data);
        return docRef.id;
      }
    } catch (e) {
      print('❌ Erreur sauvegarde dépense: $e');
      rethrow;
    }
  }

  // ✅ Supprimer une dépense
  Future<void> deleteDepense(String id) async {
    try {
      await _firestore.collection(COLLECTION).doc(id).delete();
    } catch (e) {
      print('❌ Erreur suppression dépense: $e');
      rethrow;
    }
  }

  // ✅ Supprimer toutes les dépenses
  Future<void> deleteAllDepenses() async {
    try {
      final snapshot = await _firestore.collection(COLLECTION).get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('❌ Erreur suppression toutes les dépenses: $e');
      rethrow;
    }
  }

  // ✅ Obtenir le total des dépenses par catégorie
  Future<Map<String, double>> getTotalByCategorie() async {
    try {
      final snapshot = await _firestore.collection(COLLECTION).get();
      Map<String, double> totals = {};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final categorie = data['categorie'] ?? 'Autre';
        final montant = (data['montant'] ?? 0).toDouble();
        totals[categorie] = (totals[categorie] ?? 0) + montant;
      }
      
      return totals;
    } catch (e) {
      print('❌ Erreur calcul total par catégorie: $e');
      return {};
    }
  }

  // ✅ Obtenir le total des dépenses pour une période
  Future<double> getTotalByPeriod(DateTime debut, DateTime fin) async {
    try {
      final snapshot = await _firestore
          .collection(COLLECTION)
          .where('date', isGreaterThanOrEqualTo: debut)
          .where('date', isLessThanOrEqualTo: fin)
          .get();
      
      double total = 0.0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        total += (data['montant'] ?? 0).toDouble();
      }
      
      return total;
    } catch (e) {
      print('❌ Erreur calcul total par période: $e');
      return 0.0;
    }
  }
}