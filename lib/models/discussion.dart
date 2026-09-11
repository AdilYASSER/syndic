// lib/models/discussion.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Discussion {
  final String? id;
  final String volet;
  final String titre;
  final String message;
  final String createdBy;
  final String createdByAppartement;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final int messageCount;
  final List<String> participants;
  final String lastMessage;
  final List<String> imageUrls;
  final bool hasImages;

  Discussion({
    this.id,
    required this.volet,
    required this.titre,
    required this.message,
    required this.createdBy,
    required this.createdByAppartement,
    required this.createdAt,
    required this.lastMessageAt,
    required this.messageCount,
    required this.participants,
    required this.lastMessage,
    this.imageUrls = const [],
    this.hasImages = false,
  });

  Map<String, dynamic> toFirestoreMap() {
    return {
      'volet': volet,
      'titre': titre,
      'message': message,
      'createdBy': createdBy,
      'createdByAppartement': createdByAppartement,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'messageCount': messageCount,
      'participants': participants,
      'lastMessage': lastMessage,
      'imageUrls': imageUrls,
      'hasImages': hasImages,
    };
  }

  factory Discussion.fromFirestore(Map<String, dynamic> map, String id) {
    return Discussion(
      id: id,
      volet: map['volet'] ?? 'Général',
      titre: map['titre'] ?? 'Discussion',
      message: map['message'] ?? '',
      createdBy: map['createdBy'] ?? 'Inconnu',
      createdByAppartement: map['createdByAppartement'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessageAt: (map['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      messageCount: map['messageCount'] ?? 0,
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      hasImages: map['hasImages'] ?? false,
    );
  }
}