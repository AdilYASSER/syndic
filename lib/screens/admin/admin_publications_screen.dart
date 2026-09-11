// lib/screens/admin/admin_publications_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/publication_service.dart';
import '../../models/publication_model.dart';

class AdminPublicationsScreen extends StatefulWidget {
  const AdminPublicationsScreen({super.key});

  @override
  State<AdminPublicationsScreen> createState() =>
      _AdminPublicationsScreenState();
}

class _AdminPublicationsScreenState extends State<AdminPublicationsScreen> {
  final PublicationService _service = PublicationService();
  final TextEditingController _titreController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String? _editingId;
  XFile? _selectedImage; // ✅ Type explicite au lieu de dynamic
  bool _isSaving = false;

  @override
  void dispose() {
    _titreController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // ============================================================
  // ✅ OUVRIR LE FORMULAIRE (création)
  // ============================================================
  void _openAddForm() {
    _titreController.clear();
    _messageController.clear();
    _selectedImage = null;
    _editingId = null;
    _selectedDate = DateTime.now();
    _showFormDialog();
  }

  // ============================================================
  // ✅ OUVRIR LE FORMULAIRE (édition)
  // ============================================================
  void _openEditForm(PublicationModel pub) {
    _titreController.text = pub.titre;
    _messageController.text = pub.message;
    _selectedDate = pub.datePublication;
    _editingId = pub.id;
    _selectedImage = null;
    _showFormDialog();
  }

  // ============================================================
  // ✅ SÉLECTIONNER UNE IMAGE
  // ============================================================
  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() => _selectedImage = image);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur image: $e')),
      );
    }
  }

  // ============================================================
  // ✅ FORMULAIRE (Dialog)
  // ============================================================
  void _showFormDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_editingId == null
              ? '➕ Nouvelle Publication'
              : '✏️ Modifier'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titreController,
                  decoration: const InputDecoration(labelText: 'Titre *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(labelText: 'Message *'),
                  maxLines: 3,
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Date de publication'),
                  subtitle:
                      Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => _selectedDate = picked);
                      setState(() => _selectedDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo),
                      label: const Text('Ajouter une photo'),
                    ),
                    if (_selectedImage != null) ...[
                      const SizedBox(width: 8),
                      const Text('✅ Photo sélectionnée'),
                    ],
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: _isSaving
                  ? null
                  : () async {
                      if (_titreController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('⚠️ Le titre est obligatoire'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      setState(() => _isSaving = true);
                      try {
                        if (_editingId == null) {
                          // ✅ CRÉATION
                          final pub = PublicationModel(
                            id: '',
                            titre: _titreController.text.trim(),
                            message: _messageController.text.trim(),
                            imageUrl: null,
                            datePublication: _selectedDate,
                            createdAt: DateTime.now(),
                            createdBy: 'admin',
                          );
                          await _service.createPublication(
                              pub, _selectedImage);
                        } else {
                          // ✅ MODIFICATION
                          await _service.updatePublication(
                            _editingId!,
                            {
                              'titre': _titreController.text.trim(),
                              'message': _messageController.text.trim(),
                              'datePublication': _selectedDate,
                            },
                            newImage: _selectedImage,
                          );
                        }
                        if (mounted) Navigator.pop(dialogContext);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_editingId == null
                                  ? '✅ Publication créée'
                                  : '✅ Publication modifiée'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ Erreur: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isSaving = false);
                      }
                    },
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_editingId == null ? 'Publier' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ✅ SUPPRIMER
  // ============================================================
  Future<void> _supprimerPublication(PublicationModel pub) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Supprimer cette publication ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.deletePublication(pub.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Publication supprimée'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================================
  // ✅ BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📢 Gestion des Publications'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openAddForm,
            tooltip: 'Nouvelle publication',
          ),
        ],
      ),
      body: StreamBuilder<List<PublicationModel>>(
        stream: _service.getPublications(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final pubs = snapshot.data!;
          if (pubs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.campaign, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucune publication',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _openAddForm,
                    icon: const Icon(Icons.add),
                    label: const Text('Créer une publication'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: pubs.length,
            itemBuilder: (context, index) {
              final pub = pubs[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (pub.imageUrl != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                        child: Image.network(
                          pub.imageUrl!,
                          fit: BoxFit.cover,
                          height: 200,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 200,
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.broken_image,
                                  size: 50, color: Colors.grey),
                            );
                          },
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  pub.titre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              Text(
                                DateFormat('dd/MM/yyyy')
                                    .format(pub.datePublication),
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            pub.message,
                            style: const TextStyle(fontSize: 15, height: 1.4),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _openEditForm(pub),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _supprimerPublication(pub),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}