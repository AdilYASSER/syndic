// lib/screens/reclamations_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../services/reclamation_service.dart';
import '../models/reclamation_model.dart';

class ReclamationsScreen extends StatefulWidget {
  final String role;
  final String? appartement;
  final String userId;
  final String userName;

  const ReclamationsScreen({
    super.key,
    required this.role,
    this.appartement,
    required this.userId,
    required this.userName,
  });

  @override
  State<ReclamationsScreen> createState() => _ReclamationsScreenState();
}

class _ReclamationsScreenState extends State<ReclamationsScreen> {
  final ReclamationService _reclamationService = ReclamationService();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _titreController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ✅ NOUVELLES CATÉGORIES - MODIFICATION ICI
  String _selectedCategorie = 'PROPRETÉ';
  String _selectedPriorite = 'moyenne';
  bool _isLoading = false;
  bool _isClient = false;
  
  List<dynamic> _selectedImages = [];
  bool _isUploading = false;

  // ✅ NOUVELLES CATÉGORIES - MODIFICATION ICI
  final List<String> _categories = [
    'PROPRETÉ',
    'FUITE D\'EAU',
    'FUITE AUX ÉGOUTS',
    'COUPURE D\'EAU',
    'DÉBIT FAIBLE D\'EAU',
    'COUPURE ÉLECTRICITÉ',
    'ÉCLAIRAGE',
    'INTERNET',
    'ASCENSEURS',
    'JARDINAGE',
    'BRUIT',
    'SÉCURITÉ',
    'STATIONNEMENT',
    'RONGEURS ET INSECTES',
    'AUTRE',
  ];

  final List<String> _priorites = ['basse', 'moyenne', 'haute', 'urgente'];

  // ✅ ICÔNES POUR CHAQUE CATÉGORIE
  IconData _getCategoryIcon(String categorie) {
    switch (categorie) {
      case 'PROPRETÉ': return Icons.cleaning_services;
      case 'FUITE D\'EAU': return Icons.water_damage;
      case 'FUITE AUX ÉGOUTS': return Icons.plumbing;
      case 'COUPURE D\'EAU': return Icons.water;
      case 'DÉBIT FAIBLE D\'EAU': return Icons.speed;
      case 'COUPURE ÉLECTRICITÉ': return Icons.flash_off;
      case 'ÉCLAIRAGE': return Icons.lightbulb;
      case 'INTERNET': return Icons.wifi;
      case 'ASCENSEURS': return Icons.elevator;
      case 'JARDINAGE': return Icons.grass;
      case 'BRUIT': return Icons.volume_up;
      case 'SÉCURITÉ': return Icons.security;
      case 'STATIONNEMENT': return Icons.local_parking;
      case 'RONGEURS ET INSECTES': return Icons.bug_report;
      case 'AUTRE': return Icons.more_horiz;
      default: return Icons.category;
    }
  }

