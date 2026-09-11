// lib/screens/add_habitant_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/habitant.dart';
import '../services/habitant_service.dart';

class AddHabitantScreen extends StatefulWidget {
  final Habitant? habitant;

  const AddHabitantScreen({super.key, this.habitant});

  @override
  State<AddHabitantScreen> createState() => _AddHabitantScreenState();
}

class _AddHabitantScreenState extends State<AddHabitantScreen> {
  final HabitantService _habitantService = HabitantService();
  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _numAppartementController = TextEditingController();
  final TextEditingController _telephoneController = TextEditingController();
  final TextEditingController _cinController = TextEditingController();
  final TextEditingController _ribController = TextEditingController();

  // Champs locataire
  final TextEditingController _nomLocataireController = TextEditingController();
  final TextEditingController _prenomLocataireController = TextEditingController();
  final TextEditingController _telephoneLocataireController = TextEditingController();
  final TextEditingController _cinLocataireController = TextEditingController();
  final TextEditingController _emailLocataireController = TextEditingController();
  final TextEditingController _adresseLocataireController = TextEditingController();

  String _statut = 'proprietaire';
  bool _isLoading = false;
  String? _cinPath;
  String? _cinUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.habitant != null) {
      final h = widget.habitant!;
      _nomController.text = h.nom;
      _prenomController.text = h.prenom;
      _numAppartementController.text = h.numAppartement;
      _telephoneController.text = h.telephone;
      _statut = h.statut;
      _cinController.text = h.cin;
      _ribController.text = h.rib;
      _cinUrl = h.cinUrl;
      _cinPath = h.cinPath;

      _nomLocataireController.text = h.locataireNom ?? '';
      _prenomLocataireController.text = h.locatairePrenom ?? '';
      _telephoneLocataireController.text = h.locataireTelephone ?? '';
      _cinLocataireController.text = h.locataireCin ?? '';
      _emailLocataireController.text = h.locataireEmail ?? '';
      _adresseLocataireController.text = h.locataireAdresse ?? '';
    }
  }

  @override // ✅ CORRIGÉ: @override en minuscule
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _numAppartementController.dispose();
    _telephoneController.dispose();
    _cinController.dispose();
    _ribController.dispose();
    _nomLocataireController.dispose();
    _prenomLocataireController.dispose();
    _telephoneLocataireController.dispose();
    _cinLocataireController.dispose();
    _emailLocataireController.dispose();
    _adresseLocataireController.dispose();
    super.dispose();
  }

  Future<void> _pickCINImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _cinPath = image.path;
          _isUploading = true;
        });

        final File file = File(image.path);
        final String fileName = 'cin_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final Reference ref = _storage.ref().child('cin_images/$fileName');

        final UploadTask uploadTask = ref.putFile(file);
        final TaskSnapshot snapshot = await uploadTask;
        final String downloadUrl = await snapshot.ref.getDownloadURL();

        setState(() {
          _cinUrl = downloadUrl;
          _isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Image CIN uploadée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur téléchargement CIN: $e');
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ✅ SAUVEGARDE CORRIGÉE
  Future<void> _saveHabitant() async {
    if (_nomController.text.isEmpty ||
        _prenomController.text.isEmpty ||
        _numAppartementController.text.isEmpty ||
        _telephoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir tous les champs obligatoires'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final habitant = Habitant(
        id: widget.habitant?.id,
        nom: _nomController.text.trim(),
        prenom: _prenomController.text.trim(),
        numAppartement: _numAppartementController.text.trim().toUpperCase(),
        telephone: _telephoneController.text.trim(),
        statut: _statut,
        rib: _ribController.text.trim(),
        cin: _cinController.text.trim(),
        cinPath: _cinPath,
        cinUrl: _cinUrl,
        locataireNom: _nomLocataireController.text.trim().isNotEmpty ? _nomLocataireController.text.trim() : null,
        locatairePrenom: _prenomLocataireController.text.trim().isNotEmpty ? _prenomLocataireController.text.trim() : null,
        locataireTelephone: _telephoneLocataireController.text.trim().isNotEmpty ? _telephoneLocataireController.text.trim() : null,
        locataireCin: _cinLocataireController.text.trim().isNotEmpty ? _cinLocataireController.text.trim() : null,
        locataireEmail: _emailLocataireController.text.trim().isNotEmpty ? _emailLocataireController.text.trim() : null,
        locataireAdresse: _adresseLocataireController.text.trim().isNotEmpty ? _adresseLocataireController.text.trim() : null,
        dateCreation: widget.habitant?.dateCreation ?? DateTime.now(),
        synced: widget.habitant?.synced ?? 0,
      );

      String? result;

      if (widget.habitant == null) {
        // ✅ AJOUT
        print('📝 Ajout d\'un nouvel habitant');
        result = await _habitantService.insertHabitant(habitant);
        print('📝 Résultat ajout: $result');
      } else {
        // ✅ MODIFICATION
        if (widget.habitant!.id == null || widget.habitant!.id!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ ID de l\'habitant manquant'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
        
        print('📝 Modification de l\'habitant ID: ${widget.habitant!.id}');
        result = await _habitantService.updateHabitant(habitant);
        print('📝 Résultat modification: $result');
      }

      if (result != null && result.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.habitant == null ? '✅ Habitant ajouté avec succès' : '✅ Habitant modifié avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Erreur lors de l\'enregistrement'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur sauvegarde: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.habitant != null;
    final bool showLocataireFields = _statut == 'proprietaire';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(isEditing ? '✏️ Modifier l\'habitant' : '➕ Ajouter un habitant'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informations du propriétaire
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        '👤 INFORMATIONS DU PROPRIÉTAIRE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Nom
                  TextFormField(
                    controller: _nomController,
                    decoration: const InputDecoration(
                      labelText: 'Nom *',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Prénom
                  TextFormField(
                    controller: _prenomController,
                    decoration: const InputDecoration(
                      labelText: 'Prénom *',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Téléphone
                  TextFormField(
                    controller: _telephoneController,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone *',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),

                  // CIN
                  TextFormField(
                    controller: _cinController,
                    decoration: const InputDecoration(
                      labelText: 'Numéro CIN',
                      prefixIcon: Icon(Icons.credit_card),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // RIB
                  TextFormField(
                    controller: _ribController,
                    decoration: const InputDecoration(
                      labelText: 'RIB',
                      prefixIcon: Icon(Icons.account_balance),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Appartement
                  TextFormField(
                    controller: _numAppartementController,
                    decoration: const InputDecoration(
                      labelText: 'Appartement *',
                      prefixIcon: Icon(Icons.apartment),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Statut
                  DropdownButtonFormField<String>(
                    value: _statut,
                    decoration: const InputDecoration(
                      labelText: 'Statut *',
                      prefixIcon: Icon(Icons.flag),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'proprietaire', child: Text('Propriétaire')),
                      DropdownMenuItem(value: 'locataire', child: Text('Locataire')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _statut = value!;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Photo CIN
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.badge, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        '🪪 PHOTO CIN',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isUploading ? null : _pickCINImage,
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
                          label: Text(_isUploading ? 'Upload...' : 'Choisir une image'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_cinUrl != null)
                        IconButton(
                          icon: const Icon(Icons.image, color: Colors.green),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => Dialog(
                                child: Image.network(_cinUrl!),
                              ),
                            );
                          },
                          tooltip: 'Voir l\'image',
                        ),
                      if (_cinPath != null || _cinUrl != null)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _cinPath = null;
                              _cinUrl = null;
                            });
                          },
                          tooltip: 'Supprimer l\'image',
                        ),
                    ],
                  ),
                  if (_cinPath != null || _cinUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '✅ Image sélectionnée',
                        style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Informations du locataire (si propriétaire)
            if (showLocataireFields)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_add, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          '👤 INFORMATIONS DU LOCATAIRE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Nom locataire
                    TextFormField(
                      controller: _nomLocataireController,
                      decoration: const InputDecoration(
                        labelText: 'Nom du locataire',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Prénom locataire
                    TextFormField(
                      controller: _prenomLocataireController,
                      decoration: const InputDecoration(
                        labelText: 'Prénom du locataire',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Téléphone locataire
                    TextFormField(
                      controller: _telephoneLocataireController,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone du locataire',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),

                    // CIN locataire
                    TextFormField(
                      controller: _cinLocataireController,
                      decoration: const InputDecoration(
                        labelText: 'CIN du locataire',
                        prefixIcon: Icon(Icons.credit_card),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Email locataire
                    TextFormField(
                      controller: _emailLocataireController,
                      decoration: const InputDecoration(
                        labelText: 'Email du locataire',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),

                    // Adresse locataire
                    TextFormField(
                      controller: _adresseLocataireController,
                      decoration: const InputDecoration(
                        labelText: 'Adresse du locataire',
                        prefixIcon: Icon(Icons.home_work),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Boutons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveHabitant,
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
                            isEditing ? '💾 Modifier l\'habitant' : '💾 Enregistrer l\'habitant',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Annuler',
                      style: TextStyle(fontSize: 16),
                    ),
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