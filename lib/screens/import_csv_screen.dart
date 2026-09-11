// lib/screens/import_csv_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import '../services/csv_import_service.dart';

// ⬇️ SUPPRIMER import 'dart:io'; (non disponible sur le web)

class ImportCsvScreen extends StatefulWidget {
  const ImportCsvScreen({super.key});

  @override
  State<ImportCsvScreen> createState() => _ImportCsvScreenState();
}

class _ImportCsvScreenState extends State<ImportCsvScreen> {
  final CsvImportService _importService = CsvImportService();
  bool _isLoading = false;
  String _statusMessage = '';
  bool _isSuccess = false;
  int _importedCount = 0;
  List<String> _errors = [];

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _importCsv() async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Sélection du fichier...';
        _errors = [];
        _isSuccess = false;
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        dialogTitle: 'Sélectionner un fichier CSV',
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

      final resultImport = await _importService.importCotisationsFromCsv(bytes);

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
        title: const Text('📥 Importer CSV'),
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
            Icon(Icons.upload_file, size: 80, color: Colors.green.shade700),
            const SizedBox(height: 20),
            const Text(
              '📊 Importer des cotisations (CSV)',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                  Text('• Colonne 1: Numéro d\'appartement (ex: A1)', style: TextStyle(fontSize: 13)),
                  Text('• Colonne 2: 6 premiers mois 2025', style: TextStyle(fontSize: 13)),
                  Text('• Colonne 3: 6 derniers mois 2025', style: TextStyle(fontSize: 13)),
                  Text('• Colonne 4: 6 premiers mois 2026', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('📌 Séparateur: ; ou ,', style: TextStyle(fontSize: 13, color: Colors.blue.shade700)),
                  Text('📌 Exemple: A1;1800;1800;0', style: TextStyle(fontSize: 13, color: Colors.blue.shade700)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_statusMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isSuccess ? Colors.green.shade200 : Colors.red.shade200,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _isSuccess ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_errors.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ..._errors.take(3).map((error) => 
                        Text(
                          '• $error',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ),
                      if (_errors.length > 3)
                        Text(
                          '... et ${_errors.length - 3} autre(s) erreur(s)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _importCsv,
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
              label: Text(_isLoading ? 'Import en cours...' : '📤 Choisir un fichier CSV'),
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
              onPressed: () => Navigator.pop(context, true),
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