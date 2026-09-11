// lib/screens/add_discussion_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class AddDiscussionScreen extends StatefulWidget {
  final String role;
  final String? appartement;

  const AddDiscussionScreen({
    super.key,
    required this.role,
    this.appartement,
  });

  @override
  State<AddDiscussionScreen> createState() => _AddDiscussionScreenState();
}

class _AddDiscussionScreenState extends State<AddDiscussionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // ✅ Suppression du contrôleur de titre
  final TextEditingController _messageController = TextEditingController();
  
  String _selectedVolet = 'Général';
  bool _isLoading = false;
  bool _isUploading = false;
  
  List<String> _voletList = [
    'Général',
    'Travaux',
    'Jardinage',
    'Ascenseur',
    'Chauffage',
    'Eau',
    'Électricité',
    'Propreté',
    'Stationnement',
    'Sécurité',
    'Assemblée générale',
    'Projet collectif',
    'Autre'
  ];

  // ✅ Images
  List<Uint8List> _imageBytes = [];
  List<File> _imageFiles = [];
  List<String> _imageUrls = [];
  bool _isUploadingImages = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  bool get _isAdmin => widget.role == 'admin';

  // ✅ Prendre une photo
  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _imageBytes.add(bytes);
          });
        } else {
          final file = File(image.path);
          setState(() {
            _imageFiles.add(file);
          });
        }
        print('📸 Photo prise: ${image.name}');
      }
    } catch (e) {
      print('❌ Erreur prise photo: $e');
      _showSnackBar('❌ Erreur: $e', Colors.red);
    }
  }

  // ✅ Choisir depuis la galerie
  Future<void> _pickFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      for (var image in images) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _imageBytes.add(bytes);
          });
        } else {
          final file = File(image.path);
          setState(() {
            _imageFiles.add(file);
          });
        }
        print('🖼️ Image sélectionnée: ${image.name}');
      }
    } catch (e) {
      print('❌ Erreur sélection galerie: $e');
      _showSnackBar('❌ Erreur: $e', Colors.red);
    }
  }

  // ✅ Supprimer une image
  void _removeImage(int index) {
    setState(() {
      if (_imageBytes.isNotEmpty && index < _imageBytes.length) {
        _imageBytes.removeAt(index);
      } else if (_imageFiles.isNotEmpty && index < _imageFiles.length) {
        _imageFiles.removeAt(index);
      }
    });
  }

  // ✅ Upload des images vers Firebase Storage
  Future<List<String>> _uploadImages() async {
    List<String> urls = [];
    setState(() => _isUploadingImages = true);

    try {
      // Images Web (Uint8List)
      for (int i = 0; i < _imageBytes.length; i++) {
        final bytes = _imageBytes[i];
        final fileName = 'discussion_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final ref = _storage.ref().child('discussions/$fileName');
        
        final uploadTask = ref.putData(bytes);
        final snapshot = await uploadTask;
        final url = await snapshot.ref.getDownloadURL();
        urls.add(url);
        print('✅ Image $i uploadée (Web)');
      }

      // Images Mobile (File)
      for (int i = 0; i < _imageFiles.length; i++) {
        final file = _imageFiles[i];
        final fileName = 'discussion_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final ref = _storage.ref().child('discussions/$fileName');
        
        final uploadTask = ref.putFile(file);
        final snapshot = await uploadTask;
        final url = await snapshot.ref.getDownloadURL();
        urls.add(url);
        print('✅ Image $i uploadée (Mobile)');
      }

      setState(() => _isUploadingImages = false);
      return urls;
    } catch (e) {
      setState(() => _isUploadingImages = false);
      print('❌ Erreur upload images: $e');
      rethrow;
    }
  }

  // ✅ Créer la discussion (SANS TITRE)
  Future<void> _createDiscussion() async {
    final message = _messageController.text.trim();

    // ✅ Vérifier que le message n'est pas vide
    if (message.isEmpty) {
      _showSnackBar('⚠️ Veuillez entrer un message', Colors.orange);
      return;
    }

    // ✅ Vérifier la limite de 40 mots
    final wordCount = message.split(RegExp(r'\s+')).length;
    if (wordCount > 40) {
      _showSnackBar('⚠️ Le message ne peut pas dépasser 40 mots (${wordCount} mots)', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final appartement = widget.appartement ?? 'Admin';
      final author = _isAdmin ? 'Admin' : 'App $appartement';

      // Upload des images
      List<String> imageUrls = [];
      if (_imageBytes.isNotEmpty || _imageFiles.isNotEmpty) {
        imageUrls = await _uploadImages();
      }

      // ✅ Utiliser les premiers mots du message comme titre (max 50 caractères)
      String titre = message.length > 50 ? message.substring(0, 50) + '...' : message;
      // Si le message est vide, utiliser un titre par défaut
      if (titre.isEmpty) {
        titre = 'Discussion';
      }

      // Créer la discussion
      final docRef = await _firestore.collection('discussions').add({
        'volet': _selectedVolet,
        'titre': titre, // ✅ Titre généré automatiquement
        'message': message,
        'createdBy': author,
        'createdByAppartement': appartement,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'messageCount': 1,
        'participants': [appartement],
        'lastMessage': message,
        'imageUrls': imageUrls,
        'hasImages': imageUrls.isNotEmpty,
      });

      // Ajouter le premier message
      await _firestore
          .collection('discussions')
          .doc(docRef.id)
          .collection('messages')
          .add({
        'text': message,
        'author': author,
        'authorAppartement': appartement,
        'createdAt': FieldValue.serverTimestamp(),
        'imageUrls': imageUrls,
        'hasImages': imageUrls.isNotEmpty,
      });

      _showSnackBar('✅ Discussion créée avec succès', Colors.green);
      Navigator.pop(context, true);
    } catch (e) {
      print('❌ Erreur création discussion: $e');
      _showSnackBar('❌ Erreur: $e', Colors.red);
    }

    setState(() => _isLoading = false);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalImages = _imageBytes.length + _imageFiles.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('💬 Nouvelle discussion'),
        backgroundColor: Colors.cyan.shade800,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Volet
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonFormField<String>(
                value: _selectedVolet,
                decoration: const InputDecoration(
                  labelText: '📂 Choisir un volet',
                  border: InputBorder.none,
                ),
                items: _voletList.map((v) {
                  return DropdownMenuItem(value: v, child: Text(v));
                }).toList(),
                onChanged: (v) => setState(() => _selectedVolet = v!),
              ),
            ),
            const SizedBox(height: 16),

            // ✅ Message initial (SEUL CHAMP TEXTE)
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: '💬 Message initial',
                hintText: 'Décrivez votre sujet (max 40 mots)...',
                border: OutlineInputBorder(),
                helperText: '⚠️ Limite de 40 mots',
              ),
              maxLines: 4,
              onChanged: (value) {
                final wordCount = value.trim().split(RegExp(r'\s+')).length;
                if (wordCount > 40) {
                  // Ne pas bloquer la saisie, mais afficher un indicateur
                }
              },
            ),
            const SizedBox(height: 4),
            // ✅ Compteur de mots
            ValueListenableBuilder(
              valueListenable: _messageController,
              builder: (context, TextEditingValue value, child) {
                final wordCount = value.text.trim().isEmpty 
                    ? 0 
                    : value.text.trim().split(RegExp(r'\s+')).length;
                return Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${wordCount}/40 mots',
                    style: TextStyle(
                      fontSize: 11,
                      color: wordCount > 40 ? Colors.red : Colors.grey.shade600,
                      fontWeight: wordCount > 40 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // ✅ Images
            const Text(
              '📎 Pièces jointes (justificatifs)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  // Aperçu des images
                  if (totalImages > 0)
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: totalImages,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: kIsWeb
                                      ? Image.memory(
                                          _imageBytes[index],
                                          fit: BoxFit.cover,
                                          width: 100,
                                          height: 100,
                                        )
                                      : Image.file(
                                          _imageFiles[index],
                                          fit: BoxFit.cover,
                                          width: 100,
                                          height: 100,
                                        ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 12,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
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
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Boutons
                  Row(
                    children: [
                      if (totalImages > 0)
                        Text(
                          '${totalImages} image(s)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _takePhoto,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Prendre photo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Galerie'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  if (_isUploadingImages)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ✅ Boutons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createDiscussion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyan.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            '💬 Créer',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Annuler', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}