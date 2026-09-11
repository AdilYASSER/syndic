// lib/services/habitant_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/habitant.dart';
import 'database_service.dart';

class HabitantService {
  final DatabaseService _databaseService = DatabaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'habitants';

  // Récupérer tous les habitants
  Future<List<Habitant>> getAllHabitants() async {
    try {
      return await getHabitantsFromFirestore();
    } catch (e) {
      print('❌ Erreur getAllHabitants: $e');
      return [];
    }
  }

  // Récupérer uniquement les propriétaires
  Future<List<Habitant>> getProprietaires() async {
    try {
      final allHabitants = await getHabitantsFromFirestore();
      final proprietaires = allHabitants
          .where((h) => h.statut == 'proprietaire')
          .toList();
      print('✅ ${proprietaires.length} propriétaires (sur ${allHabitants.length} habitants)');
      return proprietaires;
    } catch (e) {
      print('❌ Erreur getProprietaires: $e');
      return [];
    }
  }

  // Récupérer depuis Firestore
  Future<List<Habitant>> getHabitantsFromFirestore() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .orderBy('numAppartement')
          .get();

      final List<Habitant> habitants = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final String docId = doc.id;
        
        final habitant = Habitant.fromFirestore(data, docId);
        habitant.id = docId;
        habitants.add(habitant);
      }

      print('✅ ${habitants.length} habitants récupérés de Firestore');
      return habitants;
    } catch (e) {
      print('❌ Erreur getHabitantsFromFirestore: $e');
      return [];
    }
  }

  // Récupérer les appartements uniques
  Future<List<String>> getUniqueAppartements() async {
    try {
      final habitants = await getProprietaires();
      final Set<String> appartementsSet = {};
      
      for (var h in habitants) {
        if (h.numAppartement.isNotEmpty) {
          appartementsSet.add(h.numAppartement);
        }
      }
      
      final List<String> appartements = appartementsSet.toList()..sort();
      print('✅ ${appartements.length} appartements uniques');
      return appartements;
    } catch (e) {
      print('❌ Erreur getUniqueAppartements: $e');
      return [];
    }
  }

  // Ajouter un habitant
  Future<String> insertHabitant(Habitant habitant) async {
    try {
      final docRef = await _firestore.collection(_collectionName).add(
        habitant.toFirestoreMap()
      );
      final String id = docRef.id;
      print('✅ Habitant ajouté à Firestore avec ID: $id');
      return id;
    } catch (e) {
      print('❌ Erreur insertHabitant: $e');
      return '';
    }
  }

  // Modifier un habitant
  Future<String> updateHabitant(Habitant habitant) async {
    try {
      if (habitant.id == null || habitant.id!.isEmpty) {
        print('❌ ID manquant pour la mise à jour');
        return '';
      }

      final String docId = habitant.id!;
      print('📝 Mise à jour de l\'habitant:');
      print('   ID: $docId');
      print('   Nom: ${habitant.nom}');
      print('   Prénom: ${habitant.prenom}');
      print('   Appartement: ${habitant.numAppartement}');

      final docSnapshot = await _firestore
          .collection(_collectionName)
          .doc(docId)
          .get();
      
      if (!docSnapshot.exists) {
        print('❌ Document non trouvé pour ID: $docId');
        return '';
      }

      await _firestore
          .collection(_collectionName)
          .doc(docId)
          .update(habitant.toFirestoreMap());

      print('✅ Habitant mis à jour avec succès dans Firestore');
      return habitant.id!;
    } catch (e) {
      print('❌ Erreur updateHabitant: $e');
      return '';
    }
  }

  // Supprimer un habitant
  Future<bool> deleteHabitant(String id) async {
    try {
      if (id.isEmpty) {
        print('❌ ID vide pour la suppression');
        return false;
      }
      
      print('📝 Tentative de suppression de l\'habitant ID: $id');
      
      final docSnapshot = await _firestore
          .collection(_collectionName)
          .doc(id)
          .get();
      
      if (!docSnapshot.exists) {
        print('⚠️ Document Firestore non trouvé pour ID: $id');
        return true;
      }

      await _firestore
          .collection(_collectionName)
          .doc(id)
          .delete();
      
      print('✅ Habitant supprimé de Firestore avec succès');
      return true;
    } catch (e) {
      print('❌ Erreur deleteHabitant: $e');
      return false;
    }
  }

  // Récupérer un habitant par appartement
  Future<Habitant?> getHabitantByAppartement(String numAppartement) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('numAppartement', isEqualTo: numAppartement)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        final String id = doc.id;
        final habitant = Habitant.fromFirestore(data, id);
        habitant.id = id;
        return habitant;
      }
      return null;
    } catch (e) {
      print('❌ Erreur getHabitantByAppartement: $e');
      return null;
    }
  }

  // Récupérer un habitant par ID
  Future<Habitant?> getHabitantById(String id) async {
    try {
      final docSnapshot = await _firestore
          .collection(_collectionName)
          .doc(id)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null) {
          final habitant = Habitant.fromFirestore(data, id);
          habitant.id = id;
          return habitant;
        }
      }
      return null;
    } catch (e) {
      print('❌ Erreur getHabitantById: $e');
      return null;
    }
  }

  // Récupérer les catégories
  Future<List<String>> getCategories() async {
    try {
      final habitants = await getAllHabitants();
      final categories = habitants.map((h) => h.statutTexte).toSet().toList();
      return categories;
    } catch (e) {
      print('❌ Erreur getCategories: $e');
      return [];
    }
  }
}