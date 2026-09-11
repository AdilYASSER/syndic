// lib/screens/client/client_repertoire_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/repertoire_service.dart';
import '../../models/repertoire_model.dart';
import '../repertoire/repertoire_detail_screen.dart';

class ClientRepertoireScreen extends StatefulWidget {
  final String appartement;

  const ClientRepertoireScreen({
    super.key,
    required this.appartement,
  });

  @override
  State<ClientRepertoireScreen> createState() => _ClientRepertoireScreenState();
}

class _ClientRepertoireScreenState extends State<ClientRepertoireScreen> {
  final RepertoireService _service = RepertoireService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 Répertoire Utile'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade700,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'App: ${widget.appartement}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Categorie>>(
        stream: _service.getCategories(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final categories = snapshot.data!;
          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('Aucune catégorie disponible'),
                  const SizedBox(height: 8),
                  Text(
                    'Proposez une catégorie à l\'administrateur',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _proposerCategorie(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Proposer une catégorie'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final categorie = categories[index];
              return _buildCategorieCard(categorie);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _proposerCategorie(context),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Proposer'),
      ),
    );
  }

  Widget _buildCategorieCard(Categorie categorie) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            Icon(Icons.folder, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                categorie.nom,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        children: [
          if (categorie.sousCategories.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Aucune sous-catégorie',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...categorie.sousCategories.map((sousCategorie) {
              return ListTile(
                leading: const Icon(Icons.folder_open, color: Colors.orange),
                title: Text(sousCategorie.nom),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ✅ BOUTON PROPOSER UNE PERSONNE
                    IconButton(
                      icon: const Icon(Icons.person_add, color: Colors.green),
                      onPressed: () {
                        _proposerPersonneDialog(context, categorie.nom, sousCategorie.nom);
                      },
                      tooltip: 'Proposer une personne',
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 16),
                      onPressed: () {
                        _voirPersonnes(categorie.nom, sousCategorie.nom);
                      },
                    ),
                  ],
                ),
                onTap: () {
                  _voirPersonnes(categorie.nom, sousCategorie.nom);
                },
              );
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _voirPersonnes(String categorie, String sousCategorie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RepertoirePersonnesScreen(
          categorie: categorie,
          sousCategorie: sousCategorie,
          isAdmin: false,
          appartement: widget.appartement,
        ),
      ),
    );
  }

  // ✅ PROPOSER UNE CATÉGORIE
  void _proposerCategorie(BuildContext context) {
    final TextEditingController categorieController = TextEditingController();
    final TextEditingController sousCategorieController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('💡 Proposer une catégorie'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Proposez une nouvelle catégorie à l\'administrateur',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: categorieController,
              decoration: const InputDecoration(
                labelText: 'Nom de la catégorie *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.folder),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: sousCategorieController,
              decoration: const InputDecoration(
                labelText: 'Sous-catégorie (optionnel)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.folder_open),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final categorie = categorieController.text.trim();
              if (categorie.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ Veuillez entrer un nom de catégorie'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              try {
                await _service.proposerSousCategorie(
                  categorie,
                  sousCategorieController.text.trim(),
                  widget.appartement,
                );
                
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Proposition envoyée à l\'administrateur'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
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
            child: const Text('Proposer'),
          ),
        ],
      ),
    );
  }

  // ✅ PROPOSER UNE PERSONNE
  void _proposerPersonneDialog(BuildContext context, String categorie, String sousCategorie) {
    final TextEditingController nomController = TextEditingController();
    final TextEditingController prenomController = TextEditingController();
    final TextEditingController telephoneController = TextEditingController();
    final TextEditingController adresseController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('💡 Proposer une personne'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      '📂 $categorie',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '📁 $sousCategorie',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: prenomController,
                decoration: const InputDecoration(
                  labelText: 'Prénom *',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nomController,
                decoration: const InputDecoration(
                  labelText: 'Nom *',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telephoneController,
                decoration: const InputDecoration(
                  labelText: 'Téléphone *',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: adresseController,
                decoration: const InputDecoration(
                  labelText: 'Adresse',
                  prefixIcon: Icon(Icons.home),
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'L\'administrateur sera notifié de votre proposition',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final prenom = prenomController.text.trim();
              final nom = nomController.text.trim();
              final telephone = telephoneController.text.trim();

              if (prenom.isEmpty || nom.isEmpty || telephone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ Veuillez remplir tous les champs obligatoires'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              try {
                final personne = Personne(
                  id: '',
                  nom: nom,
                  prenom: prenom,
                  telephone: telephone,
                  adresse: adresseController.text.trim(),
                  sousCategorie: sousCategorie,
                  categorie: categorie,
                  dateAjout: DateTime.now(),
                  ajoutePar: 'client_${widget.appartement}',
                );

                await _service.proposerPersonne(personne, widget.appartement);
                
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Personne proposée à l\'administrateur'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
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
            child: const Text('Proposer'),
          ),
        ],
      ),
    );
  }
}