// lib/import_console.dart
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'models/habitant.dart';
import 'services/habitant_service.dart';

class ImportConsole {
  final HabitantService _habitantService = HabitantService();

  Future<void> run() async {
    print('🚀 DÉBUT DE L\'IMPORT CONSOLE');
    print('=' * 50);

    try {
      // Lire le fichier CSV
      print('📄 Lecture du fichier CSV...');
      final csvString = await rootBundle.loadString('assets/data/adherants.csv');
      print('✅ Fichier chargé: ${csvString.length} caractères');
      
      // Convertir
      print('🔄 Conversion du CSV...');
      List<List<dynamic>> csvTable = const CsvToListConverter(
        eol: '\n',
        fieldDelimiter: ';',
      ).convert(csvString);

      final totalLignes = csvTable.length - 1;
      print('📊 $totalLignes lignes trouvées');
      print('=' * 50);

      // Importer seulement 5 lignes pour tester
      int imported = 0;
      final maxLignes = 5; // ⬅️ Commencer avec 5 seulement

      for (int i = 1; i <= maxLignes && i < csvTable.length; i++) {
        final row = csvTable[i];
        if (row.length < 3) continue;

        final appartement = row[0]?.toString().trim().toUpperCase() ?? '';
        final nomComplet = row[1]?.toString().trim() ?? '';
        final cin = row[2]?.toString().trim() ?? '';

        if (appartement.isEmpty || nomComplet.isEmpty) continue;

        // Séparer nom et prénom
        final parts = nomComplet.split(' ');
        final prenom = parts.isNotEmpty ? parts[0] : '';
        final nom = parts.length > 1 ? parts.sublist(1).join(' ') : '';

        print('👤 Import: $appartement - $prenom $nom');

        final habitant = Habitant(
          nom: nom,
          prenom: prenom,
          numAppartement: appartement,
          telephone: '',
          statut: 'proprietaire',
          rib: '',
          cin: cin,
        );

        try {
          final id = await _habitantService.insertHabitant(habitant);
          if (id > 0) {
            imported++;
            print('✅ OK - ID: $id');
          } else {
            print('❌ Erreur insertion');
          }
        } catch (e) {
          print('❌ Exception: $e');
        }

        // Pause pour éviter de surcharger Firestore
        await Future.delayed(const Duration(milliseconds: 200));
      }

      print('=' * 50);
      print('✅ $imported habitants importés sur $maxLignes');
      print('🎉 FIN DE L\'IMPORT');

    } catch (e) {
      print('❌ Erreur: $e');
    }
  }
}