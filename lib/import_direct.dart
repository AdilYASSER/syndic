// lib/import_direct.dart
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'models/habitant.dart';
import 'services/habitant_service.dart';

class ImportDirect {
  final HabitantService _habitantService = HabitantService();

  Future<Map<String, int>> run() async {
    print('🚀 IMPORT DIRECT - DÉBUT');
    print('=' * 50);

    int imported = 0;
    int errors = 0;
    int skipped = 0;

    try {
      // Lire le CSV
      print('📄 Lecture du fichier...');
      final csvString = await rootBundle.loadString('assets/data/adherants.csv');
      print('✅ Fichier chargé: ${csvString.length} caractères');
      
      // Convertir
      print('🔄 Conversion...');
      List<List<dynamic>> csvTable = const CsvToListConverter(
        eol: '\n',
        fieldDelimiter: ';',
      ).convert(csvString);

      final total = csvTable.length - 1;
      print('📊 $total lignes trouvées');
      
      // ⬇️ IMPORTANT : Limiter à 5 pour éviter le blocage
      final maxLignes = 5;
      print('📊 Import des $maxLignes premières lignes');

      for (int i = 1; i <= maxLignes && i < csvTable.length; i++) {
        final row = csvTable[i];
        if (row.length < 3) {
          errors++;
          continue;
        }

        final appartement = row[0]?.toString().trim().toUpperCase() ?? '';
        final nomComplet = row[1]?.toString().trim() ?? '';
        final cin = row[2]?.toString().trim() ?? '';

        if (appartement.isEmpty || nomComplet.isEmpty) {
          errors++;
          continue;
        }

        // Vérifier si existe déjà
        final existing = await _habitantService.getHabitantByAppartement(appartement);
        if (existing != null) {
          print('⏭️ $appartement existe déjà');
          skipped++;
          continue;
        }

        // Créer l'habitant
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
            print('✅ OK');
          } else {
            errors++;
          }
        } catch (e) {
          print('❌ Erreur: $e');
          errors++;
        }
        
        // Pause pour éviter la surcharge
        await Future.delayed(const Duration(milliseconds: 500));
      }

      print('=' * 50);
      print('📊 RÉSULTATS:');
      print('✅ $imported importés');
      print('⏭️ $skipped ignorés');
      print('❌ $errors erreurs');
      print('🎉 FIN');

      return {
        'imported': imported,
        'skipped': skipped,
        'errors': errors,
      };
    } catch (e) {
      print('❌ Erreur: $e');
      return {
        'imported': imported,
        'skipped': skipped,
        'errors': errors + 1,
      };
    }
  }
}