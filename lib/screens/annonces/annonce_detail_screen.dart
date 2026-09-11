// lib/screens/annonces/annonce_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/annonce_model.dart';

class AnnonceDetailScreen extends StatefulWidget {
  final AnnonceModel annonce;
  final String currentUserAppartement;
  final bool isAdmin;

  const AnnonceDetailScreen({
    super.key,
    required this.annonce,
    required this.currentUserAppartement,
    this.isAdmin = false,
  });

  @override
  State<AnnonceDetailScreen> createState() => _AnnonceDetailScreenState();
}

class _AnnonceDetailScreenState extends State<AnnonceDetailScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  Future<void> _openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📋 Lien copié dans le presse-papier !'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final annonce = widget.annonce;
    final images = annonce.imageUrls;
    final isOwner = annonce.appartement == widget.currentUserAppartement;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail de l\'annonce'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ============ CARROUSEL D'IMAGES ============
            if (images.isNotEmpty)
              SizedBox(
                height: 250,
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: images.length,
                      onPageChanged: (i) => setState(() => _currentPage = i),
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () => _openUrl(images[index]),
                          child: Image.network(
                            images[index],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stack) {
                              return Container(
                                color: Colors.grey.shade200,
                                child: const Icon(
                                  Icons.broken_image,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                    // Indicateur de page
                    if (images.length > 1)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            images.length,
                            (i) => Container(
                              width: 8,
                              height: 8,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _currentPage
                                    ? Colors.white
                                    : Colors.white54,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else
              Container(
                height: 200,
                color: Colors.grey.shade100,
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    size: 60,
                    color: Colors.grey,
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ============ BADGES TYPE ============
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (annonce.isDon)
                        _buildBadge('🎁 Don', Colors.green),
                      if (annonce.isVente)
                        _buildBadge('💰 Vente', Colors.blue),
                      if (annonce.isLocation)
                        _buildBadge('🏠 Location', Colors.orange),
                      if (isOwner)
                        _buildBadge('Ma publication', Colors.purple),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ============ NOM ============
                  Text(
                    annonce.nomArticle,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ============ QUALITÉ ============
                  Text(
                    annonce.qualiteTexte,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ============ PRIX ============
                  if (annonce.prix != null && annonce.prix! > 0)
                    Text(
                      '${annonce.prix!.toStringAsFixed(0)} DH',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade700,
                      ),
                    )
                  else if (annonce.isDon)
                    Text(
                      'GRATUIT',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  const SizedBox(height: 16),

                  const Divider(),

                  // ============ DESCRIPTION ============
                  if (annonce.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      '📝 Description',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      annonce.description,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const Divider(),

                  // ============ INFOS VENDEUR ============
                  const SizedBox(height: 8),
                  const Text(
                    '👤 Vendeur',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.person, annonce.nomPrenom),
                  const SizedBox(height: 6),
                  _buildInfoRow(Icons.home, 'Appt ${annonce.appartement}'),
                  const SizedBox(height: 6),
                  _buildInfoRow(Icons.phone, annonce.telephone),
                  const SizedBox(height: 6),
                  _buildInfoRow(
                    Icons.calendar_today,
                    DateFormat('dd/MM/yyyy à HH:mm')
                        .format(annonce.dateCreation),
                  ),
                  const SizedBox(height: 16),

                  // ============ LIENS IMAGES ============
                  if (images.isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      '🔗 Liens des images',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...images.map(
                      (url) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _buildImageLink(url),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildImageLink(String url) {
    return GestureDetector(
      onTap: () => _openUrl(url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.link, size: 16, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                url,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue.shade700,
                  decoration: TextDecoration.underline,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.open_in_new, size: 14, color: Colors.blue.shade700),
          ],
        ),
      ),
    );
  }
}