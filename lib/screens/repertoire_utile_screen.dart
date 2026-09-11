// lib/screens/repertoire_utile_screen.dart
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/repertoire_model.dart';

class RepertoireUtileScreen extends StatefulWidget {
  const RepertoireUtileScreen({super.key});

  @override
  State<RepertoireUtileScreen> createState() => _RepertoireUtileScreenState();
}

class _RepertoireUtileScreenState extends State<RepertoireUtileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Categorie> _categories = [];
  bool _isLoading = true;
  String _searchQuery = '';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Répertoire Utile'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddCategoryDialog,
            tooltip: 'Ajouter une catégorie',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher une catégorie...',
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                hintStyle: const TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredCategories.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filteredCategories.length,
                  itemBuilder: (context, index) {
                    final categorie = _filteredCategories[index];
                    return _buildCategoryCard(categorie);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.category,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune catégorie trouvée',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez votre première catégorie',
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddCategoryDialog,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une catégorie'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(Categorie categorie) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
            color: Colors.blue.shade700,
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
          '${categorie.sousCategories.length} sous-catégories',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add, color: Colors.green),
              onPressed: () => _showAddSubCategoryDialog(categorie.nom),
              tooltip: 'Ajouter une sous-catégorie',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDeleteCategory(categorie.nom),
              tooltip: 'Supprimer la catégorie',
            ),
          ],
        ),
        children: [
          ...categorie.sousCategories.map((sous) {
            return ListTile(
              leading: const Icon(
                Icons.subdirectory_arrow_right,
                size: 16,
                color: Colors.grey,
              ),
              title: Text(sous.nom),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (sous.personnes.isNotEmpty)
                    Chip(
                      label: Text(
                        '${sous.personnes.length}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.green.shade100,
                    ),
                  IconButton(
                    icon: const Icon(Icons.person_add, size: 20),
                    onPressed: () => _showAddPersonDialog(categorie.nom, sous.nom),
                    tooltip: 'Ajouter une personne',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: () => _confirmDeleteSubCategory(categorie.nom, sous.nom),
                    tooltip: 'Supprimer',
                  ),
                ],
              ),
              onTap: () {
                _showSousCategorieDetail(sous);
              },
            );
          }).toList(),
        ],
      ),
    );
  }

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
                      IconButton(
                        icon: const Icon(Icons.person_add),
                        onPressed: () {
                          Navigator.pop(context);
                          // TODO: Implémenter l'ajout de personne
                        },
                        tooltip: 'Ajouter une personne',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (sousCategorie.personnes.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Aucune personne référencée dans cette catégorie',
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
                          return ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.person),
                            ),
                            title: Text(sousCategorie.personnes[index]),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                // TODO: Implémenter la suppression
                              },
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

  void _showAddCategoryDialog() {
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nouvelle catégorie'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Nom de la catégorie',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  await _firestoreService.addCategory(controller.text.trim());
                  Navigator.pop(context);
                  _loadCategories();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Catégorie "${controller.text}" ajoutée'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        );
      },
    );
  }

  void _showAddSubCategoryDialog(String categoryName) {
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Nouvelle sous-catégorie dans "$categoryName"'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Nom de la sous-catégorie',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  await _firestoreService.addSubCategory(categoryName, controller.text.trim());
                  Navigator.pop(context);
                  _loadCategories();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sous-catégorie "${controller.text}" ajoutée'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        );
      },
    );
  }

  void _showAddPersonDialog(String categoryName, String subCategoryName) {
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ajouter une personne'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ajouter à : $subCategoryName'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Nom de la personne',
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
                      content: Text('Personne "${controller.text}" ajoutée'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteCategory(String categoryName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer la catégorie'),
          content: Text('Voulez-vous vraiment supprimer la catégorie "$categoryName" ?'),
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
                    content: Text('Catégorie "$categoryName" supprimée'),
                    backgroundColor: Colors.red,
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
        );
      },
    );
  }

  void _confirmDeleteSubCategory(String categoryName, String subCategoryName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer la sous-catégorie'),
          content: Text('Voulez-vous vraiment supprimer "$subCategoryName" de "$categoryName" ?'),
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
                    content: Text('Sous-catégorie supprimée'),
                    backgroundColor: Colors.red,
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
        );
      },
    );
  }
}