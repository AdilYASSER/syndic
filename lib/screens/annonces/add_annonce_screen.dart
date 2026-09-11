// lib/screens/annonces/add_annonce_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import '../../models/annonce_model.dart';
import '../../services/annonce_service.dart';

class AddAnnonceScreen extends StatefulWidget {
  final AnnonceModel? annonce;
  final String appartement;
  final String nomPrenom;
  final String telephone;
  final String createdBy;

  const AddAnnonceScreen({
    super.key,
    this.annonce,
    required this.appartement,
    required this.nomPrenom,
    required this.telephone,
    required this.createdBy,
  });

  @override
  State<AddAnnonceScreen> createState() => _AddAnnonceScreenState();
}

class _AddAnnonceScreenState extends State<AddAnnonceScreen> {
  final _formKey = GlobalKey<FormState>();
  final AnnonceService _service = AnnonceService();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _prixController = TextEditingController();

  String _qualite = 'moyen';
  bool _isDon = false;
  bool _isVente = false;
  bool _isLocation = false;
  bool _isLoading = false;

  // Images
  List<dynamic> _newImages = []; // File (mobile) ou Uint8List (web)
  List<String> _existingImages = [];

  final List<Map<String, String>> _qualites = [
    {'value': 'neuf', 'label': '✨ Neuf'},
    {'value': 'bon_etat', 'label': '👍 Bon état'},
    {'value': 'moyen', 'label': '👌 Moyen'},
    {'value': 'usage', 'label': '🔧 Usagé'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.annonce != null) {
      _nomController.text = widget.annonce!.nomArticle;
      _descriptionController.text = widget.annonce!.description;
      _prixController.text = widget.annonce!.prix?.toString() ?? '';
      _qualite = widget.annonce!.qualite;
      _isDon = widget.annonce!.isDon;
      _isVente = widget.annonce!.isVente;
      _isLocation = widget.annonce!.isLocation;
      _existingImages = List.from(widget.annonce!.imageUrls);
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _descriptionController.dispose();
    _prixController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() => _newImages.add(bytes));
        } else {
          setState(() => _newImages.add(File(image.path)));
        }
      }
    } catch (e) {
      print('❌ Erreur image: $e');
    }
  }

  void _showImagePicker() {
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: const Icon(Icons.photo_camera, color: Colors.blue),
                ),
                title: const Text('📷 Prendre une photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: const Icon(Icons.photo_library, color: Colors.green),
                ),
                title: const Text('🖼️ Choisir depuis la galerie'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    // Validation
    if (_nomController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Veuillez entrer le nom de l\'article'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_isDon && !_isVente && !_isLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Veuillez sélectionner au moins un type (Don, Vente ou Location)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if ((_isVente || _isLocation) && _prixController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Veuillez entrer un prix pour la vente ou la location'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final annonce = AnnonceModel(
        id: widget.annonce?.id ?? '',
        nomArticle: _nomController.text.trim(),
        qualite: _qualite,
        isDon: _isDon,
        isVente: _isVente,
        isLocation: _isLocation,
        prix: (_isVente || _isLocation) ? double.tryParse(_prixController.text.trim()) : null,
        description: _descriptionController.text.trim(),
        appartement: widget.appartement,
        nomPrenom: widget.nomPrenom,
        telephone: widget.telephone,
        dateCreation: widget.annonce?.dateCreation ?? DateTime.now(),
        createdBy: widget.createdBy,
        isVisible: widget.annonce?.isVisible ?? true,
      );

      if (widget.annonce == null) {
        // Ajouter
        await _service.ajouterAnnonce(annonce, _newImages);
      } else {
        // Modifier
        await _service.modifierAnnonce(
          widget.annonce!.id,
          annonce.toJson(),
          _newImages,
          _existingImages,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.annonce == null 
                ? '✅ Annonce publiée avec succès' 
                : '✅ Annonce modifiée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.annonce == null ? '➕ Nouvelle annonce' : '✏️ Modifier l\'annonce'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Nom de l'article
              TextFormField(
                controller: _nomController,
                decoration: const InputDecoration(
                  labelText: 'Nom de l\'article *',
                  prefixIcon: Icon(Icons.inventory),
                  border: OutlineInputBorder(),
                  hintText: 'Ex: Réfrigérateur, Machine à laver...',
                ),
              ),
              const SizedBox(height: 16),

              // ✅ Qualité
              DropdownButtonFormField<String>(
                value: _qualite,
                decoration: const InputDecoration(
                  labelText: 'Qualité de l\'article *',
                  prefixIcon: Icon(Icons.star),
                  border: OutlineInputBorder(),
                ),
                items: _qualites.map((q) {
                  return DropdownMenuItem(
                    value: q['value'],
                    child: Text(q['label']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _qualite = value!);
                },
              ),
              const SizedBox(height: 16),

              // ✅ Type d'annonce
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Type d\'annonce *',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      title: const Text('🎁 Don'),
                      subtitle: const Text('Gratuit'),
                      value: _isDon,
                      onChanged: (value) {
                        setState(() => _isDon = value!);
                      },
                      activeColor: Colors.green,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      title: const Text('💰 Vente'),
                      subtitle: const Text('Avec prix'),
                      value: _isVente,
                      onChanged: (value) {
                        setState(() => _isVente = value!);
                      },
                      activeColor: Colors.blue,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      title: const Text('🏠 Location'),
                      subtitle: const Text('Avec prix'),
                      value: _isLocation,
                      onChanged: (value) {
                        setState(() => _isLocation = value!);
                      },
                      activeColor: Colors.orange,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ✅ Prix (si vente ou location)
              if (_isVente || _isLocation) ...[
                TextFormField(
                  controller: _prixController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Prix (DH) *',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                    suffixText: 'DH',
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ✅ Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optionnel)',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),

              // ✅ Photos
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.photo, color: Colors.teal),
                        const SizedBox(width: 8),
                        const Text(
                          'Photos',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          '${_newImages.length + _existingImages.length} photo(s)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Aperçu des images
                    if (_newImages.isNotEmpty || _existingImages.isNotEmpty)
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _newImages.length + _existingImages.length,
                          itemBuilder: (context, index) {
                            final isNew = index < _newImages.length;
                            
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
                                    child: isNew
                                        ? (kIsWeb
                                            ? Image.memory(
                                                _newImages[index] as Uint8List,
                                                fit: BoxFit.cover,
                                              )
                                            : Image.file(
                                                _newImages[index] as File,
                                                fit: BoxFit.cover,
                                              ))
                                        : Image.network(
                                            _existingImages[index - _newImages.length],
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 12,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (isNew) {
                                          _newImages.removeAt(index);
                                        } else {
                                          _existingImages.removeAt(index - _newImages.length);
                                        }
                                      });
                                    },
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
                    
                    // Bouton ajouter
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showImagePicker,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Ajouter des photos'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ✅ Bouton Enregistrer
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                      : Text(
                          widget.annonce == null ? '📤 Publier' : '💾 Enregistrer',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}