// lib/services/excel_import_service.dart
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/cotisation.dart';
import '../services/cotisation_service.dart';

class ExcelImportService {
  final CotisationService _cotisationService = CotisationService();

  Future<Map<String, dynamic>> importCotisationsFromExcel(Uint8List bytes) async {
    try {
      print('📊 === DÉBUT IMPORT EXCEL ===');
      print('📊 Taille du fichier: ${bytes.length} bytes');
      
      final excel = Excel.decodeBytes(bytes);
      
      if (excel.tables.isEmpty) {
        return {
          'success': false,
          'message': 'Aucune feuille trouvée dans le fichier Excel',
          'imported': 0,
        };
      }

      final sheet = excel.tables[excel.tables.keys.first];
      
      if (sheet == null) {
        return {
          'success': false,
          'message': 'Aucune feuille trouvée dans le fichier Excel',
          'imported': 0,
        };
      }

      print('📊 Feuille: ${excel.tables.keys.first}');
      print('📊 Nombre total de lignes: ${sheet.rows.length}');

      if (sheet.rows.isEmpty) {
        return {
          'success': false,
          'message': 'Le fichier Excel est vide',
          'imported': 0,
        };
      }

      // ✅ Afficher les 5 premières lignes pour déboguer
      print('📊 === APERÇU DES LIGNES ===');
      int maxLines = sheet.rows.length > 5 ? 5 : sheet.rows.length;
      for (int i = 0; i < maxLines; i++) {
        final row = sheet.rows[i];
        String rowInfo = 'Ligne $i: ';
        for (int j = 0; j < row.length && j < 6; j++) {
          final cell = row[j];
          if (cell != null) {
            rowInfo += '[Col $j: ${cell.value}] ';
          } else {
            rowInfo += '[Col $j: null] ';
          }
        }
        print(rowInfo);
      }
      print('📊 === FIN APERÇU ===');

      List<Cotisation> cotisations = [];
      int importedCount = 0;
      List<String> errors = [];

      // ✅ Déterminer la ligne de départ (en-tête)
      int startRow = 0;
      if (sheet.rows.isNotEmpty) {
        final firstRow = sheet.rows[0];
        if (firstRow.isNotEmpty && firstRow[0] != null) {
          final firstCell = firstRow[0]!.value?.toString().toLowerCase() ?? '';
          if (firstCell.contains('num') || 
              firstCell.contains('appartement') || 
              firstCell.contains('code') ||
              firstCell.contains('n°') ||
              firstCell.contains('période')) {
            startRow = 1;
            print('📊 Ligne 0 est un en-tête, on commence à la ligne 1');
          }
        }
      }

      print('📊 Début de la lecture à la ligne $startRow');

      // ⬇️ PARCOURIR LES LIGNES
      for (int i = startRow; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        
        // ✅ Vérifier si la ligne est vide
        bool isEmpty = true;
        for (var cell in row) {
          final value = cell?.value;
          if (value != null && value.toString().trim().isNotEmpty) {
            isEmpty = false;
            break;
          }
        }
        
        if (isEmpty) {
          print('📊 Ligne $i: vide, ignorée');
          continue;
        }

        try {
          // ⬇️ LIRE LES VALEURS
          String numAppartement = '';
          double periode1_2025 = 0.0;
          double periode2_2025 = 0.0;
          double periode1_2026 = 0.0;
          double periode2_2026 = 0.0;

          // Colonne 0 - Appartement
          if (row.length > 0 && row[0] != null) {
            final value = row[0]!.value;
            numAppartement = value?.toString().trim() ?? '';
          }

          // Colonne 1 - 6 premiers mois 2025
          if (row.length > 1 && row[1] != null) {
            periode1_2025 = _parseDouble(row[1]!.value);
          }

          // Colonne 2 - 6 derniers mois 2025
          if (row.length > 2 && row[2] != null) {
            periode2_2025 = _parseDouble(row[2]!.value);
          }

          // Colonne 3 - 6 premiers mois 2026
          if (row.length > 3 && row[3] != null) {
            periode1_2026 = _parseDouble(row[3]!.value);
          }

          // Colonne 4 - 6 derniers mois 2026
          if (row.length > 4 && row[4] != null) {
            periode2_2026 = _parseDouble(row[4]!.value);
          }

          print('📊 Ligne $i: Appartement="$numAppartement", P1_2025=$periode1_2025, P2_2025=$periode2_2025, P1_2026=$periode1_2026, P2_2026=$periode2_2026');

          if (numAppartement.isEmpty) {
            print('⚠️ Ligne $i: Numéro d\'appartement vide, ignorée');
            continue;
          }

          // ✅ CRÉER LES COTISATIONS (seulement si montant > 0)
          int nbCotisations = 0;

          // 1. Période 1 - 2025
          if (periode1_2025 > 0) {
            cotisations.add(Cotisation(
              numAppartement: numAppartement,
              nomPrenom: numAppartement,
              dateVersement: DateTime(2025, 6, 30),
              modeVersement: 'espece',
              montant: periode1_2025,
              periode1: true,
              periode2: false,
              annee: 2025,
              synced: 0,
            ));
            nbCotisations++;
            print('✅ Ajouté 2025 S1: $numAppartement - ${periode1_2025} DH');
          }

          // 2. Période 2 - 2025
          if (periode2_2025 > 0) {
            cotisations.add(Cotisation(
              numAppartement: numAppartement,
              nomPrenom: numAppartement,
              dateVersement: DateTime(2025, 12, 31),
              modeVersement: 'espece',
              montant: periode2_2025,
              periode1: false,
              periode2: true,
              annee: 2025,
              synced: 0,
            ));
            nbCotisations++;
            print('✅ Ajouté 2025 S2: $numAppartement - ${periode2_2025} DH');
          }

          // 3. Période 1 - 2026
          if (periode1_2026 > 0) {
            cotisations.add(Cotisation(
              numAppartement: numAppartement,
              nomPrenom: numAppartement,
              dateVersement: DateTime(2026, 6, 30),
              modeVersement: 'espece',
              montant: periode1_2026,
              periode1: true,
              periode2: false,
              annee: 2026,
              synced: 0,
            ));
            nbCotisations++;
            print('✅ Ajouté 2026 S1: $numAppartement - ${periode1_2026} DH');
          }

          // 4. Période 2 - 2026
          if (periode2_2026 > 0) {
            cotisations.add(Cotisation(
              numAppartement: numAppartement,
              nomPrenom: numAppartement,
              dateVersement: DateTime(2026, 12, 31),
              modeVersement: 'espece',
              montant: periode2_2026,
              periode1: false,
              periode2: true,
              annee: 2026,
              synced: 0,
            ));
            nbCotisations++;
            print('✅ Ajouté 2026 S2: $numAppartement - ${periode2_2026} DH');
          }

          if (nbCotisations > 0) {
            importedCount++;
          } else {
            print('⚠️ Ligne $i: Aucun montant > 0 pour $numAppartement');
          }
          
        } catch (e) {
          errors.add('Erreur ligne ${i + 1}: $e');
          print('❌ Erreur import ligne ${i + 1}: $e');
        }
      }

      print('📊 === RÉSUMÉ IMPORT ===');
      print('📊 Lignes traitées: $importedCount');
      print('📊 Cotisations créées: ${cotisations.length}');
      print('📊 Erreurs: ${errors.length}');

      // ⬇️ SAUVEGARDER LES COTISATIONS
      int savedCount = 0;
      print('📊 Sauvegarde des cotisations...');
      
      for (var cotisation in cotisations) {
        try {
          if (kIsWeb) {
            // ✅ Web : sauvegarder directement dans Firestore
            final id = await _cotisationService.saveCotisationToFirestore(cotisation);
            cotisation.id = id;
            print('✅ Sauvegardé (Web): ${cotisation.numAppartement} - ${cotisation.montant} DH (ID: $id)');
          } else {
            // ✅ Mobile : SQLite puis synchro Firestore
            final id = await _cotisationService.insertCotisation(cotisation);
            if (id != null) {
              cotisation.id = id;
              await _cotisationService.syncCotisation(cotisation);
              print('✅ Sauvegardé (Mobile): ${cotisation.numAppartement} - ${cotisation.montant} DH (ID: $id)');
            } else {
              errors.add('Erreur sauvegarde ${cotisation.numAppartement}: ID null');
              continue;
            }
          }
          savedCount++;
        } catch (e) {
          errors.add('Erreur sauvegarde ${cotisation.numAppartement}: $e');
          print('❌ Erreur sauvegarde ${cotisation.numAppartement}: $e');
        }
      }

      print('📊 === FIN IMPORT ===');
      print('📊 Total sauvegardé: $savedCount / ${cotisations.length} cotisations');

      return {
        'success': errors.isEmpty || savedCount > 0,
        'message': errors.isEmpty 
            ? '✅ Importation réussie ! $savedCount cotisations importées.'
            : '⚠️ Importation partielle. $savedCount cotisations importées. ${errors.length} erreurs.',
        'imported': savedCount,
        'total': cotisations.length,
        'errors': errors,
      };

    } catch (e) {
      print('❌ Erreur import Excel: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return {
        'success': false,
        'message': 'Erreur lors de l\'import: ${e.toString().replaceAll('Exception: ', '')}',
        'imported': 0,
        'total': 0,
        'errors': [e.toString()],
      };
    }
  }

