// lib/screens/add_cotisation_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../models/cotisation.dart';
import '../services/cotisation_service.dart';
import '../models/habitant.dart';

class AddCotisationScreen extends StatefulWidget {
  final Cotisation? cotisation;
  final String? fonction;

  const AddCotisationScreen({super.key, this.cotisation, this.fonction});

  @override
  State<AddCotisationScreen> createState() => _AddCotisationScreenState();
}

class _AddCotisationScreenState extends State<AddCotisationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numAppartementController = TextEditingController();
  final _nomPrenomController = TextEditingController();
  final _montantController = TextEditingController();
  final _anneeController = TextEditingController();
  
  DateTime _dateVersement = DateTime.now();
  String _modeVersement = 'espece';
  String _statut = 'En attente'; // ✅ Nouveau champ statut
  bool _periode1 = false;
  bool _periode2 = false;
  bool _isLoading = false;
  String _selectedAppartement = '';
  
  // Justificatif
  File? _imageFile;
  Uint8List? _imageBytes;
  String? _imageUrl;
  bool _isUploading = false;
  
  final CotisationService _cotisationService = CotisationService();
  List<Habitant> _habitants = [];
  List<String> _appartementsList = [];
  bool _isLoadingHabitants = false;
  
  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ✅ Liste des statuts disponibles
  final List<Map<String, dynamic>> _statutsList = [
    {'value': 'Payé', 'label': '✅ Payé', 'color': Colors.green},
    {'value': 'En attente', 'label': '⏳ En attente', 'color': Colors.orange},
    {'value': 'Annulée', 'label': '❌ Annulée', 'color': Colors.red},
    {'value': 'Impayé', 'label': '⚠️ Impayé', 'color': Colors.red.shade700},
  ];

  @override
  void initState() {
    super.initState();
    _loadHabitants();
    if (widget.cotisation != null) {
      _loadExistingData();
    } else {
      _anneeController.text = DateTime.now().year.toString();
      _periode1 = true;
      _montantController.text = '1800.00';
      _statut = 'En attente'; // ✅ Statut par défaut
    }
  }

  @override
  void dispose() {
    _numAppartementController.dispose();
    _nomPrenomController.dispose();
    _montantController.dispose();
    _anneeController.dispose();
    super.dispose();
  }

  Future<void> _loadHabitants() async {
    setState(() => _isLoadingHabitants = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('habitants')
          .orderBy('numAppartement')
          .get();
      
      _habitants = snapshot.docs.map((doc) {
        final data = doc.data();
        return Habitant(
          id: data['id']?.toString() ?? doc.id,
          nom: data['nom'] ?? '',
          prenom: data['prenom'] ?? '',
          numAppartement: data['numAppartement'] ?? '',
          telephone: data['telephone'] ?? '',
          statut: data['statut'] ?? 'proprietaire',
          rib: data['rib'] ?? '',
          cinUrl: data['cinUrl'],
          synced: 1,
        );
      }).toList();
      _appartementsList = _habitants.map((h) => h.numAppartement).toList();
      print('✅ ${_habitants.length} habitants chargés depuis Firestore');
    } catch (e) {
      print('❌ Erreur chargement habitants: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur chargement habitants: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) {
      setState(() => _isLoadingHabitants = false);
    }
  }

  void _loadExistingData() {
    final c = widget.cotisation!;
    _selectedAppartement = c.numAppartement;
    _numAppartementController.text = c.numAppartement;
    _nomPrenomController.text = c.nomPrenom;
    _dateVersement = c.dateVersement ?? DateTime.now();
    _modeVersement = c.modeVersement;
    _statut = c.statut ?? 'En attente'; // ✅ Charger le statut existant
    _montantController.text = c.montant.toString();
    _periode1 = c.periode1;
    _periode2 = c.periode2;
    _anneeController.text = c.annee.toString();
    _imageUrl = c.justificatifUrl;
  }

  void _onAppartementSelected(String numAppartement) {
    _selectedAppartement = numAppartement;
    _numAppartementController.text = numAppartement;
    
    final habitant = _habitants.firstWhere(
      (h) => h.numAppartement == numAppartement,
      orElse: () => Habitant(
        id: null,
        nom: '',
        prenom: '',
        numAppartement: '',
        telephone: '',
        statut: '',
        rib: '',
      ),
    );
    if (habitant.nom.isNotEmpty) {
      _nomPrenomController.text = '${habitant.prenom} ${habitant.nom}'.trim();
    } else {
      _nomPrenomController.text = '';
    }
    
    setState(() {});
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateVersement,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('fr', 'FR'),
    );
    
    if (picked != null) {
      setState(() => _dateVersement = picked);
    }
  }

  // Prendre une photo
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
            _imageBytes = bytes;
            _imageFile = null;
            _imageUrl = null;
          });
        } else {
          final file = File(photo.path);
          setState(() {
            _imageFile = file;
            _imageBytes = null;
            _imageUrl = null;
          });
        }
      }
    } catch (e) {
      print('❌ Erreur prise de photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Choisir une photo depuis la galerie
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
            _imageBytes = bytes;
            _imageFile = null;
            _imageUrl = null;
          });
        } else {
          final file = File(image.path);
          setState(() {
            _imageFile = file;
            _imageBytes = null;
            _imageUrl = null;
          });
        }
      }
    } catch (e) {
      print('❌ Erreur sélection: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Afficher le dialogue de sélection d'image
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
                '📸 Ajouter un justificatif',
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
              if (_imageFile != null || _imageBytes != null || _imageUrl != null)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.shade100,
                    child: const Icon(Icons.delete, color: Colors.red),
                  ),
                  title: const Text('🗑️ Supprimer le justificatif'),
                  subtitle: const Text('Retirer l\'image sélectionnée'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _imageFile = null;
                      _imageBytes = null;
                      _imageUrl = null;
                    });
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // Upload du justificatif
  Future<String?> _uploadJustificatif() async {
    if (_imageFile == null && _imageBytes == null) {
      return _imageUrl;
    }

    setState(() => _isUploading = true);

    try {
      String fileName = 'justificatifs_cotisations/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(fileName);
      
      if (kIsWeb && _imageBytes != null) {
        final uploadTask = ref.putData(
          _imageBytes!,
          SettableMetadata(
            contentType: 'image/jpeg',
          ),
        );
        final snapshot = await uploadTask.whenComplete(() => {});
        final url = await snapshot.ref.getDownloadURL();
        setState(() {
          _imageUrl = url;
          _isUploading = false;
        });
        return url;
      } else if (_imageFile != null) {
        final uploadTask = ref.putFile(
          _imageFile!,
          SettableMetadata(
            contentType: 'image/jpeg',
          ),
        );
        final snapshot = await uploadTask.whenComplete(() => {});
        final url = await snapshot.ref.getDownloadURL();
        setState(() {
          _imageUrl = url;
          _isUploading = false;
        });
        return url;
      }
      
      return null;
    } catch (e) {
      setState(() => _isUploading = false);
      print('❌ Erreur upload: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur upload: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  // Widget d'aperçu du justificatif
  Widget _buildJustificatifPreview() {
    if (_imageFile != null) {
      return Image.file(_imageFile!, fit: BoxFit.cover, width: 80, height: 80);
    } else if (_imageBytes != null) {
      return Image.memory(_imageBytes!, fit: BoxFit.cover, width: 80, height: 80);
    } else if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      return Image.network(_imageUrl!, fit: BoxFit.cover, width: 80, height: 80);
    }
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey.shade200,
      child: const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }

  // ✅ Widget pour le sélecteur de statut
  Widget _buildStatutSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonFormField<String>(
        value: _statut,
        decoration: const InputDecoration(
          border: InputBorder.none,
          icon: Icon(Icons.flag),
        ),
        items: _statutsList.map((statut) {
          return DropdownMenuItem<String>(
            value: statut['value'],
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statut['color'],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(statut['label']),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _statut = value!;
          });
        },
      ),
    );
  }

  Future<void> _save() async {
    if (_selectedAppartement.isEmpty && _numAppartementController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Veuillez sélectionner un numéro d\'appartement'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (!_periode1 && !_periode2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Veuillez sélectionner au moins une période'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload du justificatif
      String? justificatifUrl = await _uploadJustificatif();

      final numAppartement = _selectedAppartement.isNotEmpty 
          ? _selectedAppartement 
          : _numAppartementController.text.trim();

      // ✅ Déterminer le statut (utiliser celui sélectionné)
      String statut = _statut;

      // Si le statut est "En attente" mais qu'une date de versement existe, 
      // on peut automatiquement le passer à "Payé" (optionnel)
      if (statut == 'En attente' && _dateVersement.isBefore(DateTime.now())) {
        // On laisse le choix à l'utilisateur, on ne force pas le changement
        // statut = 'Payé';
      }

      final cotisation = Cotisation(
        id: widget.cotisation?.id,
        numAppartement: numAppartement,
        nomPrenom: _nomPrenomController.text.trim().isEmpty 
            ? numAppartement
            : _nomPrenomController.text.trim(),
        dateVersement: _dateVersement,
        modeVersement: _modeVersement,
        montant: double.parse(_montantController.text.trim()),
        periode1: _periode1,
        periode2: _periode2,
        annee: int.parse(_anneeController.text.trim()),
        synced: 0,
        justificatifUrl: justificatifUrl,
        statut: statut,
        dateCreation: widget.cotisation?.dateCreation ?? DateTime.now(),
        appartement: numAppartement,
      );

      final id = await _cotisationService.saveCotisationToFirestore(cotisation);
      cotisation.id = id;
      print('✅ Cotisation sauvegardée dans Firestore avec ID: $id');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cotisation enregistrée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('❌ Erreur lors de l\'enregistrement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Récupérer la couleur du statut actuel
    Color getStatutColor(String statut) {
      final found = _statutsList.firstWhere(
        (s) => s['value'] == statut,
        orElse: () => {'color': Colors.grey},
      );
      return found['color'];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cotisation == null ? '➕ Nouvelle cotisation' : '✏️ Modifier la cotisation'),
        backgroundColor: Colors.green.shade800,
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
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '📋 Informations de la cotisation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  _buildAppartementField(),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _nomPrenomController,
                    label: 'Nom et prénom',
                    icon: Icons.person,
                    readOnly: true,
                    validator: (v) => v!.isEmpty ? 'Sélectionnez un appartement' : null,
                  ),
                  const SizedBox(height: 16),

                  GestureDetector(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.green.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '📅 Date versement: ${DateFormat('dd/MM/yyyy').format(_dateVersement)}',
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
                      value: _modeVersement,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        icon: Icon(Icons.payment),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'espece', child: Text('💰 Espèce')),
                        DropdownMenuItem(value: 'virement', child: Text('🏦 Virement')),
                        DropdownMenuItem(value: 'cheque', child: Text('📝 Chèque')),
                      ],
                      onChanged: (v) => setState(() => _modeVersement = v!),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _montantController,
                    label: 'Montant (DH)',
                    icon: Icons.attach_money,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v!.isEmpty) return 'Montant requis';
                      if (double.tryParse(v) == null) return 'Montant invalide';
                      if (double.parse(v) <= 0) return 'Le montant doit être > 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _anneeController,
                    label: 'Année',
                    icon: Icons.calendar_month,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v!.isEmpty) return 'Année requise';
                      if (int.tryParse(v) == null) return 'Année invalide';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ✅ Sélecteur de statut
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.flag, color: getStatutColor(_statut)),
                            const SizedBox(width: 8),
                            const Text(
                              '📌 Statut de la cotisation',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: getStatutColor(_statut).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _statut,
                                style: TextStyle(
                                  color: getStatutColor(_statut),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildStatutSelector(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    '📅 Période concernée',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                        CheckboxListTile(
                          title: const Text('S1 - 6 premiers mois (Janvier - Juin)'),
                          value: _periode1,
                          onChanged: (v) => setState(() => _periode1 = v!),
                          activeColor: Colors.green,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                        CheckboxListTile(
                          title: const Text('S2 - 6 derniers mois (Juillet - Décembre)'),
                          value: _periode2,
                          onChanged: (v) => setState(() => _periode2 = v!),
                          activeColor: Colors.green,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // SECTION JUSTIFICATIF
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.attach_file, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            const Text(
                              '📎 Justificatif (optionnel)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            if (_imageFile != null || _imageBytes != null || (_imageUrl != null && _imageUrl!.isNotEmpty))
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '✅ Joint',
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
                            // Aperçu
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _buildJustificatifPreview(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _imageFile != null || _imageBytes != null || (_imageUrl != null && _imageUrl!.isNotEmpty)
                                        ? 'Justificatif sélectionné'
                                        : 'Aucun justificatif',
                                    style: TextStyle(
                                      color: _imageFile != null || _imageBytes != null || (_imageUrl != null && _imageUrl!.isNotEmpty)
                                          ? Colors.green.shade700
                                          : Colors.grey.shade600,
                                      fontWeight: _imageFile != null || _imageBytes != null || (_imageUrl != null && _imageUrl!.isNotEmpty)
                                          ? FontWeight.w500
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    onPressed: _isUploading ? null : _showImagePickerDialog,
                                    icon: Icon(
                                      _imageFile != null || _imageBytes != null || (_imageUrl != null && _imageUrl!.isNotEmpty)
                                          ? Icons.edit
                                          : Icons.add_photo_alternate,
                                      size: 18,
                                    ),
                                    label: Text(
                                      _imageFile != null || _imageBytes != null || (_imageUrl != null && _imageUrl!.isNotEmpty)
                                          ? 'Modifier'
                                          : 'Ajouter',
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
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade800,
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
                                  widget.cotisation == null ? '💾 Enregistrer' : '💾 Mettre à jour',
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

  // CHAMP APPARTEMENT
  Widget _buildAppartementField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedAppartement.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Appartement sélectionné: $_selectedAppartement',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ),
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<String>.empty();
              }
              return _appartementsList.where((String option) {
                return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
              });
            },
            onSelected: (String selection) {
              _onAppartementSelected(selection);
            },
            fieldViewBuilder: (
              BuildContext context,
              TextEditingController fieldController,
              FocusNode focusNode,
              VoidCallback onFieldSubmitted,
            ) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (fieldController.text != _numAppartementController.text) {
                  fieldController.text = _numAppartementController.text;
                }
              });

              return TextFormField(
                controller: fieldController,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: 'Numéro d\'appartement',
                  prefixIcon: Icon(Icons.apartment, color: Colors.green.shade700),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  suffixIcon: _isLoadingHabitants
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.green,
                          ),
                        )
                      : (_selectedAppartement.isNotEmpty
                          ? Icon(Icons.check_circle, color: Colors.green.shade700)
                          : null),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Numéro requis';
                  }
                  final exists = _habitants.any((h) => 
                    h.numAppartement.toUpperCase() == v.trim().toUpperCase()
                  );
                  if (!exists && widget.cotisation == null) {
                    return 'Appartement non trouvé';
                  }
                  return null;
                },
                onChanged: (value) {
                  _numAppartementController.text = value;
                  final exists = _habitants.any((h) => 
                    h.numAppartement.toUpperCase() == value.trim().toUpperCase()
                  );
                  if (exists) {
                    _selectedAppartement = value.trim();
                    final habitant = _habitants.firstWhere(
                      (h) => h.numAppartement.toUpperCase() == value.trim().toUpperCase(),
                    );
                    _nomPrenomController.text = '${habitant.prenom} ${habitant.nom}'.trim();
                  } else {
                    if (_selectedAppartement.isNotEmpty) {
                      _selectedAppartement = '';
                      _nomPrenomController.text = '';
                    }
                  }
                  setState(() {});
                },
              );
            },
            optionsViewBuilder: (
              BuildContext context,
              AutocompleteOnSelected<String> onSelected,
              Iterable<String> options,
            ) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: options.length,
                      itemBuilder: (BuildContext context, int index) {
                        final option = options.elementAt(index);
                        final habitant = _habitants.firstWhere(
                          (h) => h.numAppartement == option,
                          orElse: () => Habitant(
                            id: null,
                            nom: '',
                            prenom: '',
                            numAppartement: '',
                            telephone: '',
                            statut: '',
                            rib: '',
                          ),
                        );
                        return ListTile(
                          title: Text(option),
                          subtitle: habitant.nom.isNotEmpty
                              ? Text('${habitant.prenom} ${habitant.nom}')
                              : null,
                          onTap: () {
                            onSelected(option);
                          },
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.green.shade700),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        filled: readOnly,
        fillColor: readOnly ? Colors.grey.shade100 : null,
      ),
      validator: validator,
    );
  }
}