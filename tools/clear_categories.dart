// tools/clear_categories.dart
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

  print('🗑️ SUPPRESSION DES DONNÉES EXISTANTES\n');

  // 1. Supprimer toutes les données de personnes_utiles
  print('📂 Suppression de personnes_utiles...');
  final personnesSnapshot = await firestore.collection('personnes_utiles').get();
  for (var doc in personnesSnapshot.docs) {
    await doc.reference.delete();
  }
  print('✅ ${personnesSnapshot.docs.length} documents supprimés de personnes_utiles');

  // 2. Supprimer toutes les données de repertoire_categories
  print('📂 Suppression de repertoire_categories...');
  final categoriesSnapshot = await firestore.collection('repertoire_categories').get();
  for (var doc in categoriesSnapshot.docs) {
    await doc.reference.delete();
  }
  print('✅ ${categoriesSnapshot.docs.length} documents supprimés de repertoire_categories');

  // 3. Supprimer toutes les propositions
  print('📂 Suppression de propositions_repertoire...');
  final propositionsSnapshot = await firestore.collection('propositions_repertoire').get();
  for (var doc in propositionsSnapshot.docs) {
    await doc.reference.delete();
  }
  print('✅ ${propositionsSnapshot.docs.length} propositions supprimées');

  print('\n✅ TOUTES LES DONNÉES ONT ÉTÉ SUPPRIMÉES !');
}