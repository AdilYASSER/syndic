// lib/screens/reclamation_detail_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/reclamation_model.dart';
import '../services/reclamation_service.dart';

class ReclamationDetailScreen extends StatefulWidget {
  final ReclamationModel reclamation;
  final bool isAdmin;

  const ReclamationDetailScreen({
    super.key,
    required this.reclamation,
    this.isAdmin = false,
  });

  @override
  State<ReclamationDetailScreen> createState() => _ReclamationDetailScreenState();
}

class _ReclamationDetailScreenState extends State<ReclamationDetailScreen> {
  final ReclamationService _service = ReclamationService();
  final TextEditingController _reponseController = TextEditingController();
  File? _reponseImage;
  Uint8List? _reponseImageBytes;
  bool _isLoading = false;
  bool _isWeb = false;
  String _selectedStatut = 'en_cours';

  final List<String> _statutOptions = [
    'en_attente',
    'en_cours',
    'resolu',
    'refuse',
  ];

  final Map<String, String> _statutLabels = {
    'en_attente': '⏳ En attente',
    'en_cours': '🔄 En cours',
    'resolu': '✅ Résolu',
    'refuse': '❌ Refusé',
  };

  @override
  void initState() {
    super.initState();
    _selectedStatut = widget.reclamation.statut;
    if (widget.reclamation.reponseAdmin != null) {
      _reponseController.text = widget.reclamation.reponseAdmin!;
    }
    // ✅ NE PAS utiliser Theme.of(context) ici
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ Déterminer si c'est le Web après que le contexte est prêt
    _isWeb = Theme.of(context).platform == TargetPlatform.iOS || 
             Theme.of(context).platform == TargetPlatform.android ? false : true;
  }

  @override
  void dispose() {
    _reponseController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      if (_isWeb) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
        if (result != null && result.files.isNotEmpty) {
          final bytes = result.files.first.bytes;
          if (bytes != null) {
            setState(() {
              _reponseImageBytes = bytes;
              _reponseImage = null;
            });
          }
        }
      } else {
        final picker = ImagePicker();
        final image = await picker.pickImage(source: ImageSource.gallery);
        if (image != null) {
          setState(() {
            _reponseImage = File(image.path);
            _reponseImageBytes = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      _reponseImage = null;
      _reponseImageBytes = null;
    });
  }

  Future<void> _submitReponse() async {
    if (_reponseController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Veuillez saisir une réponse'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? photoUrl;
      
      if (_reponseImage != null) {
        final fileName = '${widget.reclamation.id}_reponse.jpg';
        photoUrl = await _service.uploadPhoto(_reponseImage!, fileName);
      } else if (_reponseImageBytes != null) {
        final fileName = '${widget.reclamation.id}_reponse.jpg';
        photoUrl = await _service.uploadPhotoBytes(_reponseImageBytes!, fileName);
      }

      await _service.repondreReclamation(
        widget.reclamation.id,
        _reponseController.text,
        photoUrl,
      );

      // Mettre à jour le statut si différent
      if (_selectedStatut != widget.reclamation.statut) {
        await _service.updateStatut(widget.reclamation.id, _selectedStatut);
      }

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Réponse envoyée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _viewImage(String url) async {
    try {
      await launchUrl(Uri.parse(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reclamation;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          r.titre,
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: Colors.deepOrange.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informations générales
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: r.statutColor.withOpacity(0.2),
                          child: Icon(
                            Icons.feedback,
                            color: r.statutColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.titre,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: r.statutColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      r.statutText,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: r.statutColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: r.prioriteColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      r.prioriteText,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: r.prioriteColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(Icons.apartment, 'Appartement', r.appartement),
                    _buildInfoRow(Icons.category, 'Catégorie', r.categorie),
                    _buildInfoRow(Icons.person, 'Utilisateur', r.utilisateurNom),
                    _buildInfoRow(
                      Icons.calendar_today,
                      'Date',
                      DateFormat('dd/MM/yyyy à HH:mm').format(r.dateCreation),
                    ),
                    if (r.dateResolution != null)
                      _buildInfoRow(
                        Icons.check_circle,
                        'Résolu le',
                        DateFormat('dd/MM/yyyy à HH:mm').format(r.dateResolution!),
                      ),
                    if (r.photoUrl != null) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _viewImage(r.photoUrl!),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.image, color: Colors.blue),
                              const SizedBox(width: 8),
                              const Text('Voir la photo jointe'),
                              const Spacer(),
                              const Icon(Icons.open_in_new, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Description
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📝 Description',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      r.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Réponse existante
            if (r.reponseAdmin != null) ...[
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.reply, color: Colors.green),
                          const SizedBox(width: 8),
                          const Text(
                            '📌 Réponse de l\'admin',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          if (r.dateReponse != null)
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(r.dateReponse!),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        r.reponseAdmin!,
                        style: const TextStyle(fontSize: 14),
                      ),
                      if (r.reponsePhotoUrl != null) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _viewImage(r.reponsePhotoUrl!),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.image, color: Colors.blue),
                                const SizedBox(width: 8),
                                const Text('Voir la photo de réponse'),
                                const Spacer(),
                                const Icon(Icons.open_in_new, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Zone de réponse (Admin uniquement)
            if (widget.isAdmin) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '✏️ Répondre à la réclamation',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Statut
                      DropdownButtonFormField<String>(
                        value: _selectedStatut,
                        decoration: const InputDecoration(
                          labelText: 'Statut',
                          border: OutlineInputBorder(),
                        ),
                        items: _statutOptions.map((statut) {
                          return DropdownMenuItem(
                            value: statut,
                            child: Text(_statutLabels[statut] ?? statut),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedStatut = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Réponse
                      TextField(
                        controller: _reponseController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Votre réponse *',
                          hintText: 'Saisissez votre réponse ici...',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Photo de réponse
                      if (_reponseImage != null || _reponseImageBytes != null)
                        Stack(
                          children: [
                            Container(
                              height: 100,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: _reponseImage != null
                                      ? FileImage(_reponseImage!)
                                      : MemoryImage(_reponseImageBytes!) as ImageProvider,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                onPressed: _removeImage,
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickImage,
                                icon: const Icon(Icons.photo_library),
                                label: const Text('Ajouter une photo'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),

                      // Boutons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submitReponse,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepOrange.shade700,
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
                                      '📤 Envoyer la réponse',
                                      style: TextStyle(fontSize: 16),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('Annuler'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }
}