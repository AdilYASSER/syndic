// lib/screens/documentation_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

class DocumentationScreen extends StatefulWidget {
  final String role;

  const DocumentationScreen({
    super.key,
    required this.role,
  });

  @override
  State<DocumentationScreen> createState() => _DocumentationScreenState();
}

class _DocumentationScreenState extends State<DocumentationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();
  
  List<Map<String, dynamic>> _documents = [];
  List<Map<String, dynamic>> _filteredDocuments = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String? _errorMessage;
  String _selectedCategorie = 'Tous';

  // ✅ Catégories
  final List<String> _categories = [
    'Tous',
    'Contrat',
    'PV',
    'Loi',
    'Document',
    'Autre',
  ];

  bool get isAdmin => widget.role == 'admin';

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  // ✅ Charger les documents depuis Firestore - Version corrigée
  Future<void> _loadDocuments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      QuerySnapshot snapshot;
      
      if (isAdmin) {
        // ✅ Admin: Charge tous les documents
        snapshot = await _firestore
            .collection('documents')
            .orderBy('uploadedAt', descending: true)
            .get();
      } else {
        // ✅ Client: Charge les documents sans orderBy (évite l'index)
        snapshot = await _firestore
            .collection('documents')
            .where('appartement', isEqualTo: 'client')
            .get();
      }

      List<Map<String, dynamic>> files = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        files.add({
          'id': doc.id,
          'nom': data['nom'] ?? 'Document.pdf',
          'url': data['url'] ?? '',
          'taille': data['taille'] ?? 0,
          'uploadedAt': (data['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'categorie': data['categorie'] ?? 'Autre',
          'uploadedBy': data['uploadedBy'] ?? '',
          'description': data['description'] ?? '',
        });
      }

      // ✅ Trier côté client
      files.sort((a, b) => b['uploadedAt'].compareTo(a['uploadedAt']));

      setState(() {
        _documents = files;
        _filteredDocuments = files;
        _isLoading = false;
      });
      
      print('✅ ${files.length} documents chargés (${isAdmin ? "Admin" : "Client"})');
      
    } catch (e) {
      print('❌ Erreur chargement documents: $e');
      
      // ✅ Fallback pour le client
      if (!isAdmin) {
        try {
          print('🔄 Tentative de chargement sans filtre...');
          final snapshot = await _firestore
              .collection('documents')
              .get();
          
          List<Map<String, dynamic>> files = [];
          for (var doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            
            if (data['appartement'] == 'client') {
              files.add({
                'id': doc.id,
                'nom': data['nom'] ?? 'Document.pdf',
                'url': data['url'] ?? '',
                'taille': data['taille'] ?? 0,
                'uploadedAt': (data['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                'categorie': data['categorie'] ?? 'Autre',
                'uploadedBy': data['uploadedBy'] ?? '',
                'description': data['description'] ?? '',
              });
            }
          }
          
          files.sort((a, b) => b['uploadedAt'].compareTo(a['uploadedAt']));
          
          setState(() {
            _documents = files;
            _filteredDocuments = files;
            _isLoading = false;
            _errorMessage = null;
          });
          
          print('✅ ${files.length} documents chargés (client - fallback)');
          return;
        } catch (fallbackError) {
          print('❌ Erreur fallback: $fallbackError');
        }
      }
      
      setState(() {
        _errorMessage = 'Erreur de chargement: $e';
        _isLoading = false;
      });
    }
  }

  // ✅ Appliquer les filtres
  void _applyFilters() {
    setState(() {
      if (_selectedCategorie == 'Tous') {
        _filteredDocuments = List.from(_documents);
      } else {
        _filteredDocuments = _documents
            .where((doc) => doc['categorie'] == _selectedCategorie)
            .toList();
      }
    });
  }

  // ✅ LIER TOUS LES DOCUMENTS AVEC STORAGE
  Future<void> _linkAllDocuments() async {
    setState(() => _isLoading = true);
    
    try {
      final storageRef = _storage.ref().child('documents');
      final result = await storageRef.listAll();
      
      Map<String, String> storageFiles = {};
      for (var item in result.items) {
        try {
          final url = await item.getDownloadURL();
          final name = item.name;
          storageFiles[name] = url;
          print('📁 Fichier Storage: $name');
        } catch (e) {
          print('⚠️ Erreur URL pour ${item.name}: $e');
        }
      }
      
      print('📁 ${storageFiles.length} fichiers trouvés dans Storage');
      
      final snapshot = await _firestore
          .collection('documents')
          .get();
      
      int updatedCount = 0;
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final nom = data['nom'] ?? '';
        final currentUrl = data['url'] ?? '';
        
        if (currentUrl.isEmpty) {
          String? foundUrl;
          String? foundName;
          
          for (var entry in storageFiles.entries) {
            if (entry.key.contains(nom.replaceAll(' ', '_')) || 
                entry.key.contains(nom)) {
              foundUrl = entry.value;
              foundName = entry.key;
              break;
            }
          }
          
          if (foundUrl == null) {
            for (var entry in storageFiles.entries) {
              final storageName = entry.key.replaceAll('_', ' ').toLowerCase();
              final docName = nom.toLowerCase();
              if (storageName.contains(docName) || docName.contains(storageName)) {
                foundUrl = entry.value;
                foundName = entry.key;
                break;
              }
            }
          }
          
          if (foundUrl != null) {
            await doc.reference.update({
              'url': foundUrl,
              'storagePath': 'documents/$foundName',
              'urlUpdatedAt': FieldValue.serverTimestamp(),
            });
            updatedCount++;
            print('✅ Lié: $nom → $foundName');
          } else {
            print('⚠️ Non trouvé: $nom');
          }
        }
      }
      
      _showSnackBar(
        '✅ $updatedCount documents liés avec succès',
        updatedCount > 0 ? Colors.green : Colors.orange,
      );
      
      await _loadDocuments();
      
    } catch (e) {
      print('❌ Erreur liaison: $e');
      _showSnackBar('❌ Erreur: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ Demander les permissions - Version compatible Web
  Future<bool> _requestPermissions() async {
    if (!isAdmin) return false;
    
    if (kIsWeb) return true;
    if (Platform.isWindows) return true;

    try {
      if (Platform.isAndroid) {
        if (await Permission.manageExternalStorage.isGranted) return true;
        final status = await Permission.manageExternalStorage.request();
        if (status.isGranted) return true;
        if (await Permission.storage.isGranted) return true;
        final storageStatus = await Permission.storage.request();
        return storageStatus.isGranted;
      }
      return true;
    } catch (e) {
      print('❌ Erreur permissions: $e');
      return true;
    }
  }

  // ✅ Importer un fichier
  Future<void> _importDocument() async {
    if (!isAdmin) {
      _showSnackBar('❌ Seul l\'administrateur peut importer des documents', Colors.orange);
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Colors.blue),
              title: const Text('📷 Prendre une photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('🖼️ Choisir depuis la galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file, color: Colors.orange),
              title: const Text('📎 Choisir un fichier (PDF, DOC, etc.)'),
              onTap: () {
                Navigator.pop(context);
                _pickFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Prendre une photo
  Future<void> _pickImage(ImageSource source) async {
    try {
      if (!kIsWeb && !Platform.isWindows) {
        final hasPermission = await _requestPermissions();
        if (!hasPermission) {
          _showSnackBar('❌ Permission de stockage refusée', Colors.red);
          return;
        }
      }

      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (pickedFile != null) {
        String fileName = pickedFile.name;
        
        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          await _processBytesDirectly(bytes, fileName, 'image');
        } else {
          final File imageFile = File(pickedFile.path);
          await _showRenameDialogForFile(imageFile, fileName, 'image');
        }
      }
    } catch (e) {
      print('❌ Erreur sélection image: $e');
      _showSnackBar('❌ Erreur: $e', Colors.red);
    }
  }

  // ✅ Choisir un fichier
  Future<void> _pickFile() async {
    try {
      if (!kIsWeb && !Platform.isWindows) {
        final hasPermission = await _requestPermissions();
        if (!hasPermission) {
          _showSnackBar('❌ Permission de stockage refusée', Colors.red);
          return;
        }
      }

      setState(() => _isUploading = true);

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isUploading = false);
        return;
      }

      final file = result.files.first;
      
      if (file.bytes == null || file.bytes!.isEmpty) {
        _showSnackBar('❌ Fichier vide', Colors.red);
        setState(() => _isUploading = false);
        return;
      }
      
      if (kIsWeb) {
        await _showRenameDialogForBytes(file.bytes!, file.name, file.extension ?? '');
      } else {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/${file.name}');
        await tempFile.writeAsBytes(file.bytes!);
        await _showRenameDialogForFile(tempFile, file.name, file.extension ?? '');
      }
      
    } catch (e) {
      print('❌ Erreur sélection fichier: $e');
      _showSnackBar('❌ Erreur: $e', Colors.red);
      setState(() => _isUploading = false);
    }
  }

  // ✅ Dialogue pour renommer (version bytes - Web)
  Future<void> _showRenameDialogForBytes(Uint8List bytes, String originalName, String type) async {
    final TextEditingController nameController = TextEditingController();
    
    String fileName = originalName;
    String extension = '';
    if (fileName.contains('.')) {
      final parts = fileName.split('.');
      extension = parts.last;
      fileName = parts.sublist(0, parts.length - 1).join('.');
    }
    nameController.text = fileName;
    
    String selectedCategorie = 'Document';
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            const Text('📝 Renommer le fichier'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.insert_drive_file,
                      color: type.toLowerCase() == 'pdf' ? Colors.red : Colors.blue.shade700,
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            originalName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Type: ${type.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            'Taille: ${_formatFileSize(bytes.length)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '📄 Nouveau nom du fichier',
                  prefixIcon: const Icon(Icons.edit),
                  border: const OutlineInputBorder(),
                  suffixText: '.$extension',
                  suffixStyle: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              
              DropdownButtonFormField<String>(
                value: selectedCategorie,
                decoration: const InputDecoration(
                  labelText: '📂 Catégorie',
                  prefixIcon: Icon(Icons.folder),
                  border: OutlineInputBorder(),
                ),
                items: _categories.where((c) => c != 'Tous').map((categorie) {
                  return DropdownMenuItem(
                    value: categorie,
                    child: Text(categorie),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) selectedCategorie = value;
                },
              ),
              
              const SizedBox(height: 8),
              Text(
                '💡 Le nom du fichier sera affiché dans la liste',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isUploading = false);
            },
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty) {
                _showSnackBar('❌ Veuillez entrer un nom', Colors.orange);
                return;
              }
              Navigator.pop(context);
              final fullName = '$newName.$extension';
              await _processBytesDirectly(bytes, fullName, selectedCategorie);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('📤 Importer'),
          ),
        ],
      ),
    );
  }

  // ✅ Dialogue pour renommer (version File - Mobile/Desktop)
  Future<void> _showRenameDialogForFile(File file, String originalName, String type) async {
    final TextEditingController nameController = TextEditingController();
    
    String fileName = originalName;
    String extension = '';
    if (fileName.contains('.')) {
      final parts = fileName.split('.');
      extension = parts.last;
      fileName = parts.sublist(0, parts.length - 1).join('.');
    }
    nameController.text = fileName;
    
    String selectedCategorie = 'Document';
    final isImage = ['jpg', 'jpeg', 'png'].contains(type.toLowerCase());
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            const Text('📝 Renommer le fichier'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    isImage && file.existsSync()
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.file(
                              file,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            Icons.insert_drive_file,
                            color: type.toLowerCase() == 'pdf' ? Colors.red : Colors.blue.shade700,
                            size: 40,
                          ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            originalName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Type: ${type.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (file.existsSync())
                            Text(
                              'Taille: ${_formatFileSize(file.lengthSync())}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '📄 Nouveau nom du fichier',
                  prefixIcon: const Icon(Icons.edit),
                  border: const OutlineInputBorder(),
                  suffixText: '.$extension',
                  suffixStyle: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              
              DropdownButtonFormField<String>(
                value: selectedCategorie,
                decoration: const InputDecoration(
                  labelText: '📂 Catégorie',
                  prefixIcon: Icon(Icons.folder),
                  border: OutlineInputBorder(),
                ),
                items: _categories.where((c) => c != 'Tous').map((categorie) {
                  return DropdownMenuItem(
                    value: categorie,
                    child: Text(categorie),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) selectedCategorie = value;
                },
              ),
              
              const SizedBox(height: 8),
              Text(
                '💡 Le nom du fichier sera affiché dans la liste',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isUploading = false);
            },
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty) {
                _showSnackBar('❌ Veuillez entrer un nom', Colors.orange);
                return;
              }
              Navigator.pop(context);
              final fullName = '$newName.$extension';
              await _processFile(file, fullName, selectedCategorie);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('📤 Importer'),
          ),
        ],
      ),
    );
  }

  // ✅ Traiter les bytes directement (Web)
  Future<void> _processBytesDirectly(Uint8List bytes, String newName, String categorie) async {
    try {
      if (bytes.isEmpty) {
        throw Exception('Fichier vide');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = newName.split('.').last;
      final uniqueFileName = '${timestamp}_$newName';
      
      final storageRef = _storage
          .ref()
          .child('documents')
          .child(uniqueFileName);
      
      String contentType = 'application/octet-stream';
      if (extension.toLowerCase() == 'pdf') contentType = 'application/pdf';
      else if (['jpg', 'jpeg'].contains(extension.toLowerCase())) contentType = 'image/jpeg';
      else if (extension.toLowerCase() == 'png') contentType = 'image/png';
      else if (['doc', 'docx'].contains(extension.toLowerCase())) contentType = 'application/msword';
      
      final metadata = SettableMetadata(
        contentType: contentType,
      );
      
      final uploadTask = storageRef.putData(bytes, metadata);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      await _firestore.collection('documents').add({
        'nom': newName,
        'url': downloadUrl,
        'taille': bytes.length,
        'categorie': categorie,
        'description': '',
        'appartement': 'client',
        'uploadedBy': widget.role,
        'uploadedAt': FieldValue.serverTimestamp(),
        'storagePath': 'documents/$uniqueFileName',
        'type': extension.toLowerCase(),
      });

      _showSnackBar('✅ Document importé avec succès', Colors.green);
      
      setState(() => _isUploading = false);
      await _loadDocuments();
      
    } catch (e) {
      print('❌ Erreur traitement document: $e');
      _showSnackBar('❌ Erreur: $e', Colors.red);
      setState(() => _isUploading = false);
    }
  }

  // ✅ Traiter le fichier (Mobile/Desktop)
  Future<void> _processFile(File file, String newName, String categorie) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('Fichier vide');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = newName.split('.').last;
      final uniqueFileName = '${timestamp}_$newName';
      
      final storageRef = _storage
          .ref()
          .child('documents')
          .child(uniqueFileName);
      
      String contentType = 'application/octet-stream';
      if (extension.toLowerCase() == 'pdf') contentType = 'application/pdf';
      else if (['jpg', 'jpeg'].contains(extension.toLowerCase())) contentType = 'image/jpeg';
      else if (extension.toLowerCase() == 'png') contentType = 'image/png';
      else if (['doc', 'docx'].contains(extension.toLowerCase())) contentType = 'application/msword';
      
      final metadata = SettableMetadata(
        contentType: contentType,
      );
      
      final uploadTask = storageRef.putData(bytes, metadata);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      await _firestore.collection('documents').add({
        'nom': newName,
        'url': downloadUrl,
        'taille': bytes.length,
        'categorie': categorie,
        'description': '',
        'appartement': 'client',
        'uploadedBy': widget.role,
        'uploadedAt': FieldValue.serverTimestamp(),
        'storagePath': 'documents/$uniqueFileName',
        'type': extension.toLowerCase(),
      });

      _showSnackBar('✅ Document importé avec succès', Colors.green);
      
      setState(() => _isUploading = false);
      await _loadDocuments();
      
    } catch (e) {
      print('❌ Erreur traitement document: $e');
      _showSnackBar('❌ Erreur: $e', Colors.red);
      setState(() => _isUploading = false);
    }
  }

  // ✅ Dialogue pour éditer un document existant
  Future<void> _editDocument(Map<String, dynamic> document) async {
    if (!isAdmin) {
      _showSnackBar('❌ Seul l\'admin peut modifier les documents', Colors.orange);
      return;
    }

    final TextEditingController nameController = TextEditingController();
    String currentName = document['nom'] ?? '';
    String currentCategorie = document['categorie'] ?? 'Document';
    
    String baseName = currentName;
    String extension = '';
    if (currentName.contains('.')) {
      final parts = currentName.split('.');
      extension = parts.last;
      baseName = parts.sublist(0, parts.length - 1).join('.');
    }
    nameController.text = baseName;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text('✏️ Modifier le document'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Document actuel',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '📂 Catégorie: $currentCategorie',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      '📅 ${DateFormat('dd/MM/yyyy à HH:mm').format(document['uploadedAt'] as DateTime)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '📄 Nouveau nom du fichier',
                  prefixIcon: const Icon(Icons.edit),
                  border: const OutlineInputBorder(),
                  suffixText: extension.isNotEmpty ? '.$extension' : null,
                  suffixStyle: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              
              DropdownButtonFormField<String>(
                value: currentCategorie,
                decoration: const InputDecoration(
                  labelText: '📂 Nouvelle catégorie',
                  prefixIcon: Icon(Icons.folder),
                  border: OutlineInputBorder(),
                ),
                items: _categories.where((c) => c != 'Tous').map((categorie) {
                  return DropdownMenuItem(
                    value: categorie,
                    child: Text(categorie),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) currentCategorie = value;
                },
              ),
              
              const SizedBox(height: 8),
              Text(
                '💡 Les modifications seront appliquées immédiatement',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty) {
                _showSnackBar('❌ Veuillez entrer un nom', Colors.orange);
                return;
              }
              Navigator.pop(context);
              final fullName = extension.isNotEmpty ? '$newName.$extension' : newName;
              await _updateDocument(document, fullName, currentCategorie);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('💾 Enregistrer'),
          ),
        ],
      ),
    );
  }

  // ✅ Mettre à jour un document existant
  Future<void> _updateDocument(Map<String, dynamic> document, String newName, String newCategorie) async {
    try {
      setState(() => _isLoading = true);
      
      final docId = document['id'] as String;
      final currentName = document['nom'] ?? '';
      
      await _firestore.collection('documents').doc(docId).update({
        'nom': newName,
        'categorie': newCategorie,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (currentName != newName) {
        final url = document['url'] as String?;
        if (url != null && url.isNotEmpty) {
          try {
            final storageRef = _storage.refFromURL(url);
            final bytes = await storageRef.getData();
            
            if (bytes != null && bytes.isNotEmpty) {
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              final extension = newName.split('.').last;
              final uniqueFileName = '${timestamp}_$newName';
              
              final newStorageRef = _storage
                  .ref()
                  .child('documents')
                  .child(uniqueFileName);
              
              String contentType = 'application/octet-stream';
              if (extension.toLowerCase() == 'pdf') contentType = 'application/pdf';
              else if (['jpg', 'jpeg'].contains(extension.toLowerCase())) contentType = 'image/jpeg';
              else if (extension.toLowerCase() == 'png') contentType = 'image/png';
              else if (['doc', 'docx'].contains(extension.toLowerCase())) contentType = 'application/msword';
              
              final metadata = SettableMetadata(contentType: contentType);
              
              final uploadTask = newStorageRef.putData(bytes, metadata);
              final snapshot = await uploadTask;
              final newUrl = await snapshot.ref.getDownloadURL();
              
              await _firestore.collection('documents').doc(docId).update({
                'url': newUrl,
                'storagePath': 'documents/$uniqueFileName',
              });
              
              await storageRef.delete();
            }
          } catch (e) {
            print('⚠️ Erreur renommage dans Storage: $e');
          }
        }
      }
      
      _showSnackBar('✅ Document mis à jour avec succès', Colors.green);
      await _loadDocuments();
      
    } catch (e) {
      print('❌ Erreur mise à jour document: $e');
      _showSnackBar('❌ Erreur: $e', Colors.red);
      setState(() => _isLoading = false);
    }
  }

  // ✅ Ouvrir un document
  Future<void> _openDocument(Map<String, dynamic> document) async {
    try {
      final url = document['url'] as String;
      if (url.isEmpty) {
        _showSnackBar('❌ URL du document introuvable', Colors.red);
        return;
      }
      
      _showSnackBar('📄 Ouverture du document...', Colors.blue);
      
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          _showSnackBar('✅ Document ouvert dans le navigateur', Colors.green);
          return;
        }
      } catch (e) {
        print('⚠️ Erreur url_launcher: $e');
      }
      
      if (!kIsWeb) {
        try {
          final storageRef = _storage.refFromURL(url);
          final bytes = await storageRef.getData();
          
          if (bytes == null || bytes.isEmpty) {
            throw Exception('Fichier vide');
          }
          
          final tempDir = await getTemporaryDirectory();
          final String fileName = document['nom'] ?? 'document.pdf';
          final tempFile = File('${tempDir.path}/$fileName');
          await tempFile.writeAsBytes(bytes);
          
          if (await tempFile.exists()) {
            final result = await OpenFile.open(tempFile.path);
            if (result.type == ResultType.done) {
              _showSnackBar('✅ Document ouvert avec succès', Colors.green);
            } else {
              _showSnackBar('⚠️ Erreur: ${result.message}', Colors.orange);
              _showDocumentDialog(tempFile);
            }
          }
        } catch (e) {
          print('❌ Erreur téléchargement: $e');
          _showSnackBar('❌ Impossible de télécharger le document', Colors.red);
        }
      }
      
    } catch (e) {
      print('❌ Erreur ouverture document: $e');
      _showSnackBar('❌ Erreur: $e', Colors.red);
    }
  }

  void _showDocumentDialog(File documentFile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📄 Document chargé'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file, size: 64, color: Colors.blue.shade700),
            const SizedBox(height: 16),
            Text(
              documentFile.path.split('/').last,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Taille: ${_formatFileSize(documentFile.lengthSync())}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Text(
              'Le fichier a été téléchargé sur votre appareil',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar('📁 Fichier: ${documentFile.path}', Colors.blue);
            },
            child: const Text('📁 Voir chemin'),
          ),
        ],
      ),
    );
  }

  // ✅ Supprimer un document
  Future<void> _deleteDocument(String id, String url) async {
    if (!isAdmin) {
      _showSnackBar('❌ Seul l\'admin peut supprimer des documents', Colors.orange);
      return;
    }

    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmation'),
          content: const Text('Voulez-vous vraiment supprimer ce fichier ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Supprimer'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      setState(() => _isLoading = true);

      try {
        final storageRef = _storage.refFromURL(url);
        await storageRef.delete();
      } catch (e) {
        print('⚠️ Erreur suppression Storage: $e');
      }

      await _firestore.collection('documents').doc(id).delete();

      _showSnackBar('✅ Document supprimé avec succès', Colors.green);
      await _loadDocuments();
      
    } catch (e) {
      print('❌ Erreur suppression document: $e');
      _showSnackBar('❌ Erreur: $e', Colors.red);
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} Ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  @override
  Widget build(BuildContext context) {
    final bool isClient = !isAdmin;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('📚 Documentation'),
        backgroundColor: isClient ? Colors.green.shade700 : Colors.blue.shade800,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isClient ? Colors.green.shade700 : Colors.orange.shade700,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isClient ? '👤 Client' : '👑 Admin',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.link, color: Colors.white),
              onPressed: _linkAllDocuments,
              tooltip: 'Lier les documents avec Storage',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDocuments,
            tooltip: 'Rafraîchir',
          ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.upload_file),
              onPressed: _isUploading ? null : _importDocument,
              tooltip: 'Importer un document',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Chargement des documents...'),
                ],
              ),
            )
          : Column(
              children: [
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.red.shade700),
                          onPressed: () => setState(() => _errorMessage = null),
                        ),
                      ],
                    ),
                  ),
                if (isAdmin)
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final categorie = _categories[index];
                        final isSelected = _selectedCategorie == categorie;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FilterChip(
                            label: Text(
                              categorie,
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() {
                                _selectedCategorie = categorie;
                              });
                              _applyFilters();
                            },
                            selectedColor: Colors.blue.shade700,
                            backgroundColor: Colors.grey.shade200,
                          ),
                        );
                      },
                    ),
                  ),
                Expanded(
                  child: _filteredDocuments.isEmpty
                      ? _buildEmptyState()
                      : _buildDocumentList(),
                ),
                if (isAdmin) _buildBottomBar(),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun document',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAdmin 
                ? 'Importez vos documents ici' 
                : 'Aucun document disponible',
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          if (isAdmin)
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _importDocument,
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(_isUploading ? 'Importation...' : '📤 Importer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredDocuments.length,
      itemBuilder: (context, index) {
        final doc = _filteredDocuments[index];
        final date = doc['uploadedAt'] as DateTime? ?? DateTime.now();
        final taille = doc['taille'] as int? ?? 0;
        final hasUrl = doc['url'] != null && doc['url'].isNotEmpty;
        
        IconData fileIcon = Icons.insert_drive_file;
        Color iconColor = Colors.blue.shade700;
        final fileName = doc['nom'] ?? '';
        if (fileName.toLowerCase().endsWith('.pdf')) {
          fileIcon = Icons.picture_as_pdf;
          iconColor = hasUrl ? Colors.red : Colors.grey;
        } else if (fileName.toLowerCase().endsWith('.jpg') || 
                   fileName.toLowerCase().endsWith('.jpeg') ||
                   fileName.toLowerCase().endsWith('.png')) {
          fileIcon = Icons.image;
          iconColor = hasUrl ? Colors.green : Colors.grey;
        } else if (fileName.toLowerCase().endsWith('.doc') || 
                   fileName.toLowerCase().endsWith('.docx')) {
          fileIcon = Icons.description;
          iconColor = hasUrl ? Colors.blue : Colors.grey;
        }
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: hasUrl ? iconColor.withOpacity(0.1) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                fileIcon,
                color: hasUrl ? iconColor : Colors.grey.shade400,
                size: 30,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    doc['nom'] ?? 'Document',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: hasUrl ? Colors.black87 : Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!hasUrl)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '⚠️ Non lié',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📅 ${DateFormat('dd/MM/yyyy à HH:mm').format(date)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  '📦 ${_formatFileSize(taille)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isAdmin)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.orange),
                    onPressed: () => _editDocument(doc),
                    tooltip: 'Modifier',
                  ),
                if (hasUrl)
                  IconButton(
                    icon: const Icon(Icons.visibility, color: Colors.blue),
                    onPressed: () => _openDocument(doc),
                    tooltip: 'Voir',
                  ),
                if (isAdmin)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteDocument(doc['id'] as String, doc['url'] as String),
                    tooltip: 'Supprimer',
                  ),
              ],
            ),
            onTap: () {
              if (hasUrl) {
                _openDocument(doc);
              } else {
                _showSnackBar('⚠️ Ce document n\'est pas lié à un fichier', Colors.orange);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isUploading ? null : _importDocument,
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(_isUploading ? 'Importation...' : '📤 Importer un document'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}