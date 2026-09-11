// lib/screens/operations_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' as ExcelLib;
import '../models/operation.dart';
import '../services/operation_service.dart';

class OperationsScreen extends StatefulWidget {
  const OperationsScreen({super.key});

  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  final OperationService _service = OperationService();
  List<Operation> _operations = [];
  bool _isLoading = true;
  bool _isImporting = false;

  // ✅ Filtres
  String _filtreLibelle = '';
  DateTime? _dateDebut;
  DateTime? _dateFin;
  String _filtreNumPiece = '';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _numPieceController = TextEditingController();
  bool _triAscendant = false;

  @override
  void initState() {
    super.initState();
    _loadOperations();
    _searchController.addListener(() {
      setState(() {
        _filtreLibelle = _searchController.text;
      });
    });
    _numPieceController.addListener(() {
      setState(() {
        _filtreNumPiece = _numPieceController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _numPieceController.dispose();
    super.dispose();
  }

  Future<void> _loadOperations() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('operations')
          .orderBy('dateOperation', descending: true)
          .get();

      _operations = snapshot.docs.map((doc) {
        return Operation.fromMap(doc.id, doc.data());
      }).toList();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('❌ Erreur: $e', Colors.red);
    }
  }

  // ✅ IMPORTER CSV UNIQUEMENT (suppression de _importWithPython)
  Future<void> _importCSV() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: true,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => _isImporting = true);

      int totalImportes = 0;
      int totalDoublons = 0;
      int totalFichiers = result.files.length;
      int totalErreurs = 0;

      for (var file in result.files) {
        try {
          final fileName = file.name;
          final bytes = file.bytes;

          if (bytes == null) {
            totalErreurs++;
            continue;
          }

          final resultImport = await _service.importCSVFromBytes(bytes, fileName);

          if (resultImport['success'] == true) {
            totalImportes += (resultImport['lignesImportees'] as num?)?.toInt() ?? 0;
            totalDoublons += (resultImport['doublons'] as num?)?.toInt() ?? 0;
          } else {
            totalErreurs++;
            print('❌ Erreur import ${file.name}: ${resultImport['error']}');
          }
        } catch (e) {
          print('❌ Erreur import ${file.name}: $e');
          totalErreurs++;
        }
      }

      setState(() => _isImporting = false);

      String message = '✅ $totalImportes importées';
      if (totalDoublons > 0) message += ', $totalDoublons doublons ignorés';
      if (totalErreurs > 0) message += ', $totalErreurs erreurs';
      message += ' sur $totalFichiers fichier(s)';

      _showSnackBar(message, totalImportes > 0 ? Colors.green : Colors.orange);
      _loadOperations();
    } catch (e) {
      setState(() => _isImporting = false);
      _showSnackBar('❌ Erreur: $e', Colors.red);
    }
  }

  Future<void> _exportExcel() async {
    try {
      final filtered = _getFilteredOperations();
      if (filtered.isEmpty) {
        _showSnackBar('⚠️ Aucune opération à exporter', Colors.orange);
        return;
      }

      final file = await _service.exportOperations(filtered);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '📊 Export des opérations (${filtered.length} lignes)',
      );
    } catch (e) {
      _showSnackBar('❌ Erreur: $e', Colors.red);
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateDebut != null && _dateFin != null
          ? DateTimeRange(start: _dateDebut!, end: _dateFin!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _dateDebut = picked.start;
        _dateFin = picked.end;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _dateDebut = null;
      _dateFin = null;
      _searchController.clear();
      _filtreLibelle = '';
      _numPieceController.clear();
      _filtreNumPiece = '';
      _triAscendant = false;
    });
  }

  void _toggleTri() {
    setState(() {
      _triAscendant = !_triAscendant;
    });
  }

  // ✅ Recherche floue améliorée : recherche par sous-chaîne
  // → quel que soit le mot avant ou après
  List<Operation> _getFilteredOperations() {
    var filtered = List<Operation>.from(_operations);

    // ✅ Filtre libellé (recherche floue)
    if (_filtreLibelle.isNotEmpty) {
      final query = _filtreLibelle.toLowerCase().trim();
      filtered = filtered.where((op) {
        final libelle = op.libelle.toLowerCase();
        // ✅ Recherche par sous-chaîne : "HACH" trouve "HACHMANE" et "HACHAM"
        return libelle.contains(query);
      }).toList();
    }

    // ✅ Filtre numéro pièce (recherche floue)
    if (_filtreNumPiece.isNotEmpty) {
      final query = _filtreNumPiece.toLowerCase().trim();
      filtered = filtered.where((op) {
        final numPiece = op.numPiece.toLowerCase();
        return numPiece.contains(query);
      }).toList();
    }

    // Filtre date
    if (_dateDebut != null && _dateFin != null) {
      filtered = filtered.where((op) =>
          op.dateOperation.isAfter(_dateDebut!.subtract(const Duration(days: 1))) &&
          op.dateOperation.isBefore(_dateFin!.add(const Duration(days: 1)))
      ).toList();
    }

    // Tri
    filtered.sort((a, b) {
      if (_triAscendant) {
        return a.dateOperation.compareTo(b.dateOperation);
      } else {
        return b.dateOperation.compareTo(a.dateOperation);
      }
    });

    return filtered;
  }

  Future<void> _deleteAllOperations() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🗑️ Supprimer tout'),
        content: const Text('Voulez-vous supprimer toutes les opérations ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer tout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.deleteAllOperations();
        _loadOperations();
        _showSnackBar('✅ Toutes les opérations supprimées', Colors.green);
      } catch (e) {
        _showSnackBar('❌ Erreur: $e', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredOperations();
    final totalDebit = filtered.fold(0.0, (sum, op) => sum + op.debit);
    final totalCredit = filtered.fold(0.0, (sum, op) => sum + op.credit);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏦 Opérations Compte'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
        actions: [
          // ✅ Suppression du bouton "Convertir Excel en CSV"
          // ✅ Conservation UNIQUEMENT du bouton Import CSV
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _isImporting ? null : _importCSV,
            tooltip: 'Importer CSV',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportExcel,
            tooltip: 'Exporter Excel',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _selectDateRange,
            tooltip: 'Filtrer par date',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearFilters,
            tooltip: 'Effacer les filtres',
          ),
          IconButton(
            icon: Icon(
              _triAscendant ? Icons.arrow_upward : Icons.arrow_downward,
              color: Colors.white,
            ),
            onPressed: _toggleTri,
            tooltip: _triAscendant ? 'Plus ancien' : 'Plus récent',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _operations.isEmpty ? null : _deleteAllOperations,
            tooltip: 'Supprimer tout',
          ),
        ],
      ),
      body: Column(
        children: [
          // ✅ Filtres
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade50,
            child: Column(
              children: [
                // ✅ Ligne 1 : Libellé (recherche floue)
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '🔍 Rechercher dans le libellé...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _filtreLibelle = '';
                              });
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                // Ligne 2 : Numéro pièce
                TextField(
                  controller: _numPieceController,
                  decoration: InputDecoration(
                    hintText: '🔍 Rechercher par numéro pièce...',
                    prefixIcon: const Icon(Icons.receipt),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: _numPieceController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _numPieceController.clear();
                                _filtreNumPiece = '';
                              });
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                // Ligne 3 : Date et compteurs
                Row(
                  children: [
                    if (_dateDebut != null && _dateFin != null) ...[
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 14),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${DateFormat('dd/MM/yyyy').format(_dateDebut!)} → ${DateFormat('dd/MM/yyyy').format(_dateFin!)}',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, size: 14),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() {
                                    _dateDebut = null;
                                    _dateFin = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        '${filtered.length} opérations',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _triAscendant ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 12,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _triAscendant ? 'Ancien' : 'Récent',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_isImporting) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 4),
                  const Text(
                    'Importation en cours...',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
          // Totaux
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('💳 Débits', style: TextStyle(fontSize: 11)),
                    Text(
                      '${totalDebit.toStringAsFixed(2)} DH',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text('💰 Crédits', style: TextStyle(fontSize: 11)),
                    Text(
                      '${totalCredit.toStringAsFixed(2)} DH',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text('📊 Solde', style: TextStyle(fontSize: 11)),
                    Text(
                      '${(totalCredit - totalDebit).toStringAsFixed(2)} DH',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: totalCredit - totalDebit >= 0
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Liste des opérations
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_balance,
                              size: 80,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _operations.isEmpty
                                  ? 'Aucune opération'
                                  : 'Aucune opération avec ces filtres',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _operations.isEmpty
                                  ? 'Importez un fichier CSV'
                                  : 'Modifiez vos filtres',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            if (_operations.isEmpty) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _importCSV,
                                icon: const Icon(Icons.upload_file),
                                label: const Text('Importer CSV'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(6),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final op = filtered[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 4),
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              leading: Container(
                                width: 6,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: op.debit > 0
                                      ? Colors.red
                                      : Colors.green,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              title: Text(
                                op.libelle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '📅 ${DateFormat('dd/MM/yyyy').format(op.dateOperation)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    '📎 Pièce: ${op.numPiece}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (op.debit > 0)
                                    Text(
                                      '- ${op.debit.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red.shade700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  if (op.credit > 0)
                                    Text(
                                      '+ ${op.credit.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 14,
                                      color: Colors.red,
                                    ),
                                    onPressed: () {
                                      _confirmDelete(op.id);
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              onTap: () {
                                _showOperationDetails(op);
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _importCSV,
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        child: const Icon(Icons.upload_file),
        tooltip: 'Importer CSV',
      ),
    );
  }

  void _showOperationDetails(Operation op) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📄 Détails'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('Libellé', op.libelle),
            _buildDetailRow('Date opération', DateFormat('dd/MM/yyyy').format(op.dateOperation)),
            _buildDetailRow('Date valeur', DateFormat('dd/MM/yyyy').format(op.dateValeur)),
            _buildDetailRow('Débit', op.debit > 0 ? '${op.debit.toStringAsFixed(2)} DH' : '-'),
            _buildDetailRow('Crédit', op.credit > 0 ? '${op.credit.toStringAsFixed(2)} DH' : '-'),
            _buildDetailRow('Numéro pièce', op.numPiece),
            _buildDetailRow('Fichier source', op.fichierSource),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🗑️ Supprimer'),
        content: const Text('Voulez-vous supprimer cette opération ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _service.deleteOperation(id);
                _loadOperations();
                Navigator.pop(context);
                _showSnackBar('✅ Opération supprimée', Colors.green);
              } catch (e) {
                Navigator.pop(context);
                _showSnackBar('❌ Erreur: $e', Colors.red);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}