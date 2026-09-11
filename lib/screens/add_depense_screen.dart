// lib/screens/add_depense_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/depense.dart';
import '../services/depense_service.dart';

class AddDepenseScreen extends StatefulWidget {
  final Depense? depense;

  const AddDepenseScreen({super.key, this.depense});

  @override
  State<AddDepenseScreen> createState() => _AddDepenseScreenState();
}

class _AddDepenseScreenState extends State<AddDepenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _beneficiaireController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _numeroChequeController = TextEditingController();
  
  String _selectedCategorie = 'Entretien Ascenseur';
  String? _selectedSousCategorie;
  DateTime _date = DateTime.now();
  String _statut = 'en_attente';
  String _modePaiement = 'espece';
  bool _isLoading = false;
  File? _imageFile;
  Uint8List? _imageBytes;
  String? _imageUrl;
  bool _isUploading = false;
  bool _showNumeroCheque = false;
  bool _hasExistingImage = false;

  final DepenseService _depenseService = DepenseService();
  final ImagePicker _imagePicker = ImagePicker();

  final List<String> _categories = [
    'Entretien Ascenseur',
    'Jardinage',
    'SRM',
    'Lignes Internet',
    'Maintenance Internet',
    'Gardiennage/Ménage',
    'Autres',
  ];

  final Map<String, List<String>> _sousCategories = {
    'Entretien Ascenseur': [
      'Réparation Ascenseur',
      'Entretien Ascenseurs',
    ],
    'Jardinage': [
      'Opération Désherbage',
      'Achat de Plantes',
      'Jardinage',
      'Fontaines',
    ],
    'SRM': [
      'SRM',
    ],
    'Lignes Internet': [
      'Lignes Internet',
    ],
    'Maintenance Internet': [
      'Maintenance Internet',
      'Entretien Internet',
    ],
    'Gardiennage/Ménage': [
      'Gardiennage',
      'Ménage',
    ],
    'Autres': [
      'Huissier',
      'Réparation Pompe Puits',
      'Réparation Éclairage',
      "Fuite d'eau",
      'Entretien Terrasse',
      'Salle de Prière',
      'Réparation Portes',
      'Entretien Caméras',
      'Préparatifs Aïd Adha',
      'Divers',
      'Lydec',
    ],
  };

  final List<String> _statuts = [
    'en_attente',
    'paye',
    'annule',
  ];

  final List<String> _modesPaiement = [
    'espece',
    'virement',
    'cheque',
  ];

  // ✅ Map pour convertir les statuts de Firestore vers l'affichage
  final Map<String, String> _statutDisplayMap = {
    'en_attente': '⏳ En attente',
    'paye': '✅ Payé',
    'annule': '❌ Annulé',
  };

  // ✅ Map pour convertir les statuts d'affichage vers Firestore
  final Map<String, String> _statutReverseMap = {
    '⏳ En attente': 'en_attente',
    '✅ Payé': 'paye',
    '❌ Annulé': 'annule',
  };

  List<String> get _allSousCategories {
    List<String> all = [];
    _sousCategories.forEach((key, value) {
      all.addAll(value);
    });
    return all;
  }

  @override
  void initState() {
    super.initState();
    if (widget.depense != null) {
      _loadExistingData();
    }
  }

  @override
  void dispose() {
    _montantController.dispose();
    _beneficiaireController.dispose();
    _descriptionController.dispose();
    _numeroChequeController.dispose();
    super.dispose();
  }

  void _loadExistingData() {
    final d = widget.depense!;
    
    print('📝 Chargement des données existantes:');
    print('   - Titre: ${d.titre}');
    print('   - Description: ${d.description}');
    print('   - Statut: ${d.statut}');
    print('   - Mode paiement: ${d.modePaiement}');
    print('   - Montant: ${d.montant}');
    print('   - Justificatif URL: ${d.justificatifUrl}');
    
    _montantController.text = d.montant.toString();
    _beneficiaireController.text = d.beneficiaire;
    _descriptionController.text = d.description;
    
    if (_categories.contains(d.categorie)) {
      _selectedCategorie = d.categorie;
    } else {
      _selectedCategorie = 'Autres';
    }
    
    if (d.sousCategorie != null && _allSousCategories.contains(d.sousCategorie)) {
      _selectedSousCategorie = d.sousCategorie;
    } else {
      _selectedSousCategorie = null;
    }
    
    _date = d.date;
    
    // ✅ CORRECTION: Chargement correct du statut
    String statutValue = d.statut ?? 'en_attente';
    // Si le statut est 'payé' (avec accent), on le corrige
    if (statutValue == 'payé') {
      statutValue = 'paye';
    }
    // Si le statut est 'paye' (sans accent), on le garde
    if (_statuts.contains(statutValue)) {
      _statut = statutValue;
    } else {
      _statut = 'en_attente';
    }
    print('   - Statut chargé: $_statut');
    
    if (_modesPaiement.contains(d.modePaiement)) {
      _modePaiement = d.modePaiement;
    } else {
      _modePaiement = 'espece';
    }
    
    // ✅ Chargement de l'image existante
    if (d.justificatifUrl != null && d.justificatifUrl!.isNotEmpty) {
      _imageUrl = d.justificatifUrl;
      _hasExistingImage = true;
      print('✅ Image existante chargée: ${_imageUrl!.substring(0, 60)}...');
    }
    
    if (d.numeroCheque != null && d.numeroCheque!.isNotEmpty) {
      _numeroChequeController.text = d.numeroCheque!;
      _showNumeroCheque = true;
    }
    
    // ✅ Forcer le rebuild pour afficher les données correctes
    setState(() {});
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (pickedFile != null) {
        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            _imageBytes = bytes;
            _imageFile = null;
            _hasExistingImage = false;
          });
          print('✅ Nouvelle image sélectionnée (Web): ${bytes.length} bytes');
        } else {
          final file = File(pickedFile.path);
          setState(() {
            _imageFile = file;
            _imageBytes = null;
            _hasExistingImage = false;
          });
          print('✅ Nouvelle image sélectionnée (Mobile): ${file.path}');
        }
      }
    } catch (e) {
      print('❌ Erreur sélection image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        if (kIsWeb) {
          if (file.bytes != null) {
            setState(() {
              _imageBytes = file.bytes;
              _imageFile = null;
              _hasExistingImage = false;
            });
            print('✅ Nouveau fichier sélectionné (Web): ${file.bytes!.length} bytes');
          }
        } else {
          if (file.path != null) {
            setState(() {
              _imageFile = File(file.path!);
              _imageBytes = null;
              _hasExistingImage = false;
            });
            print('✅ Nouveau fichier sélectionné (Mobile): ${file.path}');
          }
        }
      }
    } catch (e) {
      print('❌ Erreur sélection fichier: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImagePickerDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('📷 Prendre une photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('🖼️ Choisir depuis la galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('📎 Choisir un fichier (PDF, image)'),
              onTap: () {
                Navigator.pop(context);
                _pickFile();
              },
            ),
            if (_imageFile != null || _imageBytes != null || _hasExistingImage)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('🗑️ Supprimer le justificatif'),
                subtitle: Text(_hasExistingImage ? 'Supprimer l\'image existante' : 'Supprimer la nouvelle image'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _imageFile = null;
                    _imageBytes = null;
                    _imageUrl = null;
                    _hasExistingImage = false;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  // ✅ UPLOAD DU FICHIER
  Future<String?> _uploadFile() async {
    if (_hasExistingImage && _imageUrl != null && _imageUrl!.isNotEmpty) {
      print('ℹ️ Conservation de l\'image existante: $_imageUrl');
      return _imageUrl;
    }

    if (_imageFile == null && _imageBytes == null) {
      print('⚠️ Aucun fichier à uploader');
      return _imageUrl;
    }

    setState(() => _isUploading = true);

    try {
      final storage = FirebaseStorage.instance;
      final String fileName = 'justificatifs/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = storage.ref().child(fileName);
      
      print('📤 Upload du fichier vers: $fileName');
      
      if (kIsWeb && _imageBytes != null) {
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
        );
        await ref.putData(_imageBytes!, metadata);
        final url = await ref.getDownloadURL();
        print('✅ Upload réussi (Web): $url');
        return url;
      } else if (_imageFile != null) {
        final fileExtension = _imageFile!.path.split('.').last.toLowerCase();
        final metadata = SettableMetadata(
          contentType: fileExtension == 'pdf' ? 'application/pdf' : 'image/$fileExtension',
        );
        await ref.putFile(_imageFile!, metadata);
        final url = await ref.getDownloadURL();
        print('✅ Upload réussi (Mobile): $url');
        return url;
      }
      
      return null;
    } catch (e) {
      print('❌ Erreur upload: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur upload: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // ✅ WIDGET D'APERÇU DE L'IMAGE
  Widget _buildImagePreview() {
    if (_imageFile != null) {
      return Image.file(_imageFile!, fit: BoxFit.cover, width: 80, height: 80);
    } else if (_imageBytes != null) {
      return Image.memory(_imageBytes!, fit: BoxFit.cover, width: 80, height: 80);
    } else if (_hasExistingImage && _imageUrl != null && _imageUrl!.isNotEmpty) {
      return Image.network(
        _imageUrl!,
        fit: BoxFit.cover,
        width: 80,
        height: 80,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 80,
            height: 80,
            color: Colors.grey.shade200,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 80,
            height: 80,
            color: Colors.grey.shade200,
            child: const Icon(Icons.broken_image, color: Colors.grey),
          );
        },
      );
    }
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey.shade200,
      child: const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }

  bool _hasImage() {
    return _imageFile != null || _imageBytes != null || (_hasExistingImage && _imageUrl != null && _imageUrl!.isNotEmpty);
  }

  String _getImageStatusText() {
    if (_imageFile != null || _imageBytes != null) {
      return 'Nouveau justificatif sélectionné';
    } else if (_hasExistingImage && _imageUrl != null && _imageUrl!.isNotEmpty) {
      return 'Justificatif existant';
    }
    return 'Aucun justificatif';
  }

  Color _getImageStatusColor() {
    if (_imageFile != null || _imageBytes != null) {
      return Colors.green.shade700;
    } else if (_hasExistingImage && _imageUrl != null && _imageUrl!.isNotEmpty) {
      return Colors.blue.shade700;
    }
    return Colors.grey.shade600;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      print('❌ Formulaire invalide');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? justificatifUrl = _imageUrl;
      
      if (_imageFile != null || _imageBytes != null) {
        print('📤 Upload du nouveau justificatif...');
        final url = await _uploadFile();
        if (url != null) {
          justificatifUrl = url;
          print('✅ Nouveau justificatif uploadé: $url');
        } else {
          print('⚠️ Upload échoué');
        }
      } else if (_hasExistingImage && _imageUrl != null && _imageUrl!.isNotEmpty) {
        justificatifUrl = _imageUrl;
        print('ℹ️ Conservation de l\'image existante: $justificatifUrl');
      } else {
        justificatifUrl = null;
        print('ℹ️ Aucune image à sauvegarder');
      }

      // ✅ Construction du titre
      String titre = _selectedSousCategorie ?? _selectedCategorie;
      
      // ✅ Création de l'objet Depense avec le statut correct
      final depense = Depense(
        id: widget.depense?.id,
        titre: titre,
        montant: double.parse(_montantController.text.trim()),
        date: _date,
        categorie: _selectedCategorie,
        sousCategorie: _selectedSousCategorie,
        beneficiaire: _beneficiaireController.text.trim(),
        description: _descriptionController.text.trim(),
        justificatifUrl: justificatifUrl,
        createdBy: 'admin',
        statut: _statut, // ✅ Statut correct
        modePaiement: _modePaiement,
        numeroCheque: _modePaiement == 'cheque' ? _numeroChequeController.text.trim() : null,
      );

      print('📝 Sauvegarde de la dépense:');
      print('   - Titre: ${depense.titre}');
      print('   - Statut: ${depense.statut}');
      print('   - Montant: ${depense.montant}');
      print('   - Justificatif URL: ${depense.justificatifUrl}');

      await _depenseService.saveDepense(depense);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Dépense enregistrée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('❌ Erreur sauvegarde: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.depense == null ? '➕ Nouvelle Dépense' : '✏️ Modifier la Dépense'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
        actions: [
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedCategorie,
                    decoration: const InputDecoration(
                      labelText: '📂 Volet principal *',
                      prefixIcon: Icon(Icons.folder),
                      border: OutlineInputBorder(),
                    ),
                    items: _categories.map((categorie) {
                      return DropdownMenuItem(
                        value: categorie,
                        child: Text(categorie),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategorie = value!;
                        _selectedSousCategorie = null;
                      });
                    },
                    validator: (value) => value == null ? 'Sélectionnez un volet' : null,
                  ),
                  const SizedBox(height: 16),

                  if (_sousCategories[_selectedCategorie]?.isNotEmpty ?? false) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedSousCategorie,
                      decoration: const InputDecoration(
                        labelText: '📁 Sous-volet',
                        prefixIcon: Icon(Icons.folder_open),
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('Sélectionnez un sous-volet'),
                      items: (_sousCategories[_selectedCategorie] ?? []).map((sousCategorie) {
                        return DropdownMenuItem(
                          value: sousCategorie,
                          child: Text(sousCategorie),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSousCategorie = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '📄 Description',
                      prefixIcon: Icon(Icons.description),
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _montantController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '💰 Montant (DH) *',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(),
                      suffixText: 'DH',
                    ),
                    validator: (v) {
                      if (v!.isEmpty) return 'Montant requis';
                      if (double.tryParse(v) == null) return 'Montant invalide';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _beneficiaireController,
                    decoration: const InputDecoration(
                      labelText: '👤 Bénéficiaire',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  GestureDetector(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '📅 Date: ${DateFormat('dd/MM/yyyy').format(_date)}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _modePaiement,
                      decoration: const InputDecoration(
                        labelText: '💳 Mode de paiement',
                        border: InputBorder.none,
                      ),
                      items: _modesPaiement.map((mode) {
                        String label;
                        switch (mode) {
                          case 'virement': label = '🏦 Virement';
                            break;
                          case 'cheque': label = '📝 Chèque';
                            break;
                          default: label = '💰 Espèce';
                        }
                        return DropdownMenuItem(
                          value: mode,
                          child: Text(label),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _modePaiement = value!;
                          _showNumeroCheque = value == 'cheque';
                          if (!_showNumeroCheque) {
                            _numeroChequeController.clear();
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_showNumeroCheque)
                    TextFormField(
                      controller: _numeroChequeController,
                      decoration: const InputDecoration(
                        labelText: '📝 Numéro de chèque',
                        prefixIcon: Icon(Icons.numbers),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // ✅ DROPDOWN STATUT AVEC VALEUR CORRECTE
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _statut,
                      decoration: const InputDecoration(
                        labelText: '📊 Statut',
                        border: InputBorder.none,
                      ),
                      items: _statuts.map((statut) {
                        String label;
                        switch (statut) {
                          case 'paye': label = '✅ Payé';
                            break;
                          case 'annule': label = '❌ Annulé';
                            break;
                          default: label = '⏳ En attente';
                        }
                        return DropdownMenuItem(
                          value: statut,
                          child: Text(label),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _statut = value!;
                          print('📊 Statut changé vers: $_statut');
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ✅ SECTION JUSTIFICATIF
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _hasImage() ? Colors.green.shade300 : Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      color: _hasImage() ? Colors.green.shade50 : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _hasImage() ? Icons.check_circle : Icons.attach_file,
                              color: _hasImage() ? Colors.green.shade700 : Colors.blue.shade700,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '📎 Justificatif (optionnel)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            if (_hasImage())
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '✅ ${_imageFile != null || _imageBytes != null ? 'Nouveau' : 'Existant'}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _hasImage() ? Colors.green.shade300 : Colors.grey.shade300,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _buildImagePreview(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getImageStatusText(),
                                    style: TextStyle(
                                      color: _getImageStatusColor(),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (_hasExistingImage && _imageUrl != null && _imageUrl!.isNotEmpty)
                                    Text(
                                      'Lien: ${_imageUrl!.substring(0, _imageUrl!.length > 60 ? 60 : _imageUrl!.length)}...',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    onPressed: _isUploading ? null : _showImagePickerDialog,
                                    icon: Icon(
                                      _hasImage() ? Icons.edit : Icons.add_photo_alternate,
                                      size: 18,
                                    ),
                                    label: Text(
                                      _hasImage() ? 'Modifier' : 'Ajouter',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade50,
                                      foregroundColor: Colors.blue.shade700,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
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
                              : Text(
                                  widget.depense == null ? '💾 Enregistrer' : '💾 Mettre à jour',
                                  style: const TextStyle(fontSize: 16),
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
          ),
          if (_isUploading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Upload du justificatif...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}