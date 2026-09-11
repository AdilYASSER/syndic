// lib/services/publication_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';   // ✅ AJOUTER
import '../models/publication_model.dart';

class PublicationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _collection = 'publications';
  final String _collectionLues = 'publications_lues';

  // ============================================================
  // ✅ LIRE TOUTES LES PUBLICATIONS
  // ============================================================
  Stream<List<PublicationModel>> getPublications() {
    return _firestore
        .collection(_collection)
        .orderBy('datePublication', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => PublicationModel.fromFirestore(doc))
            .toList());
  }

  // ============================================================
  // ✅ UPLOAD D'IMAGE
  // ============================================================
  Future<String> uploadImage(dynamic image, String fileName) async {
    final ref = _storage.ref().child('publications/$fileName');

    if (kIsWeb && image is Uint8List) {
      await ref.putData(image, SettableMetadata(contentType: 'image/jpeg'));
    } else if (image is File) {
      await ref.putFile(image, SettableMetadata(contentType: 'image/jpeg'));
    } else if (image is XFile) {
      // Cas image_picker
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        await ref.putFile(File(image.path),
            SettableMetadata(contentType: 'image/jpeg'));
      }
    } else {
      throw Exception('Type d\'image non supporté: ${image.runtimeType}');
    }

    return await ref.getDownloadURL();
  }

  // ============================================================
  // ✅ CRÉER UNE PUBLICATION (nom utilisé par admin_publications_screen)
  // ============================================================
  Future<String> createPublication(
    PublicationModel publication,
    dynamic image,
  ) async {
    try {
      String? imageUrl = publication.imageUrl;

      if (image != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        imageUrl = await uploadImage(image, fileName);
      }

      final data = publication.toJson();
      if (imageUrl != null) {
        data['imageUrl'] = imageUrl;
      }

      final docRef = await _firestore.collection(_collection).add(data);
      return docRef.id;
    } catch (e) {
      print('❌ Erreur createPublication: $e');
      rethrow;
    }
  }

  // ============================================================
  // ✅ MODIFIER UNE PUBLICATION
  // ============================================================
  Future<void> updatePublication(
    String id,
    Map<String, dynamic> data, {
    dynamic newImage,
  }) async {
    try {
      // Convertir DateTime en Timestamp si nécessaire
      final cleaned = Map<String, dynamic>.from(data);
      if (cleaned['datePublication'] is DateTime) {
        cleaned['datePublication'] =
            Timestamp.fromDate(cleaned['datePublication']);
      }

      if (newImage != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final imageUrl = await uploadImage(newImage, fileName);
        cleaned['imageUrl'] = imageUrl;
      }

      await _firestore.collection(_collection).doc(id).update(cleaned);
    } catch (e) {
      print('❌ Erreur updatePublication: $e');
      rethrow;
    }
  }

  // ============================================================
  // ✅ SUPPRIMER UNE PUBLICATION
  // ============================================================
  Future<void> deletePublication(String id) async {
    try {
      // Supprimer l'image du Storage
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final imageUrl = data['imageUrl'] as String?;

        if (imageUrl != null && imageUrl.isNotEmpty) {
          try {
            final ref = _storage.refFromURL(imageUrl);
            await ref.delete();
          } catch (e) {
            print('⚠️ Erreur suppression image: $e');
          }
        }
      }

      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      print('❌ Erreur deletePublication: $e');
      rethrow;
    }
  }

  // ============================================================
  // ✅ ALIAS : ajouterPublication (ancien nom)
  // ============================================================
  Future<String> ajouterPublication(PublicationModel publication) async {
    return createPublication(publication, null);
  }

  // ============================================================
  // ✅ ALIAS : modifierPublication (ancien nom)
  // ============================================================
  Future<void> modifierPublication(
      String id, Map<String, dynamic> data) async {
    return updatePublication(id, data);
  }

  // ============================================================
  // ✅ ALIAS : supprimerPublication (ancien nom)
  // ============================================================
  Future<void> supprimerPublication(String id) async {
    return deletePublication(id);
  }

  // ============================================================
  // ✅ MARQUER LES PUBLICATIONS COMME LUES
  // ============================================================
  Future<void> marquerPublicationsLues(String userId) async {
    try {
      await _firestore.collection(_collectionLues).doc(userId).set({
        'lastReadDate': FieldValue.serverTimestamp(),
        'userId': userId,
      }, SetOptions(merge: true));
    } catch (e) {
      print('❌ Erreur marquerPublicationsLues: $e');
    }
  }

  // ============================================================
  // ✅ LIRE LA DATE DE DERNIÈRE LECTURE
  // ============================================================
  Future<DateTime> getLastReadDate(String userId) async {
    try {
      final doc = await _firestore
          .collection(_collectionLues)
          .doc(userId)
          .get();

      if (doc.exists) {
        final ts = doc.data()?['lastReadDate'] as Timestamp?;
        if (ts != null) return ts.toDate();
      }
    } catch (e) {
      print('⚠️ Erreur getLastReadDate: $e');
    }
    return DateTime(2000, 1, 1);
  }

  // ============================================================
  // ✅ COMPTER LES PUBLICATIONS NON LUES
  // ============================================================
  Future<int> countNonLues(String userId) async {
    try {
      final lastRead = await getLastReadDate(userId);
      final snap = await _firestore
          .collection(_collection)
          .where('datePublication',
              isGreaterThan: Timestamp.fromDate(lastRead))
          .get();
      return snap.docs.length;
    } catch (e) {
      print('⚠️ Erreur countNonLues: $e');
      return 0;
    }
  }
}