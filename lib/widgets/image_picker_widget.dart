// lib/widgets/image_picker_widget.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

class ImagePickerWidget {
  final ImagePicker _imagePicker = ImagePicker();

  // ✅ PRENDRE UNE PHOTO
  Future<dynamic> takePhoto() async {
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
          return bytes; // Uint8List pour Web
        } else {
          return File(photo.path); // File pour Mobile
        }
      }
      return null;
    } catch (e) {
      print('❌ Erreur prise de photo: $e');
      return null;
    }
  }

  // ✅ CHOISIR UNE PHOTO DEPUIS LA GALERIE
  Future<dynamic> pickImage() async {
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
          return bytes; // Uint8List pour Web
        } else {
          return File(image.path); // File pour Mobile
        }
      }
      return null;
    } catch (e) {
      print('❌ Erreur sélection image: $e');
      return null;
    }
  }

  // ✅ CHOISIR PLUSIEURS PHOTOS
  Future<List<dynamic>> pickMultipleImages() async {
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
            result.add(File(image.path));
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
}

// ✅ WIDGET POUR AFFICHER L'APERÇU DES IMAGES
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

    return Container(
      height: 100,
      margin: const EdgeInsets.only(bottom: 8),
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

// ✅ DIALOGUE DE SÉLECTION D'IMAGES
class ImagePickerDialog extends StatelessWidget {
  final Function(dynamic) onImageSelected;
  final Function(List<dynamic>) onMultipleImagesSelected;

  const ImagePickerDialog({
    super.key,
    required this.onImageSelected,
    required this.onMultipleImagesSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ModalBottomSheet(
      context: context,
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
                onTap: () async {
                  Navigator.pop(context);
                  final image = await ImagePickerWidget().takePhoto();
                  if (image != null) onImageSelected(image);
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
                  final image = await ImagePickerWidget().pickImage();
                  if (image != null) onImageSelected(image);
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
                  final images = await ImagePickerWidget().pickMultipleImages();
                  if (images.isNotEmpty) onMultipleImagesSelected(images);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}