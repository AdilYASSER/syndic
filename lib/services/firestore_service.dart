// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/repertoire_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // 📁 GESTION DES CATÉGORIES
  // ============================================================

  // Récupérer toutes les catégories
  Future<List<Categorie>> getCategories() async {
    try {
      final snapshot = await _firestore.collection('repertoire_categories').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final sousCategoriesData = List<Map<String, dynamic>>.from(data['sousCategories'] ?? []);
        final sousCategories = sousCategoriesData.map((s) => SousCategorie.fromJson(s)).toList();
        
        return Categorie(
          nom: doc.id,
          sousCategories: sousCategories,
        );
      }).toList();
    } catch (e) {
      print('❌ Erreur lors du chargement des catégories: $e');
      return [];
    }
  }

  // Écouter les changements en temps réel
  Stream<List<Categorie>> streamCategories() {
    return _firestore.collection('repertoire_categories').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final sousCategoriesData = List<Map<String, dynamic>>.from(data['sousCategories'] ?? []);
        final sousCategories = sousCategoriesData.map((s) => SousCategorie.fromJson(s)).toList();
        
        return Categorie(
          nom: doc.id,
          sousCategories: sousCategories,
        );
      }).toList();
    });
  }

  // Ajouter une nouvelle catégorie
  Future<void> addCategory(String nom) async {
    try {
      await _firestore.collection('repertoire_categories').doc(nom).set({
        'sousCategories': [],
      });
      print('✅ Catégorie "$nom" créée');
    } catch (e) {
      print('❌ Erreur lors de la création de la catégorie: $e');
      rethrow;
    }
  }

  // Ajouter une sous-catégorie
  Future<void> addSubCategory(String categoryName, String subCategoryName) async {
    try {
      final docRef = _firestore.collection('repertoire_categories').doc(categoryName);
      final doc = await docRef.get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final sousCategories = List<Map<String, dynamic>>.from(data['sousCategories'] ?? []);
        
        // Vérifier si la sous-catégorie existe déjà
        final exists = sousCategories.any((s) => s['nom'] == subCategoryName);
        if (!exists) {
          sousCategories.add({
            'nom': subCategoryName,
            'personnes': [],
          });
          await docRef.update({'sousCategories': sousCategories});
          print('✅ Sous-catégorie "$subCategoryName" ajoutée à "$categoryName"');
        } else {
          print('⚠️ La sous-catégorie "$subCategoryName" existe déjà');
        }
      } else {
        // Créer la catégorie avec la sous-catégorie
        await docRef.set({
          'sousCategories': [
            {
              'nom': subCategoryName,
              'personnes': [],
            }
          ],
        });
        print('✅ Catégorie "$categoryName" créée avec la sous-catégorie "$subCategoryName"');
      }
    } catch (e) {
      print('❌ Erreur lors de l\'ajout de la sous-catégorie: $e');
      rethrow;
    }
  }

  // Ajouter une personne à une sous-catégorie
  Future<void> addPersonToSubCategory(String categoryName, String subCategoryName, String personName) async {
    try {
      final docRef = _firestore.collection('repertoire_categories').doc(categoryName);
      final doc = await docRef.get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final sousCategories = List<Map<String, dynamic>>.from(data['sousCategories'] ?? []);
        
        for (var sous in sousCategories) {
          if (sous['nom'] == subCategoryName) {
            if (!sous.containsKey('personnes')) {
              sous['personnes'] = [];
            }
            if (!sous['personnes'].contains(personName)) {
              sous['personnes'].add(personName);
              await docRef.update({'sousCategories': sousCategories});
              print('✅ Personne "$personName" ajoutée à "$subCategoryName"');
              return;
            } else {
              print('⚠️ Personne "$personName" existe déjà dans "$subCategoryName"');
              return;
            }
          }
        }
        print('⚠️ Sous-catégorie "$subCategoryName" non trouvée');
      } else {
        print('❌ Catégorie "$categoryName" non trouvée');
      }
    } catch (e) {
      print('❌ Erreur lors de l\'ajout de la personne: $e');
      rethrow;
    }
  }

  // Supprimer une catégorie
  Future<void> deleteCategory(String categoryName) async {
    try {
      await _firestore.collection('repertoire_categories').doc(categoryName).delete();
      print('✅ Catégorie "$categoryName" supprimée');
    } catch (e) {
      print('❌ Erreur lors de la suppression: $e');
      rethrow;
    }
  }

  // Supprimer une sous-catégorie
  Future<void> deleteSubCategory(String categoryName, String subCategoryName) async {
    try {
      final docRef = _firestore.collection('repertoire_categories').doc(categoryName);
      final doc = await docRef.get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final sousCategories = List<Map<String, dynamic>>.from(data['sousCategories'] ?? []);
        
        sousCategories.removeWhere((s) => s['nom'] == subCategoryName);
        await docRef.update({'sousCategories': sousCategories});
        print('✅ Sous-catégorie "$subCategoryName" supprimée de "$categoryName"');
      }
    } catch (e) {
      print('❌ Erreur lors de la suppression: $e');
      rethrow;
    }
  }

  // Supprimer une personne d'une sous-catégorie
  Future<void> removePersonFromSubCategory(String categoryName, String subCategoryName, String personName) async {
    try {
      final docRef = _firestore.collection('repertoire_categories').doc(categoryName);
      final doc = await docRef.get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final sousCategories = List<Map<String, dynamic>>.from(data['sousCategories'] ?? []);
        
        for (var sous in sousCategories) {
          if (sous['nom'] == subCategoryName) {
            final personnes = List<String>.from(sous['personnes'] ?? []);
            personnes.remove(personName);
            sous['personnes'] = personnes;
            await docRef.update({'sousCategories': sousCategories});
            print('✅ Personne "$personName" retirée de "$subCategoryName"');
            return;
          }
        }
      }
    } catch (e) {
      print('❌ Erreur lors de la suppression: $e');
      rethrow;
    }
  }
}