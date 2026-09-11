// lib/scripts/force_add_status.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class ForceAddStatus {
  static Future<void> execute() async {
    print('═══════════════════════════════════════════════════════════');
    print('  FORCE AJOUT DU CHAMP STATUT A TOUTES LES COTISATIONS');
    print('═══════════════════════════════════════════════════════════');
    
    try {
      await Firebase.initializeApp();
      final firestore = FirebaseFirestore.instance;
      
      print('\n📡 Récupération de toutes les cotisations...');
      final snapshot = await firestore.collection('cotisations').get();
      
      final int total = snapshot.docs.length;
      print('📊 $total cotisations trouvées\n');
      
      int count = 0;
      
      // ✅ Parcourir tous les documents
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String? statut = data['statut'] as String?;
        
        // ✅ Si le champ statut n'existe PAS ou est vide
        if (statut == null || statut.isEmpty) {
          // ✅ Déterminer le statut
          final hasDateVersement = data['dateVersement'] != null;
          final String newStatut = hasDateVersement ? 'Payé' : 'En attente';
          
          // ✅ FORCER l'ajout du champ
          await doc.reference.update({
            'statut': newStatut,
          });
          
          count++;
          final app = data['numAppartement']?.toString() ?? '???';
          print('✅ ${doc.id.substring(0, 12)}... | App: $app | $newStatut');
        }
      }
      
      print('\n═══════════════════════════════════════════════════════════');
      print('  RÉSULTAT');
      print('═══════════════════════════════════════════════════════════');
      print('✅ $count cotisations mises à jour');
      print('📊 Total: $total cotisations');
      print('═══════════════════════════════════════════════════════════');
      
    } catch (e) {
      print('❌ Erreur: $e');
    }
  }
}