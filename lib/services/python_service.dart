// lib/services/python_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:process_run/process_run.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PythonService {
  static const String PYTHON_SCRIPT = 'excel_to_csv_converter.py';
  
  // ✅ Vérifier si Python est installé
  static Future<bool> isPythonInstalled() async {
    try {
      final result = await runCmd('python', ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
  
  // ✅ Vérifier si pandas est installé
  static Future<bool> isPandasInstalled() async {
    try {
      final result = await runCmd('python', ['-c', 'import pandas; print(pandas.__version__)']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
  
  // ✅ Installer pandas
  static Future<bool> installPandas() async {
    try {
      final result = await runCmd('pip', ['install', 'pandas', 'openpyxl']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
  
  // ✅ Exécuter une commande
  static Future<ProcessResult> runCmd(String command, List<String> args) async {
    return await Process.run(command, args);
  }
  
  // ✅ Convertir un fichier Excel en CSV
  static Future<Map<String, dynamic>> convertExcelToCSV(String excelPath) async {
    try {
      final scriptPath = await getScriptPath();
      
      print('🐍 Conversion via Python: $excelPath');
      
      final result = await Process.run(
        'python',
        [scriptPath, 'convert', excelPath],
        runInShell: true,
      );
      
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        print('📊 Résultat Python: $output');
        return jsonDecode(output);
      } else {
        print('❌ Erreur Python: ${result.stderr}');
        return {'success': false, 'error': result.stderr.toString()};
      }
    } catch (e) {
      print('❌ Erreur conversion: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
  
  // ✅ Convertir plusieurs fichiers Excel en CSV
  static Future<List<Map<String, dynamic>>> convertMultipleExcelToCSV(List<String> excelPaths) async {
    try {
      final scriptPath = await getScriptPath();
      final pathsString = excelPaths.join('|');
      
      print('🐍 Conversion multiple via Python: ${excelPaths.length} fichiers');
      
      final result = await Process.run(
        'python',
        [scriptPath, 'convert_multiple', pathsString],
        runInShell: true,
      );
      
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        print('📊 Résultat Python: $output');
        return List<Map<String, dynamic>>.from(jsonDecode(output));
      } else {
        print('❌ Erreur Python: ${result.stderr}');
        return [];
      }
    } catch (e) {
      print('❌ Erreur conversion multiple: $e');
      return [];
    }
  }
  
  // ✅ Obtenir le chemin du script Python
  static Future<String> getScriptPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final scriptPath = '${dir.path}/$PYTHON_SCRIPT';
    
    // Copier le script depuis les assets s'il n'existe pas
    final scriptFile = File(scriptPath);
    if (!await scriptFile.exists()) {
      // Pour le Web, utiliser une approche différente
      if (kIsWeb) {
        throw Exception('Python n\'est pas supporté sur le Web');
      }
      
      // Créer le script
      await scriptFile.writeAsString('''
import pandas as pd
import sys
import os
import json
from pathlib import Path

def convert_excel_to_csv(excel_path, csv_path=None):
    try:
        df = pd.read_excel(excel_path, header=1, dtype=str)
        df.columns = ['Libellé', "Date d'opération", 'Date de valeur', 'Débit (MAD)', 'Crédit (MAD)', 'Num. Pièce']
        df = df.dropna(how='all')
        df = df[df['Libellé'].notna()]
        df = df[df['Libellé'] != '']
        df = df[df['Libellé'] != ' ']
        
        if csv_path is None:
            csv_path = str(Path(excel_path).with_suffix('.csv'))
        
        df.to_csv(csv_path, index=False, encoding='utf-8-sig')
        
        return {'success': True, 'csv_path': csv_path, 'rows': len(df), 'columns': list(df.columns)}
    except Exception as e:
        return {'success': False, 'error': str(e)}

def convert_multiple_excel_to_csv(excel_paths):
    results = []
    for excel_path in excel_paths:
        result = convert_excel_to_csv(excel_path)
        results.append(result)
    return results

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(json.dumps({'success': False, 'error': 'Aucun fichier spécifié'}))
        sys.exit(1)
    
    action = sys.argv[1]
    
    if action == 'convert':
        excel_path = sys.argv[2]
        result = convert_excel_to_csv(excel_path)
        print(json.dumps(result))
    elif action == 'convert_multiple':
        excel_paths = sys.argv[2].split('|')
        results = convert_multiple_excel_to_csv(excel_paths)
        print(json.dumps(results))
    else:
        print(json.dumps({'success': False, 'error': 'Action inconnue'}))
''');
    }
    
    return scriptPath;
  }
}