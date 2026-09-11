// tools/cleanup_duplicate_recus.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class CleanupDuplicateRecus {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> execute() async {
    print('🔍 Recherche des doublons "Total"...');
    
    final snapshot = await _firestore
        .collection('recus')
        .where('statut', isEqualTo: 'Total')
        .get();

    print('📊 ${snapshot.docs.length} reçus "Total" trouvés');

    Map<String, List<DocumentSnapshot>> groups = {};
    
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final key = '${data['numAppartement']}_${data['annee']}_${data['periode']}';
      groups.putIfAbsent(key, () => []).add(doc);
    }

    int deleted = 0;
    int kept = 0;

    for (var entry in groups.entries) {
      final docs = entry.value;
      if (docs.length > 1) {
        docs.sort((a, b) {
          final dateA = (a.data() as Map)['dateEmission'] as String? ?? '';
          final dateB = (b.data() as Map)['dateEmission'] as String? ?? '';
          return dateB.compareTo(dateA);
        });
        
        for (int i = 1; i < docs.length; i++) {
          await docs[i].reference.delete();
          deleted++;
          print('🗑️ Supprimé: ${docs[i].id} (${docs[i].data()['numAppartement']} - ${docs[i].data()['annee']} - ${docs[i].data()['periode']})');
        }
        kept++;
        print('✅ Gardé: ${docs[0].id} (${docs[0].data()['numAppartement']} - ${docs[0].data()['annee']} - ${docs[0].data()['periode']})');
      }
    }

    print('\n📊 Résultat:');
    print('✅ $kept reçus gardés');
    print('🗑️ $deleted doublons supprimés');
  }
}