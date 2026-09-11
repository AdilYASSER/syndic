// lib/screens/realisations_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher.dart'; // ✅ IMPORT AJOUTÉ

class RealisationsScreen extends StatefulWidget {
  final String role;

  const RealisationsScreen({
    super.key,
    required this.role,
  });

  @override
  State<RealisationsScreen> createState() => _RealisationsScreenState();
}

class _RealisationsScreenState extends State<RealisationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();
  
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;
  String? _editingId;
  
  // Contrôleurs pour le formulaire
  final TextEditingController _descriptionController = TextEditingController();
  
  // Sélections
  DateTime _selectedDate = DateTime.now();
  String _selectedCategorie = 'Gardiennage';
  
  // Listes pour les images
  List<dynamic> _selectedImages = []; // Peut contenir File (mobile) ou Uint8List (web)
  List<String> _existingImageUrls = [];
  
  // Catégories disponibles
  final List<String> _categories = [
    'Gardiennage',
    'Ménage',
    'Entretien Ascenseur',
    'Jardinage',
    'Réparation',
    'Rénovation',
    'Peinture',
    'Plomberie',
    'Électricité',
    'Autres'
  ];

  @override
  void initState() {
    super.initState();
    _loadRealisations();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadRealisations() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _firestore
          .collection('realisations')
          .orderBy('date', descending: true)
          .get();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ✅ VÉRIFIER SI L'UTILISATEUR EST ADMIN
  bool _isAdmin() {
    return widget.role == 'admin';
  }

  // ✅ PRENDRE UNE PHOTO - Compatible PC et Mobile
  Future<void> _takePhoto() async {
    if (!_isAdmin()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Seul l\'administrateur peut prendre des photos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (photo != null) {
        if (kIsWeb) {
          final bytes = await photo.readAsBytes();
          setState(() {
            _selectedImages.add(bytes);
          });
          print('✅ Photo prise (Web): ${bytes.length} bytes');
        } else {
          final file = File(photo.path);
          if (await file.exists()) {
            setState(() {
              _selectedImages.add(file);
            });
            print('✅ Photo prise (Mobile): ${photo.path}');
          }
        }
      }
    } catch (e) {
      print('❌ Erreur prise de photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ CHOISIR UNE PHOTO - Compatible PC et Mobile
  Future<void> _pickImage() async {
    if (!_isAdmin()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Seul l\'administrateur peut sélectionner des photos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _selectedImages.add(bytes);
          });
          print('✅ Image sélectionnée (Web): ${bytes.length} bytes');
        } else {
          final file = File(image.path);
          if (await file.exists()) {
            setState(() {
              _selectedImages.add(file);
            });
            print('✅ Image sélectionnée (Mobile): ${image.path}');
          }
        }
      }
    } catch (e) {
      print('❌ Erreur sélection: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ CHOISIR PLUSIEURS PHOTOS - Compatible PC et Mobile
  Future<void> _pickMultipleImages() async {
    if (!_isAdmin()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Seul l\'administrateur peut sélectionner plusieurs photos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final List<XFile>? images = await _imagePicker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (images != null && images.isNotEmpty) {
        if (kIsWeb) {
          for (var image in images) {
            final bytes = await image.readAsBytes();
            setState(() {
              _selectedImages.add(bytes);
            });
          }
          print('✅ ${images.length} images sélectionnées (Web)');
        } else {
          for (var image in images) {
            final file = File(image.path);
            if (await file.exists()) {
              setState(() {
                _selectedImages.add(file);
              });
            }
          }
          print('✅ ${images.length} images sélectionnées (Mobile)');
        }
      }
    } catch (e) {
      print('❌ Erreur sélection multiple: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ SUPPRIMER UNE IMAGE SÉLECTIONNÉE
  void _removeSelectedImage(int index) {
    if (!_isAdmin()) return;
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  // ✅ AFFICHER LE DIALOGUE DE SÉLECTION D'IMAGES
  void _showImagePickerDialog() {
    if (!_isAdmin()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Seul l\'administrateur peut ajouter des photos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '📸 Ajouter des photos',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: const Icon(Icons.photo_camera, color: Colors.blue),
                ),
                title: const Text('📷 Prendre une photo'),
                subtitle: const Text('Utiliser l\'appareil photo'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: const Icon(Icons.photo_library, color: Colors.green),
                ),
                title: const Text('🖼️ Choisir une photo'),
                subtitle: const Text('Depuis la galerie'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple.shade100,
                  child: const Icon(Icons.collections, color: Colors.purple),
                ),
                title: const Text('📁 Choisir plusieurs photos'),
                subtitle: const Text('Sélectionner plusieurs images'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMultipleImages();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ UPLOAD DES IMAGES - Compatible PC et Mobile
  Future<List<String>> _uploadImages(List<dynamic> images) async {
    List<String> urls = [];
    
    print('📸 Début de l\'upload de ${images.length} image(s)');
    
    if (images.isEmpty) {
      print('⚠️ Aucune image à uploader');
      return urls;
    }
    
    for (int i = 0; i < images.length; i++) {
      try {
        final image = images[i];
        
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'realisations/${timestamp}_$i.jpg';
        print('📤 Upload vers: $fileName');
        
        final ref = _storage.ref().child(fileName);
        
        if (kIsWeb) {
          // ✅ Version Web: Utiliser Uint8List
          if (image is Uint8List) {
            print('📤 Upload Web de ${image.length} bytes');
            final uploadTask = ref.putData(
              image,
              SettableMetadata(
                contentType: 'image/jpeg',
              ),
            );
            final snapshot = await uploadTask.whenComplete(() => {});
            if (snapshot.state == TaskState.success) {
              final downloadUrl = await snapshot.ref.getDownloadURL();
              urls.add(downloadUrl);
              print('✅ Image $i uploadée avec succès (Web)');
              print('📎 URL: $downloadUrl');
            } else {
              print('❌ Upload Web échoué: ${snapshot.state}');
            }
          } else {
            print('❌ Format d\'image non supporté pour le Web');
          }
        } else {
          // ✅ Version Mobile: Utiliser File
          if (image is File) {
            final fileSize = await image.length();
            print('📤 Upload Mobile de $fileSize bytes');
            
            if (fileSize > 10 * 1024 * 1024) {
              print('❌ Fichier trop grand (>10MB)');
              continue;
            }
            
            final uploadTask = ref.putFile(
              image,
              SettableMetadata(
                contentType: 'image/jpeg',
              ),
            );
            
            uploadTask.snapshotEvents.listen((snapshot) {
              final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
              print('📊 Progression: ${progress.toStringAsFixed(1)}%');
            });
            
            final snapshot = await uploadTask.whenComplete(() => {});
            if (snapshot.state == TaskState.success) {
              final downloadUrl = await snapshot.ref.getDownloadURL();
              urls.add(downloadUrl);
              print('✅ Image $i uploadée avec succès (Mobile)');
              print('📎 URL: $downloadUrl');
            } else {
              print('❌ Upload Mobile échoué: ${snapshot.state}');
            }
          } else {
            print('❌ Format d\'image non supporté pour le Mobile');
          }
        }
        
      } catch (e) {
        print('❌ Erreur upload image $i: $e');
      }
    }
    
    print('📸 Total uploadé: ${urls.length} image(s)');
    return urls;
  }

  // ✅ AFFICHER LE LIEN DE L'IMAGE UPLOADÉE (CLIQUABLE)
  Widget _buildImageLinkWidget(String url) {
    return GestureDetector(
      onTap: () {
        _openUrl(url);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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

  // ✅ OUVRE L'IMAGE DANS LE NAVIGATEUR DU TÉLÉPHONE OU SUR PC (CORRIGÉ)
  void _openUrl(String url) async {
    // Sur le Web (PC), on ouvre dans un nouvel onglet
    if (kIsWeb) {
      html.window.open(url, '_blank');
      return;
    }

    // Sur le téléphone, on utilise url_launcher pour ouvrir dans le navigateur
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      // Lance l'image dans le navigateur externe (Safari/Chrome)
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Si l'ouverture échoue, on copie le lien dans le presse-papier
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

  // ✅ AFFICHER LE WIDGET D'IMAGE (Compatible PC et Mobile)
  Widget _buildImageWidget(dynamic image) {
    if (kIsWeb) {
      if (image is Uint8List) {
        return Image.memory(
          image,
          fit: BoxFit.cover,
          width: 100,
          height: 100,
        );
      }
    } else {
      if (image is File) {
        return Image.file(
          image,
          fit: BoxFit.cover,
          width: 100,
          height: 100,
        );
      }
    }
    return Container(
      width: 100,
      height: 100,
      color: Colors.grey.shade300,
      child: const Icon(Icons.image_not_supported),
    );
  }

  // ✅ OUVRIR LE FORMULAIRE D'AJOUT
  void _openAddForm() {
    if (!_isAdmin()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Seul l\'administrateur peut ajouter des réalisations'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isEditing = false;
      _editingId = null;
      _descriptionController.clear();
      _selectedImages.clear();
      _existingImageUrls.clear();
      _selectedDate = DateTime.now();
      _selectedCategorie = 'Gardiennage';
    });

    _showFormDialog();
  }

  // ✅ OUVRIR LE FORMULAIRE DE MODIFICATION
  void _openEditForm(Map<String, dynamic> data, String id) {
    if (!_isAdmin()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Seul l\'administrateur peut modifier'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    List<String> existingUrls = [];
    
    if (data['images'] != null && data['images'] is List) {
      existingUrls = List<String>.from(data['images']);
    } else if (data['imageUrls'] != null && data['imageUrls'] is List) {
      existingUrls = List<String>.from(data['imageUrls']);
    } else if (data['imageUrl'] != null && data['imageUrl'] is String && (data['imageUrl'] as String).isNotEmpty) {
      existingUrls = [data['imageUrl']];
    }
    
    print('📸 Photos existantes trouvées: ${existingUrls.length}');

    setState(() {
      _isEditing = true;
      _editingId = id;
      _descriptionController.text = data['description'] ?? '';
      _selectedDate = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
      _selectedCategorie = data['categorie'] ?? 'Gardiennage';
      _existingImageUrls = existingUrls;
      _selectedImages.clear();
    });

    _showFormDialog();
  }

  // ✅ AFFICHER LE DIALOGUE DU FORMULAIRE
  void _showFormDialog() {
    final bool isAdmin = _isAdmin();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9,
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
                      Icon(
                        _isEditing ? Icons.edit : Icons.add,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isEditing ? '✏️ Modifier la réalisation' : '➕ Nouvelle Réalisation',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  
                  // Formulaire
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Catégorie
                          DropdownButtonFormField<String>(
                            value: _selectedCategorie,
                            decoration: const InputDecoration(
                              labelText: 'Catégorie *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.category),
                            ),
                            items: _categories.map((cat) {
                              return DropdownMenuItem(
                                value: cat,
                                child: Text(cat),
                              );
                            }).toList(),
                            onChanged: isAdmin ? (value) {
                              if (value != null) {
                                setDialogState(() {
                                  _selectedCategorie = value;
                                });
                              }
                            } : null,
                          ),
                          const SizedBox(height: 12),
                          
                          // Description
                          TextFormField(
                            controller: _descriptionController,
                            enabled: isAdmin,
                            decoration: const InputDecoration(
                              labelText: 'Description *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.description),
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 12),
                          
                          // Date
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.calendar_today),
                            title: const Text('Date de la réalisation'),
                            subtitle: Text(
                              DateFormat('dd/MM/yyyy').format(_selectedDate),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTap: isAdmin ? () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setDialogState(() => _selectedDate = picked);
                              }
                            } : null,
                          ),
                          const SizedBox(height: 12),
                          
                          // ✅ SECTION PHOTOS AVEC LIEN CLIQUABLE
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.photo, color: Colors.blue.shade700),
                                    const SizedBox(width: 8),
                                    const Text(
                                      '📸 Photos (optionnelles)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_selectedImages.isNotEmpty || _existingImageUrls.isNotEmpty)
                                      Text(
                                        '${_selectedImages.length + _existingImageUrls.length} photo(s)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                
                                // ═══════════════════════════════════════
                                // ✅ AFFICHAGE DU LIEN DE L'IMAGE UPLOADÉE
                                // ═══════════════════════════════════════
                                if (_existingImageUrls.isNotEmpty) ...[
                                  const Text(
                                    '🔗 Lien de l\'image sur Firebase Storage :',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _buildImageLinkWidget(_existingImageUrls.first),
                                  const SizedBox(height: 8),
                                  
                                  const Text(
                                    '🖼️ Aperçu :',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    height: 100,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _existingImageUrls.length,
                                      itemBuilder: (context, index) {
                                        return Container(
                                          width: 100,
                                          height: 100,
                                          margin: const EdgeInsets.only(right: 10),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: Colors.blue.shade200,
                                              width: 2,
                                            ),
                                          ),
                                          child: Stack(
                                            children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: GestureDetector(
                                                  onTap: () => _openUrl(
                                                    _existingImageUrls[index]
                                                  ),
                                                  child: Image.network(
                                                    _existingImageUrls[index],
                                                    fit: BoxFit.cover,
                                                    width: 100,
                                                    height: 100,
                                                    loadingBuilder: (context, child, loadingProgress) {
                                                      if (loadingProgress == null) return child;
                                                      return Container(
                                                        width: 100,
                                                        height: 100,
                                                        color: Colors.grey.shade200,
                                                        child: const Center(
                                                          child: SizedBox(
                                                            width: 20,
                                                            height: 20,
                                                            child: CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    errorBuilder: (context, error, stackTrace) {
                                                      return Container(
                                                        width: 100,
                                                        height: 100,
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
                                              if (isAdmin)
                                                Positioned(
                                                  top: -5,
                                                  right: -5,
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      setDialogState(() {
                                                        _existingImageUrls.removeAt(index);
                                                      });
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.all(4),
                                                      decoration: const BoxDecoration(
                                                        color: Colors.red,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons.close,
                                                        color: Colors.white,
                                                        size: 14,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                                
                                // ═══════════════════════════════════════
                                // ✅ NOUVELLES PHOTOS
                                // ═══════════════════════════════════════
                                if (_selectedImages.isNotEmpty) ...[
                                  const Text(
                                    '📸 Nouvelles photos :',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    height: 100,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _selectedImages.length,
                                      itemBuilder: (context, index) {
                                        return Container(
                                          width: 100,
                                          height: 100,
                                          margin: const EdgeInsets.only(right: 10),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: Colors.green.shade200,
                                              width: 2,
                                            ),
                                          ),
                                          child: Stack(
                                            children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: _buildImageWidget(_selectedImages[index]),
                                              ),
                                              if (isAdmin)
                                                Positioned(
                                                  top: -5,
                                                  right: -5,
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      setDialogState(() {
                                                        _selectedImages.removeAt(index);
                                                      });
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.all(4),
                                                      decoration: const BoxDecoration(
                                                        color: Colors.red,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons.close,
                                                        color: Colors.white,
                                                        size: 14,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                                
                                // BOUTONS POUR AJOUTER DES PHOTOS
                                if (isAdmin) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _showImagePickerDialog,
                                          icon: const Icon(Icons.add_photo_alternate, size: 20),
                                          label: const Text('📸 Ajouter des photos'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue.shade50,
                                            foregroundColor: Colors.blue.shade700,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _takePhoto,
                                          icon: const Icon(Icons.photo_camera, size: 20),
                                          label: const Text('📷 Prendre une photo'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.green.shade700,
                                            side: BorderSide(color: Colors.green.shade300),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  
                  // BOUTONS
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Annuler'),
                        ),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : () => _saveRealisation(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(_isEditing ? 'Mettre à jour' : 'Ajouter'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ✅ SAUVEGARDER LA RÉALISATION
  Future<void> _saveRealisation(BuildContext dialogContext) async {
    if (!_isAdmin()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Seul l\'administrateur peut enregistrer'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Veuillez entrer une description'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      print('🔍 === DÉBUT DE LA SAUVEGARDE ===');
      print('🔍 Description: ${_descriptionController.text}');
      print('🔍 Catégorie: $_selectedCategorie');
      print('🔍 Nouvelles images: ${_selectedImages.length}');
      print('🔍 Images existantes: ${_existingImageUrls.length}');
      print('🔍 Plateforme: ${kIsWeb ? "Web" : "Mobile"}');
      
      List<String> allImageUrls = List.from(_existingImageUrls);
      
      if (_selectedImages.isNotEmpty) {
        print('📤 Upload de ${_selectedImages.length} images...');
        List<String> newUrls = await _uploadImages(_selectedImages);
        allImageUrls.addAll(newUrls);
        print('✅ ${newUrls.length} images uploadées avec succès');
      }

      print('📸 Total des images: ${allImageUrls.length}');

      if (_isEditing && _editingId != null) {
        final Map<String, dynamic> updateData = {
          'categorie': _selectedCategorie,
          'description': _descriptionController.text.trim(),
          'date': Timestamp.fromDate(_selectedDate),
          'updatedAt': Timestamp.now(),
          'updatedBy': 'admin',
        };
        
        if (allImageUrls.isNotEmpty) {
          updateData['images'] = allImageUrls;
          print('✅ Sauvegarde des images dans Firestore: ${allImageUrls.length}');
        } else {
          updateData['images'] = [];
          print('⚠️ Aucune image à sauvegarder');
        }
        
        await _firestore.collection('realisations').doc(_editingId).update(updateData);
        
        print('✅ Réalisation mise à jour avec succès');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Réalisation modifiée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final Map<String, dynamic> addData = {
          'categorie': _selectedCategorie,
          'description': _descriptionController.text.trim(),
          'date': Timestamp.fromDate(_selectedDate),
          'createdAt': Timestamp.now(),
          'createdBy': 'admin',
        };
        
        if (allImageUrls.isNotEmpty) {
          addData['images'] = allImageUrls;
          print('✅ Sauvegarde des images dans Firestore: ${allImageUrls.length}');
        }
        
        await _firestore.collection('realisations').add(addData);
        
        print('✅ Réalisation ajoutée avec succès');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Réalisation ajoutée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }

      setState(() => _isSaving = false);
      Navigator.pop(dialogContext);
      _loadRealisations();
      
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde: $e');
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ SUPPRIMER UNE RÉALISATION
  Future<void> _deleteRealisation(String id) async {
    if (!_isAdmin()) {
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
        title: const Text('⚠️ Confirmation'),
        content: const Text('Voulez-vous vraiment supprimer cette réalisation ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('realisations').doc(id).delete();
        _loadRealisations();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Réalisation supprimée'),
            backgroundColor: Colors.green,
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
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = _isAdmin();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('🛠️ Réalisations'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _openAddForm,
              tooltip: 'Nouvelle réalisation',
            ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isAdmin ? Colors.orange.shade900 : Colors.green.shade700,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isAdmin ? '👑 Admin' : '👤 Client',
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
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('realisations')
                        .orderBy('date', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Erreur: ${snapshot.error}'),
                        );
                      }
                      
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.construction, size: 60, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text(
                                'Aucune réalisation',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (isAdmin) ...[
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _openAddForm,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Ajouter une réalisation'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange.shade700,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }
                      
                      final realisations = snapshot.data!.docs;
                      
                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: realisations.length,
                        itemBuilder: (context, index) {
                          final doc = realisations[index];
                          final data = doc.data() as Map<String, dynamic>;
                          
                          final String id = doc.id;
                          final String categorie = data['categorie'] ?? 'Non catégorisé';
                          final String description = data['description'] ?? '';
                          final DateTime date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
                          
                          final List<String> imageUrls = data['images'] != null
                              ? List<String>.from(data['images'])
                              : data['imageUrls'] != null
                                  ? List<String>.from(data['imageUrls'])
                                  : [];
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      topRight: Radius.circular(12),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade700,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          categorie,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        DateFormat('dd/MM/yyyy').format(date),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      if (isAdmin) ...[
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Colors.blue,
                                            size: 20,
                                          ),
                                          onPressed: () => _openEditForm(data, id),
                                          tooltip: 'Modifier',
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                            size: 20,
                                          ),
                                          onPressed: () => _deleteRealisation(id),
                                          tooltip: 'Supprimer',
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                                  child: Text(
                                    description,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                                
                                // Lien photo - Espacement très réduit
                                if (imageUrls.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        GestureDetector(
                                          onTap: () => _openUrl(imageUrls.first),
                                          child: Row(
                                            children: [
                                              Icon(Icons.image, color: Colors.blue.shade700, size: 16),
                                              const SizedBox(width: 6),
                                              Text(
                                                '📸 Afficher la photo (${imageUrls.length} image${imageUrls.length > 1 ? 's' : ''})',
                                                style: TextStyle(
                                                  color: Colors.blue.shade700,
                                                  fontSize: 13,
                                                  decoration: TextDecoration.underline,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (imageUrls.length > 1)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 24, top: 2),
                                            child: Text(
                                              '+ ${imageUrls.length - 1} autre(s) photo(s) disponible(s)',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade500,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}