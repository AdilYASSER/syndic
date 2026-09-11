// lib/services/database_service.dart
// ✅ Version corrigée - Supprimer la duplication

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/depense.dart';
import '../models/habitant.dart';
import '../models/cotisation.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;
  static bool _isInitialized = false;

  // ✅ Initialiser la base de données
  Future<void> initDatabase() async {
    if (_isInitialized) return;
    try {
      _database = await _initDatabase();
      _isInitialized = true;
      print('✅ Base de données initialisée avec succès');
    } catch (e) {
      print('❌ Erreur initialisation base de données: $e');
      _isInitialized = false;
    }
  }

  Future<Database> get database async {
    if (!_isInitialized || _database == null) {
      await initDatabase();
    }
    if (_database == null) {
      throw Exception('Base de données non initialisée');
    }
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      final path = await getDatabasesPath();
      final dbPath = join(path, 'syndic.db');

      return await openDatabase(
        dbPath,
        version: 2,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      print('❌ Erreur création base de données: $e');
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE depenses(
        id TEXT PRIMARY KEY,
        titre TEXT,
        montant REAL,
        date TEXT,
        categorie TEXT,
        beneficiaire TEXT,
        description TEXT,
        justificatifUrl TEXT,
        createdBy TEXT,
        createdAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE habitants(
        id TEXT PRIMARY KEY,
        nom TEXT,
        prenom TEXT,
        numAppartement TEXT,
        telephone TEXT,
        statut TEXT,
        rib TEXT,
        cinUrl TEXT,
        synced INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE cotisations(
        id TEXT PRIMARY KEY,
        numAppartement TEXT,
        nomPrenom TEXT,
        dateVersement TEXT,
        modeVersement TEXT,
        montant REAL,
        periode1 INTEGER,
        periode2 INTEGER,
        annee INTEGER,
        dateCreation TEXT,
        synced INTEGER,
        justificatifUrl TEXT,
        statut TEXT,
        appartement TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE cotisations ADD COLUMN justificatifUrl TEXT');
        await db.execute('ALTER TABLE cotisations ADD COLUMN statut TEXT');
        await db.execute('ALTER TABLE cotisations ADD COLUMN appartement TEXT');
        print('✅ Migration de la table cotisations effectuée');
      } catch (e) {
        print('⚠️ Erreur lors de la migration: $e');
      }
    }
  }

  // ============================================================
  // ============ DEPENSES ============
  // ============================================================
  
  Future<int> insertDepense(Depense depense) async {
    final db = await database;
    return await db.insert('depenses', {
      'id': depense.id ?? '',
      'titre': depense.titre,
      'montant': depense.montant,
      'date': depense.date.toIso8601String(),
      'categorie': depense.categorie,
      'beneficiaire': depense.beneficiaire,
      'description': depense.description,
      'justificatifUrl': depense.justificatifUrl,
      'createdBy': depense.createdBy,
      'createdAt': depense.createdAt.toIso8601String(),
    });
  }

  Future<List<Depense>> getDepenses() async {
    final db = await database;
    final result = await db.query('depenses', orderBy: 'date DESC');
    return result.map((map) {
      final id = map['id']?.toString() ?? '';
      return Depense.fromMap(id, map);
    }).toList();
  }

  Future<Depense?> getDepense(String id) async {
    final db = await database;
    final result = await db.query('depenses', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) {
      final idMap = result.first['id']?.toString() ?? '';
      return Depense.fromMap(idMap, result.first);
    }
    return null;
  }

  Future<int> updateDepense(Depense depense) async {
    final db = await database;
    return await db.update(
      'depenses',
      {
        'titre': depense.titre,
        'montant': depense.montant,
        'date': depense.date.toIso8601String(),
        'categorie': depense.categorie,
        'beneficiaire': depense.beneficiaire,
        'description': depense.description,
        'justificatifUrl': depense.justificatifUrl,
        'createdBy': depense.createdBy,
        'createdAt': depense.createdAt.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [depense.id],
    );
  }

  Future<int> deleteDepense(String id) async {
    final db = await database;
    return await db.delete('depenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllDepenses() async {
    final db = await database;
    await db.delete('depenses');
  }

  // ============================================================
  // ============ HABITANTS ============
  // ============================================================
  
  Future<int> insertHabitant(Habitant habitant) async {
    final db = await database;
    return await db.insert('habitants', {
      'id': habitant.id ?? '',
      'nom': habitant.nom,
      'prenom': habitant.prenom,
      'numAppartement': habitant.numAppartement,
      'telephone': habitant.telephone,
      'statut': habitant.statut,
      'rib': habitant.rib,
      'cinUrl': habitant.cinUrl,
      'synced': habitant.synced,
    });
  }

  Future<List<Habitant>> getHabitants() async {
    try {
      final db = await database;
      final result = await db.query('habitants', orderBy: 'numAppartement ASC');
      return result.map((map) => Habitant.fromMap(map)).toList();
    } catch (e) {
      print('❌ Erreur récupération habitants: $e');
      return [];
    }
  }

  Future<Habitant?> getHabitant(String id) async {
    final db = await database;
    final result = await db.query('habitants', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) {
      return Habitant.fromMap(result.first);
    }
    return null;
  }

  Future<Habitant?> getHabitantByAppartement(String numAppartement) async {
    final db = await database;
    final result = await db.query(
      'habitants', 
      where: 'numAppartement = ?', 
      whereArgs: [numAppartement]
    );
    if (result.isNotEmpty) {
      return Habitant.fromMap(result.first);
    }
    return null;
  }

  Future<int> updateHabitant(Habitant habitant) async {
    final db = await database;
    return await db.update(
      'habitants',
      {
        'nom': habitant.nom,
        'prenom': habitant.prenom,
        'numAppartement': habitant.numAppartement,
        'telephone': habitant.telephone,
        'statut': habitant.statut,
        'rib': habitant.rib,
        'cinUrl': habitant.cinUrl,
        'synced': habitant.synced,
      },
      where: 'id = ?',
      whereArgs: [habitant.id],
    );
  }

  Future<int> deleteHabitant(String id) async {
    final db = await database;
    return await db.delete('habitants', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllHabitants() async {
    final db = await database;
    await db.delete('habitants');
  }

  // ✅ Récupérer le nombre total d'habitants
  Future<int> getTotalCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM habitants');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ✅ Récupérer les statistiques par statut
  Future<Map<String, int>> getStatsByStatut() async {
    try {
      final db = await database;
      final result = await db.rawQuery('''
        SELECT statut, COUNT(*) as count 
        FROM habitants 
        GROUP BY statut
      ''');
      
      final Map<String, int> stats = {};
      for (var row in result) {
        final statut = row['statut']?.toString() ?? 'Inconnu';
        final count = row['count'] as int? ?? 0;
        stats[statut] = count;
      }
      return stats;
    } catch (e) {
      return {};
    }
  }

  // ✅ Récupérer tous les habitants
  Future<List<Habitant>> getAllHabitants() async {
    return await getHabitants();
  }

  // ============================================================
  // ============ COTISATIONS ============
  // ============================================================
  
  Future<int> insertCotisation(Cotisation cotisation) async {
    final db = await database;
    return await db.insert('cotisations', {
      'id': cotisation.id ?? '',
      'numAppartement': cotisation.numAppartement,
      'appartement': cotisation.appartement ?? cotisation.numAppartement,
      'nomPrenom': cotisation.nomPrenom,
      'dateVersement': cotisation.dateVersement?.toIso8601String(),
      'modeVersement': cotisation.modeVersement,
      'montant': cotisation.montant,
      'periode1': cotisation.periode1 ? 1 : 0,
      'periode2': cotisation.periode2 ? 1 : 0,
      'annee': cotisation.annee,
      'dateCreation': cotisation.dateCreation?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'synced': cotisation.synced,
      'justificatifUrl': cotisation.justificatifUrl,
      'statut': cotisation.statut ?? 'En attente',
    });
  }

  Future<List<Cotisation>> getCotisations() async {
    try {
      final db = await database;
      final result = await db.query('cotisations', orderBy: 'annee DESC, dateVersement DESC');
      return result.map((map) => Cotisation.fromMap(map)).toList();
    } catch (e) {
      print('❌ Erreur récupération cotisations: $e');
      return [];
    }
  }

  Future<List<Cotisation>> getCotisationsByAppartement(String numAppartement) async {
    final db = await database;
    final result = await db.query(
      'cotisations', 
      where: 'numAppartement = ?', 
      whereArgs: [numAppartement],
      orderBy: 'annee DESC, dateVersement DESC'
    );
    return result.map((map) => Cotisation.fromMap(map)).toList();
  }

  Future<List<Cotisation>> getCotisationsByYear(int annee) async {
    final db = await database;
    final result = await db.query(
      'cotisations', 
      where: 'annee = ?', 
      whereArgs: [annee],
      orderBy: 'dateVersement DESC'
    );
    return result.map((map) => Cotisation.fromMap(map)).toList();
  }

  Future<List<Cotisation>> getCotisationsByStatut(String statut) async {
    final db = await database;
    final result = await db.query(
      'cotisations', 
      where: 'statut = ?', 
      whereArgs: [statut],
      orderBy: 'annee DESC, dateVersement DESC'
    );
    return result.map((map) => Cotisation.fromMap(map)).toList();
  }

  Future<Cotisation?> getCotisation(String id) async {
    final db = await database;
    final result = await db.query('cotisations', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) {
      return Cotisation.fromMap(result.first);
    }
    return null;
  }

  Future<int> updateCotisation(Cotisation cotisation) async {
    final db = await database;
    return await db.update(
      'cotisations',
      {
        'numAppartement': cotisation.numAppartement,
        'appartement': cotisation.appartement ?? cotisation.numAppartement,
        'nomPrenom': cotisation.nomPrenom,
        'dateVersement': cotisation.dateVersement?.toIso8601String(),
        'modeVersement': cotisation.modeVersement,
        'montant': cotisation.montant,
        'periode1': cotisation.periode1 ? 1 : 0,
        'periode2': cotisation.periode2 ? 1 : 0,
        'annee': cotisation.annee,
        'dateCreation': cotisation.dateCreation?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'synced': cotisation.synced,
        'justificatifUrl': cotisation.justificatifUrl,
        'statut': cotisation.statut ?? 'En attente',
      },
      where: 'id = ?',
      whereArgs: [cotisation.id],
    );
  }

  Future<int> deleteCotisation(String id) async {
    final db = await database;
    return await db.delete('cotisations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllCotisations() async {
    final db = await database;
    await db.delete('cotisations');
  }

  Future<bool> cotisationExistsForPeriod(
    String numAppartement, 
    int annee, 
    bool periode1, 
    bool periode2
  ) async {
    final db = await database;
    String whereClause = 'numAppartement = ? AND annee = ?';
    List<dynamic> whereArgs = [numAppartement, annee];
    
    if (periode1) {
      whereClause += ' AND periode1 = 1';
    }
    if (periode2) {
      whereClause += ' AND periode2 = 1';
    }
    
    final result = await db.query(
      'cotisations',
      where: whereClause,
      whereArgs: whereArgs,
      limit: 1,
    );
    
    return result.isNotEmpty;
  }

  Future<Map<String, double>> getTotauxByStatut() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT statut, SUM(montant) as total 
      FROM cotisations 
      GROUP BY statut
    ''');
    
    final Map<String, double> totaux = {};
    for (var row in result) {
      final statut = row['statut']?.toString() ?? 'En attente';
      final total = (row['total'] as num?)?.toDouble() ?? 0;
      totaux[statut] = total;
    }
    return totaux;
  }

  // ============================================================
  // ============ SYNC ============
  // ============================================================
  
  Future<List<Map<String, dynamic>>> getUnsyncedItems(String table) async {
    final db = await database;
    return await db.query(table, where: 'synced = 0');
  }

  // ✅ UNE SEULE méthode markAsSynced (avec table)
  Future<void> markAsSynced(String table, String id) async {
    final db = await database;
    await db.update(
      table,
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ✅ Méthode spécifique pour les habitants (appelle la méthode générique)
  Future<void> markHabitantAsSynced(String id) async {
    await markAsSynced('habitants', id);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedHabitants() async {
    final db = await database;
    return await db.query('habitants', where: 'synced = 0');
  }

  Future<int> getUnsyncedCount(String table) async {
    final db = await database;
    final result = await db.query(
      table,
      where: 'synced = 0',
      columns: ['COUNT(*) as count'],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ============================================================
  // ============ STATISTIQUES ============
  // ============================================================
  
  Future<Map<String, dynamic>> getStats() async {
    final db = await database;
    
    final totalCotisations = await db.rawQuery('SELECT COUNT(*) as count FROM cotisations');
    final totalCount = Sqflite.firstIntValue(totalCotisations) ?? 0;
    
    final totalMontant = await db.rawQuery('SELECT SUM(montant) as total FROM cotisations');
    final totalAmount = (totalMontant.first['total'] as num?)?.toDouble() ?? 0;
    
    final payeCount = await db.rawQuery(
      "SELECT COUNT(*) as count FROM cotisations WHERE statut = 'Payé'"
    );
    final paye = Sqflite.firstIntValue(payeCount) ?? 0;
    
    final attenteCount = await db.rawQuery(
      "SELECT COUNT(*) as count FROM cotisations WHERE statut = 'En attente'"
    );
    final attente = Sqflite.firstIntValue(attenteCount) ?? 0;
    
    return {
      'totalCotisations': totalCount,
      'totalMontant': totalAmount,
      'paye': paye,
      'enAttente': attente,
    };
  }

  // ============================================================
  // ============ RECHERCHE ============
  // ============================================================
  
  Future<List<Cotisation>> searchCotisations({
    String? numAppartement,
    String? nomPrenom,
    int? annee,
    String? statut,
    bool? periode1,
    bool? periode2,
  }) async {
    final db = await database;
    
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];
    
    if (numAppartement != null && numAppartement.isNotEmpty) {
      whereClause += ' AND numAppartement LIKE ?';
      whereArgs.add('%$numAppartement%');
    }
    
    if (nomPrenom != null && nomPrenom.isNotEmpty) {
      whereClause += ' AND nomPrenom LIKE ?';
      whereArgs.add('%$nomPrenom%');
    }
    
    if (annee != null) {
      whereClause += ' AND annee = ?';
      whereArgs.add(annee);
    }
    
    if (statut != null && statut.isNotEmpty && statut != 'Tous') {
      whereClause += ' AND statut = ?';
      whereArgs.add(statut);
    }
    
    if (periode1 != null) {
      whereClause += ' AND periode1 = ?';
      whereArgs.add(periode1 ? 1 : 0);
    }
    
    if (periode2 != null) {
      whereClause += ' AND periode2 = ?';
      whereArgs.add(periode2 ? 1 : 0);
    }
    
    final result = await db.query(
      'cotisations',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'annee DESC, dateVersement DESC',
    );
    
    return result.map((map) => Cotisation.fromMap(map)).toList();
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('cotisations');
    await db.delete('depenses');
    await db.delete('habitants');
  }
}