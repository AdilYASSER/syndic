// lib/services/import_service.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../models/habitant.dart';
import '../services/habitant_service.dart';

class ImportService {
  final HabitantService _habitantService = HabitantService();

  // ⬇️ IMPORTER AVEC SÉLECTION DE FICHIER
  Future<Map<String, dynamic>> importFromCSVWithPicker() async {
    int imported = 0;
    int errors = 0;
    int skipped = 0;

    try {
      print('📂 Ouverture du sélecteur de fichier...');
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        dialogTitle: 'Sélectionner le fichier CSV des habitants',
      );

      if (result == null) {
        print('❌ Aucun fichier sélectionné');
        return {
          'imported': 0,
          'skipped': 0,
          'errors': 0,
          'cancelled': true,
        };
      }

      final file = result.files.first;
      print('📄 Fichier sélectionné: ${file.name}');
      print('📄 Taille: ${file.size} octets');

      final bytes = file.bytes;
      if (bytes == null) {
        print('❌ Impossible de lire le fichier');
        return {
          'imported': 0,
          'skipped': 0,
          'errors': 1,
          'cancelled': false,
        };
      }

      String csvString;
      try {
        csvString = utf8.decode(bytes);
        print('✅ Décodage UTF-8 réussi');
      } catch (e) {
        print('⚠️ Erreur UTF-8, essai Latin-1...');
        try {
          csvString = latin1.decode(bytes);
          print('✅ Décodage Latin-1 réussi');
        } catch (e2) {
          print('❌ Erreur de décodage: $e');
          return {
            'imported': 0,
            'skipped': 0,
            'errors': 1,
            'cancelled': false,
          };
        }
      }

      print('📄 Fichier chargé: ${csvString.length} caractères');
      print('📄 Aperçu (100 premiers caractères):');
      print('   ${csvString.substring(0, csvString.length > 100 ? 100 : csvString.length)}...');

      // Convertir en CSV - Essayer plusieurs séparateurs
      List<List<dynamic>> csvTable = [];
      bool conversionReussie = false;

      // Essayer avec point-virgule (;)
      try {
        csvTable = const CsvToListConverter(
          eol: '\n',
          fieldDelimiter: ';',
        ).convert(csvString);
        if (csvTable.isNotEmpty && csvTable.length > 1) {
          conversionReussie = true;
          print('✅ Conversion CSV réussie avec séparateur ;');
        }
      } catch (e) {
        print('⚠️ Erreur avec séparateur ;, essai avec ,...');
      }

      // Essayer avec virgule (,)
      if (!conversionReussie) {
        try {
          csvTable = const CsvToListConverter(
            eol: '\n',
            fieldDelimiter: ',',
          ).convert(csvString);
          if (csvTable.isNotEmpty && csvTable.length > 1) {
            conversionReussie = true;
            print('✅ Conversion CSV réussie avec séparateur ,');
          }
        } catch (e) {
          print('⚠️ Erreur avec séparateur ,, essai avec tabulation...');
        }
      }

      // Essayer avec tabulation (\t)
      if (!conversionReussie) {
        try {
          csvTable = const CsvToListConverter(
            eol: '\n',
            fieldDelimiter: '\t',
          ).convert(csvString);
          if (csvTable.isNotEmpty && csvTable.length > 1) {
            conversionReussie = true;
            print('✅ Conversion CSV réussie avec séparateur TAB');
          }
        } catch (e) {
          print('❌ Échec de toutes les tentatives de conversion');
          return {
            'imported': 0,
            'skipped': 0,
            'errors': 1,
            'cancelled': false,
          };
        }
      }

      if (!conversionReussie || csvTable.isEmpty) {
        print('❌ Aucune donnée valide trouvée');
        return {
          'imported': 0,
          'skipped': 0,
          'errors': 1,
          'cancelled': false,
        };
      }

      final totalLignes = csvTable.length - 1;
      print('📊 $totalLignes lignes trouvées dans le CSV');

      if (totalLignes == 0) {
        print('❌ Aucune donnée trouvée');
        return {
          'imported': 0,
          'skipped': 0,
          'errors': 1,
          'cancelled': false,
        };
      }

      // Afficher les 5 premières lignes pour vérification
      print('📋 Aperçu des 5 premières lignes:');
      for (int i = 0; i < 5 && i < csvTable.length; i++) {
        print('   Ligne ${i+1}: ${csvTable[i]}');
      }

      // ⬇️⬇️⬇️ IMPORTANT : MODIFIER ICI POUR IMPORTER TOUS LES HABITANTS ⬇️⬇️⬇️
      final maxLignes = totalLignes; // ⬅️ Tous les habitants
      
      print('📊 Import de $maxLignes habitants...');

      for (int i = 1; i <= maxLignes && i < csvTable.length; i++) {
        try {
          final row = csvTable[i];
          print('🔄 Traitement ligne $i...');
          
          if (row.length < 3) {
            errors++;
            print('⚠️ Ligne $i: format incorrect (${row.length} colonnes)');
            continue;
          }

          final appartement = row[0]?.toString().trim().toUpperCase() ?? '';
          final nomComplet = row[1]?.toString().trim() ?? '';
          final cin = row[2]?.toString().trim() ?? '';

          print('   Appartement: "$appartement"');
          print('   Nom complet: "$nomComplet"');
          print('   CIN: "$cin"');

          if (appartement.isEmpty || nomComplet.isEmpty) {
            errors++;
            print('⚠️ Ligne $i: données vides');
            continue;
          }

          // Vérifier si l'appartement existe déjà
          print('🔍 Vérification de l\'appartement $appartement...');
          final existing = await _habitantService.getHabitantByAppartement(appartement);
          if (existing != null) {
            print('⏭️ $appartement existe déjà - Ignoré');
            skipped++;
            continue;
          }

          // Séparer le nom et prénom
          final parts = nomComplet.split(' ');
          final prenom = parts.isNotEmpty ? parts[0] : '';
          final nom = parts.length > 1 ? parts.sublist(1).join(' ') : '';

          print('👤 Création: $appartement - $prenom $nom');

          final habitant = Habitant(
            id: null,
            nom: nom,
            prenom: prenom,
            numAppartement: appartement,
            telephone: '',
            statut: 'proprietaire',
            rib: '',
            cin: cin,
          );

          print('💾 Insertion dans Firestore...');
          final String id = await _habitantService.insertHabitant(habitant);
          if (id.isNotEmpty) {  // ✅ CORRIGÉ: id.isNotEmpty au lieu de id > 0
            imported++;
            print('✅ Importé: $appartement - $nomComplet (ID: $id)');
          } else {
            errors++;
            print('❌ Erreur insertion: $appartement');
          }
        } catch (e) {
          errors++;
          print('❌ Erreur ligne $i: $e');
        }
      }

      print('=' * 50);
      print('📊 RÉSULTATS FINAUX:');
      print('✅ $imported habitants importés');
      print('⚠️ $skipped doublons ignorés');
      print('❌ $errors erreurs');
      print('=' * 50);

      return {
        'imported': imported,
        'skipped': skipped,
        'errors': errors,
        'cancelled': false,
      };
    } catch (e) {
      print('❌ Erreur générale: $e');
      print('📚 Stacktrace: $e');
      return {
        'imported': imported,
        'skipped': skipped,
        'errors': errors + 1,
        'cancelled': false,
      };
    }
  }

  // ⬇️ IMPORTER TOUT LE FICHIER (version alternative)
  Future<Map<String, dynamic>> importAllFromCSV() async {
    int imported = 0;
    int errors = 0;
    int skipped = 0;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        dialogTitle: 'Sélectionner le fichier CSV des habitants',
      );

      if (result == null) {
        return {
          'imported': 0,
          'skipped': 0,
          'errors': 0,
          'cancelled': true,
        };
      }

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        return {
          'imported': 0,
          'skipped': 0,
          'errors': 1,
          'cancelled': false,
        };
      }

      String csvString;
      try {
        csvString = utf8.decode(bytes);
      } catch (e) {
        csvString = latin1.decode(bytes);
      }

      List<List<dynamic>> csvTable = const CsvToListConverter(
        eol: '\n',
        fieldDelimiter: ';',
      ).convert(csvString);

      print('📊 ${csvTable.length - 1} lignes à importer');

      for (int i = 1; i < csvTable.length; i++) {
        try {
          final row = csvTable[i];
          if (row.length < 3) continue;

          final appartement = row[0]?.toString().trim().toUpperCase() ?? '';
          final nomComplet = row[1]?.toString().trim() ?? '';
          final cin = row[2]?.toString().trim() ?? '';

          if (appartement.isEmpty || nomComplet.isEmpty) continue;

          final existing = await _habitantService.getHabitantByAppartement(appartement);
          if (existing != null) {
            skipped++;
            continue;
          }

          final parts = nomComplet.split(' ');
          final prenom = parts.isNotEmpty ? parts[0] : '';
          final nom = parts.length > 1 ? parts.sublist(1).join(' ') : '';

          final habitant = Habitant(
            id: null,
            nom: nom,
            prenom: prenom,
            numAppartement: appartement,
            telephone: '',
            statut: 'proprietaire',
            rib: '',
            cin: cin,
          );

          final String id = await _habitantService.insertHabitant(habitant);
          if (id.isNotEmpty) imported++;  // ✅ CORRIGÉ
          else errors++;
        } catch (e) {
          errors++;
        }
      }

      print('📊 RÉSULTATS:');
      print('✅ $imported importés');
      print('⚠️ $skipped ignorés');
      print('❌ $errors erreurs');

      return {
        'imported': imported,
        'skipped': skipped,
        'errors': errors,
        'cancelled': false,
      };
    } catch (e) {
      return {
        'imported': imported,
        'skipped': skipped,
        'errors': errors + 1,
        'cancelled': false,
      };
    }
  }

  // ⬇️ ANCIENNE MÉTHODE POUR L'IMPORT DEPUIS LES ASSETS
  Future<Map<String, int>> importFromCSV() async {
    int imported = 0;
    int errors = 0;
    int skipped = 0;

    try {
      final csvString = await rootBundle.loadString('assets/data/adherants.csv');
      
      List<List<dynamic>> csvTable = const CsvToListConverter(
        eol: '\n',
        fieldDelimiter: ';',
      ).convert(csvString);

      print('📊 ${csvTable.length - 1} lignes trouvées dans le CSV');

      for (int i = 1; i < csvTable.length; i++) {
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

        final existing = await _habitantService.getHabitantByAppartement(appartement);
        if (existing != null) {
          print('⚠️ Appartement $appartement existe déjà - Ignoré');
          skipped++;
          continue;
        }

        final parts = nomComplet.split(' ');
        final prenom = parts.isNotEmpty ? parts[0] : '';
        final nom = parts.length > 1 ? parts.sublist(1).join(' ') : '';

        final habitant = Habitant(
          id: null,
          nom: nom,
          prenom: prenom,
          numAppartement: appartement,
          telephone: '',
          statut: 'proprietaire',
          rib: '',
          cin: cin,
        );

        final String id = await _habitantService.insertHabitant(habitant);
        if (id.isNotEmpty) {  // ✅ CORRIGÉ
          imported++;
          print('✅ Importé: $appartement - $nomComplet');
        } else {
          errors++;
        }
      }

      print('📊 RÉSULTATS:');
      print('✅ $imported habitants importés');
      print('⚠️ $skipped doublons ignorés');
      print('❌ $errors erreurs');

      return {
        'imported': imported,
        'skipped': skipped,
        'errors': errors,
      };
    } catch (e) {
      print('❌ Erreur import: $e');
      return {
        'imported': imported,
        'skipped': skipped,
        'errors': errors + 1,
      };
    }
  }
}