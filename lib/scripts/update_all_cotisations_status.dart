// lib/scripts/update_all_cotisations_status.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class UpdateAllCotisationsStatus {
  static Future<void> execute() async {
    print('╔════════════════════════════════════════════════════════════════╗');
    print('║     MISE À JOUR DES COTISATIONS SANS STATUT                   ║');
    print('╚════════════════════════════════════════════════════════════════╝');
    
    try {
      final firestore = FirebaseFirestore.instance;
      
      print('\n📡 Récupération de toutes les cotisations...');
      final snapshot = await firestore.collection('cotisations').get();
      
      final int total = snapshot.docs.length;
      print('📊 $total cotisations trouvées\n');
      
      int updatedCount = 0;
      int alreadyHasStatus = 0;
      int errorCount = 0;
      
      // ✅ Compter les statuts existants
      Map<String, int> statusCount = {};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String? statut = data['statut'] as String?;
        
        if (statut != null && statut.isNotEmpty) {
          alreadyHasStatus++;
          statusCount[statut] = (statusCount[statut] ?? 0) + 1;
        }
      }
      
      if (alreadyHasStatus > 0) {
        print('📊 Statuts existants:');
        statusCount.forEach((statut, count) {
          print('   • "$statut": $count cotisations');
        });
        print('');
      }
      
      final int toUpdate = total - alreadyHasStatus;
      print('📝 $toUpdate cotisations sans statut à traiter\n');
      
      if (toUpdate == 0) {
        print('✅ Toutes les cotisations ont déjà un statut !');
        return;
      }
      
      // ✅ Traiter par lots de 50
      final int batchSize = 50;
      int batchCount = 0;
      int processedInBatch = 0;
      
      for (int i = 0; i < snapshot.docs.length; i += batchSize) {
        final end = (i + batchSize < snapshot.docs.length) 
            ? i + batchSize 
            : snapshot.docs.length;
        
        final batch = firestore.batch();
        int batchUpdated = 0;
        
        for (int j = i; j < end; j++) {
          final doc = snapshot.docs[j];
          final data = doc.data();
          
          try {
            final String? statut = data['statut'] as String?;
            
            // ✅ Seulement si le statut n'existe pas
            if (statut == null || statut.isEmpty) {
              // ✅ Déterminer le statut
              final hasDateVersement = data['dateVersement'] != null;
              final String newStatut = hasDateVersement ? 'Payé' : 'En attente';
              
              batch.update(doc.reference, {'statut': newStatut});
              
              updatedCount++;
              batchUpdated++;
              final app = data['numAppartement']?.toString() ?? '???';
              final annee = data['annee']?.toString() ?? '?';
              print('✅ ${doc.id.substring(0, 10)}... | App: $app | $annee | $newStatut');
            }
            
          } catch (e) {
            errorCount++;
            print('❌ Erreur pour ${doc.id}: $e');
          }
        }
        
        // ✅ Exécuter le batch
        if (batchUpdated > 0) {
          batchCount++;
          processedInBatch += batchUpdated;
          await batch.commit();
          print('\n📦 Lot $batchCount terminé ($batchUpdated documents, total: $processedInBatch/$toUpdate)\n');
        }
      }
      
      // ✅ Résumé final
      print('\n╔════════════════════════════════════════════════════════════════╗');
      print('║                     RÉSUMÉ FINAL                             ║');
      print('╚════════════════════════════════════════════════════════════════╝');
      print('📝 Total des cotisations: $total');
      print('✅ Nouvelles cotisations mises à jour: $updatedCount');
      print('ℹ️ Cotisations déjà avec statut: $alreadyHasStatus');
      
      if (statusCount.isNotEmpty) {
        print('\n📊 Répartition des statuts existants:');
        statusCount.forEach((statut, count) {
          final percentage = (count / total * 100).toStringAsFixed(1);
          print('   • "$statut": $count (${percentage}%)');
        });
      }
      
      print('❌ Erreurs: $errorCount');
      print('📦 Lots exécutés: $batchCount');
      
      if (updatedCount > 0) {
        print('\n✅ $updatedCount cotisations mises à jour avec succès !');
      }
      
    } catch (e) {
      print('\n❌ Erreur générale: $e');
    }
  }
}