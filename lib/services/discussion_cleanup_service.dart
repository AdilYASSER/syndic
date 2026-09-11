// lib/services/discussion_cleanup_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class DiscussionCleanupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ Effacer toutes les discussions et leurs messages
  Future<Map<String, int>> clearAllDiscussions() async {
    Map<String, int> result = {
      'discussions': 0,
      'messages': 0,
    };
    
    try {
      print('🗑️ Début du nettoyage des discussions...');
      
      // 1. Récupérer toutes les discussions
      final discussionsSnapshot = await _firestore
          .collection('discussions')
          .get();
      
      result['discussions'] = discussionsSnapshot.docs.length;
      print('📊 ${result['discussions']} discussions trouvées');
      
      // 2. Supprimer chaque discussion et ses messages
      for (var doc in discussionsSnapshot.docs) {
        final discussionId = doc.id;
        
        // Supprimer les messages de la discussion
        final messagesSnapshot = await _firestore
            .collection('discussions')
            .doc(discussionId)
            .collection('messages')
            .get();
        
        result['messages'] = (result['messages'] ?? 0) + messagesSnapshot.docs.length;
        
        for (var msgDoc in messagesSnapshot.docs) {
          await msgDoc.reference.delete();
        }
        
        // Supprimer la discussion
        await doc.reference.delete();
        
        print('✅ Discussion $discussionId supprimée (${messagesSnapshot.docs.length} messages)');
      }
      
      print('✅ Nettoyage terminé: ${result['discussions']} discussions, ${result['messages']} messages');
      
    } catch (e) {
      print('❌ Erreur lors du nettoyage: $e');
      throw Exception('Erreur lors du nettoyage: $e');
    }
    
    return result;
  }

  // ✅ Effacer les discussions d'un volet spécifique
  Future<Map<String, int>> clearDiscussionsByVolet(String volet) async {
    Map<String, int> result = {
      'discussions': 0,
      'messages': 0,
    };
    
    try {
      print('🗑️ Nettoyage des discussions du volet: $volet');
      
      final discussionsSnapshot = await _firestore
          .collection('discussions')
          .where('volet', isEqualTo: volet)
          .get();
      
      result['discussions'] = discussionsSnapshot.docs.length;
      print('📊 ${result['discussions']} discussions trouvées dans le volet $volet');
      
      for (var doc in discussionsSnapshot.docs) {
        final discussionId = doc.id;
        
        final messagesSnapshot = await _firestore
            .collection('discussions')
            .doc(discussionId)
            .collection('messages')
            .get();
        
        result['messages'] = (result['messages'] ?? 0) + messagesSnapshot.docs.length;
        
        for (var msgDoc in messagesSnapshot.docs) {
          await msgDoc.reference.delete();
        }
        
        await doc.reference.delete();
      }
      
      print('✅ ${result['discussions']} discussions supprimées du volet $volet');
      
    } catch (e) {
      print('❌ Erreur lors du nettoyage: $e');
      throw Exception('Erreur lors du nettoyage: $e');
    }
    
    return result;
  }

  // ✅ Effacer les discussions de plus de X jours
  Future<Map<String, int>> clearDiscussionsOlderThan(int days) async {
    Map<String, int> result = {
      'discussions': 0,
      'messages': 0,
    };
    
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      print('🗑️ Nettoyage des discussions de plus de $days jours (avant ${cutoffDate.toLocal()})');
      
      final discussionsSnapshot = await _firestore
          .collection('discussions')
          .where('createdAt', isLessThan: cutoffDate)
          .get();
      
      result['discussions'] = discussionsSnapshot.docs.length;
      print('📊 ${result['discussions']} discussions anciennes trouvées');
      
      for (var doc in discussionsSnapshot.docs) {
        final discussionId = doc.id;
        
        final messagesSnapshot = await _firestore
            .collection('discussions')
            .doc(discussionId)
            .collection('messages')
            .get();
        
        result['messages'] = (result['messages'] ?? 0) + messagesSnapshot.docs.length;
        
        for (var msgDoc in messagesSnapshot.docs) {
          await msgDoc.reference.delete();
        }
        
        await doc.reference.delete();
      }
      
      print('✅ ${result['discussions']} discussions de plus de $days jours supprimées');
      
    } catch (e) {
      print('❌ Erreur lors du nettoyage: $e');
      throw Exception('Erreur lors du nettoyage: $e');
    }
    
    return result;
  }

  // ✅ Compter le nombre de discussions
  Future<int> countDiscussions() async {
    try {
      final snapshot = await _firestore
          .collection('discussions')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('❌ Erreur comptage discussions: $e');
      return 0;
    }
  }

  // ✅ Compter le nombre total de messages dans toutes les discussions
  Future<int> countAllMessages() async {
    try {
      int totalMessages = 0;
      final discussionsSnapshot = await _firestore
          .collection('discussions')
          .get();
      
      for (var doc in discussionsSnapshot.docs) {
        final messagesSnapshot = await _firestore
            .collection('discussions')
            .doc(doc.id)
            .collection('messages')
            .count()
            .get();
        totalMessages += messagesSnapshot.count ?? 0;
      }
      
      return totalMessages;
    } catch (e) {
      print('❌ Erreur comptage messages: $e');
      return 0;
    }
  }

  // ✅ Compter les messages d'une discussion spécifique
  Future<int> countMessagesByDiscussion(String discussionId) async {
    try {
      final snapshot = await _firestore
          .collection('discussions')
          .doc(discussionId)
          .collection('messages')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('❌ Erreur comptage messages pour la discussion $discussionId: $e');
      return 0;
    }
  }

  // ✅ Vérifier si la collection existe
  Future<bool> collectionExists() async {
    try {
      final snapshot = await _firestore
          .collection('discussions')
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Erreur vérification collection: $e');
      return false;
    }
  }

  // ✅ Obtenir les statistiques des discussions
  Future<Map<String, dynamic>> getDiscussionStats() async {
    try {
      final discussionsCount = await countDiscussions();
      final messagesCount = await countAllMessages();
      
      // Compter les discussions par volet
      Map<String, int> voletCounts = {};
      final snapshot = await _firestore
          .collection('discussions')
          .get();
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final volet = data['volet'] ?? 'Général';
        voletCounts[volet] = (voletCounts[volet] ?? 0) + 1;
      }
      
      return {
        'totalDiscussions': discussionsCount,
        'totalMessages': messagesCount,
        'voletCounts': voletCounts,
        'lastUpdated': DateTime.now(),
      };
    } catch (e) {
      print('❌ Erreur obtention statistiques: $e');
      return {
        'totalDiscussions': 0,
        'totalMessages': 0,
        'voletCounts': {},
        'error': e.toString(),
      };
    }
  }

  // ✅ Nettoyer les discussions vides (sans messages)
  Future<Map<String, int>> clearEmptyDiscussions() async {
    Map<String, int> result = {
      'discussions': 0,
      'messages': 0,
    };
    
    try {
      print('🗑️ Nettoyage des discussions vides...');
      
      final discussionsSnapshot = await _firestore
          .collection('discussions')
          .get();
      
      for (var doc in discussionsSnapshot.docs) {
        final messagesSnapshot = await _firestore
            .collection('discussions')
            .doc(doc.id)
            .collection('messages')
            .count()
            .get();
        
        if (messagesSnapshot.count == 0 || messagesSnapshot.count == null) {
          await doc.reference.delete();
          result['discussions'] = (result['discussions'] ?? 0) + 1;
          print('✅ Discussion vide supprimée: ${doc.id}');
        }
      }
      
      print('✅ ${result['discussions']} discussions vides supprimées');
      
    } catch (e) {
      print('❌ Erreur lors du nettoyage: $e');
      throw Exception('Erreur lors du nettoyage: $e');
    }
    
    return result;
  }
}