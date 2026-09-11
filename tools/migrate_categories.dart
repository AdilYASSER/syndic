// tools/migrate_categories.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import '../lib/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;
  
  print('🚀 MIGRATION DES CATÉGORIES VERS repertoire_categories\n');

  // Récupérer toutes les catégories de personnes_utiles
  final snapshot = await firestore
      .collection('personnes_utiles')
      .where('type', isEqualTo: 'categorie')
      .get();

  print('📊 ${snapshot.docs.length} catégories trouvées');

  for (var doc in snapshot.docs) {
    final data = doc.data();
    final categorieNom = data['categorie'] ?? doc.id;
    
    // Récupérer les sous-catégories
    final sousSnapshot = await firestore
        .collection('personnes_utiles')
        .where('categorie', isEqualTo: categorieNom)
        .where('type', isEqualTo: 'sous_categorie')
        .get();

    print('📁 Catégorie: $categorieNom (${sousSnapshot.docs.length} sous-catégories)');

    // Créer la catégorie dans repertoire_categories
    final sousCategories = sousSnapshot.docs.map((sDoc) {
      final sData = sDoc.data();
      return {
        'nom': sData['nom'] ?? '',
        'personnes': [],
      };
    }).toList();

    await firestore
        .collection('repertoire_categories')
        .doc(categorieNom)
        .set({
          'sousCategories': sousCategories,
        });

    print('✅ Catégorie "$categorieNom" migrée');
  }

  print('\n✅ MIGRATION TERMINÉE !');
}