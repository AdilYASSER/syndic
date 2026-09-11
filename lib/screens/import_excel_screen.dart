// lib/screens/import_excel_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import '../services/excel_import_service.dart';
import '../services/cotisation_service.dart';

// ⬇️ SUPPRIMER import 'dart:io'; (non disponible sur le web)

class ImportExcelScreen extends StatefulWidget {
  const ImportExcelScreen({super.key});

  @override
  State<ImportExcelScreen> createState() => _ImportExcelScreenState();
}

class _ImportExcelScreenState extends State<ImportExcelScreen> {
  final ExcelImportService _importService = ExcelImportService();
  final CotisationService _cotisationService = CotisationService();
  bool _isLoading = false;
  String _statusMessage = '';
  bool _isSuccess = false;
  int _importedCount = 0;
  List<String> _errors = [];

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _importExcel() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _statusMessage = 'Sélection du fichier...';
        _errors = [];
        _isSuccess = false;
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        dialogTitle: 'Sélectionner un fichier Excel',
      );

      if (result == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _statusMessage = 'Import annulé';
          });
        }
        return;
      }

      final file = result.files.first;
      
      if (file.bytes == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _statusMessage = 'Erreur: fichier vide';
            _isSuccess = false;
          });
        }
        return;
      }

      final bytes = file.bytes!;

      if (mounted) {
        setState(() {
          _statusMessage = 'Import en cours...';
        });
      }

      final resultImport = await _importService.importCotisationsFromExcel(bytes);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSuccess = resultImport['success'] ?? false;
          _statusMessage = resultImport['message'] ?? 'Import terminé';
          _importedCount = resultImport['imported'] ?? 0;
          _errors = List<String>.from(resultImport['errors'] ?? []);
        });
      }

      if (_isSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${_importedCount} cotisations importées'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSuccess = false;
          _statusMessage = 'Erreur: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📥 Importer Excel'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.file_upload,
              size: 80,
              color: Colors.green.shade700,
            ),
            const SizedBox(height: 20),
            const Text(
              '📊 Importer des cotisations (Excel)',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📋 Format attendu :',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text('• Colonne A: Numéro d\'appartement (ex: A1)', style: TextStyle(fontSize: 13)),
                  Text('• Colonne B: 6 premiers mois 2025', style: TextStyle(fontSize: 13)),
                  Text('• Colonne C: 6 derniers mois 2025', style: TextStyle(fontSize: 13)),
                  Text('• Colonne D: 6 premiers mois 2026', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('📌 Fichiers acceptés: .xlsx ou .xls', style: TextStyle(fontSize: 13, color: Colors.blue.shade700)),
                  Text('📌 Exemple: A1 | 1800 | 1800 | 0', style: TextStyle(fontSize: 13, color: Colors.blue.shade700)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_statusMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isSuccess 
                      ? Colors.green.shade50 
                      : (_isLoading 
                          ? Colors.blue.shade50 
                          : Colors.red.shade50),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isSuccess 
                        ? Colors.green.shade200 
                        : (_isLoading 
                            ? Colors.blue.shade200 
                            : Colors.red.shade200),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isSuccess 
                              ? Icons.check_circle 
                              : (_isLoading 
                                  ? Icons.info 
                                  : Icons.error),
                          color: _isSuccess 
                              ? Colors.green 
                              : (_isLoading 
                                  ? Colors.blue 
                                  : Colors.red),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _statusMessage,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _isSuccess 
                                  ? Colors.green.shade700 
                                  : (_isLoading 
                                      ? Colors.blue.shade700 
                                      : Colors.red.shade700),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_errors.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _errors.take(3).map((error) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Icon(Icons.warning, size: 14, color: Colors.orange.shade700),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    error,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )).toList(),
                        ),
                      ),
                    if (_importedCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '📊 ${_importedCount} cotisations importées',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _importExcel,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(_isLoading ? 'Import en cours...' : '📤 Choisir un fichier Excel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isLoading ? Colors.grey.shade600 : Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context, true);
              },
              icon: const Icon(Icons.list),
              label: const Text('📋 Voir les cotisations'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}