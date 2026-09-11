// lib/screens/admin/admin_repertoire_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/repertoire_service.dart';
import '../../models/repertoire_model.dart';
import 'admin_ajouter_personne.dart';
import '../repertoire/repertoire_detail_screen.dart';
import '../../services/categorie_import_service.dart';

class AdminRepertoireScreen extends StatefulWidget {
  const AdminRepertoireScreen({super.key});

  @override
  State<AdminRepertoireScreen> createState() => _AdminRepertoireScreenState();
}

class _AdminRepertoireScreenState extends State<AdminRepertoireScreen> {
  final RepertoireService _service = RepertoireService();
  final TextEditingController _newCategorieController = TextEditingController();
  final TextEditingController _newSousCategorieController = TextEditingController();
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('📋 Répertoire Utile'),
          backgroundColor: Colors.blue.shade800,
          foregroundColor: Colors.white,
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: '📂 Catégories'),
              Tab(text: '📥 Propositions'),
            ],
          ),
          actions: [
            // ✅ BOUTON D'IMPORTATION
            IconButton(
              icon: _isImporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download),
              onPressed: _isImporting ? null : _importerCategories,
              tooltip: 'Importer les catégories prédéfinies',
            ),
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: () async {
                await _service.debugPropositions();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🔍 Vérifiez la console pour les résultats'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              tooltip: 'Déboguer les propositions',
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _ajouterCategorieDialog,
              tooltip: 'Ajouter une catégorie',
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildCategoriesTab(),
            _buildPropositionsTab(),
          ],
        ),
      ),
    );
  }

  // ✅ MÉTHODE D'IMPORTATION (CORRIGÉE)
  Future<void> _importerCategories() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📥 Importer les catégories'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Cette action va importer toutes les catégories prédéfinies :',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Santé (13 sous-catégories)'),
            Text('• Éducation (10 sous-catégories)'),
            Text('• Bricolage (19 sous-catégories)'),
            Text('• Sécurité (7 sous-catégories)'),
            Text('• Services généraux (8 sous-catégories)'),
            Text('• Automobile (8 sous-catégories)'),
            Text('• Alimentation (10 sous-catégories)'),
            Text('• Commerces (10 sous-catégories)'),
            Text('• Immobilier (7 sous-catégories)'),
            Text('• Services domestiques (6 sous-catégories)'),
            Text('• Électroménager & TV (7 sous-catégories)'),
            Text('• Divertissement & Loisirs (10 sous-catégories)'),
            SizedBox(height: 12),
            Text(
              '⚠️ Les catégories existantes seront mises à jour',
              style: TextStyle(color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('📥 Importer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isImporting = true);

    try {
      final importer = CategorieImportService();
      final result = await importer.importerToutesCategories();

      String message = '✅ Importation terminée\n';
      message += '• ${result['imported']} créées\n';
      message += '• ${result['updated']} mises à jour';
      if (result['errors'] > 0) {
        message += '\n• ⚠️ ${result['errors']} erreurs';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: result['errors'] > 0 ? Colors.orange : Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
      
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isImporting = false);
    }
  }

  Widget _buildCategoriesTab() {
    return StreamBuilder<List<Categorie>>(
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
                const Text('Aucune catégorie'),
                const SizedBox(height: 8),
                Text(
                  'Cliquez sur 📥 pour importer les catégories prédéfinies',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isImporting ? null : _importerCategories,
                  icon: _isImporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.download),
                  label: const Text('Importer les catégories'),
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
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.orange),
              onPressed: () {
                _modifierCategorie(categorie.nom);
              },
              tooltip: 'Modifier la catégorie',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _supprimerCategorie(categorie.nom),
              tooltip: 'Supprimer la catégorie',
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _newSousCategorieController,
                    decoration: const InputDecoration(
                      hintText: 'Nouvelle sous-catégorie',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    _ajouterSousCategorie(categorie.nom);
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ajouter'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orange),
                      onPressed: () {
                        _modifierSousCategorie(categorie.nom, sousCategorie.nom);
                      },
                      tooltip: 'Modifier la sous-catégorie',
                    ),
                    IconButton(
                      icon: const Icon(Icons.person_add, color: Colors.green),
                      onPressed: () {
                        _ajouterPersonne(categorie.nom, sousCategorie.nom);
                      },
                      tooltip: 'Ajouter une personne',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        _supprimerSousCategorie(categorie.nom, sousCategorie.nom);
                      },
                      tooltip: 'Supprimer',
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

  void _modifierCategorie(String ancienNom) {
    final TextEditingController controller = TextEditingController(text: ancienNom);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✏️ Modifier la catégorie'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Entrez le nouveau nom de la catégorie',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Nouveau nom',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit),
              ),
              autofocus: true,
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
              final nouveauNom = controller.text.trim();
              if (nouveauNom.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ Veuillez entrer un nom'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              
              if (nouveauNom == ancienNom) {
                Navigator.pop(context);
                return;
              }
              
              try {
                await _service.modifierCategorie(ancienNom, nouveauNom);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Catégorie renommée en "$nouveauNom"'),
                    backgroundColor: Colors.green,
                  ),
                );
                setState(() {});
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Erreur: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  void _modifierSousCategorie(String categorieNom, String ancienNom) {
    final TextEditingController controller = TextEditingController(text: ancienNom);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✏️ Modifier la sous-catégorie'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Catégorie: $categorieNom',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 8),
            const Text(
              'Entrez le nouveau nom de la sous-catégorie',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Nouveau nom',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit),
              ),
              autofocus: true,
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
              final nouveauNom = controller.text.trim();
              if (nouveauNom.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ Veuillez entrer un nom'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              
              if (nouveauNom == ancienNom) {
                Navigator.pop(context);
                return;
              }
              
              try {
                await _service.modifierSousCategorie(categorieNom, ancienNom, nouveauNom);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Sous-catégorie renommée en "$nouveauNom"'),
                    backgroundColor: Colors.green,
                  ),
                );
                setState(() {});
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Erreur: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  Widget _buildPropositionsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _service.getPropositions(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final propositions = snapshot.data?.docs ?? [];
        if (propositions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('📭 Aucune proposition en attente'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: propositions.length,
          itemBuilder: (context, index) {
            final doc = propositions[index];
            final data = doc.data() as Map<String, dynamic>;
            final type = data['type'] ?? 'sous_categorie';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: type == 'sous_categorie' ? Colors.blue.shade100 : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            type == 'sous_categorie' ? '📂 Sous-catégorie' : '👤 Personne',
                            style: TextStyle(
                              fontSize: 10,
                              color: type == 'sous_categorie' ? Colors.blue.shade700 : Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Proposé par: ${data['proposePar'] ?? 'Client'}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (type == 'sous_categorie') ...[
                      Text('📂 Catégorie: ${data['categorie'] ?? 'N/A'}'),
                      Text('📁 Nom: ${data['nom'] ?? 'N/A'}'),
                    ] else ...[
                      Text('👤 Nom: ${data['prenom']} ${data['nom']}'),
                      Text('📞 Téléphone: ${data['telephone']}'),
                      if (data['adresse'] != null && data['adresse'].toString().isNotEmpty)
                        Text('📍 Adresse: ${data['adresse']}'),
                      Text('📂 Catégorie: ${data['categorie']}'),
                      Text('📁 Sous-catégorie: ${data['sousCategorie']}'),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => _rejeterProposition(doc.id),
                          child: const Text('Rejeter', style: TextStyle(color: Colors.red)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _approuverProposition(doc.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('✅ Approuver'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _ajouterCategorieDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter une catégorie'),
        content: TextField(
          controller: _newCategorieController,
          decoration: const InputDecoration(
            labelText: 'Nom de la catégorie',
            hintText: 'Ex: Santé, Éducation, Bricolage...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nom = _newCategorieController.text.trim();
              if (nom.isNotEmpty) {
                await _service.ajouterCategorie(nom);
                _newCategorieController.clear();
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _ajouterSousCategorie(String categorie) async {
    final nom = _newSousCategorieController.text.trim();
    if (nom.isNotEmpty) {
      await _service.ajouterSousCategorie(categorie, nom);
      _newSousCategorieController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Sous-catégorie "$nom" ajoutée'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _ajouterPersonne(String categorie, String sousCategorie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminAjouterPersonneScreen(
          categorie: categorie,
          sousCategorie: sousCategorie,
        ),
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
          isAdmin: true,
        ),
      ),
    );
  }

  Future<void> _supprimerCategorie(String nom) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation'),
        content: Text('Supprimer la catégorie "$nom" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _service.supprimerCategorie(nom);
    }
  }

  Future<void> _supprimerSousCategorie(String categorie, String sousCategorie) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation'),
        content: Text('Supprimer la sous-catégorie "$sousCategorie" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _service.supprimerSousCategorie(categorie, sousCategorie);
    }
  }

  Future<void> _approuverProposition(String id) async {
    await _service.approuverProposition(id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Proposition approuvée'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _rejeterProposition(String id) async {
    await _service.rejeterProposition(id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('❌ Proposition rejetée'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}