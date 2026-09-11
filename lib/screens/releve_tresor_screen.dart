// lib/screens/releve_tresor_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'package:http/http.dart' as http;

class ReleveTresorScreen extends StatefulWidget {
  final String role;
  final String? appartement;

  const ReleveTresorScreen({
    super.key,
    required this.role,
    this.appartement,
  });

  @override
  State<ReleveTresorScreen> createState() => _ReleveTresorScreenState();
}

class _ReleveTresorScreenState extends State<ReleveTresorScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  List<Map<String, dynamic>> _releves = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  bool _isUploading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _isAdmin = widget.role == 'admin';
    _loadReleves();
  }

  Future<void> _loadReleves() async {
    setState(() => _isLoading = true);
    try {
      QuerySnapshot snapshot;
      
      if (_isAdmin) {
        snapshot = await _firestore
            .collection('releves_tresor')
            .orderBy('dateUpload', descending: true)
            .get();
      } else {
        snapshot = await _firestore
            .collection('releves_tresor')
            .get();
      }

      setState(() {
        _releves = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'nom': data['nom'] ?? 'Relevé',
            'url': data['url'] ?? '',
            'appartement': data['appartement'] ?? 'Général',
            'dateUpload': data['dateUpload'] != null
                ? (data['dateUpload'] as Timestamp).toDate()
                : DateTime.now(),
            'uploadedBy': data['uploadedBy'] ?? 'admin',
            'taille': data['taille'] ?? 0,
          };
        }).toList();
        
        // ✅ Filtrage en mémoire pour le client
        if (!_isAdmin && widget.appartement != null && widget.appartement!.isNotEmpty) {
          _releves = _releves.where((r) => 
            r['appartement'] == 'Général' || r['appartement'] == widget.appartement
          ).toList();
        }
        
        // ✅ Trier par date (plus récent en premier)
        _releves.sort((a, b) => b['dateUpload'].compareTo(a['dateUpload']));
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ✅ IMPORTER UN PDF - UNIQUEMENT ADMIN
  Future<void> _importerPDF() async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Seul l\'administrateur peut importer des PDF'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result == null) {
        setState(() => _isUploading = false);
        return;
      }

      final file = result.files.first;
      
      if (!file.name.toLowerCase().endsWith('.pdf')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Veuillez sélectionner un fichier PDF'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isUploading = false);
        return;
      }

      if (file.size > 10 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Le fichier est trop volumineux (max 10MB)'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isUploading = false);
        return;
      }

      String fileName = 'releves_tresor/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      
      Uint8List? fileBytes;
      if (kIsWeb) {
        fileBytes = file.bytes;
      } else {
        fileBytes = await File(file.path!).readAsBytes();
      }

      if (fileBytes == null) {
        throw Exception('Impossible de lire le fichier');
      }

      final ref = _storage.ref().child(fileName);
      final uploadTask = ref.putData(
        fileBytes,
        SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: {
            'originalName': file.name,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      final snapshot = await uploadTask.whenComplete(() => {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await _firestore.collection('releves_tresor').add({
        'nom': file.name,
        'url': downloadUrl,
        'appartement': 'Général',
        'dateUpload': Timestamp.now(),
        'uploadedBy': 'admin',
        'taille': file.size,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ PDF importé avec succès'),
          backgroundColor: Colors.green,
        ),
      );

      _loadReleves();

    } catch (e) {
      print('❌ Erreur import: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // ✅ MODIFIER LE TITRE DU PDF - UNIQUEMENT ADMIN
  Future<void> _modifierTitre(Map<String, dynamic> releve) async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Seul l\'administrateur peut modifier le titre'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final TextEditingController controller = TextEditingController(text: releve['nom']);
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✏️ Modifier le titre du PDF'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nouveau titre',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.edit),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Modifier'),
          ),
        ],
      ),
    );

    if (result == true && controller.text.trim().isNotEmpty) {
      try {
        await _firestore.collection('releves_tresor').doc(releve['id']).update({
          'nom': controller.text.trim(),
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Titre modifié avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        _loadReleves();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ VISUALISER UN PDF - DISPONIBLE POUR TOUS (CLIENT ET ADMIN)
  Future<void> _visualiserPDF(String url) async {
    try {
      if (kIsWeb) {
        // ✅ Pour le Web : ouvrir dans un nouvel onglet
        html.window.open(url, '_blank');
      } else {
        // ✅ Pour Mobile : ouvrir avec un viewer
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final directory = await getTemporaryDirectory();
          final filePath = '${directory.path}/temp_releve.pdf';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          
          // ✅ Ouvrir le PDF avec le viewer natif
          await Share.shareXFiles(
            [XFile(filePath)],
            text: '📄 Visualisation du relevé de trésorerie',
          );
        } else {
          throw Exception('Erreur de chargement');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ TÉLÉCHARGER UN PDF - UNIQUEMENT ADMIN
  Future<void> _downloadPDF(String url, String nom) async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Seul l\'administrateur peut télécharger'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      if (kIsWeb) {
        html.window.open(url, '_blank');
      } else {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final directory = await getTemporaryDirectory();
          final filePath = '${directory.path}/$nom';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          
          await Share.shareXFiles(
            [XFile(filePath)],
            text: '📄 Relevé de trésorerie',
          );
        } else {
          throw Exception('Erreur de téléchargement');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ SUPPRIMER UN PDF - UNIQUEMENT ADMIN
  Future<void> _deletePDF(Map<String, dynamic> releve) async {
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
          'Voulez-vous vraiment supprimer le relevé : ${releve['nom']} ?',
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
        final url = releve['url'] as String;
        final ref = _storage.refFromURL(url);
        await ref.delete();

        await _firestore.collection('releves_tresor').doc(releve['id']).delete();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ PDF supprimé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        _loadReleves();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ FORMATER LA TAILLE DU FICHIER
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ✅ WIDGET DE LA CARTE D'UN RELEVÉ
  Widget _buildReleveCard(Map<String, dynamic> releve) {
    final bool isAdmin = _isAdmin;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec icône et nom
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.picture_as_pdf,
                    color: Colors.red.shade700,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre avec bouton modifier pour admin
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              releve['nom'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isAdmin) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                              onPressed: () => _modifierTitre(releve),
                              tooltip: 'Modifier le titre',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(releve['dateUpload']),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.folder, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            releve['appartement'] ?? 'Général',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Taille du fichier
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatFileSize(releve['taille'] ?? 0),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ✅ Boutons d'action
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // ✅ Bouton Visualiser - DISPONIBLE POUR TOUS
                ElevatedButton.icon(
                  onPressed: () => _visualiserPDF(releve['url']),
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('Visualiser'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                // ✅ Bouton Télécharger - UNIQUEMENT ADMIN
                if (isAdmin)
                  ElevatedButton.icon(
                    onPressed: () => _downloadPDF(releve['url'], releve['nom']),
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Télécharger'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                // ✅ Bouton Supprimer - UNIQUEMENT ADMIN
                if (isAdmin) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _deletePDF(releve),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Supprimer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredReleves = _releves.where((r) {
      final query = _searchQuery.toLowerCase();
      return r['nom'].toString().toLowerCase().contains(query) ||
          r['appartement'].toString().toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('📊 Relevé Trésor'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        actions: [
          // ✅ Bouton Importer - UNIQUEMENT ADMIN
          if (_isAdmin)
            IconButton(
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.upload_file),
              onPressed: _isUploading ? null : _importerPDF,
              tooltip: 'Importer un PDF',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReleves,
            tooltip: 'Rafraîchir',
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _isAdmin ? Colors.orange.shade700 : Colors.green.shade700,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _isAdmin ? '👑 Admin' : '👤 Client',
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
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: '🔍 Rechercher un relevé...',
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
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          // ✅ Info pour l'admin uniquement
          if (_isAdmin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '📎 Cliquez sur l\'icône 📤 pour importer un PDF',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          // Liste des relevés
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredReleves.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.picture_as_pdf,
                              size: 80,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _isAdmin
                                  ? 'Aucun relevé PDF importé'
                                  : 'Aucun relevé disponible pour cet appartement',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            if (_isAdmin) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Cliquez sur l\'icône 📤 pour importer un PDF',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filteredReleves.length,
                        itemBuilder: (context, index) {
                          return _buildReleveCard(filteredReleves[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}