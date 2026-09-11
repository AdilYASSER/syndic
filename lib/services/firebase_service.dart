// lib/services/firebase_service.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/habitant.dart';
import 'database_service.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String COLLECTION = 'habitants';

  DatabaseService get _db => DatabaseService();

  Future<void> syncHabitant(Habitant habitant) async {
    try {
      // ⬇️ STORAGE DÉSACTIVÉ SUR WEB
      if (!kIsWeb) {
        // Code pour l'upload d'image (uniquement sur Windows/Android/iOS)
        // À ajouter plus tard
      }

      // ⬇️ CORRECTION : Générer un ID unique si nécessaire
      final docId = habitant.id != null && habitant.id! > 0 
          ? habitant.id.toString() 
          : DateTime.now().millisecondsSinceEpoch.toString();

      final data = habitant.toFirestoreMap();
      
      // ⬇️ CORRECTION : S'assurer que l'ID est correct
      data['id'] = habitant.id ?? int.parse(docId);
      
      // ⬇️ CORRECTION : Utiliser docId pour le document Firestore
      await _firestore.collection(COLLECTION).doc(docId).set(data);
      
      // ⬇️ CORRECTION : Ne pas marquer comme synchronisé sur Web
      if (!kIsWeb) {
        await _db.markAsSynced(habitant.id!);
      } else {
        print('✅ Habitant synchronisé sur Firestore (Web) avec ID: $docId');
      }
    } catch (e) {
      print('❌ Erreur synchronisation: $e');
      rethrow;
    }
  }

  Future<void> syncAllUnsynced() async {
    if (kIsWeb) {
      print('⚠️ Synchronisation des non-synchronisés non supportée sur Web');
      return;
    }
    final unsynced = await _db.getUnsyncedHabitants();
    for (var habitant in unsynced) {
      await syncHabitant(habitant);
    }
  }

  Future<void> deleteFromFirestore(int id) async {
    try {
      await _firestore.collection(COLLECTION).doc(id.toString()).delete();
    } catch (e) {
      print('❌ Erreur suppression Firestore: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot> getHabitantsStream() {
    return _firestore
        .collection(COLLECTION)
        .orderBy('numAppartement')
        .snapshots();
  }

  Future<List<Habitant>> getHabitantsFromFirestore() async {
    try {
      final snapshot = await _firestore
          .collection(COLLECTION)
          .orderBy('numAppartement')
          .get();
      
      List<Habitant> habitants = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        // ⬇️ CORRECTION : Récupérer l'ID depuis le document ou les données
        final id = data['id'] as int? ?? int.tryParse(doc.id) ?? 0;
        if (id > 0) {
          habitants.add(Habitant.fromFirestore(data, id));
        } else {
          // ⬇️ CORRECTION : Cas où l'ID est -1, utiliser l'ID du document
          final docId = int.tryParse(doc.id) ?? 0;
          if (docId > 0) {
            habitants.add(Habitant.fromFirestore(data, docId));
          }
        }
      }
      return habitants;
    } catch (e) {
      print('❌ Erreur récupération Firestore: $e');
      return [];
    }
  }

  // ⬇️ MÉTHODE DÉSACTIVÉE SUR WEB
  Future<void> uploadCINImage(int habitantId, File imageFile) async {
    if (kIsWeb) {
      print('⚠️ Upload d\'image désactivé sur Web');
      return;
    }
    print('⚠️ Firebase Storage non disponible sur Web');
  }

  // ⬇️ NOUVELLE MÉTHODE : Récupérer un habitant par ID
  Future<Habitant?> getHabitantFromFirestore(int id) async {
    try {
      final doc = await _firestore
          .collection(COLLECTION)
          .doc(id.toString())
          .get();
      
      if (!doc.exists) return null;
      
      final data = doc.data();
      if (data == null) return null;
      
      return Habitant.fromFirestore(data, id);
    } catch (e) {
      print('❌ Erreur récupération habitant: $e');
      return null;
    }
  }

  // ⬇️ NOUVELLE MÉTHODE : Mettre à jour un habitant dans Firestore
  Future<void> updateHabitantInFirestore(Habitant habitant) async {
    try {
      if (habitant.id == null || habitant.id! <= 0) {
        throw Exception('ID invalide pour la mise à jour');
      }
      
      final data = habitant.toFirestoreMap();
      await _firestore
          .collection(COLLECTION)
          .doc(habitant.id.toString())
          .update(data);
      
      print('✅ Habitant ${habitant.id} mis à jour dans Firestore');
    } catch (e) {
      print('❌ Erreur mise à jour Firestore: $e');
      rethrow;
    }
  }
}