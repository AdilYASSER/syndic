// lib/services/cotisation_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cotisation.dart';

class CotisationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'cotisations';

  // ✅ Initialiser la collection
  Future<void> initializeFirestoreCollection() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).limit(1).get();
      if (snapshot.docs.isEmpty) {
        print('✅ Collection "$_collectionName" initialisée');
      }
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation: $e');
    }
  }

  // ✅ Récupérer les cotisations depuis Firestore
  Future<List<Cotisation>> getCotisationsFromFirestore() async {
    return await getAllCotisations();
  }

  // ✅ Récupérer toutes les cotisations
  Future<List<Cotisation>> getAllCotisations() async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .orderBy('dateCreation', descending: true)
          .get();

      print('📊 ${snapshot.docs.length} cotisations trouvées dans Firestore');

      final List<Cotisation> cotisations = [];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final cotisation = Cotisation.fromFirestore(data, doc.id);
          cotisations.add(cotisation);
        } catch (e) {
          print('❌ Erreur lors de la conversion du document ${doc.id}: $e');
          continue;
        }
      }

      print('✅ ${cotisations.length} cotisations chargées avec succès');
      return cotisations;
    } catch (e) {
      print('❌ Erreur lors du chargement des cotisations: $e');
      return [];
    }
  }

  // ✅ Sauvegarder une cotisation
  Future<String> saveCotisationToFirestore(Cotisation cotisation) async {
    try {
      final data = cotisation.toFirestoreMap();
      
      if (cotisation.id != null && cotisation.id!.isNotEmpty) {
        await _firestore
            .collection(_collectionName)
            .doc(cotisation.id)
            .update(data);
        return cotisation.id!;
      } else {
        final docRef = await _firestore.collection(_collectionName).add(data);
        return docRef.id;
      }
    } catch (e) {
      throw Exception('Erreur lors de la sauvegarde: $e');
    }
  }

  // ✅ Supprimer une cotisation
  Future<void> deleteCotisation(String id) async {
    try {
      await _firestore.collection(_collectionName).doc(id).delete();
    } catch (e) {
      throw Exception('Erreur lors de la suppression: $e');
    }
  }

  // ✅ Mettre à jour une cotisation
  Future<void> updateCotisation(Cotisation cotisation) async {
    try {
      if (cotisation.id == null || cotisation.id!.isEmpty) {
        throw Exception('ID de cotisation manquant');
      }
      final data = cotisation.toFirestoreMap();
      await _firestore
          .collection(_collectionName)
          .doc(cotisation.id)
          .update(data);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour: $e');
    }
  }

  // ✅ Récupérer une cotisation par ID
  Future<Cotisation?> getCotisationById(String id) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(id).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return Cotisation.fromFirestore(data, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Erreur lors du chargement: $e');
    }
  }

  // ✅ Récupérer les cotisations par année
  Future<List<Cotisation>> getCotisationsByYear(int year) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('annee', isEqualTo: year)
          .orderBy('dateCreation', descending: true)
          .get();
      
      final List<Cotisation> cotisations = [];
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          cotisations.add(Cotisation.fromFirestore(data, doc.id));
        } catch (e) {
          print('❌ Erreur de conversion: $e');
          continue;
        }
      }
      return cotisations;
    } catch (e) {
      throw Exception('Erreur lors du chargement: $e');
    }
  }

  // ✅ Stream de cotisations en temps réel
  Stream<List<Cotisation>> streamCotisations() {
    return _firestore
        .collection(_collectionName)
        .orderBy('dateCreation', descending: true)
        .snapshots()
        .map((snapshot) {
          final List<Cotisation> cotisations = [];
          for (var doc in snapshot.docs) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              cotisations.add(Cotisation.fromFirestore(data, doc.id));
            } catch (e) {
              print('❌ Erreur de conversion: $e');
              continue;
            }
          }
          return cotisations;
        });
  }

  // ✅ Récupérer le nombre de cotisations
  Future<int> getCotisationsCount() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }
}