  // ⬇️ FONCTION DE PARSING AMÉLIORÉE
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    
    // Si c'est déjà un nombre
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    
    // Si c'est une chaîne
    if (value is String) {
      String cleaned = value.trim();
      if (cleaned.isEmpty) return 0.0;
      
      // ✅ Supprimer les séparateurs de milliers
      cleaned = cleaned.replaceAll(' ', '').replaceAll("'", '');
      
      // ✅ Remplacer la virgule par le point (format français)
      // Si la virgule est le dernier séparateur avant 2 chiffres
      if (cleaned.contains(',') && cleaned.indexOf(',') == cleaned.length - 3) {
        cleaned = cleaned.replaceAll(',', '.');
      } else if (cleaned.contains(',') && !cleaned.contains('.')) {
        // Format: 1.234,56 -> 1234.56
        cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else if (cleaned.contains(',') && cleaned.contains('.')) {
        // Format: 1,234.56 -> 1234.56
        cleaned = cleaned.replaceAll(',', '');
      }
      
      // ✅ Supprimer les caractères non numériques (sauf le point)
      cleaned = cleaned.replaceAll(RegExp(r'[^0-9.]'), '');
      
      if (cleaned.isEmpty) return 0.0;
      
      final parsed = double.tryParse(cleaned);
      return parsed ?? 0.0;
    }
    
    return 0.0;
  }
}