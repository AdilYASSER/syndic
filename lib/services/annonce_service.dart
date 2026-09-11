// lib/services/annonce_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import '../models/annonce_model.dart';

class AnnonceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ✅ Récupérer toutes les annonces visibles
  Stream<List<AnnonceModel>> getAnnonces() {
    return _firestore
        .collection('annonces')
        .where('isVisible', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final annonces = snapshot.docs
              .map((doc) => AnnonceModel.fromFirestore(doc))
              .toList();
          annonces.sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
          return annonces;
        });
  }

  // ✅ Récupérer toutes les annonces (admin)
  Stream<List<AnnonceModel>> getAllAnnonces() {
    return _firestore
        .collection('annonces')
        .snapshots()
        .map((snapshot) {
          final annonces = snapshot.docs
              .map((doc) => AnnonceModel.fromFirestore(doc))
              .toList();
          annonces.sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
          return annonces;
        });
  }

  // ✅ Récupérer les annonces d'un appartement
  Stream<List<AnnonceModel>> getAnnoncesByAppartement(String appartement) {
    return _firestore
        .collection('annonces')
        .where('appartement', isEqualTo: appartement)
        .snapshots()
        .map((snapshot) {
          final annonces = snapshot.docs
              .map((doc) => AnnonceModel.fromFirestore(doc))
              .toList();
          annonces.sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
          return annonces;
        });
  }

  // ✅ Upload d'une image
  Future<String> uploadImage(dynamic image, String fileName) async {
    try {
      final ref = _storage.ref().child('annonces/$fileName');
      
      if (kIsWeb && image is Uint8List) {
        await ref.putData(image, SettableMetadata(contentType: 'image/jpeg'));
      } else if (image is File) {
        await ref.putFile(image, SettableMetadata(contentType: 'image/jpeg'));
      }
      
      return await ref.getDownloadURL();
    } catch (e) {
      print('❌ Erreur upload: $e');
      rethrow;
    }
  }

  // ✅ Upload de plusieurs images
  Future<List<String>> uploadImages(List<dynamic> images) async {
    List<String> urls = [];
    for (int i = 0; i < images.length; i++) {
      try {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final url = await uploadImage(images[i], fileName);
        urls.add(url);
      } catch (e) {
        print('❌ Erreur upload image $i: $e');
      }
    }
    return urls;
  }

  // ✅ Ajouter une annonce
  Future<String> ajouterAnnonce(AnnonceModel annonce, List<dynamic> images) async {
    try {
      // Upload des images
      List<String> imageUrls = [];
      if (images.isNotEmpty) {
        imageUrls = await uploadImages(images);
      }

      // Créer l'annonce
      final data = annonce.toJson();
      data['imageUrls'] = imageUrls;
      
      final docRef = await _firestore.collection('annonces').add(data);
      return docRef.id;
    } catch (e) {
      print('❌ Erreur ajout annonce: $e');
      rethrow;
    }
  }

  // ✅ Modifier une annonce
  Future<void> modifierAnnonce(
    String id,
    Map<String, dynamic> data,
    List<dynamic> newImages,
    List<String> existingImageUrls,
  ) async {
    try {
      List<String> allImageUrls = List.from(existingImageUrls);
      
      if (newImages.isNotEmpty) {
        final newUrls = await uploadImages(newImages);
        allImageUrls.addAll(newUrls);
      }

      data['imageUrls'] = allImageUrls;
      await _firestore.collection('annonces').doc(id).update(data);
    } catch (e) {
      print('❌ Erreur modification: $e');
      rethrow;
    }
  }

  // ✅ Supprimer une annonce
  Future<void> supprimerAnnonce(String id) async {
    try {
      // Récupérer l'annonce pour supprimer les images
      final doc = await _firestore.collection('annonces').doc(id).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final imageUrls = List<String>.from(data['imageUrls'] ?? []);
        
        // Supprimer les images du Storage
        for (var url in imageUrls) {
          try {
            final ref = _storage.refFromURL(url);
            await ref.delete();
          } catch (e) {
            print('⚠️ Erreur suppression image: $e');
          }
        }
      }
      
      // Supprimer le document
      await _firestore.collection('annonces').doc(id).delete();
    } catch (e) {
      print('❌ Erreur suppression: $e');
      rethrow;
    }
  }

  // ✅ Masquer/Afficher une annonce (admin)
  Future<void> toggleVisibility(String id, bool isVisible) async {
    await _firestore.collection('annonces').doc(id).update({
      'isVisible': isVisible,
    });
  }
}