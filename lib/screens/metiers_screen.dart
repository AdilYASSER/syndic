// lib/screens/metiers_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/repertoire_model.dart';
import '../services/firestore_service.dart';

class MetiersScreen extends StatefulWidget {
  const MetiersScreen({super.key});

  @override
  State<MetiersScreen> createState() => _MetiersScreenState();
}

class _MetiersScreenState extends State<MetiersScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Categorie> _categories = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _isAdmin = true; // À adapter selon votre logique

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    _categories = await _firestoreService.getCategories();
    setState(() => _isLoading = false);
  }

  List<Categorie> get _filteredCategories {
    if (_searchQuery.isEmpty) return _categories;
    return _categories.where((categorie) {
      return categorie.nom.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          categorie.sousCategories.any((sous) =>
              sous.nom.toLowerCase().contains(_searchQuery.toLowerCase()));
    }).toList();
  }

  // ✅ Même design que ReclamationsListScreen
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('📂 Gestion des Métiers'),
        backgroundColor: Colors.deepOrange.shade700,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
        actions: [
          // ✅ Indicateur Admin
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _isAdmin ? Colors.amber : Colors.green,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _isAdmin ? '👑 ADMIN' : '👤 CLIENT',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddCategoryDialog,
              tooltip: 'Ajouter une catégorie',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCategories,
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: Column(
        children: [
          // ✅ Barre de recherche (comme les réclamations)
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: '🔍 Rechercher une catégorie ou un métier...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCategories.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _filteredCategories.length,
                        itemBuilder: (context, index) {
                          final categorie = _filteredCategories[index];
                          return _buildCategoryCard(categorie);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // ✅ Même design que l'état vide des réclamations
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.work_outline, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Aucun métier trouvé',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez votre première catégorie de métiers',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          if (_isAdmin)
            ElevatedButton.icon(
              onPressed: _showAddCategoryDialog,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une catégorie'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange.shade700,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  // ✅ Carte de catégorie inspirée des réclamations
  Widget _buildCategoryCard(Categorie categorie) {
    final color = Colors.blue.shade700;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getCategoryIcon(categorie.nom),
            color: color,
          ),
        ),
        title: Text(
          categorie.nom,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${categorie.sousCategories.length} métier(s)',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isAdmin) ...[
              IconButton(
                icon: const Icon(Icons.add, color: Colors.green),
                onPressed: () => _showAddSubCategoryDialog(categorie.nom),
                tooltip: 'Ajouter un métier',
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _confirmDeleteCategory(categorie.nom),
                tooltip: 'Supprimer la catégorie',
              ),
            ],
          ],
        ),
        children: [
          // ✅ Liste des métiers avec le même style que les réclamations
          ...categorie.sousCategories.map((sous) {
            return _buildSubCategoryTile(categorie.nom, sous);
          }).toList(),
          if (_isAdmin)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Ajouter un nouveau métier...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        prefixIcon: Icon(Icons.add, size: 20),
                      ),
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          _addSubCategory(categorie.nom, value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      _showAddSubCategoryDialog(categorie.nom);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('Ajouter'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ✅ Tile de métier inspirée des réclamations
  Widget _buildSubCategoryTile(String categoryName, SousCategorie sousCategorie) {
    return ListTile(
      leading: const Icon(
        Icons.work,
        size: 20,
        color: Colors.grey,
      ),
      title: Text(
        sousCategorie.nom,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sousCategorie.description.isNotEmpty)
            Text(
              sousCategorie.description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          if (sousCategorie.personnes.isNotEmpty)
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: sousCategorie.personnes.map((personne) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    personne,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue.shade700,
                    ),
                  ),
                );
              }).toList(),
            ),
          // ✅ Indicateur d'utilisation dans les réclamations
          if (sousCategorie.estUtiliseDansReclamations ?? false)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '✓ Utilisé dans les réclamations',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      trailing: _isAdmin
          ? IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () => _confirmDeleteSubCategory(categoryName, sousCategorie.nom),
              tooltip: 'Supprimer ce métier',
            )
          : null,
      onTap: () {
        _showSousCategorieDetail(sousCategorie);
      },
    );
  }

  // ✅ Détail d'un métier (comme le détail d'une réclamation)
  void _showSousCategorieDetail(SousCategorie sousCategorie) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          sousCategorie.nom,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_isAdmin)
                        IconButton(
                          icon: const Icon(Icons.person_add),
                          onPressed: () => _showAddPersonDialog('', sousCategorie.nom),
                          tooltip: 'Ajouter une personne',
                        ),
                    ],
                  ),
                  if (sousCategorie.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        sousCategorie.description,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    '👥 Personnes référencées',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (sousCategorie.personnes.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Aucune personne référencée',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: sousCategorie.personnes.length,
                        itemBuilder: (context, index) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                child: Icon(Icons.person, color: Colors.blue.shade700),
                              ),
                              title: Text(sousCategorie.personnes[index]),
                              trailing: _isAdmin
                                  ? IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        // TODO: Supprimer la personne
                                      },
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ✅ Dialogues de gestion (comme les réclamations)
  void _showAddCategoryDialog() {
    final TextEditingController nomController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('➕ Nouvelle catégorie de métiers'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomController,
                decoration: const InputDecoration(
                  labelText: 'Nom de la catégorie *',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optionnelle)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
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
              if (nomController.text.isNotEmpty) {
                await _firestoreService.addCategory(
                  nomController.text.trim(),
                  description: descriptionController.text.trim(),
                );
                Navigator.pop(context);
                _loadCategories();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Catégorie "${nomController.text}" ajoutée'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _showAddSubCategoryDialog(String categoryName) {
    final TextEditingController nomController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController personnesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('➕ Ajouter un métier à "$categoryName"'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomController,
                decoration: const InputDecoration(
                  labelText: 'Nom du métier *',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optionnelle)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: personnesController,
                decoration: const InputDecoration(
                  labelText: 'Personnes (séparées par des virgules)',
                  hintText: 'Ex: Jean Dupont, Marie Martin',
                  border: OutlineInputBorder(),
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
              if (nomController.text.isNotEmpty) {
                final personnes = personnesController.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();

                await _firestoreService.addSubCategory(
                  categoryName,
                  nomController.text.trim(),
                  description: descriptionController.text.trim(),
                  personnes: personnes,
                );
                Navigator.pop(context);
                _loadCategories();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Métier "${nomController.text}" ajouté'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _addSubCategory(String categoryName, String subCategoryName) async {
    if (subCategoryName.trim().isNotEmpty) {
      await _firestoreService.addSubCategory(categoryName, subCategoryName.trim());
      _loadCategories();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Métier "$subCategoryName" ajouté'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showAddPersonDialog(String categoryName, String subCategoryName) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('👤 Ajouter une personne'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ajouter à : $subCategoryName',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Nom de la personne *',
                border: OutlineInputBorder(),
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
              if (controller.text.isNotEmpty) {
                await _firestoreService.addPersonToSubCategory(
                  categoryName,
                  subCategoryName,
                  controller.text.trim(),
                );
                Navigator.pop(context);
                _loadCategories();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Personne "${controller.text}" ajoutée'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(String categoryName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Supprimer la catégorie'),
        content: Text(
          'Voulez-vous vraiment supprimer la catégorie "$categoryName" ?\n\nTous les métiers associés seront également supprimés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _firestoreService.deleteCategory(categoryName);
              Navigator.pop(context);
              _loadCategories();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Catégorie "$categoryName" supprimée'),
                  backgroundColor: Colors.green,
                ),
              );
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

  void _confirmDeleteSubCategory(String categoryName, String subCategoryName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Supprimer le métier'),
        content: Text(
          'Voulez-vous vraiment supprimer "$subCategoryName" de "$categoryName" ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _firestoreService.deleteSubCategory(categoryName, subCategoryName);
              Navigator.pop(context);
              _loadCategories();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Métier "$subCategoryName" supprimé'),
                  backgroundColor: Colors.green,
                ),
              );
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

  // ✅ Icônes pour les catégories
  IconData _getCategoryIcon(String nom) {
    switch (nom) {
      case 'Santé':
        return Icons.health_and_safety;
      case 'Éducation':
        return Icons.school;
      case 'Bricolage':
        return Icons.build;
      case 'Sécurité':
        return Icons.security;
      case 'Services généraux':
        return Icons.room_service;
      case 'Automobile':
        return Icons.directions_car;
      case 'Alimentation':
        return Icons.restaurant;
      case 'Commerces':
        return Icons.store;
      case 'Immobilier':
        return Icons.home_work;
      case 'Services domestiques':
        return Icons.cleaning_services;
      case 'Électroménager & TV':
        return Icons.electrical_services;
      case 'Divertissement & Loisirs':
        return Icons.sports_esports;
      default:
        return Icons.category;
    }
  }
}