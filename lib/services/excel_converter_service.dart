// lib/services/excel_converter_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ExcelConverterService {
  
  // ✅ Convertir un fichier Excel en CSV
  static Future<Uint8List> convertExcelToCSV(Uint8List excelBytes) async {
    try {
      print('🔄 ===== CONVERSION EXCEL → CSV =====');
      print('📊 Taille du fichier: ${excelBytes.length} bytes');
      
      // ✅ Lire le fichier Excel
      final excel = Excel.decodeBytes(excelBytes);
      
      if (excel.tables.isEmpty) {
        throw Exception('Fichier Excel vide');
      }
      
      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null) {
        throw Exception('Feuille Excel vide');
      }
      
      print('📊 Lignes trouvées: ${sheet.rows.length}');
      
      // Afficher les 3 premières lignes
      for (var i = 0; i < sheet.rows.length && i < 3; i++) {
        final row = sheet.rows[i];
        final rowData = row.map((cell) => cell?.value?.toString() ?? 'VIDE').join(' | ');
        print('📝 Ligne $i: $rowData');
      }
      
      // Construire le contenu CSV
      List<String> csvLines = [];
      bool isHeader = true;
      int dataLines = 0;
      int rowIndex = 0;
      
      for (var row in sheet.rows) {
        rowIndex++;
        if (row.isEmpty) continue;
        
        // Nettoyer les cellules
        List<String> cells = [];
        for (var cell in row) {
          String value = cell?.value?.toString()?.trim() ?? '';
          // Nettoyer la valeur
          value = value.replaceAll('"', '""');
          if (value.contains(',') || value.contains(';') || value.contains('"') || value.contains('\n')) {
            value = '"$value"';
          }
          cells.add(value);
        }
        
        // Compléter avec des cellules vides si nécessaire
        while (cells.length < 6) {
          cells.add('');
        }
        
        // Ligne d'en-tête
        if (isHeader) {
          isHeader = false;
          // Vérifier si c'est une vraie en-tête
          if (cells.any((c) => c.contains('Libellé') || c.contains('Date') || c.contains('Débit'))) {
            csvLines.add(cells.join(','));
            print('📋 En-tête trouvée');
          } else {
            // Ajouter une en-tête standard
            csvLines.add('"Libellé","Date d\'opération","Date de valeur","Débit (MAD)","Crédit (MAD)","Num. Pièce"');
            // Ajouter la ligne comme donnée
            csvLines.add(cells.join(','));
            dataLines++;
            print('📋 En-tête standard ajoutée');
          }
          continue;
        }
        
        // Vérifier si la ligne a du contenu
        bool hasData = cells.any((c) => c.isNotEmpty && c != '""' && c != '"0"' && c != '""""');
        if (hasData) {
          csvLines.add(cells.join(','));
          dataLines++;
          print('📝 Ligne $rowIndex: ${cells[0].substring(0, cells[0].length > 30 ? 30 : cells[0].length)}...');
        }
      }
      
      if (csvLines.length <= 1) {
        throw Exception('Aucune donnée trouvée');
      }
      
      String csvContent = csvLines.join('\n');
      
      print('📊 RÉSUMÉ CONVERSION:');
      print('   📋 Lignes totales: ${csvContent.split('\n').length}');
      print('   📊 Lignes de données: $dataLines');
      print('   📏 Taille CSV: ${csvContent.length} bytes');
      
      return Uint8List.fromList(utf8.encode(csvContent));
      
    } catch (e) {
      print('❌ Erreur conversion: $e');
      rethrow;
    }
  }
}