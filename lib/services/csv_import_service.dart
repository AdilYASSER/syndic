// lib/services/csv_import_service.dart
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/cotisation.dart';
import '../services/cotisation_service.dart';

class CsvImportService {
  final CotisationService _cotisationService = CotisationService();

  Future<Map<String, dynamic>> importCotisationsFromCsv(Uint8List bytes) async {
    try {
      final String content = utf8.decode(bytes);
      final List<String> lines = content.split('\n');

      if (lines.isEmpty) {
        return {
          'success': false,
          'message': 'Le fichier CSV est vide',
          'imported': 0,
        };
      }

      print('📊 === DÉBUT IMPORT CSV ===');
      print('📊 Nombre de lignes: ${lines.length}');

      List<Cotisation> cotisations = [];
      int importedCount = 0;
      List<String> errors = [];

      // ✅ Détection de l'en-tête
      int startRow = 0;
      if (lines.isNotEmpty) {
        final firstLine = lines[0].trim().toLowerCase();
        if (firstLine.contains('num') || 
            firstLine.contains('appartement') ||
            firstLine.contains('appart') ||
            firstLine.contains('période')) {
          startRow = 1;
          print('📊 Ligne 0 est un en-tête, on commence à la ligne 1');
        }
      }

      for (int i = startRow; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        try {
          // ✅ Détection du séparateur
          List<String> parts;
          if (line.contains(';')) {
            parts = line.split(';');
          } else if (line.contains('\t')) {
            parts = line.split('\t');
          } else {
            parts = line.split(',');
          }

          parts = parts.map((p) => p.trim().replaceAll('"', '')).toList();

          // ✅ Supprimer les colonnes vides en fin de ligne
          while (parts.isNotEmpty && parts.last.isEmpty) {
            parts.removeLast();
          }

          if (parts.length < 5) {
            errors.add('Ligne ${i + 1}: Format incorrect (${parts.length} colonnes, attendu 5)');
            continue;
          }

          final numAppartement = parts[0].trim();
          if (numAppartement.isEmpty) {
            errors.add('Ligne ${i + 1}: Numéro d\'appartement vide');
            continue;
          }

          // ✅ Extraire les montants (supporte plusieurs formats)
          final periode1_2025 = _parseDouble(parts[1].trim());
          final periode2_2025 = _parseDouble(parts[2].trim());
          final periode1_2026 = _parseDouble(parts[3].trim());
          final periode2_2026 = _parseDouble(parts[4].trim());

          print('📊 Ligne $i: Appartement="$numAppartement", P1_2025=$periode1_2025, P2_2025=$periode2_2025, P1_2026=$periode1_2026, P2_2026=$periode2_2026');

          // ✅ CRÉER 4 COTISATIONS (une par période)
          // Période 1 - 2025 (Janvier-Juin)
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
          }

          // Période 2 - 2025 (Juillet-Décembre)
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
          }

          // Période 1 - 2026 (Janvier-Juin)
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
          }

          // Période 2 - 2026 (Juillet-Décembre)
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
          }

          importedCount++;
          print('✅ Ligne $i: ${cotisations.length} cotisations ajoutées');

        } catch (e) {
          errors.add('Erreur ligne ${i + 1}: $e');
          print('❌ Erreur import ligne ${i + 1}: $e');
        }
      }

      print('📊 Total: ${cotisations.length} cotisations à importer');

      // ✅ Sauvegarde des cotisations
      int savedCount = 0;
      for (var cotisation in cotisations) {
        try {
          if (kIsWeb) {
            // ✅ Web : sauvegarder directement dans Firestore
            final id = await _cotisationService.saveCotisationToFirestore(cotisation);
            cotisation.id = id;
            print('✅ Sauvegardé (Web): ${cotisation.numAppartement} (ID: $id)');
          } else {
            // ✅ Mobile : SQLite puis synchro Firestore
            final id = await _cotisationService.insertCotisation(cotisation);
            if (id != null) {
              cotisation.id = id;
              await _cotisationService.syncCotisation(cotisation);
              print('✅ Sauvegardé (Mobile): ${cotisation.numAppartement} (ID: $id)');
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
      print('📊 Importés: $savedCount / ${cotisations.length}');
      print('📊 Erreurs: ${errors.length}');

      return {
        'success': errors.isEmpty || savedCount > 0,
        'message': errors.isEmpty
            ? '✅ Importation réussie ! $savedCount cotisations importées sur ${cotisations.length}.'
            : '⚠️ Importation partielle. $savedCount cotisations importées. ${errors.length} erreurs.',
        'imported': savedCount,
        'total': cotisations.length,
        'errors': errors,
      };
    } catch (e) {
      print('❌ Erreur générale: $e');
      return {
        'success': false,
        'message': '❌ Erreur: $e',
        'imported': 0,
        'errors': [e.toString()],
      };
    }
  }

  double _parseDouble(String value) {
    if (value.isEmpty) return 0.0;
    try {
      // ✅ Nettoyer la valeur
      String cleaned = value
          .replaceAll(' ', '')
          .replaceAll('"', '')
          .replaceAll('€', '')
          .replaceAll('DH', '')
          .replaceAll('dh', '')
          .trim();
      
      // ✅ Gérer les séparateurs (virgule ou point)
      // D'abord remplacer les virgules par des points (format français)
      if (cleaned.contains(',') && !cleaned.contains('.') && cleaned.indexOf(',') == cleaned.length - 3) {
        cleaned = cleaned.replaceAll(',', '.');
      } else if (cleaned.contains(',') && !cleaned.contains('.')) {
        // Format: 1.234,56 -> 1234.56
        cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else if (cleaned.contains(',') && cleaned.contains('.')) {
        // Format: 1,234.56 -> 1234.56
        cleaned = cleaned.replaceAll(',', '');
      }
      
      return double.tryParse(cleaned) ?? 0.0;
    } catch (e) {
      print('⚠️ Erreur parse double: $value -> $e');
      return 0.0;
    }
  }
}