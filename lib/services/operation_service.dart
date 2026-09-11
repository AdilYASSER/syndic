// lib/services/operation_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/operation.dart';

class OperationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  static const String COLLECTION = 'operations';
  static const String STORAGE_PATH = 'operations_excel';

  // ✅ Importer un fichier CSV UNIQUEMENT
  Future<Map<String, dynamic>> importCSVFromBytes(Uint8List bytes, String fileName) async {
    try {
      print('📄 ===== IMPORT CSV: $fileName =====');
      print('📊 Taille du fichier: ${bytes.length} bytes');

      final content = utf8.decode(bytes, allowMalformed: true);
      final lines = content.split('\n');

      print('📊 Nombre de lignes: ${lines.length}');

      // Afficher les 5 premières lignes pour debug
      for (var i = 0; i < lines.length && i < 5; i++) {
        final line = lines[i].trim();
        if (line.isNotEmpty) {
          print('📝 Ligne $i: ${line.substring(0, line.length > 80 ? 80 : line.length)}');
        }
      }

      List<Operation> operations = [];
      int lignesImportees = 0;
      int doublons = 0;
      int lignesErreur = 0;

      bool isHeader = true;
      int rowIndex = 0;

      for (var line in lines) {
        rowIndex++;
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) continue;

        if (isHeader) {
          isHeader = false;
          print('📋 En-tête: $trimmedLine');
          continue;
        }

        // ✅ Extraire les données CSV avec gestion des guillemets
        List<String> parts = _parseCSVLine(trimmedLine);

        // ✅ Si le séparateur est un point-virgule
        if (parts.length < 3 && trimmedLine.contains(';')) {
          parts = trimmedLine.split(';').map((p) => p.trim()).toList();
        }
        // ✅ Si le séparateur est une tabulation
        else if (parts.length < 3 && trimmedLine.contains('\t')) {
          parts = trimmedLine.split('\t').map((p) => p.trim()).toList();
        }

        if (parts.length < 6) {
          print('⚠️ Ligne $rowIndex: colonnes insuffisantes (${parts.length})');
          lignesErreur++;
          continue;
        }

        try {
          final libelle = parts[0].replaceAll('"', '').trim();
          final dateOpStr = parts[1].replaceAll('"', '').trim();
          final dateValStr = parts[2].replaceAll('"', '').trim();
          final debitStr = parts[3].replaceAll('"', '').trim();
          final creditStr = parts[4].replaceAll('"', '').trim();
          final numPiece = parts.length > 5 ? parts[5].replaceAll('"', '').trim() : '';

          if (libelle.isEmpty || dateOpStr.isEmpty) {
            print('⚠️ Ligne $rowIndex: libelle ou date vide');
            lignesErreur++;
            continue;
          }

          print('📝 Ligne $rowIndex: $libelle | $dateOpStr');

          final dateOperation = _parseDate(dateOpStr);
          if (dateOperation == null) {
            print('⚠️ Ligne $rowIndex: date invalide ($dateOpStr)');
            lignesErreur++;
            continue;
          }

          final operation = Operation(
            id: '',
            libelle: libelle,
            dateOperation: dateOperation,
            dateValeur: _parseDate(dateValStr) ?? dateOperation,
            debit: _parseDouble(debitStr),
            credit: _parseDouble(creditStr),
            numPiece: numPiece,
            fichierSource: fileName,
            dateImport: DateTime.now(),
          );

          final exists = await _checkDuplicate(operation);
          if (!exists) {
            operations.add(operation);
            lignesImportees++;
            print('✅ Ligne $rowIndex importée: $libelle');
          } else {
            doublons++;
            print('⚠️ Ligne $rowIndex: doublon ignoré: $libelle');
          }
        } catch (e) {
          lignesErreur++;
          print('❌ Erreur ligne $rowIndex: $e');
        }
      }

      print('📊 RÉSUMÉ FINAL:');
      print('   ✅ Importées: $lignesImportees');
      print('   ⚠️ Doublons: $doublons');
      print('   ❌ Erreurs: $lignesErreur');

      // ✅ Sauvegarde en batch pour plus d'efficacité
      if (operations.isNotEmpty) {
        final batch = _firestore.batch();
        for (var op in operations) {
          final docRef = _firestore.collection(COLLECTION).doc();
          batch.set(docRef, op.toMap());
        }
        await batch.commit();
        print('✅ ${operations.length} opérations sauvegardées en batch');
      }

      return {
        'success': true,
        'lignesImportees': lignesImportees,
        'doublons': doublons,
        'erreurs': lignesErreur,
        'total': lignesImportees + doublons + lignesErreur,
      };
    } catch (e) {
      print('❌ Erreur import CSV: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ✅ Importer un fichier CSV (avec fichier)
  Future<Map<String, dynamic>> importCSV(File file, String fileName) async {
    try {
      final bytes = await file.readAsBytes();
      return await importCSVFromBytes(bytes, fileName);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ✅ Parse une ligne CSV avec gestion des guillemets
  List<String> _parseCSVLine(String line) {
    List<String> parts = [];
    StringBuffer current = StringBuffer();
    bool inQuotes = false;

    for (var char in line.split('')) {
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        parts.add(current.toString().trim());
        current.clear();
      } else {
        current.write(char);
      }
    }
    parts.add(current.toString().trim());

    return parts;
  }

  Future<bool> _checkDuplicate(Operation operation) async {
    try {
      final snapshot = await _firestore
          .collection(COLLECTION)
          .where('libelle', isEqualTo: operation.libelle)
          .where('dateOperation', isEqualTo: operation.dateOperation.toIso8601String())
          .where('debit', isEqualTo: operation.debit)
          .where('credit', isEqualTo: operation.credit)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Stream<List<Operation>> getAllOperations() {
    return _firestore
        .collection(COLLECTION)
        .orderBy('dateOperation', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Operation.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  Stream<List<Operation>> getOperationsByDate(DateTime debut, DateTime fin) {
    final debutStr = debut.toIso8601String();
    final finStr = fin.toIso8601String();

    return _firestore
        .collection(COLLECTION)
        .where('dateOperation', isGreaterThanOrEqualTo: debutStr)
        .where('dateOperation', isLessThanOrEqualTo: finStr)
        .orderBy('dateOperation', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Operation.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  Future<void> deleteOperation(String id) async {
    try {
      await _firestore.collection(COLLECTION).doc(id).delete();
    } catch (e) {
      print('❌ Erreur suppression: $e');
      rethrow;
    }
  }

  Future<void> deleteAllOperations() async {
    try {
      final snapshot = await _firestore.collection(COLLECTION).get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('❌ Erreur suppression tout: $e');
      rethrow;
    }
  }

  // ✅ Méthode d'export (corrigée avec "Excel" au lieu de "ExcelLib")
  Future<File> exportOperations(List<Operation> operations) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Opérations'];

      sheet.appendRow([
        TextCellValue('Libellé'),
        TextCellValue("Date d'opération"),
        TextCellValue('Date de valeur'),
        TextCellValue('Débit (MAD)'),
        TextCellValue('Crédit (MAD)'),
        TextCellValue('Num. Pièce'),
      ]);

      for (var op in operations) {
        sheet.appendRow([
          TextCellValue(op.libelle),
          TextCellValue(DateFormat('dd/MM/yyyy').format(op.dateOperation)),
          TextCellValue(DateFormat('dd/MM/yyyy').format(op.dateValeur)),
          TextCellValue(op.debit > 0 ? op.debit.toStringAsFixed(2) : ''),
          TextCellValue(op.credit > 0 ? op.credit.toStringAsFixed(2) : ''),
          TextCellValue(op.numPiece),
        ]);
      }

      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/operations_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);

      return file;
    } catch (e) {
      print('❌ Erreur export: $e');
      rethrow;
    }
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      String clean = value.trim().replaceAll('"', '');

      // Format: DD/MM/YYYY
      final parts = clean.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0].trim());
        final month = int.parse(parts[1].trim());
        final year = int.parse(parts[2].trim());
        return DateTime(year, month, day);
      }

      // Format: YYYY-MM-DD
      final parts2 = clean.split('-');
      if (parts2.length == 3) {
        final year = int.parse(parts2[0].trim());
        final month = int.parse(parts2[1].trim());
        final day = int.parse(parts2[2].trim());
        return DateTime(year, month, day);
      }

      // Format: DD-MM-YYYY
      final parts3 = clean.split('-');
      if (parts3.length == 3 && parts3[0].length == 2) {
        final day = int.parse(parts3[0].trim());
        final month = int.parse(parts3[1].trim());
        final year = int.parse(parts3[2].trim());
        return DateTime(year, month, day);
      }

      print('⚠️ Date non reconnue: $value');
      return null;
    } catch (e) {
      print('❌ Erreur parse date: $value -> $e');
      return null;
    }
  }

  double _parseDouble(String? value) {
    if (value == null || value.isEmpty) return 0.0;
    try {
      String clean = value
          .replaceAll(' ', '')
          .replaceAll(',', '.')
          .replaceAll(' ', '')
          .replaceAll('"', '')
          .replaceAll('€', '');

      if (clean.isEmpty) return 0.0;
      return double.parse(clean);
    } catch (e) {
      print('❌ Erreur parse double: $value -> $e');
      return 0.0;
    }
  }
}