// lib/services/pdf_storage_service.dart
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;

class PdfStorageService {
  static const String PDFS_FILE = 'pdfs_list.json';
  static const String PDFS_FOLDER = 'pdfs_storage';
  
  // ⬇️ CACHE POUR LE WEB
  static final Map<String, Uint8List> _webCache = {};

  static Future<String> get _storagePath async {
    if (kIsWeb) {
      return '';
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      final pdfDir = Directory('${appDir.path}/$PDFS_FOLDER');
      if (!await pdfDir.exists()) {
        await pdfDir.create(recursive: true);
      }
      return pdfDir.path;
    }
  }

  // ⬇️ SAUVEGARDER LA LISTE DES PDFS
  static Future<void> savePdfsList(List<Map<String, dynamic>> pdfs) async {
    try {
      if (kIsWeb) {
        final jsonData = jsonEncode(pdfs.map((pdf) {
          return {
            'name': pdf['name'],
            'file': pdf['file'],
            'categorie': pdf['categorie'],
            'date': pdf['date'],
            'size': pdf['size'],
            'isLocal': true,
          };
        }).toList());
        html.window.localStorage[PDFS_FILE] = jsonData;
        
        for (var pdf in pdfs) {
          if (pdf['bytes'] != null) {
            _webCache[pdf['file']] = pdf['bytes'];
          }
        }
      } else {
        final path = await _storagePath;
        final file = File('$path/$PDFS_FILE');
        final jsonData = jsonEncode(pdfs.map((pdf) {
          return {
            'name': pdf['name'],
            'file': pdf['file'],
            'categorie': pdf['categorie'],
            'date': pdf['date'],
            'size': pdf['size'],
            'isLocal': true,
          };
        }).toList());
        await file.writeAsString(jsonData);
      }
      print('✅ Liste des PDFs sauvegardée');
    } catch (e) {
      print('❌ Erreur sauvegarde liste PDFs: $e');
    }
  }

  // ⬇️ CHARGER LA LISTE DES PDFS
  static Future<List<Map<String, dynamic>>> loadPdfsList() async {
    try {
      List<Map<String, dynamic>> pdfs = [];
      
      if (kIsWeb) {
        final jsonData = html.window.localStorage[PDFS_FILE];
        if (jsonData != null && jsonData.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(jsonData);
          pdfs = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
          
          for (var pdf in pdfs) {
            final cachedBytes = _webCache[pdf['file']];
            if (cachedBytes != null) {
              pdf['bytes'] = cachedBytes;
            }
          }
        }
      } else {
        final path = await _storagePath;
        final file = File('$path/$PDFS_FILE');
        if (await file.exists()) {
          final jsonData = await file.readAsString();
          if (jsonData.isNotEmpty) {
            final List<dynamic> decoded = jsonDecode(jsonData);
            pdfs = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
          }
        }
      }
      
      print('✅ ${pdfs.length} PDFs chargés');
      return pdfs;
    } catch (e) {
      print('❌ Erreur chargement liste PDFs: $e');
      return [];
    }
  }

  // ⬇️ SAUVEGARDER UN FICHIER PDF
  static Future<void> savePdfFile(String fileName, Uint8List bytes) async {
    try {
      if (kIsWeb) {
        _webCache[fileName] = bytes;
        print('✅ PDF sauvegardé en cache: $fileName');
      } else {
        final path = await _storagePath;
        final file = File('$path/$fileName');
        await file.writeAsBytes(bytes);
        print('✅ PDF sauvegardé: $fileName');
      }
    } catch (e) {
      print('❌ Erreur sauvegarde PDF: $e');
    }
  }

  // ⬇️ CHARGER UN FICHIER PDF
  static Future<Uint8List?> loadPdfFile(String fileName) async {
    try {
      if (kIsWeb) {
        final cachedBytes = _webCache[fileName];
        if (cachedBytes != null) {
          return cachedBytes;
        }
        return null;
      } else {
        final path = await _storagePath;
        final file = File('$path/$fileName');
        if (await file.exists()) {
          return await file.readAsBytes();
        }
        return null;
      }
    } catch (e) {
      print('❌ Erreur chargement PDF: $e');
      return null;
    }
  }

  // ⬇️ SUPPRIMER UN FICHIER PDF
  static Future<void> deletePdfFile(String fileName) async {
    try {
      if (kIsWeb) {
        _webCache.remove(fileName);
        print('✅ PDF supprimé du cache: $fileName');
      } else {
        final path = await _storagePath;
        final file = File('$path/$fileName');
        if (await file.exists()) {
          await file.delete();
          print('✅ PDF supprimé: $fileName');
        }
      }
    } catch (e) {
      print('❌ Erreur suppression PDF: $e');
    }
  }

  // ⬇️ SUPPRIMER TOUS LES PDFS
  static Future<void> deleteAllPdfFiles() async {
    try {
      if (kIsWeb) {
        html.window.localStorage.remove(PDFS_FILE);
        _webCache.clear();
        print('✅ Tous les PDFs supprimés (web)');
      } else {
        final path = await _storagePath;
        final dir = Directory(path);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
          await dir.create(recursive: true);
          print('✅ Tous les PDFs supprimés');
        }
      }
    } catch (e) {
      print('❌ Erreur suppression tous les PDFs: $e');
    }
  }

  // ⬇️ EXPORTER LES PDFS VERS UN DOSSIER (pour les sauvegarder sur PC)
  static Future<void> exportPdfsToFolder() async {
    if (kIsWeb) {
      print('⚠️ Export non disponible sur le web');
      return;
    }

    try {
      final pdfs = await loadPdfsList();
      if (pdfs.isEmpty) {
        print('⚠️ Aucun PDF à exporter');
        return;
      }

      final exportDir = await getExternalStorageDirectory();
      if (exportDir == null) {
        print('❌ Impossible d\'accéder au stockage externe');
        return;
      }

      final exportPath = '${exportDir.path}/ExportedPDFs';
      final dir = Directory(exportPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      int count = 0;
      for (var pdf in pdfs) {
        final bytes = await loadPdfFile(pdf['file']);
        if (bytes != null) {
          final file = File('$exportPath/${pdf['file']}');
          await file.writeAsBytes(bytes);
          count++;
        }
      }

      print('✅ $count PDFs exportés vers: $exportPath');
    } catch (e) {
      print('❌ Erreur export: $e');
    }
  }
}