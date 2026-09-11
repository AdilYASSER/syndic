// lib/services/vote_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vote_model.dart';

class VoteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String COLLECTION = 'votes';
  static const String USERS_COLLECTION = 'users';

  // ✅ CORRIGÉ : Création d'un vote avec liaison automatique aux utilisateurs
  Future<void> createVote(VoteModel vote) async {
    try {
      // 1. Créer le document principal dans 'votes'
      DocumentReference voteRef = await _firestore.collection(COLLECTION).add(vote.toMap());

      // 2. Récupérer tous les utilisateurs
      QuerySnapshot usersSnapshot = await _firestore.collection(USERS_COLLECTION).get();

      // 3. Pour chaque utilisateur, ajouter une sous-collection 'votes' contenant l'ID du vote
      for (var doc in usersSnapshot.docs) {
        await _firestore
            .collection(USERS_COLLECTION)
            .doc(doc.id)
            .collection(COLLECTION)
            .doc(voteRef.id)
            .set({
          'voteId': voteRef.id,
          'statut': vote.statut, // Permet de filtrer facilement
        });
      }
      print('✅ Vote créé et lié à ${usersSnapshot.docs.length} utilisateurs');
    } catch (e) {
      print('❌ Erreur création vote: $e');
      rethrow;
    }
  }

  // ✅ CORRIGÉ : Suppression sécurisée (supprime d'abord les sous-collections)
  Future<void> deleteVote(String voteId) async {
    try {
      // 1. Récupérer tous les utilisateurs
      QuerySnapshot usersSnapshot = await _firestore.collection(USERS_COLLECTION).get();

      // 2. Supprimer le vote de la sous-collection de chaque utilisateur
      for (var doc in usersSnapshot.docs) {
        try {
          await _firestore
              .collection(USERS_COLLECTION)
              .doc(doc.id)
              .collection(COLLECTION)
              .doc(voteId)
              .delete();
        } catch (e) {
          // Si l'utilisateur n'avait pas ce vote, on ignore
        }
      }

      // 3. Enfin, supprimer le document principal de la collection 'votes'
      await _firestore.collection(COLLECTION).doc(voteId).delete();
      print('✅ Vote supprimé avec toutes ses références');
    } catch (e) {
      print('❌ Erreur suppression vote: $e');
      rethrow;
    }
  }

  // ✅ FILTRAGE CORRIGÉ (utilise un Stream de la collection principale)
  Stream<List<VoteModel>> getAllVotes() {
    return _firestore
        .collection(COLLECTION)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return VoteModel.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  Stream<List<VoteModel>> getTermineVotes() {
    return _firestore
        .collection(COLLECTION)
        .where('statut', isEqualTo: 'termine')
        .orderBy('dateFin', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return VoteModel.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  Future<void> vote(String voteId, String option, String appartement) async {
    try {
      final docRef = _firestore.collection(COLLECTION).doc(voteId);
      final snapshot = await docRef.get();
      final data = snapshot.data() as Map<String, dynamic>;
      
      Map<String, List<String>> votes = {};
      final votesData = data['votes'] as Map? ?? {};
      votesData.forEach((key, value) {
        if (value is List) {
          votes[key.toString()] = value.map((e) => e.toString()).toList();
        } else {
          votes[key.toString()] = [];
        }
      });
      
      // Retirer l'appartement s'il a déjà voté
      for (var key in votes.keys) {
        if (votes[key]?.contains(appartement) ?? false) {
          votes[key]?.remove(appartement);
        }
      }
      
      // Ajouter le nouveau vote
      if (!votes.containsKey(option)) {
        votes[option] = [];
      }
      if (!votes[option]!.contains(appartement)) {
        votes[option]!.add(appartement);
      }
      
      int total = 0;
      for (var list in votes.values) {
        total += list.length;
      }
      
      await docRef.update({
        'votes': votes,
        'totalVotes': total,
      });
      
      print('✅ Vote enregistré pour $appartement: $option');
    } catch (e) {
      print('❌ Erreur vote: $e');
      rethrow;
    }
  }

  Future<void> updateStatut(String voteId, String statut) async {
    try {
      await _firestore.collection(COLLECTION).doc(voteId).update({
        'statut': statut,
      });
    } catch (e) {
      print('❌ Erreur mise à jour statut: $e');
      rethrow;
    }
  }

  Future<void> updateVote(String voteId, VoteModel vote) async {
    try {
      await _firestore.collection(COLLECTION).doc(voteId).update(vote.toMap());
    } catch (e) {
      print('❌ Erreur mise à jour vote: $e');
      rethrow;
    }
  }

  Future<VoteModel?> getVoteById(String voteId) async {
    try {
      final doc = await _firestore.collection(COLLECTION).doc(voteId).get();
      if (doc.exists) {
        return VoteModel.fromMap(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      print('❌ Erreur récupération vote: $e');
      return null;
    }
  }

  Future<void> updateVoteStatuses() async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection(COLLECTION)
          .where('statut', isEqualTo: 'en_cours')
          .get();
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final dateFin = (data['dateFin'] as Timestamp).toDate();
        if (dateFin.isBefore(now)) {
          await doc.reference.update({'statut': 'termine'});
        }
      }
      
      final aVenirSnapshot = await _firestore
          .collection(COLLECTION)
          .where('statut', isEqualTo: 'a_venir')
          .get();
      
      for (var doc in aVenirSnapshot.docs) {
        final data = doc.data();
        final dateDebut = (data['dateDebut'] as Timestamp).toDate();
        if (dateDebut.isBefore(now)) {
          await doc.reference.update({'statut': 'en_cours'});
        }
      }
    } catch (e) {
      print('❌ Erreur mise à jour statuts: $e');
    }
  }
}