  @override
  void initState() {
    super.initState();
    _isClient = widget.role != 'admin';
    
    if (_isClient) {
      _titreController.text = 'Réclamation - App ${widget.appartement ?? ''} - ${DateFormat('dd/MM/yy').format(DateTime.now())}';
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _titreController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
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
        } else {
          final file = File(photo.path);
          setState(() {
            _selectedImages.add(file);
          });
        }
      }
    } catch (e) {
      print('❌ Erreur prise de photo: $e');
    }
  }

  Future<void> _pickImage() async {
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
        } else {
          final file = File(image.path);
          setState(() {
            _selectedImages.add(file);
          });
        }
      }
    } catch (e) {
      print('❌ Erreur sélection: $e');
    }
  }

  Future<void> _pickMultipleImages() async {
    try {
      final List<XFile>? images = await _imagePicker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (images != null && images.isNotEmpty) {
        for (var image in images) {
          if (kIsWeb) {
            final bytes = await image.readAsBytes();
            setState(() {
              _selectedImages.add(bytes);
            });
          } else {
            final file = File(image.path);
            setState(() {
              _selectedImages.add(file);
            });
          }
        }
      }
    } catch (e) {
      print('❌ Erreur sélection multiple: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<List<String>> _uploadImages() async {
    List<String> urls = [];
    
    for (var image in _selectedImages) {
      try {
        String fileName = 'reclamations/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = _storage.ref().child(fileName);
        
        if (kIsWeb && image is Uint8List) {
          final metadata = SettableMetadata(
            contentType: 'image/jpeg',
          );
          await ref.putData(image, metadata);
        } else if (!kIsWeb && image is File) {
          final metadata = SettableMetadata(
            contentType: 'image/jpeg',
          );
          await ref.putFile(image, metadata);
        }
        
        final url = await ref.getDownloadURL();
        urls.add(url);
      } catch (e) {
        print('❌ Erreur upload image: $e');
      }
    }
    
    return urls;
  }

  void _showImagePickerDialog() {
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
              if (_selectedImages.isNotEmpty)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.shade100,
                    child: const Icon(Icons.delete, color: Colors.red),
                  ),
                  title: const Text('🗑️ Supprimer toutes les photos'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedImages.clear());
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_selectedImages.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 100,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedImages.length,
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
                          _selectedImages[index] as Uint8List,
                          fit: BoxFit.cover,
                          width: 100,
                          height: 100,
                        )
                      : Image.file(
                          _selectedImages[index] as File,
                          fit: BoxFit.cover,
                          width: 100,
                          height: 100,
                        ),
                ),
              ),
              Positioned(
                top: -5,
                right: 5,
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
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submitReclamation() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir une description'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        setState(() => _isUploading = true);
        imageUrls = await _uploadImages();
        setState(() => _isUploading = false);
      }

      final reclamation = ReclamationModel(
        id: '',
        titre: _isClient 
            ? 'Réclamation - App ${widget.appartement ?? ''} - ${DateFormat('dd/MM/yy').format(DateTime.now())}'
            : _titreController.text.trim(),
        description: _descriptionController.text.trim(),
        categorie: _selectedCategorie,
        statut: 'en_attente',
        appartement: widget.appartement ?? 'N/A',
        utilisateurId: widget.userId,
        utilisateurNom: widget.userName,
        dateCreation: DateTime.now(),
        priorite: _selectedPriorite,
        imageUrls: imageUrls,
      );

      await _reclamationService.createReclamation(reclamation);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Réclamation envoyée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('❌ Erreur: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getPrioriteLabel(String value) {
    switch (value) {
      case 'basse': return '🟢 Basse';
      case 'moyenne': return '🟡 Moyenne';
      case 'haute': return '🟠 Haute';
      case 'urgente': return '🔴 Urgente';
      default: return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isClient = widget.role != 'admin';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('📝 Nouvelle Réclamation'),
        backgroundColor: isClient ? Colors.green.shade700 : Colors.blue.shade800,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isClient ? Colors.green.shade700 : Colors.orange.shade700,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isClient ? '👤 Client' : '👑 Admin',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.apartment, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Appartement: ${widget.appartement ?? 'N/A'}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (!isClient) ...[
              TextFormField(
                controller: _titreController,
                decoration: const InputDecoration(
                  labelText: 'Titre de la réclamation *',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un titre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],

            // ✅ CATÉGORIE AVEC ICÔNES
            DropdownButtonFormField<String>(
              value: _selectedCategorie,
              decoration: const InputDecoration(
                labelText: 'Catégorie *',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              items: _categories.map((categorie) {
                return DropdownMenuItem(
                  value: categorie,
                  child: Row(
                    children: [
                      Icon(_getCategoryIcon(categorie), size: 20, color: Colors.blue.shade700),
                      const SizedBox(width: 10),
                      Text(categorie),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategorie = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedPriorite,
              decoration: const InputDecoration(
                labelText: 'Priorité',
                prefixIcon: Icon(Icons.flag),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              items: _priorites.map((priorite) {
                return DropdownMenuItem(
                  value: priorite,
                  child: Text(_getPrioriteLabel(priorite)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPriorite = value!;
                });
              },
            ),
            const SizedBox(height: 16),

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
                      if (_selectedImages.isNotEmpty)
                        Text(
                          '${_selectedImages.length} photo(s)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                          ),
                        ),
                    ],
                  ),
                  if (_selectedImages.isNotEmpty)
                    _buildImagePreview(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isUploading ? null : _showImagePickerDialog,
                          icon: const Icon(Icons.add_photo_alternate, size: 18),
                          label: const Text('Ajouter des photos'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade50,
                            foregroundColor: Colors.blue.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description *',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                alignLabelWithHint: true,
              ),
              maxLines: 6,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez saisir une description';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitReclamation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isClient ? Colors.green.shade700 : Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading || _isUploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '📤 Envoyer la réclamation',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}