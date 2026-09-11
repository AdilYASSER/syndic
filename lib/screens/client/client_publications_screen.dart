// lib/screens/client/client_publications_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/publication_service.dart';
import '../../models/publication_model.dart';

class ClientPublicationsScreen extends StatefulWidget {
  final String? appartement;
  const ClientPublicationsScreen({super.key, this.appartement});

  @override
  State<ClientPublicationsScreen> createState() =>
      _ClientPublicationsScreenState();
}

class _ClientPublicationsScreenState extends State<ClientPublicationsScreen> {
  final PublicationService _service = PublicationService();

  @override
  void initState() {
    super.initState();
    // ✅ Marquer comme lues dans FIRESTORE
    _markAsRead();
  }

  Future<void> _markAsRead() async {
    final userId = 'client_${widget.appartement ?? 'unknown'}';
    await _service.marquerPublicationsLues(userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📢 Publications'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
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
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.campaign, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Aucune publication pour le moment',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
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
                elevation: 2,
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
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                              Text(
                                DateFormat('dd/MM/yyyy HH:mm')
                                    .format(pub.datePublication),
                                style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            pub.message,
                            style: const TextStyle(fontSize: 15, height: 1.4),
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