// lib/screens/depenses_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

// ✅ IMPORT DU MODÈLE DEPENSE EXISTANT
import '../models/depense.dart';
import 'add_depense_screen.dart';

class DepensesListScreen extends StatefulWidget {
  final bool isClient;
  final String? appartement;

  const DepensesListScreen({
    super.key,
    this.isClient = false,
    this.appartement,
  });

  @override
  State<DepensesListScreen> createState() => _DepensesListScreenState();
}

class _DepensesListScreenState extends State<DepensesListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _depenses = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterCategorie = 'Toutes';
  bool _isAdmin = false;

  final List<String> _categories = [
    'Toutes',
    'Entretien Ascenseur',
    'Gardiennage/Ménage',
    'Lignes Internet',
    'Maintenance Internet',
    'SRM',
    'Autres'
  ];

  final List<String> _sousCategories = [
    'Eclairage',
    'Réparation Ascenseur',
    'Fuite d\'Eau',
    'Peinture',
    'Vitres',
    'Portes',
    'Jardinage',
    'Terrasse',
    'Fontaines',
    'Pompe de Puit',
    'Désherbage'
  ];

  final List<String> _modesPaiement = ['Espèces', 'Virement', 'Chèque'];
  final List<String> _statuts = ['En Attente', 'Payé', 'Annulé'];

  @override
  void initState() {
    super.initState();
    _isAdmin = !widget.isClient;
    _loadDepenses();
  }

  Future<void> _loadDepenses() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _firestore.collection('depenses').get();

      setState(() {
        _depenses = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          
          // ✅ Récupération des justificatifs (support des deux formats)
          List<String> justificatifUrls = [];
          if (data['justificatifUrls'] != null && data['justificatifUrls'] is List) {
            justificatifUrls = List<String>.from(data['justificatifUrls']);
          } else if (data['justificatifUrl'] != null && data['justificatifUrl'].toString().isNotEmpty) {
            justificatifUrls = [data['justificatifUrl'].toString()];
          }
          
          return {
            'id': doc.id,
            'description': data['description'] ?? data['titre'] ?? 'N/A',
            'montant': (data['montant'] ?? 0).toDouble(),
            'categorie': data['categorie'] ?? 'Autre',
            'sousCategorie': data['sousCategorie'] ?? '',
            'date': data['date'] != null
                ? (data['date'] as Timestamp).toDate()
                : DateTime.now(),
            'fournisseur': data['beneficiaire'] ?? data['fournisseur'] ?? 'N/A',
            'statut': data['statut'] ?? 'En Attente',
            'modePaiement': data['modePaiement'] ?? 'Espèces',
            'numeroCheque': data['numeroCheque'] ?? '',
            'titre': data['titre'] ?? data['description'] ?? 'N/A',
            'justificatifUrls': justificatifUrls,
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ✅ AFFICHER LES DÉTAILS COMPLETS D'UNE DÉPENSE
  void _showDepenseDetails(Map<String, dynamic> depense) {
    final bool isPaye = depense['statut'] == 'Payé';
    final bool isEnAttente = depense['statut'] == 'En Attente';
    Color statusColor = isPaye ? Colors.green : isEnAttente ? Colors.orange : Colors.red;

    // ✅ Récupération des justificatifs
    List<String> justificatifUrls = depense['justificatifUrls'] ?? [];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: 500,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPaye ? Icons.check_circle : 
                      isEnAttente ? Icons.pending : Icons.cancel,
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      depense['titre'] ?? depense['description'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),
              
              // Contenu scrollable
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Statut
                      Row(
                        children: [
                          const Text(
                            'Statut : ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              depense['statut'] ?? 'N/A',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Montant
                      Row(
                        children: [
                          const Text(
                            'Montant : ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${depense['montant'].toStringAsFixed(2)} DH',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Catégorie
                      _buildDetailRow(Icons.category, 'Catégorie', depense['categorie']),
                      
                      // Sous-catégorie
                      if (depense['sousCategorie'] != null && depense['sousCategorie'].isNotEmpty)
                        _buildDetailRow(Icons.label, 'Sous-catégorie', depense['sousCategorie']),
                      
                      // Fournisseur
                      _buildDetailRow(Icons.business, 'Fournisseur', depense['fournisseur']),
                      
                      // Date
                      _buildDetailRow(
                        Icons.calendar_today,
                        'Date',
                        DateFormat('dd/MM/yyyy').format(depense['date']),
                      ),
                      
                      // Mode de paiement
                      _buildDetailRow(Icons.payment, 'Mode de paiement', depense['modePaiement'] ?? 'N/A'),
                      
                      // Numéro de chèque
                      if (depense['numeroCheque'] != null && depense['numeroCheque'].isNotEmpty)
                        _buildDetailRow(Icons.numbers, 'Chèque N°', depense['numeroCheque']),
                      
                      const SizedBox(height: 12),
                      
                      // ✅ Justificatifs avec lien cliquable
                      if (justificatifUrls.isNotEmpty) ...[
                        const Text(
                          '📎 Justificatifs :',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...justificatifUrls.map((url) {
                          return _buildJustificatifLink(url);
                        }),
                        const SizedBox(height: 8),
                        // Miniatures des images
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: justificatifUrls.map((url) {
                            return GestureDetector(
                              onTap: () => _showJustificatifFullScreen(context, url),
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded /
                                                    loadingProgress.expectedTotalBytes!
                                                : null,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(
                                          Icons.broken_image,
                                          color: Colors.grey,
                                          size: 30,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const Divider(height: 16),
              
              // Boutons d'action (Admin uniquement)
              if (_isAdmin)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteDepense(depense);
                      },
                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                      label: const Text(
                        'Supprimer',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _editDepense(depense);
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Modifier'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ WIDGET POUR AFFICHER UN LIEN DE JUSTIFICATIF CLIQUABLE
  Widget _buildJustificatifLink(String url) {
    return GestureDetector(
      onTap: () => _openJustificatifUrl(url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.link, size: 16, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                url,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue.shade700,
                  decoration: TextDecoration.underline,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.open_in_new,
              size: 14,
              color: Colors.blue.shade700,
            ),
          ],
        ),
      ),
    );
  }

  // ✅ OUVRIR UN LIEN DE JUSTIFICATIF
  void _openJustificatifUrl(String url) {
    if (kIsWeb) {
      // ✅ Pour le Web : ouvrir dans un nouvel onglet
      html.window.open(url, '_blank');
    } else {
      // ✅ Pour Mobile : copier le lien
      _copyLinkToClipboard(url);
    }
  }

  // ✅ COPIER LE LIEN DANS LE PRESSE-PAPIER
  void _copyLinkToClipboard(String url) {
    try {
      Clipboard.setData(ClipboardData(text: url));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📋 Lien copié dans le presse-papier !'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ AFFICHER UN JUSTIFICATIF EN PLEIN ÉCRAN
  void _showJustificatifFullScreen(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 400,
                        width: 300,
                        color: Colors.grey.shade100,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey.shade100,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, size: 50, color: Colors.red),
                              SizedBox(height: 8),
                              Text(
                                'Erreur de chargement',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.5),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ WIDGET POUR AFFICHER UNE LIGNE DE DÉTAIL
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              '$label :',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ EXPORT EXCEL - Admin uniquement
  Future<void> _exportExcel() async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Seul l\'administrateur peut exporter'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final filteredDepenses = _depenses.where((d) {
        final query = _searchQuery.toLowerCase();
        final matchSearch = d['titre'].toString().toLowerCase().contains(query) ||
            d['fournisseur'].toString().toLowerCase().contains(query);
        final matchCategorie = _filterCategorie == 'Toutes' || d['categorie'] == _filterCategorie;
        return matchSearch && matchCategorie;
      }).toList();

      var excel = excel_lib.Excel.createExcel();
      excel_lib.Sheet sheet = excel['Dépenses'];

      List<String> headers = ['Titre', 'Description', 'Montant (DH)', 'Catégorie', 'Sous-catégorie', 'Fournisseur', 'Date', 'Mode Paiement', 'Chèque N°', 'Statut', 'Justificatif'];
      List<excel_lib.CellValue> headerRow = headers.map((h) => excel_lib.TextCellValue(h)).toList();
      sheet.appendRow(headerRow);

      for (var d in filteredDepenses) {
        List<String> justificatifs = d['justificatifUrls'] ?? [];
        String justificatifStr = justificatifs.isNotEmpty ? justificatifs.join(', ') : 'Aucun';
        
        List<excel_lib.CellValue> row = [
          excel_lib.TextCellValue(d['titre']),
          excel_lib.TextCellValue(d['description']),
          excel_lib.TextCellValue(d['montant']?.toString() ?? '0'),
          excel_lib.TextCellValue(d['categorie']),
          excel_lib.TextCellValue(d['sousCategorie'] ?? ''),
          excel_lib.TextCellValue(d['fournisseur']),
          excel_lib.TextCellValue(DateFormat('dd/MM/yyyy').format(d['date'])),
          excel_lib.TextCellValue(d['modePaiement'] ?? ''),
          excel_lib.TextCellValue(d['numeroCheque'] ?? ''),
          excel_lib.TextCellValue(d['statut']),
          excel_lib.TextCellValue(justificatifStr),
        ];
        sheet.appendRow(row);
      }

      String filename = 'depenses_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
      List<int>? excelBytes = excel.save();

      if (excelBytes == null) {
        throw Exception('Erreur lors de la création du fichier Excel');
      }

      if (kIsWeb) {
        final blob = html.Blob([excelBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..target = '_blank'
          ..download = filename;
        anchor.click();
        html.Url.revokeObjectUrl(url);
      } else {
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/$filename';
        final file = File(filePath);
        await file.writeAsBytes(excelBytes);
        await Share.shareXFiles([XFile(filePath)]);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Excel exporté: $filename'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur export: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ✅ EXPORT CSV - Admin uniquement
  Future<void> _exportCSV() async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Seul l\'administrateur peut exporter'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final filteredDepenses = _depenses.where((d) {
        final query = _searchQuery.toLowerCase();
        final matchSearch = d['titre'].toString().toLowerCase().contains(query) ||
            d['fournisseur'].toString().toLowerCase().contains(query);
        final matchCategorie = _filterCategorie == 'Toutes' || d['categorie'] == _filterCategorie;
        return matchSearch && matchCategorie;
      }).toList();

      List<List<dynamic>> rows = [
        ['Titre', 'Description', 'Montant (DH)', 'Catégorie', 'Sous-catégorie', 'Fournisseur', 'Date', 'Mode Paiement', 'Chèque N°', 'Statut', 'Justificatif']
      ];

      for (var d in filteredDepenses) {
        List<String> justificatifs = d['justificatifUrls'] ?? [];
        String justificatifStr = justificatifs.isNotEmpty ? justificatifs.join(', ') : 'Aucun';
        
        rows.add([
          d['titre'],
          d['description'],
          d['montant']?.toString() ?? '0',
          d['categorie'],
          d['sousCategorie'] ?? '',
          d['fournisseur'],
          DateFormat('dd/MM/yyyy').format(d['date']),
          d['modePaiement'] ?? '',
          d['numeroCheque'] ?? '',
          d['statut'],
          justificatifStr,
        ]);
      }

      String csv = const ListToCsvConverter().convert(rows);
      String filename = 'depenses_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';

      if (kIsWeb) {
        final blob = html.Blob([csv]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..target = '_blank'
          ..download = filename;
        anchor.click();
        html.Url.revokeObjectUrl(url);
      } else {
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/$filename';
        final file = File(filePath);
        await file.writeAsString(csv);
        await Share.shareXFiles([XFile(filePath)]);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ CSV exporté: $filename'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur export: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📤 Exporter les dépenses'),
        content: const Text('Choisissez le format d\'exportation :'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _exportCSV();
            },
            child: const Text('CSV'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _exportExcel();
            },
            child: const Text('Excel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  Future<void> _addDepense() async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Seul l\'administrateur peut ajouter'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddDepenseScreen(),
      ),
    );

    if (result == true) {
      _loadDepenses();
    }
  }

  Future<void> _editDepense(Map<String, dynamic> depense) async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Seul l\'administrateur peut modifier'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // ✅ Récupérer l'URL du justificatif
    List<String> justificatifUrls = depense['justificatifUrls'] ?? [];
    String? justificatifUrl = justificatifUrls.isNotEmpty ? justificatifUrls.first : null;

    final depenseObj = Depense(
      id: depense['id'],
      titre: depense['titre'] ?? depense['description'],
      montant: depense['montant'],
      date: depense['date'],
      categorie: depense['categorie'],
      sousCategorie: depense['sousCategorie'],
      beneficiaire: depense['fournisseur'],
      description: depense['description'],
      justificatifUrl: justificatifUrl,
      createdBy: 'admin',
      statut: _convertStatut(depense['statut']),
      modePaiement: _convertModePaiement(depense['modePaiement']),
      numeroCheque: depense['numeroCheque'],
    );

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddDepenseScreen(
          depense: depenseObj,
        ),
      ),
    );

    if (result == true) {
      _loadDepenses();
    }
  }

  String _convertStatut(String statut) {
    switch (statut) {
      case 'Payé': return 'paye';
      case 'Annulé': return 'annule';
      default: return 'en_attente';
    }
  }

  String _convertModePaiement(String mode) {
    switch (mode) {
      case 'Virement': return 'virement';
      case 'Chèque': return 'cheque';
      default: return 'espece';
    }
  }

  Future<void> _deleteDepense(Map<String, dynamic> depense) async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Seul l\'administrateur peut supprimer'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Confirmation de suppression'),
        content: Text(
          'Voulez-vous vraiment supprimer la dépense : ${depense['titre'] ?? depense['description']} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('depenses').doc(depense['id']).delete();
        _loadDepenses();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Dépense supprimée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredDepenses = _depenses.where((d) {
      final query = _searchQuery.toLowerCase();
      final matchSearch = d['titre'].toString().toLowerCase().contains(query) ||
          d['fournisseur'].toString().toLowerCase().contains(query);
      final matchCategorie = _filterCategorie == 'Toutes' || d['categorie'] == _filterCategorie;
      return matchSearch && matchCategorie;
    }).toList();

    double total = filteredDepenses.fold(0, (sum, d) => sum + (d['montant'] ?? 0));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.isClient ? '📉 Dépenses' : '📉 Dépenses'), // ✅ CORRIGÉ ICI
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addDepense,
              tooltip: 'Ajouter une dépense',
            ),
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _showExportDialog,
              tooltip: 'Exporter',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDepenses,
            tooltip: 'Rafraîchir',
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: widget.isClient ? Colors.green.shade700 : Colors.orange.shade700,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.isClient ? '👤 Client' : '👑 Admin',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: '🔍 Rechercher...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _filterDepenses();
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _filterDepenses();
                });
              },
            ),
          ),
          if (_isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(cat),
                        selected: _filterCategorie == cat,
                        onSelected: (_) => setState(() => _filterCategorie = cat),
                        backgroundColor: Colors.grey.shade200,
                        selectedColor: Colors.orange.shade100,
                        checkmarkColor: Colors.orange.shade700,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '💰 Total des dépenses :',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${total.toStringAsFixed(2)} DH',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredDepenses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              widget.isClient
                                  ? 'Aucune dépense disponible'
                                  : 'Aucune dépense trouvée',
                              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                            ),
                            if (_isAdmin) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _addDepense,
                                icon: const Icon(Icons.add),
                                label: const Text('Ajouter une dépense'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade700,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredDepenses.length,
                        padding: const EdgeInsets.all(8),
                        itemBuilder: (context, index) {
                          final depense = filteredDepenses[index];
                          final isPaye = depense['statut'] == 'Payé';
                          final isEnAttente = depense['statut'] == 'En Attente';
                          final Color statusColor = isPaye ? Colors.green : isEnAttente ? Colors.orange : Colors.red;
                          
                          // ✅ Récupération des justificatifs
                          List<String> justificatifUrls = depense['justificatifUrls'] ?? [];
                          bool hasJustificatif = justificatifUrls.isNotEmpty;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              onTap: () => _showDepenseDetails(depense),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    // Statut - icône
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: statusColor.withOpacity(0.2),
                                      child: Icon(
                                        isPaye ? Icons.check_circle : 
                                        isEnAttente ? Icons.pending : Icons.cancel,
                                        color: statusColor,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Titre et montant
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            depense['titre'] ?? 'N/A',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.category, size: 12, color: Colors.grey.shade500),
                                              const SizedBox(width: 4),
                                              Text(
                                                depense['categorie'],
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(width: 12),
                                              Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                                              const SizedBox(width: 4),
                                              Text(
                                                DateFormat('dd/MM/yy').format(depense['date']),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              // ✅ Indicateur de justificatif
                                              if (hasJustificatif) ...[
                                                const SizedBox(width: 8),
                                                Icon(
                                                  Icons.attach_file,
                                                  size: 12,
                                                  color: Colors.blue.shade400,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Montant
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${depense['montant'].toStringAsFixed(2)} DH',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: statusColor,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            depense['statut'] ?? 'N/A',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: statusColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey.shade400,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _filterDepenses() {
    setState(() {});
  }
}