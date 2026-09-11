// lib/services/discussion_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/discussion.dart';

class DiscussionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ Stream en temps réel des discussions
  Stream<List<Discussion>> streamDiscussions() {
    return _firestore
        .collection('discussions')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Discussion.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // ✅ Récupérer les discussions une fois (pour compatibilité)
  Future<List<Discussion>> getDiscussions() async {
    try {
      final snapshot = await _firestore
          .collection('discussions')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Discussion.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('❌ Erreur récupération discussions: $e');
      return [];
    }
  }

  // ✅ Récupérer les discussions par volet
  Future<List<Discussion>> getDiscussionsByVolet(String volet) async {
    try {
      final snapshot = await _firestore
          .collection('discussions')
          .where('volet', isEqualTo: volet)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Discussion.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('❌ Erreur récupération discussions par volet: $e');
      return [];
    }
  }

  // ✅ Stream des discussions par volet
  Stream<List<Discussion>> streamDiscussionsByVolet(String volet) {
    return _firestore
        .collection('discussions')
        .where('volet', isEqualTo: volet)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Discussion.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // ✅ Créer une nouvelle discussion
  Future<String> createDiscussion(Discussion discussion) async {
    try {
      final docRef = await _firestore.collection('discussions').add(discussion.toFirestoreMap());
      print('✅ Discussion créée avec succès: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Erreur création discussion: $e');
      throw Exception('Erreur lors de la création de la discussion: $e');
    }
  }

  // ✅ Ajouter un message à une discussion
  Future<void> addMessage(String discussionId, String userId, String userName, String message) async {
    try {
      final docRef = _firestore.collection('discussions').doc(discussionId);
      
      final doc = await docRef.get();
      final data = doc.data();
      
      if (data == null) {
        throw Exception('Discussion non trouvée');
      }
      
      List<dynamic> messages = data['messages'] ?? [];
      
      messages.add({
        'userId': userId,
        'userName': userName,
        'message': message,
        'date': FieldValue.serverTimestamp(),
      });
      
      await docRef.update({
        'messages': messages,
        'lastMessage': message,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'messageCount': FieldValue.increment(1),
      });
      
      print('✅ Message ajouté à la discussion $discussionId');
    } catch (e) {
      print('❌ Erreur ajout message: $e');
      throw Exception('Erreur lors de l\'ajout du message: $e');
    }
  }

  // ✅ Mettre à jour une discussion
  Future<void> updateDiscussion(Discussion discussion) async {
    try {
      await _firestore
          .collection('discussions')
          .doc(discussion.id)
          .update(discussion.toFirestoreMap());
      print('✅ Discussion mise à jour avec succès');
    } catch (e) {
      print('❌ Erreur mise à jour discussion: $e');
      throw Exception('Erreur lors de la mise à jour de la discussion: $e');
    }
  }

  // ✅ Supprimer une discussion (soft delete)
  Future<void> deleteDiscussion(String id) async {
    try {
      await _firestore.collection('discussions').doc(id).update({
        'estActif': false,
      });
      print('✅ Discussion désactivée avec succès');
    } catch (e) {
      print('❌ Erreur suppression discussion: $e');
      throw Exception('Erreur lors de la suppression de la discussion: $e');
    }
  }

  // ✅ Compter les discussions par volet
  Future<Map<String, int>> countByVolet() async {
    try {
      final snapshot = await _firestore.collection('discussions').get();
      Map<String, int> counts = {};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final volet = data['volet'] ?? 'Général';
        counts[volet] = (counts[volet] ?? 0) + 1;
      }
      
      return counts;
    } catch (e) {
      print('❌ Erreur comptage discussions: $e');
      return {};
    }
  }
}