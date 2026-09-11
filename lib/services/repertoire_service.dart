// lib/services/repertoire_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/repertoire_model.dart';

class RepertoireService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // 📁 GESTION DES CATÉGORIES (depuis repertoire_categories)
  // ============================================================

  /// Récupère toutes les catégories avec leurs sous-catégories
  Stream<List<Categorie>> getCategories() {
    return _firestore
        .collection('repertoire_categories')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            final sousCategoriesData = List<Map<String, dynamic>>.from(data['sousCategories'] ?? []);
            
            final sousCategories = sousCategoriesData.map((s) {
              // Récupérer les IDs des personnes pour cette sous-catégorie
              final personnesIds = List<String>.from(s['personnes'] ?? []);
              
              return SousCategorie(
                nom: s['nom'] ?? '',
                personnes: personnesIds, // IDs des personnes
              );
            }).toList();
            
            return Categorie(
              nom: doc.id,
              sousCategories: sousCategories,
            );
          }).toList();
        });
  }

  /// Récupère toutes les personnes (ouvriers) d'une sous-catégorie
  Stream<List<Personne>> getPersonnesBySousCategorie(String categorie, String sousCategorie) {
    return _firestore
        .collection('personnes_utiles')
        .where('categorie', isEqualTo: categorie)
        .where('sousCategorie', isEqualTo: sousCategorie)
        .where('type', isEqualTo: 'personne')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Personne.fromFirestore(doc)).toList();
        });
  }

  /// Récupère toutes les personnes (ouvriers) d'une catégorie
  Stream<List<Personne>> getPersonnesByCategorie(String categorie) {
    return _firestore
        .collection('personnes_utiles')
        .where('categorie', isEqualTo: categorie)
        .where('type', isEqualTo: 'personne')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Personne.fromFirestore(doc)).toList();
        });
  }

  /// Récupère une personne par son ID
  Future<Personne?> getPersonneById(String id) async {
    final doc = await _firestore.collection('personnes_utiles').doc(id).get();
    if (doc.exists) {
      return Personne.fromFirestore(doc);
    }
    return null;
  }

  // ============================================================
  // ➕ AJOUT DE DONNÉES
  // ============================================================

  /// Ajoute une nouvelle catégorie
  Future<void> ajouterCategorie(String nom) async {
    await _firestore
        .collection('repertoire_categories')
        .doc(nom)
        .set({
          'sousCategories': [],
        });
  }

  /// Ajoute une sous-catégorie à une catégorie existante
  Future<void> ajouterSousCategorie(String categorieNom, String sousCategorieNom) async {
    final docRef = _firestore.collection('repertoire_categories').doc(categorieNom);
    final doc = await docRef.get();
    
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final sousCategories = List<Map<String, dynamic>>.from(data['sousCategories'] ?? []);
      
      // Vérifier si la sous-catégorie existe déjà
      final exists = sousCategories.any((s) => s['nom'] == sousCategorieNom);
      if (!exists) {
        sousCategories.add({
          'nom': sousCategorieNom,
          'personnes': [], // IDs des personnes qui seront ajoutées plus tard
        });
        await docRef.update({'sousCategories': sousCategories});
      }
    }
  }

  /// Ajoute une personne (ouvrier/artisan) dans personnes_utiles
  Future<void> ajouterPersonne(Personne personne) async {
    // 1. Ajouter la personne dans personnes_utiles
    final docRef = await _firestore.collection('personnes_utiles').add({
      'nom': personne.nom,
      'prenom': personne.prenom,
      'telephone': personne.telephone,
      'adresse': personne.adresse,
      'categorie': personne.categorie,
      'sousCategorie': personne.sousCategorie,
      'type': 'personne',
      'statut': 'approuve',
      'satisfaits': 0,
      'insatisfaits': 0,
      'commentaires': [],
      'dateAjout': FieldValue.serverTimestamp(),
      'ajoutePar': personne.ajoutePar,
    });

    // 2. Ajouter l'ID de la personne dans la sous-catégorie correspondante
    final docRefCategorie = _firestore.collection('repertoire_categories').doc(personne.categorie);
    final doc = await docRefCategorie.get();
    
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final sousCategories = List<Map<String, dynamic>>.from(data['sousCategories'] ?? []);
      
      for (var i = 0; i < sousCategories.length; i++) {
        if (sousCategories[i]['nom'] == personne.sousCategorie) {
          final personnes = List<String>.from(sousCategories[i]['personnes'] ?? []);
          personnes.add(docRef.id); // Ajouter l'ID de la personne
          sousCategories[i]['personnes'] = personnes;
          break;
        }
      }
      
      await docRefCategorie.update({'sousCategories': sousCategories});
    }
  }

  // ============================================================
  // 👍 GESTION DE LA SATISFACTION
  // ============================================================

  /// Ajoute un vote de satisfaction pour une personne
  Future<void> ajouterSatisfaction(
    String personneId,
    bool satisfait,
    String? commentaire,
  ) async {
    try {
      final docRef = _firestore.collection('personnes_utiles').doc(personneId);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        throw Exception('Personne non trouvée');
      }
      
      final data = doc.data() as Map<String, dynamic>;
      final satisfaits = (data['satisfaits'] as num?)?.toInt() ?? 0;
      final insatisfaits = (data['insatisfaits'] as num?)?.toInt() ?? 0;
      final commentaires = List<String>.from(data['commentaires'] ?? []);
      
      if (commentaire != null && commentaire.isNotEmpty) {
        commentaires.add(commentaire);
      }
      
      await docRef.update({
        'satisfaits': satisfait ? satisfaits + 1 : satisfaits,
        'insatisfaits': satisfait ? insatisfaits : insatisfaits + 1,
        'commentaires': commentaires,
      });
    } catch (e) {
      print('❌ Erreur lors de l\'ajout de la satisfaction: $e');
      rethrow;
    }
  }

  // ============================================================
  // 🗑️ SUPPRESSION DE DONNÉES
  // ============================================================

  /// Supprime une catégorie et toutes ses sous-catégories
  Future<void> supprimerCategorie(String nom) async {
    await _firestore.collection('repertoire_categories').doc(nom).delete();
  }

  /// Supprime une sous-catégorie d'une catégorie
  Future<void> supprimerSousCategorie(String categorieNom, String sousCategorieNom) async {
    final docRef = _firestore.collection('repertoire_categories').doc(categorieNom);
    final doc = await docRef.get();
    
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final sousCategories = List<Map<String, dynamic>>.from(data['sousCategories'] ?? []);
      sousCategories.removeWhere((s) => s['nom'] == sousCategorieNom);
      await docRef.update({'sousCategories': sousCategories});
    }
  }

  /// Supprime une personne de personnes_utiles et de la sous-catégorie
  Future<void> supprimerPersonne(String personneId) async {
    // 1. Récupérer la personne
    final personneDoc = await _firestore.collection('personnes_utiles').doc(personneId).get();
    if (!personneDoc.exists) return;
    
    final data = personneDoc.data() as Map<String, dynamic>;
    final categorie = data['categorie'] ?? '';
    final sousCategorie = data['sousCategorie'] ?? '';
    
    // 2. Supprimer la personne de personnes_utiles
    await _firestore.collection('personnes_utiles').doc(personneId).delete();
    
    // 3. Retirer l'ID de la sous-catégorie
    if (categorie.isNotEmpty && sousCategorie.isNotEmpty) {
      final docRef = _firestore.collection('repertoire_categories').doc(categorie);
      final doc = await docRef.get();
      
      if (doc.exists) {
        final catData = doc.data() as Map<String, dynamic>;
        final sousCategories = List<Map<String, dynamic>>.from(catData['sousCategories'] ?? []);
        
        for (var i = 0; i < sousCategories.length; i++) {
          if (sousCategories[i]['nom'] == sousCategorie) {
            final personnes = List<String>.from(sousCategories[i]['personnes'] ?? []);
            personnes.remove(personneId);
            sousCategories[i]['personnes'] = personnes;
            break;
          }
        }
        
        await docRef.update({'sousCategories': sousCategories});
      }
    }
  }

  // ============================================================
  // ✏️ MODIFICATION DE DONNÉES
  // ============================================================

  /// Modifie le nom d'une catégorie
  Future<void> modifierCategorie(String ancienNom, String nouveauNom) async {
    final docRef = _firestore.collection('repertoire_categories').doc(ancienNom);
    final doc = await docRef.get();
    
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      await _firestore.collection('repertoire_categories').doc(nouveauNom).set(data);
      await docRef.delete();
    }
  }

  /// Modifie le nom d'une sous-catégorie
  Future<void> modifierSousCategorie(String categorieNom, String ancienNom, String nouveauNom) async {
    final docRef = _firestore.collection('repertoire_categories').doc(categorieNom);
    final doc = await docRef.get();
    
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final sousCategories = List<Map<String, dynamic>>.from(data['sousCategories'] ?? []);
      
      for (var i = 0; i < sousCategories.length; i++) {
        if (sousCategories[i]['nom'] == ancienNom) {
          final personnes = List<String>.from(sousCategories[i]['personnes'] ?? []);
          sousCategories[i] = {
            'nom': nouveauNom,
            'personnes': personnes,
          };
          break;
        }
      }
      
      await docRef.update({'sousCategories': sousCategories});
    }
  }

  /// Modifie les coordonnées d'une personne
  Future<void> modifierPersonne(String personneId, Map<String, dynamic> nouvellesDonnees) async {
    await _firestore.collection('personnes_utiles').doc(personneId).update(nouvellesDonnees);
  }

  // ============================================================
  // 💡 GESTION DES PROPOSITIONS
  // ============================================================

  /// Propose une nouvelle sous-catégorie
  Future<void> proposerSousCategorie(String categorie, String sousCategorie, String proposePar) async {
    await _firestore.collection('propositions_repertoire').add({
      'type': 'sous_categorie',
      'categorie': categorie,
      'nom': sousCategorie,
      'proposePar': proposePar,
      'datePropose': FieldValue.serverTimestamp(),
      'statut': 'en_attente',
    });
  }

  /// Propose une nouvelle personne
  Future<void> proposerPersonne(Personne personne, String proposePar) async {
    await _firestore.collection('propositions_repertoire').add({
      'type': 'personne',
      'nom': personne.nom,
      'prenom': personne.prenom,
      'telephone': personne.telephone,
      'adresse': personne.adresse,
      'categorie': personne.categorie,
      'sousCategorie': personne.sousCategorie,
      'proposePar': proposePar,
      'datePropose': FieldValue.serverTimestamp(),
      'statut': 'en_attente',
      'satisfaits': 0,
      'insatisfaits': 0,
      'commentaires': [],
    });
  }

  /// Récupère toutes les propositions en attente
  Stream<QuerySnapshot> getPropositions() {
    return _firestore
        .collection('propositions_repertoire')
        .where('statut', isEqualTo: 'en_attente')
        .snapshots();
  }

  /// Approuve une proposition
  Future<void> approuverProposition(String propositionId) async {
    final docRef = _firestore.collection('propositions_repertoire').doc(propositionId);
    final doc = await docRef.get();
    
    if (!doc.exists) return;
    
    final data = doc.data() as Map<String, dynamic>;
    await docRef.update({'statut': 'approuve'});
    
    if (data['type'] == 'sous_categorie') {
      await ajouterSousCategorie(data['categorie'], data['nom']);
    } else if (data['type'] == 'personne') {
      final personne = Personne(
        id: '',
        nom: data['nom'] ?? '',
        prenom: data['prenom'] ?? '',
        telephone: data['telephone'] ?? '',
        adresse: data['adresse'] ?? '',
        sousCategorie: data['sousCategorie'] ?? '',
        categorie: data['categorie'] ?? '',
        dateAjout: DateTime.now(),
        ajoutePar: data['proposePar'] ?? 'admin',
      );
      await ajouterPersonne(personne);
    }
  }

  /// Rejette une proposition
  Future<void> rejeterProposition(String propositionId) async {
    await _firestore
        .collection('propositions_repertoire')
        .doc(propositionId)
        .update({'statut': 'rejete'});
  }

  // ============================================================
  // 🐛 DÉBOGAGE
  // ============================================================

  Future<void> debugPropositions() async {
    try {
      final snapshot = await _firestore
          .collection('propositions_repertoire')
          .get();
      
      print('📊 Total propositions: ${snapshot.docs.length}');
      for (var doc in snapshot.docs) {
        print('📄 ${doc.id}: ${doc.data()}');
      }
    } catch (e) {
      print('❌ Erreur debug: $e');
    }
  }
}