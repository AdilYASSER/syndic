// lib/services/acces_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/acces.dart';

class AccesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String COLLECTION = 'acces';

  // ⬇️ ENREGISTRER UN ACCÈS
  Future<void> enregistrerAcces({
    required String numAppartement,
    required String role,
    String? ipAdresse,
    String? navigateur,
  }) async {
    try {
      final acces = Acces(
        numAppartement: numAppartement,
        role: role,
        dateAcces: DateTime.now(),
        ipAdresse: ipAdresse,
        navigateur: navigateur,
      );

      await _firestore.collection(COLLECTION).add(acces.toFirestoreMap());
      print('✅ Accès enregistré pour $numAppartement');
    } catch (e) {
      print('❌ Erreur enregistrement accès: $e');
    }
  }

  // ⬇️ RÉCUPÉRER TOUS LES ACCÈS
  Future<List<Acces>> getTousAcces() async {
    try {
      final snapshot = await _firestore
          .collection(COLLECTION)
          .orderBy('dateAcces', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return Acces.fromFirestore(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      print('❌ Erreur récupération accès: $e');
      return [];
    }
  }

  // ⬇️ RÉCUPÉRER LES STATISTIQUES PAR APPARTEMENT
  Future<Map<String, dynamic>> getStatistiquesAcces() async {
    try {
      final acces = await getTousAcces();
      final Map<String, int> compteur = {};
      
      for (var a in acces) {
        compteur[a.numAppartement] = (compteur[a.numAppartement] ?? 0) + 1;
      }

      // Trier par nombre d'accès décroissant
      final sorted = compteur.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return {
        'totalAcces': acces.length,
        'appartementsUniques': compteur.keys.length,
        'topAppartements': sorted.take(10).toList(),
        'dernierAcces': acces.isNotEmpty ? acces.first : null,
      };
    } catch (e) {
      print('❌ Erreur statistiques: $e');
      return {};
    }
  }

  // ⬇️ RÉCUPÉRER LES ACCÈS D'UN APPARTEMENT
  Future<List<Acces>> getAccesByAppartement(String numAppartement) async {
    try {
      final snapshot = await _firestore
          .collection(COLLECTION)
          .where('numAppartement', isEqualTo: numAppartement)
          .orderBy('dateAcces', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return Acces.fromFirestore(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      print('❌ Erreur récupération accès par appartement: $e');
      return [];
    }
  }
}