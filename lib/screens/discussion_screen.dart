// lib/screens/discussion_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:universal_html/html.dart' as html;
import '../services/discussion_service.dart';
import '../models/discussion.dart';
import '../services/discussion_cleanup_service.dart';

// ✅ WIDGET D'APERÇU DES IMAGES
class ImagePreviewWidget extends StatelessWidget {
  final List<dynamic> images;
  final Function(int) onRemove;

  const ImagePreviewWidget({
    super.key,
    required this.images,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
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
                          images[index] as Uint8List,
                          fit: BoxFit.cover,
                          width: 100,
                          height: 100,
                        )
                      : Image.file(
                          images[index] as File,
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
                  onTap: () => onRemove(index),
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
}

// ✅ WIDGET POUR AFFICHER UN LIEN CLIQUABLE
class ImageLinkWidget extends StatelessWidget {
  final String url;
  final bool isWeb;

  const ImageLinkWidget({
    super.key,
    required this.url,
    required this.isWeb,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openUrl(context, url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link, size: 12, color: Colors.blue.shade700),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                url,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.blue.shade700,
                  decoration: TextDecoration.underline,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.open_in_new,
              size: 10,
              color: Colors.blue.shade700,
            ),
          ],
        ),
      ),
    );
  }

  void _openUrl(BuildContext context, String url) {
    if (isWeb) {
      html.window.open(url, '_blank');
    } else {
      try {
        Clipboard.setData(ClipboardData(text: url));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📋 Lien copié dans le presse-papier !'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
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
}

class DiscussionScreen extends StatefulWidget {
  final String role;
  final String? appartement;

  const DiscussionScreen({
    super.key,
    required this.role,
    this.appartement,
  });

  @override
  State<DiscussionScreen> createState() => _DiscussionScreenState();
}

class _DiscussionScreenState extends State<DiscussionScreen> with SingleTickerProviderStateMixin {
  final DiscussionService _discussionService = DiscussionService();
  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  String _filtrePeriode = 'Toutes';
  bool _isLoading = true;
  
  List<Discussion> _discussions = [];
  List<Discussion> _filteredDiscussions = [];
  
  StreamSubscription<QuerySnapshot>? _discussionsSubscription;
  
  Map<String, bool> _expandedVolets = {};
  Set<String> _readDiscussionIds = {};
  List<dynamic> _selectedImages = [];
  bool _isUploading = false;
  bool _isAdmin = false;
  bool _isCleaning = false;

  final List<Map<String, dynamic>> _volets = [
    {'nom': 'PROPRETÉ', 'icon': Icons.forum, 'color': Colors.grey},
    {'nom': 'FUITE D\'EAU', 'icon': Icons.water_drop, 'color': Colors.blue},
    {'nom': 'FUITE AUX ÉGOUTS', 'icon': Icons.lightbulb, 'color': Colors.amber},
    {'nom': 'COUPURE D\'EAU', 'icon': Icons.wifi, 'color': Colors.purple},
    {'nom': 'DÉBIT FAIBLE D\'EAU', 'icon': Icons.cleaning_services, 'color': Colors.green},
    {'nom': 'COUPURE ÉLECTRICITÉ', 'icon': Icons.grass, 'color': Colors.lightGreen},
    {'nom': 'ÉCLAIRAGE', 'icon': Icons.elevator, 'color': Colors.orange},
    {'nom': 'INTERNET', 'icon': Icons.volume_up, 'color': Colors.red},
    {'nom': 'ASCENSEURS', 'icon': Icons.water_damage, 'color': Colors.cyan},
    {'nom': 'JARDINAGE', 'icon': Icons.build, 'color': Colors.indigo},
    {'nom': 'BRUIT', 'icon': Icons.forum, 'color': Colors.grey},
    {'nom': 'SÉCURITÉ', 'icon': Icons.water_drop, 'color': Colors.blue},
    {'nom': 'STATIONNEMENT', 'icon': Icons.lightbulb, 'color': Colors.amber},
    {'nom': 'RONGEURS ET INSECTES', 'icon': Icons.wifi, 'color': Colors.purple},
    {'nom': 'AUTRE', 'icon': Icons.cleaning_services, 'color': Colors.green},
  ];
  
  final List<String> _periodes = ['Toutes', 'Aujourd\'hui', 'Cette semaine', 'Ce mois'];

  @override
  void initState() {
    super.initState();
    _isAdmin = widget.role == 'admin';
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _listenToDiscussions();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _discussionsSubscription?.cancel();
    super.dispose();
  }

  void _listenToDiscussions() {
    setState(() => _isLoading = true);

    _discussionsSubscription?.cancel();

    _discussionsSubscription = FirebaseFirestore.instance
        .collection('discussions')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
          final List<Discussion> newDiscussions = snapshot.docs
              .map((doc) => Discussion.fromFirestore(doc.data(), doc.id))
              .toList();

          setState(() {
            _discussions = newDiscussions;
            _applyFilters();
            _isLoading = false;
            _updateExpandedState();
          });

          print('✅ Discussions mises à jour: ${newDiscussions.length}');
        }, onError: (error) {
          print('❌ Erreur stream: $error');
          setState(() => _isLoading = false);
        });
  }

  void _updateExpandedState() {
    final grouped = _groupByVolet(_filteredDiscussions);
    
    for (var volet in _volets) {
      final nom = volet['nom'] as String;
      final discussions = grouped[nom] ?? [];
      final hasUnread = discussions.any((d) => _isRecent(d.createdAt) && !_isRead(d.id));
      _expandedVolets[nom] = hasUnread;
    }
  }

  bool _isRead(String? discussionId) {
    if (discussionId == null) return true;
    return _readDiscussionIds.contains(discussionId);
  }

  void _markAsRead(String discussionId) {
    if (!_readDiscussionIds.contains(discussionId)) {
      setState(() {
        _readDiscussionIds.add(discussionId);
        _updateExpandedState();
      });
    }
  }

  void _markVoletAsRead(String voletNom) {
    final grouped = _groupByVolet(_filteredDiscussions);
    final discussions = grouped[voletNom] ?? [];
    
    for (var discussion in discussions) {
      if (discussion.id != null) {
        _markAsRead(discussion.id!);
      }
    }
  }

  void _applyFilters() {
    final now = DateTime.now();
    
    if (_filtrePeriode == 'Toutes') {
      _filteredDiscussions = List.from(_discussions);
    } else {
      _filteredDiscussions = _discussions.where((discussion) {
        final diff = now.difference(discussion.createdAt);
        
        switch (_filtrePeriode) {
          case 'Aujourd\'hui':
            return diff.inDays == 0;
          case 'Cette semaine':
            return diff.inDays <= 7;
          case 'Ce mois':
            return diff.inDays <= 30;
          default:
            return true;
        }
      }).toList();
    }
    
    _filteredDiscussions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void _filtrerDiscussions(String periode) {
    setState(() {
      _filtrePeriode = periode;
      _applyFilters();
      _updateExpandedState();
    });
  }

  bool _isRecent(DateTime date) {
    return date.isAfter(DateTime.now().subtract(const Duration(hours: 24)));
  }

  Color _getVoletColor(String voletNom) {
    for (var volet in _volets) {
      if (volet['nom'] == voletNom) {
        return volet['color'] as Color;
      }
    }
    return Colors.grey;
  }

  IconData _getVoletIcon(String voletNom) {
    for (var volet in _volets) {
      if (volet['nom'] == voletNom) {
        return volet['icon'] as IconData;
      }
    }
    return Icons.forum;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      return 'Aujourd\'hui ${DateFormat('HH:mm').format(date)}';
    } else if (diff.inDays == 1) {
      return 'Hier ${DateFormat('HH:mm').format(date)}';
    } else if (diff.inDays < 7) {
      return 'Il y a ${diff.inDays} jours';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    }
  }

  Map<String, List<Discussion>> _groupByVolet(List<Discussion> discussions) {
    Map<String, List<Discussion>> grouped = {};
    
    for (var volet in _volets) {
      grouped[volet['nom'] as String] = [];
    }
    
    for (var discussion in discussions) {
      final volet = discussion.volet;
      if (grouped.containsKey(volet)) {
        grouped[volet]!.add(discussion);
      } else {
        if (!grouped.containsKey(volet)) {
          grouped[volet] = [];
        }
        grouped[volet]!.add(discussion);
      }
    }
    
    for (var key in grouped.keys) {
      grouped[key]!.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    
    return grouped;
  }

  void _toggleVolet(String voletNom) {
    setState(() {
      _expandedVolets[voletNom] = !(_expandedVolets[voletNom] ?? false);
    });
  }

  // ✅ PRENDRE UNE PHOTO POUR LA CRÉATION
  Future<dynamic> _takePhotoForCreation() async {
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
          return bytes;
        } else {
          final file = File(photo.path);
          return file;
        }
      }
      return null;
    } catch (e) {
      print('❌ Erreur prise de photo: $e');
      return null;
    }
  }

  // ✅ CHOISIR UNE PHOTO POUR LA CRÉATION
  Future<dynamic> _pickImageForCreation() async {
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
          return bytes;
        } else {
          final file = File(image.path);
          return file;
        }
      }
      return null;
    } catch (e) {
      print('❌ Erreur sélection: $e');
      return null;
    }
  }

  // ✅ CHOISIR PLUSIEURS PHOTOS POUR LA CRÉATION
  Future<List<dynamic>> _pickMultipleImagesForCreation() async {
    try {
      final List<XFile>? images = await _imagePicker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (images != null && images.isNotEmpty) {
        List<dynamic> result = [];
        for (var image in images) {
          if (kIsWeb) {
            final bytes = await image.readAsBytes();
            result.add(bytes);
          } else {
            final file = File(image.path);
            result.add(file);
          }
        }
        return result;
      }
      return [];
    } catch (e) {
      print('❌ Erreur sélection multiple: $e');
      return [];
    }
  }

  // ✅ UPLOAD DES IMAGES
  Future<List<String>> _uploadImages() async {
    List<String> urls = [];
    
    if (_selectedImages.isEmpty) {
      print('⚠️ Aucune image à uploader');
      return urls;
    }

    print('📤 Upload de ${_selectedImages.length} image(s)...');

    for (int i = 0; i < _selectedImages.length; i++) {
      try {
        final image = _selectedImages[i];
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'discussions/discussion_${timestamp}_$i.jpg';
        final ref = _storage.ref().child(fileName);
        
        print('📤 Upload vers: $fileName');
        
        if (kIsWeb && image is Uint8List) {
          final metadata = SettableMetadata(contentType: 'image/jpeg');
          await ref.putData(image, metadata);
        } else if (!kIsWeb && image is File) {
          final metadata = SettableMetadata(contentType: 'image/jpeg');
          await ref.putFile(image, metadata);
        } else {
          print('❌ Format non supporté');
          continue;
        }
        
        final url = await ref.getDownloadURL();
        urls.add(url);
        print('✅ Image $i uploadée: $url');
        
      } catch (e) {
        print('❌ Erreur upload image $i: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Erreur upload: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    
    print('📸 Total uploadé: ${urls.length} image(s)');
    return urls;
  }

  // ✅ AFFICHER UNE IMAGE EN PLEIN ÉCRAN
  void _showImageFullScreen(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 400,
                        width: 300,
                        color: Colors.grey.shade100,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey.shade100,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, size: 50, color: Colors.red),
                              SizedBox(height: 8),
                              Text(
                                'Erreur de chargement',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.5),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ AFFICHER LE DIALOGUE DE CRÉATION DE DISCUSSION - Version BottomSheet
  void _showCreateDiscussionDialog() {
    final TextEditingController messageController = TextEditingController();
    // ✅ CORRECTION ICI : 'Général' n'existe pas, on met 'PROPRETÉ'
    String selectedVolet = 'PROPRETÉ';
    _selectedImages.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '📝 Nouvelle Discussion',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedVolet,
                  decoration: const InputDecoration(
                    labelText: 'Volet *',
                    border: OutlineInputBorder(),
                  ),
                  items: _volets.map<DropdownMenuItem<String>>((volet) {
                    return DropdownMenuItem<String>(
                      value: volet['nom'] as String,
                      child: Row(
                        children: [
                          Icon(volet['icon'] as IconData, color: volet['color'] as Color, size: 20),
                          const SizedBox(width: 8),
                          Text(volet['nom'] as String),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) selectedVolet = value;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message *',
                    prefixIcon: Icon(Icons.message),
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                // ✅ SECTION PHOTOS
                Container(
                  padding: const EdgeInsets.all(8),
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
                            style: TextStyle(fontWeight: FontWeight.bold),
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
                        ImagePreviewWidget(
                          images: _selectedImages,
                          onRemove: (index) {
                            setDialogState(() {
                              _selectedImages.removeAt(index);
                            });
                          },
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await _showImagePickerDialog(context, setDialogState);
                              },
                              icon: const Icon(Icons.add_photo_alternate, size: 18),
                              label: const Text('Ajouter des photos'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade50,
                                foregroundColor: Colors.blue.shade700,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _selectedImages.clear();
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Annuler'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isUploading
                            ? null
                            : () async {
                                if (messageController.text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Veuillez entrer un message'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                  return;
                                }

                                setState(() => _isUploading = true);

                                try {
                                  String titre = messageController.text;
                                  if (titre.length > 50) {
                                    titre = titre.substring(0, 50) + '...';
                                  }

                                  final String createur = widget.appartement ?? 'Client';
                                  final String createurAppartement = widget.appartement ?? 'N/A';

                                  List<String> imageUrls = [];
                                  if (_selectedImages.isNotEmpty) {
                                    print('📤 Upload des images...');
                                    imageUrls = await _uploadImages();
                                    print('✅ ${imageUrls.length} images uploadées');
                                  }

                                  final newDiscussion = Discussion(
                                    id: null,
                                    volet: selectedVolet,
                                    titre: titre,
                                    message: messageController.text,
                                    createdBy: createur,
                                    createdByAppartement: createurAppartement,
                                    createdAt: DateTime.now(),
                                    lastMessageAt: DateTime.now(),
                                    messageCount: 1,
                                    participants: [createur],
                                    lastMessage: messageController.text,
                                    imageUrls: imageUrls,
                                    hasImages: imageUrls.isNotEmpty,
                                  );

                                  await _discussionService.createDiscussion(newDiscussion);
                                  
                                  setState(() {
                                    _selectedImages.clear();
                                    _isUploading = false;
                                  });
                                  
                                  Navigator.pop(context);
                                  
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('✅ Discussion créée avec succès'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  
                                } catch (e) {
                                  setState(() => _isUploading = false);
                                  print('❌ Erreur: $e');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('❌ Erreur: ${e.toString()}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                        ),
                        child: _isUploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Créer'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  // ✅ DIALOGUE DE SÉLECTION D'IMAGES
  Future<void> _showImagePickerDialog(
    BuildContext context,
    StateSetter setDialogState,
  ) async {
    await showModalBottomSheet(
      context: context,
      isDismissible: true,
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
                subtitle: const Text('Utiliser l\'appareil photo'),
                onTap: () async {
                  Navigator.pop(context);
                  final photo = await _takePhotoForCreation();
                  if (photo != null && mounted) {
                    setDialogState(() {
                      _selectedImages.add(photo);
                    });
                  }
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: const Icon(Icons.photo_library, color: Colors.green),
                ),
                title: const Text('🖼️ Choisir une photo'),
                subtitle: const Text('Depuis la galerie'),
                onTap: () async {
                  Navigator.pop(context);
                  final image = await _pickImageForCreation();
                  if (image != null && mounted) {
                    setDialogState(() {
                      _selectedImages.add(image);
                    });
                  }
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple.shade100,
                  child: const Icon(Icons.collections, color: Colors.purple),
                ),
                title: const Text('📁 Choisir plusieurs photos'),
                subtitle: const Text('Sélectionner plusieurs images'),
                onTap: () async {
                  Navigator.pop(context);
                  final images = await _pickMultipleImagesForCreation();
                  if (images.isNotEmpty && mounted) {
                    setDialogState(() {
                      _selectedImages.addAll(images);
                    });
                  }
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
                    setDialogState(() {
                      _selectedImages.clear();
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

  // ✅ AFFICHER LES DÉTAILS D'UNE DISCUSSION AVEC LIENS CLIQUABLES
  void _showDiscussionDetails(Discussion discussion) {
    if (discussion.id != null) {
      _markAsRead(discussion.id!);
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          final List<String> imageUrls = discussion.imageUrls ?? [];
          
          return Container(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getVoletColor(discussion.volet).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getVoletIcon(discussion.volet),
                          color: _getVoletColor(discussion.volet),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              discussion.titre.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              discussion.volet,
                              style: TextStyle(
                                fontSize: 12,
                                color: _getVoletColor(discussion.volet),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isRecent(discussion.createdAt) && !_isRead(discussion.id))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'NOUVEAU',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  const Divider(height: 30),
                  
                  _buildDetailRow(Icons.person, 'Créé par', discussion.createdByAppartement ?? discussion.createdBy),
                  _buildDetailRow(Icons.calendar_today, 'Date de création', _formatDate(discussion.createdAt)),
                  _buildDetailRow(Icons.message, 'Nombre de messages', '${discussion.messageCount} message${discussion.messageCount > 1 ? 's' : ''}'),
                  
                  if (discussion.participants.isNotEmpty)
                    _buildDetailRow(Icons.people, 'Participants', discussion.participants.join(', ')),
                  
                  const SizedBox(height: 16),
                  
                  // ✅ IMAGES AVEC LIENS CLIQUABLES
                  if (imageUrls.isNotEmpty) ...[
                    const Text(
                      '📸 Photos :',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    ...imageUrls.map((url) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: ImageLinkWidget(
                          url: url,
                          isWeb: kIsWeb,
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: imageUrls.map((url) {
                        return GestureDetector(
                          onTap: () => _showImageFullScreen(url),
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                url,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
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
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💬 Message',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          discussion.message,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  if (discussion.lastMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📌 Dernier message',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            discussion.lastMessage,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Fermer'),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ CARTE DE DISCUSSION AVEC LIEN CLIQUABLE
  Widget _buildDiscussionCard(Discussion discussion, bool isUnread, Color voletColor) {
    final bool hasImages = discussion.imageUrls != null && discussion.imageUrls!.isNotEmpty;
    final String? firstImageUrl = hasImages ? discussion.imageUrls!.first : null;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUnread ? Colors.red.shade300 : Colors.grey.shade200,
          width: isUnread ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: isUnread ? 4 : 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDiscussionDetails(discussion),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (isUnread)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(width: 8),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              discussion.titre.toUpperCase(),
                              style: TextStyle(
                                fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
                                fontSize: 14,
                                color: isUnread ? Colors.red.shade700 : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasImages)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.photo,
                                size: 14,
                                color: Colors.blue.shade400,
                              ),
                            ),
                          if (isUnread)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(left: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.shade700,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'NOUVEAU',
                                style: TextStyle(
                                  fontSize: 7,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: isUnread ? Colors.red.shade400 : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(discussion.createdAt),
                            style: TextStyle(
                              fontSize: 10,
                              color: isUnread ? Colors.red.shade400 : Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.message,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${discussion.messageCount} msg',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          if (discussion.lastMessage.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  discussion.lastMessage,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.blue.shade700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (firstImageUrl != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: ImageLinkWidget(
                            url: firstImageUrl,
                            isWeb: kIsWeb,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(minWidth: 14),
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ MÉTHODES DE NETTOYAGE
  void _showCleanupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🧹 Nettoyer les discussions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choisissez une option de nettoyage :',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildCleanupOption(
              icon: Icons.delete_forever,
              title: 'Tout supprimer',
              subtitle: 'Supprime toutes les discussions et messages',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteAll();
              },
            ),
            const Divider(),
            _buildCleanupOption(
              icon: Icons.filter_alt,
              title: 'Par volet',
              subtitle: 'Supprime les discussions d\'un volet spécifique',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _showVoletSelectionDialog();
              },
            ),
            const Divider(),
            _buildCleanupOption(
              icon: Icons.history,
              title: 'Anciennes discussions',
              subtitle: 'Supprime les discussions de plus de 30 jours',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteOld();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanupOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _showVoletSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📂 Sélectionner un volet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _volets.map((volet) {
            return ListTile(
              leading: Icon(volet['icon'] as IconData, color: volet['color'] as Color),
              title: Text(volet['nom'] as String),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteByVolet(volet['nom'] as String);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Attention !'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vous allez supprimer TOUTES les discussions et leurs messages.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Cette opération est irréversible !'),
            SizedBox(height: 8),
            Text('Voulez-vous vraiment continuer ?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _executeCleanup('all');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tout supprimer'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteByVolet(String volet) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Attention !'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vous allez supprimer toutes les discussions du volet "$volet".',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Cette opération est irréversible !'),
            const SizedBox(height: 8),
            const Text('Voulez-vous vraiment continuer ?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _executeCleanup('volet', volet: volet);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteOld() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Attention !'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vous allez supprimer toutes les discussions de plus de 30 jours.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Cette opération est irréversible !'),
            const SizedBox(height: 8),
            const Text('Voulez-vous vraiment continuer ?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _executeCleanup('old');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeCleanup(String type, {String? volet}) async {
    setState(() => _isLoading = true);
    
    try {
      final service = DiscussionCleanupService();
      Map<String, int> result;
      
      switch (type) {
        case 'all':
          result = await service.clearAllDiscussions();
          break;
        case 'volet':
          result = await service.clearDiscussionsByVolet(volet!);
          break;
        case 'old':
          result = await service.clearDiscussionsOlderThan(30);
          break;
        default:
          return;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${result['discussions']} discussions et ${result['messages']} messages supprimés'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      
      // Recharger la liste
      _listenToDiscussions();
      
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
    final bool isClient = widget.role != 'admin';
    
    final groupedDiscussions = _groupByVolet(_filteredDiscussions);
    
    List<Map<String, dynamic>> voletsAvecNouveau = [];
    List<Map<String, dynamic>> voletsSansNouveau = [];
    
    for (var volet in _volets) {
      final nom = volet['nom'] as String;
      final discussions = groupedDiscussions[nom] ?? [];
      
      if (discussions.isNotEmpty) {
        final hasUnread = discussions.any((d) => _isRecent(d.createdAt) && !_isRead(d.id));
        if (hasUnread) {
          voletsAvecNouveau.add(volet);
        } else {
          voletsSansNouveau.add(volet);
        }
      } else {
        voletsSansNouveau.add(volet);
      }
    }
    
    voletsAvecNouveau.sort((a, b) {
      final discussionsA = groupedDiscussions[a['nom'] as String] ?? [];
      final discussionsB = groupedDiscussions[b['nom'] as String] ?? [];
      
      final dateA = discussionsA.isNotEmpty ? discussionsA.first.createdAt : DateTime(2000);
      final dateB = discussionsB.isNotEmpty ? discussionsB.first.createdAt : DateTime(2000);
      return dateB.compareTo(dateA);
    });
    
    List<Map<String, dynamic>> voletsOrdonnes = [];
    voletsOrdonnes.addAll(voletsAvecNouveau);
    
    if (voletsSansNouveau.isNotEmpty && voletsAvecNouveau.isNotEmpty) {
      voletsOrdonnes.add({
        'nom': '___SEPARATEUR___',
        'icon': Icons.remove,
        'color': Colors.grey,
        'isSeparator': true,
      });
    }
    voletsOrdonnes.addAll(voletsSansNouveau);
    
    int totalDiscussions = _filteredDiscussions.length;
    int totalMessages = _filteredDiscussions.fold(0, (sum, d) => sum + d.messageCount);
    int totalVoletsActifs = voletsAvecNouveau.length + voletsSansNouveau.where((v) => groupedDiscussions[v['nom'] as String]?.isNotEmpty ?? false).length;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('💬 Discussions par Volet'),
        backgroundColor: isClient ? Colors.green.shade700 : Colors.blue.shade800,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _listenToDiscussions();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🔄 Rechargement...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            tooltip: 'Rafraîchir',
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _showCreateDiscussionDialog,
            tooltip: 'Nouvelle Discussion',
          ),
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              onPressed: _showCleanupDialog,
              tooltip: 'Nettoyer les discussions',
            ),
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
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Live',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (isClient)
            IconButton(
              icon: const Icon(Icons.done_all, color: Colors.blue),
              onPressed: () {
                for (var discussion in _filteredDiscussions) {
                  if (discussion.id != null) {
                    _markAsRead(discussion.id!);
                  }
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Toutes les discussions marquées comme lues'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              tooltip: 'Tout marquer comme lu',
            ),
        ],
      ),
      body: Column(
        children: [
          // Période
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                const Text(
                  '📅 Période:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _filtrePeriode,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                    items: _periodes.map<DropdownMenuItem<String>>((periode) {
                      return DropdownMenuItem<String>(
                        value: periode,
                        child: Text(periode),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _filtrerDiscussions(value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // Statistiques
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: Colors.blue.shade50,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildStatChip('📋 Discussions', totalDiscussions.toString(), Colors.blue),
                _buildStatChip('💬 Messages', totalMessages.toString(), Colors.green),
                _buildStatChip('📌 Volets Actifs', totalVoletsActifs.toString(), Colors.orange),
                if (isClient)
                  _buildStatChip(
                    '🆕 Nouveaux', 
                    _filteredDiscussions.where((d) => _isRecent(d.createdAt) && !_isRead(d.id)).length.toString(), 
                    Colors.red,
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Liste des discussions
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Chargement des discussions...'),
                      ],
                    ),
                  )
                : _filteredDiscussions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.forum_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'Aucune discussion',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Aucune discussion trouvée pour cette période',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: voletsOrdonnes.length,
                        itemBuilder: (context, index) {
                          final volet = voletsOrdonnes[index];
                          
                          if (volet['isSeparator'] == true) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      '📭 Volets lus',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          
                          final voletNom = volet['nom'] as String;
                          final discussions = groupedDiscussions[voletNom] ?? [];
                          
                          if (discussions.isEmpty) {
                            final Color voletColor = volet['color'] as Color;
                            final IconData voletIcon = volet['icon'] as IconData;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(voletIcon, color: voletColor.withOpacity(0.5), size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    voletNom,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '0 discussion',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          
                          final Color voletColor = volet['color'] as Color;
                          final IconData voletIcon = volet['icon'] as IconData;
                          
                          int totalMessagesVolet = discussions.fold(0, (sum, d) => sum + d.messageCount);
                          bool hasUnread = discussions.any((d) => _isRecent(d.createdAt) && !_isRead(d.id));
                          bool isExpanded = _expandedVolets[voletNom] ?? false;
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // En-tête du volet
                              Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: hasUnread
                                      ? LinearGradient(
                                          colors: [voletColor.withOpacity(0.3), Colors.transparent],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        )
                                      : null,
                                  color: hasUnread ? null : voletColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: hasUnread ? voletColor : voletColor.withOpacity(0.3),
                                    width: hasUnread ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(voletIcon, color: voletColor, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          if (hasUnread) {
                                            _markVoletAsRead(voletNom);
                                          } else {
                                            _toggleVolet(voletNom);
                                          }
                                        },
                                        child: Row(
                                          children: [
                                            Text(
                                              voletNom,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: voletColor,
                                              ),
                                            ),
                                            if (hasUnread)
                                              AnimatedBuilder(
                                                animation: _animation,
                                                builder: (context, child) {
                                                  return Opacity(
                                                    opacity: _animation.value,
                                                    child: Container(
                                                      margin: const EdgeInsets.only(left: 8),
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: [Colors.red.shade700, Colors.red.shade400],
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                        ),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: const Text(
                                                        'NOUVEAU',
                                                        style: TextStyle(
                                                          fontSize: 8,
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            const Spacer(),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: voletColor,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                '${discussions.length} d • $totalMessagesVolet m',
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            AnimatedRotation(
                                              duration: const Duration(milliseconds: 200),
                                              turns: isExpanded ? 0.5 : 0.0,
                                              child: Icon(
                                                Icons.expand_more,
                                                color: Colors.grey.shade600,
                                                size: 24,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isExpanded) ...[
                                const SizedBox(height: 4),
                                ...discussions.map((discussion) {
                                  final isRecent = _isRecent(discussion.createdAt);
                                  final isRead = _isRead(discussion.id);
                                  
                                  return _buildDiscussionCard(discussion, isRecent && !isRead, voletColor);
                                }).toList(),
                                const SizedBox(height: 8),
                              ],
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}