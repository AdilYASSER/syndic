// lib/models/annonce_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AnnonceModel {
  final String id;
  final String nomArticle;
  final String qualite; // 'neuf', 'moyen', 'bon_etat', 'usage'
  final bool isDon;
  final bool isVente;
  final bool isLocation;
  final double? prix;
  final String description;
  final List<String> imageUrls;
  final String appartement;
  final String nomPrenom;
  final String telephone;
  final DateTime dateCreation;
  final String createdBy;
  final bool isVisible;

  AnnonceModel({
    required this.id,
    required this.nomArticle,
    required this.qualite,
    this.isDon = false,
    this.isVente = false,
    this.isLocation = false,
    this.prix,
    this.description = '',
    this.imageUrls = const [],
    required this.appartement,
    required this.nomPrenom,
    required this.telephone,
    required this.dateCreation,
    required this.createdBy,
    this.isVisible = true,
  });

  // ✅ Type d'annonce
  String get typeAnnonce {
    List<String> types = [];
    if (isDon) types.add('🎁 Don');
    if (isVente) types.add('💰 Vente');
    if (isLocation) types.add('🏠 Location');
    return types.join(' • ');
  }

  // ✅ Qualité en texte
  String get qualiteTexte {
    switch (qualite) {
      case 'neuf': return '✨ Neuf';
      case 'bon_etat': return '👍 Bon état';
      case 'moyen': return '👌 Moyen';
      case 'usage': return '🔧 Usagé';
      default: return qualite;
    }
  }

  Map<String, dynamic> toJson() => {
    'nomArticle': nomArticle,
    'qualite': qualite,
    'isDon': isDon,
    'isVente': isVente,
    'isLocation': isLocation,
    'prix': prix,
    'description': description,
    'imageUrls': imageUrls,
    'appartement': appartement,
    'nomPrenom': nomPrenom,
    'telephone': telephone,
    'dateCreation': FieldValue.serverTimestamp(),
    'createdBy': createdBy,
    'isVisible': isVisible,
  };

  factory AnnonceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AnnonceModel(
      id: doc.id,
      nomArticle: data['nomArticle'] ?? '',
      qualite: data['qualite'] ?? 'moyen',
      isDon: data['isDon'] ?? false,
      isVente: data['isVente'] ?? false,
      isLocation: data['isLocation'] ?? false,
      prix: (data['prix'] as num?)?.toDouble(),
      description: data['description'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      appartement: data['appartement'] ?? '',
      nomPrenom: data['nomPrenom'] ?? '',
      telephone: data['telephone'] ?? '',
      dateCreation: (data['dateCreation'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      isVisible: data['isVisible'] ?? true,
    );
  }
}